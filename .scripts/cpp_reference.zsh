cppr() {
  cd ~/dev/c/cppreference-doc/local_website/reference/ || return 1
  python3 -m http.server 8000
}