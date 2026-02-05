#!/bin/bash
#
# Server Mode Toggle
# ========================================
# Configures this ThinkPad as a headless server:
#   - No suspend on lid close
#   - Battery charge capped at 80%
#   - TLP power management tuned for AC
#
# Usage:
#   server-mode on      Enable server mode
#   server-mode off     Restore laptop defaults
#   server-mode status  Show current state
#
# Requires: tlp, sudo
#

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

log()   { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }
info()  { echo -e "${CYAN}[i]${NC} $1"; }

has() { command -v "$1" &>/dev/null; }

as_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# =============================================================================
# CONSTANTS
# =============================================================================

readonly LOGIND_CONF="/etc/systemd/logind.conf"
readonly LOGIND_DROP="/etc/systemd/logind.conf.d/server-mode.conf"
readonly TLP_DROP="/etc/tlp.d/01-server-mode.conf"
readonly CHARGE_STOP=80
readonly CHARGE_START=75

# =============================================================================
# FUNCTIONS
# =============================================================================

preflight() {
    has tlp || error "tlp is not installed. Run: sudo apt install tlp tlp-rdw"
    [[ -f /sys/class/power_supply/BAT0/charge_control_end_threshold ]] || error "No battery threshold support found"
}

enable_server_mode() {
    preflight
    echo -e "${BOLD}Enabling server mode...${NC}"

    # --- Lid close: ignore (no suspend) ---
    log "Setting lid close action to ignore"
    as_root mkdir -p /etc/systemd/logind.conf.d
    as_root tee "$LOGIND_DROP" > /dev/null <<EOF
# Managed by server-mode script
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
    as_root systemctl restart systemd-logind 2>/dev/null || warn "Could not restart logind (session may need re-login)"

    # --- Battery charge threshold: 80% ---
    log "Setting battery charge threshold to ${CHARGE_STOP}%"
    as_root tee "$TLP_DROP" > /dev/null <<EOF
# Managed by server-mode script
START_CHARGE_THRESH_BAT0=${CHARGE_START}
STOP_CHARGE_THRESH_BAT0=${CHARGE_STOP}
EOF
    as_root tlp start > /dev/null 2>&1
    log "TLP reloaded"

    # --- Verify ---
    local current_threshold
    current_threshold=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo "?")
    if [[ "$current_threshold" == "$CHARGE_STOP" ]]; then
        log "Battery threshold confirmed: ${current_threshold}%"
    else
        warn "Threshold reads ${current_threshold}% (may update after TLP settles)"
    fi

    echo ""
    log "Server mode ${GREEN}enabled${NC}"
    info "Lid close: ignore | Battery cap: ${CHARGE_STOP}%"
}

disable_server_mode() {
    echo -e "${BOLD}Disabling server mode...${NC}"

    # --- Restore lid close behavior ---
    if [[ -f "$LOGIND_DROP" ]]; then
        log "Removing lid close override"
        as_root rm -f "$LOGIND_DROP"
        as_root systemctl restart systemd-logind 2>/dev/null || warn "Could not restart logind"
    else
        info "Lid close override already absent"
    fi

    # --- Restore battery threshold ---
    if [[ -f "$TLP_DROP" ]]; then
        log "Removing battery threshold override"
        as_root rm -f "$TLP_DROP"
        as_root tlp start > /dev/null 2>&1
    else
        info "Battery threshold override already absent"
    fi

    echo ""
    log "Server mode ${YELLOW}disabled${NC}"
    info "Lid close: suspend (default) | Battery cap: 100% (default)"
}

show_status() {
    echo -e "${BOLD}Server mode status${NC}"
    echo ""

    # Lid policy
    local lid_policy
    lid_policy=$(loginctl show-session "$(loginctl --no-legend | awk 'NR==1{print $1}')" -p HandleLidSwitch 2>/dev/null | cut -d= -f2 || echo "unknown")
    if [[ -f "$LOGIND_DROP" ]]; then
        info "Lid close:         ${GREEN}ignore${NC} (server mode)"
    else
        info "Lid close:         ${YELLOW}suspend${NC} (default)"
    fi

    # Battery threshold
    local threshold
    threshold=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo "?")
    if [[ -f "$TLP_DROP" ]]; then
        info "Battery cap:       ${GREEN}${threshold}%${NC} (server mode)"
    else
        info "Battery cap:       ${YELLOW}${threshold}%${NC} (default)"
    fi

    # Battery level
    local capacity
    capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "?")
    local status
    status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "?")
    info "Battery:           ${capacity}% (${status})"

    # TLP (runs on boot/power events then exits — "inactive" is normal)
    if systemctl is-enabled tlp &>/dev/null; then
        info "TLP:               ${GREEN}enabled${NC} (runs on boot + power events)"
    else
        info "TLP:               ${RED}not enabled${NC} — run: sudo systemctl enable tlp"
    fi

    # Temps
    if has sensors; then
        local temp
        temp=$(sensors 2>/dev/null | grep -m1 "Package id 0:" | awk '{print $4}' || echo "?")
        info "CPU temp:          ${temp}"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

case "${1:-status}" in
    on|enable)   enable_server_mode ;;
    off|disable) disable_server_mode ;;
    status)      show_status ;;
    *)
        echo "Usage: server-mode {on|off|status}"
        exit 1
        ;;
esac
