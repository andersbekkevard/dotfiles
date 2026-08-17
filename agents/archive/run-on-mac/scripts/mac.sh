#!/usr/bin/env bash
set -euo pipefail

host=mac

usage() {
  cat <<'EOF'
Usage:
  mac.sh run COMMAND [ARG ...]
  mac.sh copy LOCAL_FILE [REMOTE_DIR]
  mac.sh copy-open LOCAL_FILE [REMOTE_DIR]
  mac.sh open-url URL
  mac.sh forward LOCAL_PORT [MAC_PORT] [--open]
  mac.sh forward-status MAC_PORT
  mac.sh forward-stop MAC_PORT
  mac.sh desktop-start [--url URL] [--profile-dir PATH] [--mac-port PORT]
  mac.sh desktop-status
  mac.sh desktop-stop
EOF
}

require_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" >= 1 && "$1" <= 65535 )) || {
    echo "Invalid port: $1" >&2
    exit 2
  }
}

control_socket() {
  printf '/tmp/codex-mac-forward-%s.sock' "$1"
}

open_on_mac() {
  local target=$1 remote_command
  printf -v remote_command 'open -a Comet -- %q' "$target"
  ssh "$host" "$remote_command"
}

desktop_root=${XDG_RUNTIME_DIR:-/tmp}/codex-run-on-mac-desktop
desktop_state=$desktop_root/state

port_in_use_local() {
  ss -ltnH "sport = :$1" 2>/dev/null | grep -q .
}

port_in_use_mac() {
  ssh "$host" -- lsof -nP -iTCP:"$1" -sTCP:LISTEN 2>/dev/null | grep -q .
}

choose_port() {
  local start=$1 side=$2 port
  for ((port=start; port<start+100; port++)); do
    if [[ "$side" == local ]]; then
      port_in_use_local "$port" || { printf '%s\n' "$port"; return; }
    else
      port_in_use_mac "$port" || { printf '%s\n' "$port"; return; }
    fi
  done
  echo "No unused port found from $start" >&2
  exit 1
}

find_chrome() {
  local candidate
  for candidate in chromium google-chrome chromium-browser; do
    command -v "$candidate" 2>/dev/null && return
  done
  if command -v node >/dev/null 2>&1; then
    candidate=$(node --input-type=module -e "import {chromium} from 'playwright'; console.log(chromium.executablePath())" 2>/dev/null || true)
    [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return; }
  fi
  candidate=$(find "${HOME}/.cache/ms-playwright" -type f -path '*/chrome-linux*/chrome' -perm -u+x 2>/dev/null | sort -V | tail -1)
  [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return; }
  echo "Chromium not found. Install Chromium or Playwright Chromium first." >&2
  exit 1
}

desktop_stop() {
  [[ -f "$desktop_state" ]] || { echo "No managed desktop is active"; return; }
  # shellcheck disable=SC1090
  source "$desktop_state"
  ssh -S "$(control_socket "$mac_port")" -O exit "$host" >/dev/null 2>&1 || true
  rm -f -- "$(control_socket "$mac_port")"
  systemctl --user stop "$unit" >/dev/null 2>&1 || true
  systemctl --user reset-failed "$unit" >/dev/null 2>&1 || true
  [[ ${temporary_profile:-false} == true ]] && rm -rf -- "$profile_dir"
  rm -f -- "$desktop_state"
  echo "Stopped Linux-host desktop and Mac tunnel"
}

command=${1:-}
case "$command" in
  run)
    shift
    (($# > 0)) || { usage >&2; exit 2; }
    exec ssh "$host" -- "$@"
    ;;
  copy|copy-open)
    shift
    (($# >= 1 && $# <= 2)) || { usage >&2; exit 2; }
    local_file=$1
    remote_dir=${2:-Downloads/Codex}
    [[ -f "$local_file" ]] || { echo "File not found: $local_file" >&2; exit 2; }
    basename=${local_file##*/}
    ssh "$host" mkdir -p -- "$remote_dir"
    scp -- "$local_file" "$host:$remote_dir/$basename"
    echo "Copied to ~/$remote_dir/$basename"
    if [[ "$command" == copy-open ]]; then
      open_on_mac "$remote_dir/$basename"
    fi
    ;;
  open-url)
    (($# == 2)) || { usage >&2; exit 2; }
    open_on_mac "$2"
    ;;
  forward)
    (($# >= 2 && $# <= 4)) || { usage >&2; exit 2; }
    local_port=$2
    mac_port=${3:-$local_port}
    open_after=false
    [[ ${3:-} != --open ]] || mac_port=$local_port
    [[ ${3:-} == --open || ${4:-} == --open ]] && open_after=true
    require_port "$local_port"
    require_port "$mac_port"
    socket=$(control_socket "$mac_port")
    if ssh -S "$socket" -O check "$host" >/dev/null 2>&1; then
      echo "Tunnel already active on Mac localhost:$mac_port" >&2
      exit 1
    fi
    rm -f -- "$socket"
    ssh -M -S "$socket" -fnNT \
      -o ExitOnForwardFailure=yes \
      -R "127.0.0.1:$mac_port:127.0.0.1:$local_port" \
      "$host"
    ssh -S "$socket" -O check "$host"
    echo "Mac http://127.0.0.1:$mac_port -> Linux host 127.0.0.1:$local_port"
    if [[ "$open_after" == true ]]; then
      open_on_mac "http://127.0.0.1:$mac_port"
    fi
    ;;
  forward-status)
    (($# == 2)) || { usage >&2; exit 2; }
    require_port "$2"
    ssh -S "$(control_socket "$2")" -O check "$host"
    ;;
  forward-stop)
    (($# == 2)) || { usage >&2; exit 2; }
    require_port "$2"
    socket=$(control_socket "$2")
    ssh -S "$socket" -O exit "$host"
    rm -f -- "$socket"
    ;;
  desktop-start)
    shift
    url=https://example.com
    profile_dir=
    requested_mac_port=
    while (($#)); do
      case "$1" in
        --url) (($# >= 2)) || { usage >&2; exit 2; }; url=$2; shift 2 ;;
        --profile-dir) (($# >= 2)) || { usage >&2; exit 2; }; profile_dir=$2; shift 2 ;;
        --mac-port) (($# >= 2)) || { usage >&2; exit 2; }; requested_mac_port=$2; shift 2 ;;
        *) echo "Unknown desktop-start option: $1" >&2; usage >&2; exit 2 ;;
      esac
    done
    [[ "$url" =~ ^https?:// ]] || { echo "desktop URL must use http or https" >&2; exit 2; }
    [[ ! -f "$desktop_state" ]] || { echo "A managed desktop is already active; run desktop-status or desktop-stop" >&2; exit 1; }
    missing=()
    for dependency in Xvfb xdpyinfo x11vnc websockify systemd-run ss; do
      command -v "$dependency" >/dev/null 2>&1 || missing+=("$dependency")
    done
    if ((${#missing[@]})); then
      echo "Missing desktop dependencies: ${missing[*]}" >&2
      echo "Ubuntu install command: sudo apt-get install xvfb x11-utils x11vnc novnc websockify" >&2
      exit 1
    fi
    chrome=$(find_chrome)
    mkdir -p -- "$desktop_root"
    chmod 700 -- "$desktop_root"
    display_num=
    for n in {99..119}; do
      [[ ! -e "/tmp/.X11-unix/X$n" ]] && { display_num=$n; break; }
    done
    [[ -n "$display_num" ]] || { echo "No unused X display found" >&2; exit 1; }
    display=:$display_num
    vnc_port=$(choose_port 5901 local)
    web_port=$(choose_port 6080 local)
    mac_port=${requested_mac_port:-$(choose_port 6080 mac)}
    require_port "$mac_port"
    session_id="${display_num}-${web_port}"
    unit="codex-run-on-mac-desktop-$session_id.service"
    log_dir="$desktop_root/$session_id"
    temporary_profile=false
    if [[ -z "$profile_dir" ]]; then
      profile_dir="$log_dir/profile"
      temporary_profile=true
    else
      profile_dir=$(realpath -m -- "$profile_dir")
    fi
    helper=$(realpath -- "$(dirname -- "$0")/remote-desktop-session.sh")
    systemd-run --user --unit="$unit" --collect --quiet -- \
      "$helper" "$display" "$vnc_port" "$web_port" "$chrome" "$profile_dir" "$url" "$log_dir"
    ready=false
    for _ in {1..100}; do
      curl -sSf "http://127.0.0.1:$web_port/vnc.html" >/dev/null 2>&1 && { ready=true; break; }
      systemctl --user is-active --quiet "$unit" || break
      sleep 0.1
    done
    if [[ "$ready" != true ]]; then
      systemctl --user status "$unit" --no-pager >&2 || true
      systemctl --user stop "$unit" >/dev/null 2>&1 || true
      exit 1
    fi
    socket=$(control_socket "$mac_port")
    rm -f -- "$socket"
    ssh -M -S "$socket" -fnNT -o ExitOnForwardFailure=yes \
      -R "127.0.0.1:$mac_port:127.0.0.1:$web_port" "$host"
    viewer_url="http://127.0.0.1:$mac_port/vnc.html?autoconnect=1&resize=scale"
    open_on_mac "$viewer_url"
    cat >"$desktop_state" <<EOF
unit=$(printf '%q' "$unit")
display=$(printf '%q' "$display")
vnc_port=$(printf '%q' "$vnc_port")
web_port=$(printf '%q' "$web_port")
mac_port=$(printf '%q' "$mac_port")
profile_dir=$(printf '%q' "$profile_dir")
temporary_profile=$(printf '%q' "$temporary_profile")
url=$(printf '%q' "$url")
log_dir=$(printf '%q' "$log_dir")
viewer_url=$(printf '%q' "$viewer_url")
EOF
    chmod 600 -- "$desktop_state"
    echo "Desktop active: $url"
    echo "Viewer on Mac: $viewer_url"
    echo "Stop with: $0 desktop-stop"
    ;;
  desktop-status)
    [[ -f "$desktop_state" ]] || { echo "No managed desktop is active"; exit 1; }
    # shellcheck disable=SC1090
    source "$desktop_state"
    systemctl --user is-active "$unit"
    ssh -S "$(control_socket "$mac_port")" -O check "$host"
    curl -sSf "http://127.0.0.1:$web_port/vnc.html" >/dev/null
    echo "Display: $display"
    echo "URL: $url"
    echo "Viewer on Mac: $viewer_url"
    echo "Logs: $log_dir"
    ;;
  desktop-stop)
    (($# == 1)) || { usage >&2; exit 2; }
    desktop_stop
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
