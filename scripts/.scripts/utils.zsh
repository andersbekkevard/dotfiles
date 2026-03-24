# VM browser (SOCKS proxy + Chrome, Ctrl+C to stop)
# Usage: vm-browse <host> [port]
vm-browse() {
  if [[ -z "$1" ]]; then
    echo "Usage: vm-browse <host> [port]"
    return 1
  fi
  local host="$1"
  local port="${2:-1080}"
  local chrome
  if [[ -f "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
    chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  else
    chrome="google-chrome"
  fi
  "$chrome" \
    --proxy-server="socks5://localhost:$port" \
    --proxy-bypass-list="<-loopback>" \
    --user-data-dir="$HOME/.chrome-vm-$host" \
    --no-first-run &>/dev/null &
  echo "Chrome launched -> proxy through $host:$port"
  echo "Ctrl+C to stop proxy"
  ssh -D "$port" -N "$host"
}

# Kill process running on a specific port
killport() {
  if [ -z "$1" ]; then
    echo "Usage: killport <port>"
    return 1
  fi
  local pid=$(lsof -ti tcp:"$1")
  if [ -n "$pid" ]; then
    kill -9 "$pid"
    echo "✓ Killed process $pid on port $1"
  else
    echo "No process found on port $1"
  fi
}

