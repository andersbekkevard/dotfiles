#!/usr/bin/env bash
set -euo pipefail

if (($# != 7)); then
  echo "usage: remote-desktop-session.sh DISPLAY VNC_PORT WEB_PORT CHROME PROFILE_DIR URL LOG_DIR" >&2
  exit 2
fi

display=$1
vnc_port=$2
web_port=$3
chrome=$4
profile_dir=$5
url=$6
log_dir=$7

mkdir -p -- "$profile_dir" "$log_dir"
chmod 700 -- "$profile_dir" "$log_dir"

Xvfb "$display" -screen 0 1440x1200x24 -nolisten tcp >"$log_dir/xvfb.log" 2>&1 &
xvfb_pid=$!

cleanup() {
  kill "${browser_pid:-}" "${web_pid:-}" "${vnc_pid:-}" "$xvfb_pid" 2>/dev/null || true
  wait "${browser_pid:-}" "${web_pid:-}" "${vnc_pid:-}" "$xvfb_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

for _ in {1..50}; do
  DISPLAY="$display" xdpyinfo >/dev/null 2>&1 && break
  sleep 0.1
done
DISPLAY="$display" xdpyinfo >/dev/null 2>&1 || { echo "Xvfb did not become ready" >&2; exit 1; }

x11vnc -display "$display" -localhost -nopw -forever -shared -rfbport "$vnc_port" >"$log_dir/x11vnc.log" 2>&1 &
vnc_pid=$!
websockify --web=/usr/share/novnc "127.0.0.1:$web_port" "127.0.0.1:$vnc_port" >"$log_dir/websockify.log" 2>&1 &
web_pid=$!

DISPLAY="$display" "$chrome" \
  --no-sandbox \
  --user-data-dir="$profile_dir" \
  --no-first-run \
  --disable-dev-shm-usage \
  --window-size=1440,1200 \
  "$url" >"$log_dir/browser.log" 2>&1 &
browser_pid=$!

wait "$browser_pid"
