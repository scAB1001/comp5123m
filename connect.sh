#!/bin/bash
set -e

# --- Configuration & Colours ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_ROOT=$(pwd)

log_info()    { echo -e " ${BLUE}${BOLD}i${BLUE} $1${NC}"; }
log_data()    { echo -e " ${NC}${BOLD}  >${NC} $1${NC}"; }
log_success() { echo -e " ${GREEN}${BOLD}✓${NC} ${GREEN}$1${NC}"; }
log_warn()    { echo -e " ${YELLOW}${BOLD}⚠${YELLOW} $1${NC}"; }
log_error()   { echo -e " ${RED}${BOLD}✗${NC} ${RED}$1${NC}"; }
opt()         { echo -e "${CYAN}$1${NC}"; }

# --- Environment Setup ---
load_env() {
    local env_file="${PROJECT_ROOT}/.env"
    if [ -f "$env_file" ]; then
        log_info "Loading configurations from .env file..."
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ ! "$line" =~ ^\s*# ]] && [[ -n "$line" ]]; then
                clean_line=$(echo "$line" | sed 's/\s*#.*$//' | tr -d '\r')
                export "$clean_line"
            fi
        done < "$env_file"
    else
        log_warn "No .env file found at $env_file!"
        echo "Copy .env and fill in your Azure VM details."
        exit 1
    fi
}

# --- SSH Function ---
connect_vm() {
    local vm_name="$1"
    local key_file="${PROJECT_ROOT}/$2"
    local target_ip="$3"

    if [ ! -f "$key_file" ]; then
        log_warn "Key file not found at: $key_file"
        echo "Ensure you have copied the .pem file to the project root."
        return 1
    fi

    chmod 400 "$key_file"
    log_info "Connecting to $vm_name ($target_ip) as ${AZURE_USER}..."
    ssh -i "$key_file" "${AZURE_USER}@${target_ip}"
}

# --- Command Logic ---
exec_cmd() {
    case "$1" in
        "cloud"|1)
            connect_vm "Cloud VM" "$CLOUD_KEY_FILE" "$CLOUD_VM_IP"
            ;;
        "edge"|2)
            connect_vm "Edge VM" "$EDGE_KEY_FILE" "$EDGE_VM_IP"
            ;;
        "prom"|3)
            log_info "Launching Prometheus in Firefox..."
            firefox "http://${CLOUD_VM_IP}:9090/query" &>/dev/null &
            sleep 1
            ;;
        "graf"|4)
            log_info "Launching Grafana in Firefox..."
            log_data "Grafana Password: ${GRAFANA_PASS}"
            firefox "http://${CLOUD_VM_IP}:3000" &>/dev/null &
            sleep 1
            ;;
        *)
            log_error "Command '$1' not found."
            return 1
            ;;
    esac
}

# --- Interactive Menu ---
show_menu() {
    clear
    echo -e "${CYAN}${BOLD}🖥️  AZURE VM CONNECTION MANAGER${NC}"
    echo -e "---------------------------------------------------"
    echo -e "  1) $(opt "cloud")        Connect to Cloud Server (${CLOUD_VM_IP})"
    echo -e "  2) $(opt "edge")         Connect to Edge Client  (${EDGE_VM_IP})"
    echo -e "  3) $(opt "prom")         Open Prometheus Web UI  (Firefox)"
    echo -e "  4) $(opt "graf")         Open Grafana Web UI     (Firefox)"
    echo -e "  q) Quit"
    echo -ne "\n  Select an option: "

    read -r user_opt
    user_opt=$(echo "$user_opt" | tr '[:upper:]' '[:lower:]')

    case $user_opt in
        1|cloud|server)     run_script "cloud" ;;
        2|edge|client)      run_script "edge" ;;
        3|prom|prometheus)  run_script "prom" ;;
        4|graf|grafana)     run_script "graf" ;;
        q|quit|exit)        log_success "Exiting..."; exit 0 ;;
        *)                  echo -e "Invalid option.\n"; sleep 1; show_menu ;;
    esac
}

# --- Interactive Wrapper ---
run_script() {
    local target_cmd=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    shift
    exec_cmd "$target_cmd" "$@"
    echo -e "\n${YELLOW}Press enter to return to menu...${NC}"
    read -r
    show_menu
}

# --- Script Initialisation ---
load_env
log_info "Checking current Public IP (for Azure NSG Whitelisting):"
PUBLIC_IP=$(curl -s ifconfig.me)
echo -e "  > ${BOLD}$PUBLIC_IP${NC}\n"

# Usage: ./connect.sh cloud
if [ -z "$1" ]; then
    show_menu
else
    entry_cmd=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    shift
    exec_cmd "$entry_cmd" "$@"
fi
