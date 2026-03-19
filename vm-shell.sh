#!/bin/bash
set -e

# --- Configuration & Variables ---
USER="azureuser"
CLOUD_IP="20.90.75.243"
EDGE_IP="40.120.43.27"

# --- UI Helpers ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e " ${BLUE}${BOLD}i${BLUE} $1${NC}"; }
log_success() { echo -e " ${GREEN}${BOLD}✓${NC} ${GREEN}$1${NC}"; }
log_warn()    { echo -e " ${YELLOW}${BOLD}⚠${YELLOW} $1${NC}"; }

# --- Machine Detection ---
# Checks which directory structure exists to determine the current machine
LENOVO_DIR="$HOME/github-projects/uni/sem2/comp5123m"
LAB_DIR="$HOME/github-projects/uni/comp5123m"

if [ -d "$LENOVO_DIR" ]; then
    BASE_DIR="$LENOVO_DIR"
    log_info "Detected Personal Machine (Lenovo)."
elif [ -d "$LAB_DIR" ]; then
    BASE_DIR="$LAB_DIR"
    log_info "Detected Lab Machine."
else
    log_warn "Could not detect standard project directories."
    echo "Please ensure you are running this from the correct machine."
    exit 1
fi

# --- Pre-Flight Checks ---
log_info "Checking current Public IP (for Azure NSG Whitelisting):"
PUBLIC_IP=$(curl -s ifconfig.me)
echo -e "  > ${BOLD}$PUBLIC_IP${NC}\n"

# --- Reusable SSH Function ---
connect_vm() {
    local vm_name="$1"
    local key_file="$BASE_DIR/$2"
    local target_ip="$3"

    if [ ! -f "$key_file" ]; then
        log_warn "Key file not found at: $key_file"
        echo "Ensure you have copied the .pem file to this machine."
        read -p "Press enter to return to menu..."
        return
    fi

    # Ensure strict permissions to satisfy SSH requirements
    chmod 400 "$key_file"

    log_info "Connecting to $vm_name ($target_ip)..."
    ssh -i "$key_file" "${USER}@${target_ip}"
}

# --- Interactive Menu ---
show_menu() {
    echo -e "${CYAN}${BOLD}🖥️  AZURE VM CONNECTION MANAGER${NC}"
    echo -e "---------------------------------------------------"
    echo -e "  1) Connect to Cloud Server (vm-ab)"
    echo -e "  2) Connect to Edge Client  (vm-edge)"
    echo -e "  3) Open Prometheus Web UI  (Firefox)"
    echo -e "  4) Open Grafana Web UI     (Firefox)"
    echo -e "  q) Quit"
    echo -ne "\n  Select an option: "

    read -r opt
    case $opt in
        1)
            connect_vm "Cloud VM" "vm-ab_key.pem" "$CLOUD_IP"
            ;;
        2)
            connect_vm "Edge VM" "vm-edge_key.pem" "$EDGE_IP"
            ;;
        3)
            log_info "Launching Prometheus in Firefox..."
            # Runs Firefox as a background process silently
            firefox "http://${CLOUD_IP}:9090/query" &>/dev/null &
            sleep 1
            ;;
        4)
            log_info "Launching Grafana in Firefox..."
            firefox "http://${CLOUD_IP}:3000" &>/dev/null &
            sleep 1
            ;;
        q|quit|exit)
            log_success "Exiting..."; exit 0
            ;;
        *)
            echo -e "Invalid option.\n"; show_menu
            ;;
    esac

    # Loop back to menu automatically after the SSH session closes
    echo ""
    show_menu
}

# Start script
show_menu

# pass for grafana
# nLpY9FM%8t'V~^2

# user, pass and PAT for docker registry
# scab1001
# $:tyjcVSFL8>~hF