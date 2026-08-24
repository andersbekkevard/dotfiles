#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RAINDROP="$REPO_ROOT/scripts/.local/bin/raindrop"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TEMP_DIR/bin" "$TEMP_DIR/home"
cat > "$TEMP_DIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$RAINDROP_TEST_CAPTURE"
printf '{"result":true}\n'
EOF
chmod +x "$TEMP_DIR/bin/curl"

[[ "$($RAINDROP --version)" == 'raindrop 0.1.0' ]] || fail 'version output'
$RAINDROP --help | grep -q 'raindrop request <method> <path>' || fail 'help output'

RAINDROP_TEST_CAPTURE="$TEMP_DIR/capture" \
RAINDROP_API_TOKEN='test-token' \
PATH="$TEMP_DIR/bin:/usr/bin:/bin" \
HOME="$TEMP_DIR/home" \
  "$RAINDROP" request GET /collections/all >/dev/null

grep -q '^Authorization: Bearer test-token$' "$TEMP_DIR/capture" || fail 'auth header'
grep -q '^https://api.raindrop.io/rest/v1/collections/all$' "$TEMP_DIR/capture" || fail 'API URL'

if RAINDROP_API_TOKEN='test-token' "$RAINDROP" request GET https://example.com >/dev/null 2>&1; then
  fail 'absolute URL accepted'
fi

printf 'raindrop contracts: ok\n'
