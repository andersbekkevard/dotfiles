#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLEET="$REPO_ROOT/scripts/.local/bin/fleet"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

make_key() {
  ssh-keygen -q -t ed25519 -N '' -f "$1"
}

test_target_install_is_restricted_and_idempotent() {
  local home="$TEST_ROOT/target-home" key="$TEST_ROOT/target-key" output
  mkdir -p "$home"
  make_key "$key"

  output="$(HOME="$home" "$FLEET" enroll-install-key devbox-test <"$key.pub")"
  [[ "$output" == client-key\ installed* ]] || fail "first target install did not report installed"
  output="$(HOME="$home" "$FLEET" enroll-install-key devbox-test <"$key.pub")"
  [[ "$output" == client-key\ unchanged* ]] || fail "second target install was not idempotent"
  [[ "$(stat -c '%a' "$home/.ssh")" == "700" ]] || fail "target .ssh mode is not 700"
  [[ "$(stat -c '%a' "$home/.ssh/authorized_keys")" == "600" ]] || fail "authorized_keys mode is not 600"
  grep -Eq '^from="100\.64\.0\.0/10,fd7a:115c:a1e0::/48",no-agent-forwarding,no-X11-forwarding,no-pty ssh-ed25519 [^ ]+ fleet:devbox-test$' \
    "$home/.ssh/authorized_keys" || fail "target key is missing the Fleet restrictions"
  [[ "$(grep -c 'fleet:devbox-test' "$home/.ssh/authorized_keys")" == "1" ]] ||
    fail "idempotent target install duplicated the key"
}

test_target_install_refuses_silent_rotation() {
  local home="$TEST_ROOT/rotation-home" first="$TEST_ROOT/rotation-first" second="$TEST_ROOT/rotation-second"
  mkdir -p "$home"
  make_key "$first"
  make_key "$second"
  HOME="$home" "$FLEET" enroll-install-key devbox-test <"$first.pub" >/dev/null
  if HOME="$home" "$FLEET" enroll-install-key devbox-test <"$second.pub" >"$TEST_ROOT/rotation.out" 2>&1; then
    fail "target install silently rotated an enrolled machine key"
  fi
  grep -Fq "already has a different enrolled key" "$TEST_ROOT/rotation.out" ||
    fail "target install returned the wrong rotation failure"
}

write_fake_tailscale() {
  local directory="$1"
  mkdir -p "$directory"
  cat >"$directory/tailscale" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  status)
    printf '%s\n' '{"BackendState":"Running","Self":{"UserID":42,"HostName":"devbox-test"}}'
    ;;
  whois)
    printf '{"Node":{"User":%s,"MachineAuthorized":true,"Tags":[],"Hostinfo":{"Hostname":"devbox-test"}}}\n' "${FLEET_TEST_WHOIS_USER:-42}"
    ;;
  ssh)
    cat >"$FLEET_TEST_TAILSCALE_KEY"
    printf '%s\n' "$*" >>"$FLEET_TEST_TAILSCALE_LOG"
    ;;
  *) exit 2 ;;
esac
EOF
  chmod +x "$directory/tailscale"
}

test_registrar_verifies_tailnet_owner_before_installing() {
  local home="$TEST_ROOT/registrar-home" mac_home="$TEST_ROOT/registrar-mac-home" key="$TEST_ROOT/registrar-key" fake_bin="$TEST_ROOT/registrar-bin"
  mkdir -p "$home" "$mac_home" "$fake_bin"
  make_key "$key"
  write_fake_tailscale "$fake_bin"
  cat >"$fake_bin/fleet" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FLEET_TEST_FLEET_LOG"
if [[ "$1" == "mac" && "$2" == "run" && "$3" == "--" ]]; then
  shift 3
  HOME="$FLEET_TEST_MAC_HOME" "$@"
fi
EOF
  chmod +x "$fake_bin/fleet"

  HOME="$home" \
    PATH="$fake_bin:/usr/bin:/bin" \
    SSH_CONNECTION="100.64.0.9 54321 100.100.56.45 22" \
    FLEET_TEST_FLEET_LOG="$TEST_ROOT/registrar-fleet.log" \
    FLEET_TEST_MAC_HOME="$mac_home" \
    "$FLEET" enroll-authorize <"$key.pub" >/dev/null

  [[ "$(awk '{ print $2 }' "$key.pub")" == "$(awk '{ print $3 }' "$mac_home/.ssh/authorized_keys")" ]] ||
    fail "registrar did not install the exact key on the Mac"
  grep -Fq 'fleet:devbox-test' "$mac_home/.ssh/authorized_keys" || fail "registrar did not label the Mac key"
  grep -Fq 'fleet:devbox-test' "$home/.ssh/authorized_keys" || fail "registrar did not install the key locally"

  if HOME="$TEST_ROOT/rejected-home" \
    PATH="$fake_bin:/usr/bin:/bin" \
    SSH_CONNECTION="100.64.0.10 54321 100.100.56.45 22" \
    FLEET_TEST_WHOIS_USER=99 \
    FLEET_TEST_FLEET_LOG="$TEST_ROOT/rejected-fleet.log" \
    FLEET_TEST_MAC_HOME="$TEST_ROOT/rejected-mac-home" \
    "$FLEET" enroll-authorize <"$key.pub" >"$TEST_ROOT/rejected.out" 2>&1; then
    fail "registrar accepted a key from another Tailnet owner"
  fi
  grep -Fq "not owned by the registrar's Tailnet user" "$TEST_ROOT/rejected.out" ||
    fail "registrar returned the wrong owner failure"
  [[ ! -e "$TEST_ROOT/rejected-home/.ssh/authorized_keys" ]] ||
    fail "registrar changed authorized_keys before owner verification"
}

test_client_enroll_uses_dedicated_identity_and_verifies_targets() {
  local home="$TEST_ROOT/client-home" fake_bin="$TEST_ROOT/client-bin" config="$TEST_ROOT/client-machines.tsv"
  mkdir -p "$home" "$fake_bin"
  write_fake_tailscale "$fake_bin"
  cat >"$fake_bin/ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FLEET_TEST_SSH_LOG"
printf 'remote-ok\n'
EOF
  chmod +x "$fake_bin/ssh"
  cat >"$fake_bin/hostname" <<'EOF'
#!/usr/bin/env bash
printf 'devbox-test\n'
EOF
  chmod +x "$fake_bin/hostname"
  cat >"$config" <<'EOF'
europa	anders@europa	europa-target	-
mac	andersbekkevard@mac.tailnet.example	mac-target	open
EOF
  : >"$TEST_ROOT/client-known-hosts"

  HOME="$home" \
    PATH="$fake_bin:/usr/bin:/bin" \
    FLEET_CONFIG="$config" \
    FLEET_LOCAL_CONFIG='' \
    FLEET_KNOWN_HOSTS="$TEST_ROOT/client-known-hosts" \
    FLEET_TEST_TAILSCALE_KEY="$TEST_ROOT/client-enrollment-key" \
    FLEET_TEST_TAILSCALE_LOG="$TEST_ROOT/client-tailscale.log" \
    FLEET_TEST_SSH_LOG="$TEST_ROOT/client-ssh.log" \
    "$FLEET" enroll >"$TEST_ROOT/client.out"

  [[ -f "$home/.ssh/fleet_ed25519" ]] || fail "client enrollment did not create its dedicated identity"
  cmp -s "$home/.ssh/fleet_ed25519.pub" "$TEST_ROOT/client-enrollment-key" ||
    fail "client enrollment did not send its exact public key"
  [[ "$(grep -c 'IdentityFile=' "$TEST_ROOT/client-ssh.log")" == "2" ]] ||
    fail "post-enrollment checks did not use the dedicated identity"
  grep -Fq 'enrolled machine=devbox-test' "$TEST_ROOT/client.out" ||
    fail "client enrollment did not report its verified machine"
}

test_target_install_is_restricted_and_idempotent
test_target_install_refuses_silent_rotation
test_registrar_verifies_tailnet_owner_before_installing
test_client_enroll_uses_dedicated_identity_and_verifies_targets

printf 'fleet enrollment contracts: ok\n'
