#!/bin/bash
set -e

# --- Configuration & Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
ORANGE='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

VM_IP="http://20.90.75.243"

# --- UI Helpers ---
log_warn()      { echo -e " ${YELLOW}${BOLD}⚠${YELLOW} $1${NC}"; }
log_error()     { echo -e " ${RED}${BOLD}✗${RED} $1${NC}"; }
log_success()   { echo -e " ${GREEN}${BOLD}✓${NC} ${GREEN}$1${NC}"; }
log_data()      { echo -e " ${NC}${BOLD}  >${NC} $1${NC}"; }
log_info()      { echo -e " ${BLUE}${BOLD}i${BLUE} $1${NC}"; }
header()        { echo -e "\n${PURPLE}${BOLD}=========== $1 ===========${NC}"; }
opt()           { echo -e "${CYAN}$1${NC}"; }

# Usage: assert_cmd "Success Message" "Error Message" command args...
assert_cmd() {
    local success_msg="$1"
    local error_msg="$2"
    shift 2

    # Temporarily suspends 'set -e' for graceful error handling
    if "$@"; then
        [ -n "$success_msg" ] && log_success "$success_msg"
    else
        [ -n "$error_msg" ] && log_error "$error_msg"
        exit 1
    fi
}

ask_yes_no() {
    read -p "$(echo -e "${YELLOW} ? $1 (y/N): ${NC}")" response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# --- System Helpers ---
reload_systemd() {
    log_info "Reloading systemd daemon..."
    assert_cmd "Systemd daemon reloaded." "Failed to reload systemd." sudo systemctl daemon-reload
}

get_latest_github_release() {
    # Usage: get_latest_github_release "owner/repo"
    curl -s "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/'
}

# --- Interactive Menu ---
show_menu() {
    clear
    echo -e "${CYAN}${BOLD}🍃 CLOUD & EDGE MONITORING SETUP${NC}"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}🛠️  Service Installation${NC}"
    echo -e "  01) $(opt "node")        Install Node Exporter    02) $(opt "prom")        Install Prometheus"
    echo -e "  03) $(opt "grafana")     Install Grafana LTS      04) $(opt "view")        View all Written Files"
    echo -e "  05) $(opt "all")         Install Full Stack       06) $(opt "nuke")        Nuke files and Restart"

    echo -ne "\n   q) ${NC}[${RED}Quit${NC}]        ${YELLOW}Select an option: ${NC}"

    read -r user_opt
    user_opt=$(echo "$user_opt" | tr '[:upper:]' '[:lower:]')

    case $user_opt in
        1|node)      run_script "node" ;;
        2|prom)      run_script "prom" ;;
        3|grafana)   run_script "grafana" ;;
        4|view)      run_script "view" ;;
        5|all)       run_script "all" ;;
        6|nuke)      run_script "nuke" ;;
        7|test)      run_script "test" ;;
        q|quit|exit) log_success "Exiting..."; exit 0 ;;
        *)           log_error "Invalid option"; sleep 1; show_menu ;;
    esac
}

# --- Command Logic ---
exec_cmd() {
    case "$1" in
        "node")
            header "NODE EXPORTER SETUP"
            log_info "Fetching latest Node Exporter version..."
            NE_VERSION=$(get_latest_github_release "prometheus/node_exporter")
            log_data "Latest Version: $NE_VERSION"

            log_info "Downloading and extracting archive..."
            assert_cmd "Download complete." "Failed to download." wget -q https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}/node_exporter-${NE_VERSION}.linux-amd64.tar.gz
            tar -xf node_exporter-${NE_VERSION}.linux-amd64.tar.gz

            log_info "Installing binaries to /usr/local/bin..."
            sudo mv node_exporter-${NE_VERSION}.linux-amd64/node_exporter /usr/local/bin

            log_info "Removing residual files..."
            rm -r node_exporter-${NE_VERSION}.linux-amd64*

            log_info "Configuring system user..."
            id -u node_exporter &>/dev/null || sudo useradd -rs /bin/false node_exporter

            log_info "Writing systemd service file..."
            sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
            log_data "Service file written to /etc/systemd/system/node_exporter.service"

            reload_systemd
            assert_cmd "Node Exporter enabled." "Failed to enable service." sudo systemctl enable node_exporter
            assert_cmd "Node Exporter started." "Failed to start service." sudo systemctl restart node_exporter
            ;;

            "prom")
            header "PROMETHEUS SETUP"
            log_info "Fetching latest Prometheus version..."
            PROM_VERSION=$(get_latest_github_release "prometheus/prometheus")
            log_data "Latest Version: $PROM_VERSION"

            log_info "Downloading and extracting archive..."
            # Clean up any failed previous downloads to prevent .tar.gz.1 duplicates
            rm -f prometheus-*.tar.gz*
            assert_cmd "Download complete." "Failed to download." wget -q https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
            tar -xf prometheus-${PROM_VERSION}.linux-amd64.tar.gz

            # Clean up the archive immediately after extraction
            rm -f prometheus-${PROM_VERSION}.linux-amd64.tar.gz

            log_info "Installing binaries and configuration directories..."
            sudo mv prometheus-${PROM_VERSION}.linux-amd64/prometheus prometheus-${PROM_VERSION}.linux-amd64/promtool /usr/local/bin
            sudo mkdir -p /etc/prometheus /var/lib/prometheus

            # Clean up extracted folder (consoles and console_libraries are no longer bundled in v3.0+)
            log_info "Removing residual files..."
            rm -r prometheus-${PROM_VERSION}.linux-amd64*

            log_info "Opening /etc/hosts file to add machine IPs..."
            # Add the following, replace x.x.x.x with the machine’s corresponding IP address

            log_info "Copy and paste these lines:"
            log_data "20.90.75.243 prometheus-target-1"
            log_data "20.90.75.243 prometheus-target-2"
            sleep 2
            sudo vim /etc/hosts

            log_info "Writing default prometheus.yml (Edge-optimised intervals)..."
            sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus_metrics'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node_exporter_metrics'
    static_configs:
      - targets: ['localhost:9100']
EOF
            log_data "Config written to /etc/prometheus/prometheus.yml"

            log_info "Configuring system user and permissions..."
            id -u prometheus &>/dev/null || sudo useradd -rs /bin/false prometheus
            sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

            log_info "Writing systemd service file..."
            # The --web.console flags have been removed to ensure v3.0+ compatibility
            sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file /etc/prometheus/prometheus.yml \\
    --storage.tsdb.path /var/lib/prometheus/

[Install]
WantedBy=multi-user.target
EOF
            log_data "Service file written to /etc/systemd/system/prometheus.service"

            reload_systemd
            assert_cmd "Prometheus enabled." "Failed to enable service." sudo systemctl enable prometheus
            assert_cmd "Prometheus started." "Failed to start service." sudo systemctl restart prometheus

            log_warn "Remember to add targets to /etc/hosts if resolving via hostnames!"
            ;;

        "grafana")
            header "GRAFANA LTS SETUP"
            log_info "Adding Grafana APT repository..."
            sudo apt-get install -y -qq apt-transport-https software-properties-common wget > /dev/null
            sudo mkdir -p /etc/apt/keyrings/

            log_info "Downloading and extracting archive..."
            wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
            echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list > /dev/null

            log_info "Installing Grafana package..."
            sudo apt-get update -qq
            assert_cmd "Grafana installed successfully." "Failed to install Grafana via apt." sudo apt-get install -y -qq grafana

            reload_systemd
            assert_cmd "Grafana enabled." "Failed to enable service." sudo systemctl enable grafana-server
            assert_cmd "Grafana started." "Failed to start service." sudo systemctl restart grafana-server
            ;;

        "view")
            header "VIEW WRITTEN FILES"
            log_info "Showing /etc/systemd/system/node_exporter.service contents..."
            cat /etc/systemd/system/node_exporter.service

            log_info "Showing /etc/hosts contents..."
            cat /etc/hosts

            log_info "Showing /etc/prometheus/prometheus.yml contents..."
            cat /etc/prometheus/prometheus.yml

            log_info "Showing /etc/systemd/system/prometheus.service contents..."
            cat /etc/systemd/system/prometheus.service
            ;;

        "all")
            exec_cmd "node"
            exec_cmd "prom"
            exec_cmd "grafana"
            header "FULL STACK INSTALLATION COMPLETE"
            log_data "Prometheus Web UI: http://localhost:9090"
            log_data "Grafana Web UI:    http://localhost:3000 (Default: admin / admin)"
            ;;

        "nuke")
            header "PURGING SERVICES & DATA"
            log_warn "This will completely remove Prometheus, Node Exporter, and Grafana."

            if ask_yes_no "Are you sure you want to nuke the stack?"; then
                log_info "Stopping services (if running)..."
                # The '2>/dev/null || true' swallows errors if the service doesn't exist/isn't loaded
                sudo systemctl stop prometheus 2>/dev/null || true
                sudo systemctl stop node_exporter 2>/dev/null || true
                sudo systemctl stop grafana-server 2>/dev/null || true

                log_info "Removing binaries..."
                # Added -f to ignore non-existent files without throwing errors
                sudo rm -f /usr/local/bin/prometheus /usr/local/bin/promtool /usr/local/bin/node_exporter

                log_info "Removing configuration and data directories..."
                sudo rm -rf /etc/prometheus /var/lib/prometheus

                log_info "Removing systemd service files..."
                sudo rm -f /etc/systemd/system/prometheus.service /etc/systemd/system/node_exporter.service

                log_info "Purging Grafana packages..."
                sudo apt-get purge -y -qq grafana grafana-enterprise 2>/dev/null || true
                sudo apt-get autoremove -y -qq 2>/dev/null || true

                log_info "Removing Grafana data and log directories..."
                sudo rm -rf /etc/grafana /var/lib/grafana /var/log/grafana

                # Call your existing systemd reload function
                reload_systemd

                log_success "Stack completely removed."
            else
                log_info "Nuke operation aborted."
            fi
            ;;

        "test")
            header "TESTING ENDPOINTS"
            # Current IP
            curl ifconfig.me
            echo

            # Prove Prometheus is Working Locally
            curl -I http://localhost:9090

            # Prove Grafana is Working Locally
            curl -I http://localhost:3000

            # nLpY9FM%8t'V~^2

            # You must explicitly allow external traffic to reach that specific port.
            # Go to the Microsoft Azure Portal.
            # Ubuntu Virtual Machine (vm-ab) > Networking > Add inbound port rule.
            # Set Destination port ranges to 9090, Protocol to TCP, and Action to Allow.
            # (Repeat this process for port 3000 so Grafana works later).
            ;;

        *)
            log_error "Command '$1' not found."
            ;;
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

# --- Execution Entry ---
if [ -z "$1" ]; then
    show_menu
else
    entry_cmd=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    shift
    exec_cmd "$entry_cmd" "$@"
fi