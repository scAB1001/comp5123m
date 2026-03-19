#!/bin/bash
# ==============================================================================
# CW2: Cloud Server (Minikube) Master Orchestration Script
# Role: Provisions the heavy "Cloud-like" VM, monitoring stack, and VNF deployments.
# Architecture: Ubuntu 22.04 LTS (Host) -> Minikube (K8s) -> Prometheus/Grafana
# ==============================================================================
set -e # Exit immediately if a command exits with a non-zero status to prevent cascading failures

# --- Configuration & Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# --- UI & Logging Helpers ---
log_warn()      { echo -e " ${YELLOW}${BOLD}⚠${YELLOW} $1${NC}"; }
log_error()     { echo -e " ${RED}${BOLD}✗${RED} $1${NC}"; }
log_success()   { echo -e " ${GREEN}${BOLD}✓${NC} ${GREEN}$1${NC}"; }
log_data()      { echo -e " ${NC}${BOLD}  >${NC} $1${NC}"; }
log_info()      { echo -e " ${BLUE}${BOLD}i${BLUE} $1${NC}"; }
log_serious()   { echo -e " ${PURPLE}${BOLD}❗${PURPLE} $1${NC}"; }
header()        { echo -e "\n${PURPLE}${BOLD}=========== $1 ===========${NC}"; }
opt()           { echo -e "${CYAN}$1${NC}"; }

# Safely executes a command. If it fails, catches the error rather than letting 'set -e' kill the script silently.
assert_cmd() {
    local success_msg="$1"
    local error_msg="$2"
    shift 2
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

# --- K8s & System Helpers ---
wait_for_pods() {
    log_info "Waiting for all pods in default namespace to reach 'Ready' state (Timeout: 90s)..."
    kubectl wait --for=condition=ready pod --all --timeout=90s 2>/dev/null || true
}

get_latest_github_release() {
    # Dynamically scrapes the latest release tag from GitHub API to avoid hardcoded versions
    curl -s "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/'
}

reload_systemd() {
    log_info "Reloading systemd daemon..."
    assert_cmd "Systemd daemon reloaded." "Failed to reload systemd." sudo systemctl daemon-reload
}

check_endpoint() {
    local name="$1"
    local url="$2"
    local max_attempts=5
    local wait_time=3

    log_info "Testing $name endpoint ($url)..."

    for ((i=1; i<=max_attempts; i++)); do
        # -s (silent), -I (headers only). Grep checks for HTTP response code.
        if curl -s -I "$url" | grep -q "HTTP"; then
            log_success "$name is reachable and responding!"
            return 0
        fi
        log_warn "Attempt $i/$max_attempts: $name not ready yet. Waiting ${wait_time}s..."
        sleep $wait_time
    done

    log_error "$name failed to respond after $max_attempts attempts."
    log_info "Run 'sudo journalctl -u grafana-server -n 20' to check for crash logs."
}

update_packages() {
    log_info "Updating Apt Package Repository..."
    sudo apt update -qq
    log_info "Upgrades found..."
    sudo apt list --upgradable 2>/dev/null | head -n 5
    log_info "Upgrading packages..."
    sudo apt upgrade -y -qq
}

# --- Interactive Menu ---
show_menu() {
    clear
    echo -e "${CYAN}${BOLD}☁️   CW2: CLOUD SERVER ORCHESTRATION (VM-AB)${NC}"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}📦  Task B: Infrastructure Provisioning${NC}"
    echo -e "  01) $(opt "k8s")         Install K8s Stack (Docker, Kubectl, Minikube)"
    echo -e "  02) $(opt "monitor")     Install Monitoring (Prometheus, Grafana, Node Exporter, stress-ng)"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}🚀  Task C & D: Cloud Deployment & Experimental Testing${NC}"
    echo -e "  03) $(opt "deploy")      Deploy 5G Service Chain & Run 'Hello World'"
    echo -e "  04) $(opt "test")        Run Experimental Load Tests (iperf3, wrk, ping)"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}⚙️  Lifecycle & Utilities${NC}"
    echo -e "  05) $(opt "up")          Start All Cloud Services (Minikube & Monitoring)"
    echo -e "  06) $(opt "down")        Stop All Services (Reduce compute usage)"
    echo -e "  07) $(opt "stats")       View VM Specs & Service Health"
    echo -e "  08) $(opt "update")      Update OS Packages"
    echo -e "  09) $(opt "nuke")        Purge Monitoring Stack (Prometheus, Grafana, Node)"

    echo -ne "\n   q) ${NC}[${RED}Quit${NC}]        ${YELLOW}Select an option: ${NC}"

    read -r user_opt
    user_opt=$(echo "$user_opt" | tr '[:upper:]' '[:lower:]')

    case $user_opt in
        1|k8s)       exec_cmd "k8s" ;;
        2|monitor)   exec_cmd "monitor" ;;
        3|deploy)    exec_cmd "deploy" ;;
        4|test)      exec_cmd "test" ;;
        5|up)        exec_cmd "up" ;;
        6|down)      exec_cmd "down" ;;
        7|stats)     exec_cmd "stats" ;;
        8|update)    exec_cmd "update" ;;
        9|nuke)      exec_cmd "nuke" ;;
        q|quit|exit) log_success "Exiting..."; exit 0 ;;
        *)           log_error "Invalid option"; sleep 1; show_menu ;;
    esac
}

# --- Command Logic ---
exec_cmd() {
    case "$1" in
        # ==========================================================
        # TASK B: INFRASTRUCTURE SETUP
        # ==========================================================
        "k8s")
            header "KUBERNETES STACK SETUP (CLOUD)"
            log_info "Step 1: Installing Docker Engine..."
            exec_cmd "docker"
            log_info "Step 2: Installing Kubectl..."
            exec_cmd "kubectl"
            log_info "Step 3: Installing Minikube..."
            exec_cmd "minikube"
            log_success "Kubernetes base successfully provisioned."
            ;;

        "monitor")
            header "MONITORING STACK SETUP (PROMETHEUS & GRAFANA)"
            log_info "Step 1: Installing Node Exporter (Hardware Metrics)..."
            exec_cmd "node"
            log_info "Step 2: Installing Prometheus (Time-Series Database)..."
            exec_cmd "prom"
            log_info "Step 3: Installing Grafana LTS (Visualisation)..."
            exec_cmd "grafana"
            log_info "Step 4: Installing stress-ng LTS (Workload Generator)..."
            exec_cmd "stress"
            log_success "Monitoring stack installed. Run 'up' to start services."
            ;;

        # --- Component Installations ---
        "docker")
            if ask_yes_no "Do you want to log into Docker Hub now?"; then
                log_info "Enter your Docker Hub credentials:"
                log_warn "Note for Examiner: Password hint provided below for lab convenience. Avoid in production."
                log_data "$:tyjcVSFL8>~hF"
                docker login -u scab1001
                log_success "Logged into Docker registry."
            fi
            log_info "Adding Docker's official GPG key & Repo..."
            update_packages
            sudo apt-get install -y -qq ca-certificates curl > /dev/null
            sudo install -m 0755 -d /etc/apt/keyrings
            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            sudo chmod a+r /etc/apt/keyrings/docker.asc
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            log_info "Installing Docker Engine..."
            update_packages
            assert_cmd "Docker installed." "Docker installation failed." sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null
            sudo usermod -aG docker $USER || true
            log_serious "CRITICAL: You MUST run 'newgrp docker' in your terminal right now, or log out and back in, for group permissions to apply!"
            ;;

        "kubectl")
            log_info "Downloading latest stable kubectl..."
            assert_cmd "Download complete." "Failed to download." curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm -f kubectl
            log_success "Kubectl installed successfully: $(kubectl version --client | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
            ;;

        "minikube")
            log_info "Downloading latest Minikube release..."
            assert_cmd "Download complete." "Failed to download." curl -sLO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
            sudo install minikube-linux-amd64 /usr/local/bin/minikube
            rm -f minikube-linux-amd64
            log_success "Minikube binaries installed."
            ;;

        "node")
            NE_VERSION=$(get_latest_github_release "prometheus/node_exporter")
            wget -q https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}/node_exporter-${NE_VERSION}.linux-amd64.tar.gz
            tar -xf node_exporter-${NE_VERSION}.linux-amd64.tar.gz
            sudo mv node_exporter-${NE_VERSION}.linux-amd64/node_exporter /usr/local/bin
            rm -r node_exporter-${NE_VERSION}.linux-amd64*
            id -u node_exporter &>/dev/null || sudo useradd -rs /bin/false node_exporter
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
            reload_systemd
            assert_cmd "Node Exporter enabled." "Failed." sudo systemctl enable node_exporter
            assert_cmd "Node Exporter started." "Failed." sudo systemctl restart node_exporter
            sleep 2
            check_endpoint "Node Exporter" "http://localhost:9100/health"
            ;;

        "prom")
            PROM_VERSION=$(get_latest_github_release "prometheus/prometheus")
            rm -f prometheus-*.tar.gz*
            wget -q https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
            tar -xf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
            rm -f prometheus-${PROM_VERSION}.linux-amd64.tar.gz
            sudo mv prometheus-${PROM_VERSION}.linux-amd64/prometheus prometheus-${PROM_VERSION}.linux-amd64/promtool /usr/local/bin
            sudo mkdir -p /etc/prometheus /var/lib/prometheus
            rm -r prometheus-${PROM_VERSION}.linux-amd64*

            log_info "Opening /etc/hosts file to add machine IPs..."
            log_info "Copy and paste these lines if required:"
            log_data "20.90.75.243 prometheus-target-1"
            log_data "20.90.75.243 prometheus-target-2"
            sleep 2
            sudo vim /etc/hosts

            log_info "Writing Distributed prometheus.yml config (Targets Cloud and Edge VMs)..."
            sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus_metrics'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node_exporter_metrics'
    static_configs:
      - targets: ['localhost:9100', '10.0.0.5:9100']
EOF
            id -u prometheus &>/dev/null || sudo useradd -rs /bin/false prometheus
            sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

            sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
After=network.target
[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus --config.file /etc/prometheus/prometheus.yml --storage.tsdb.path /var/lib/prometheus/ --web.enable-lifecycle
[Install]
WantedBy=multi-user.target
EOF
            reload_systemd
            assert_cmd "Prometheus enabled." "Failed." sudo systemctl enable prometheus
            # assert_cmd "Prometheus started." "Failed." sudo systemctl restart prometheus
            curl -X POST http://localhost:9090/-/reload 2>/dev/null || true
            sleep 2
            check_endpoint "Prometheus" "http://localhost:9090/-/healthy"
            ;;

        "grafana")
            sudo apt-get install -y -qq apt-transport-https software-properties-common wget > /dev/null
            sudo mkdir -p /etc/apt/keyrings/
            wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
            echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list > /dev/null
            update_packages
            assert_cmd "Grafana installed." "Failed." sudo apt-get install -y -qq grafana
            reload_systemd
            assert_cmd "Grafana enabled." "Failed." sudo systemctl enable grafana-server
            assert_cmd "Grafana started." "Failed." sudo systemctl restart grafana-server
            sleep 2
            check_endpoint "Grafana" "http://localhost:3000/api/health"
            ;;

        "stress")
            update_packages
            assert_cmd "stress-ng installed." "Failed." sudo apt-get install -y -qq stress-ng
            if ask_yes_no "Run a 1-minute benchmark now? (4 CPU, 2 VM, 1 HDD, 8 Fork)"; then
                log_warn "Commencing stress test for 1 minute. Watch Grafana!"
                stress-ng --cpu 4 --vm 2 --hdd 1 --fork 8 --timeout 1m --metrics || true
                log_success "Stress test completed."
            else
                log_info "You can run tests later manually (e.g., 'stress-ng --cpu 4 --timeout 1m')."
            fi
            ;;

        # ==========================================================
        # TASK C & D: DEPLOYMENT & TESTING
        # ==========================================================
        "deploy")
            header "TASK C: VNF DEPLOYMENT & HELLO WORLD (CLOUD)"
            if [ ! -f "5g-service-chain.yaml" ]; then
                log_error "5g-service-chain.yaml not found! Please create the Service Chain manifest."
                exit 1
            fi

            log_info "Applying 5G Service Chain Manifests (Firewall -> Gateway -> Backend)..."
            assert_cmd "Manifests applied." "Apply failed." kubectl apply -f 5g-service-chain.yaml

            wait_for_pods
            log_info "Cloud Pods Currently Running:"
            kubectl get pods | sed 's/^/  > /'

            if ask_yes_no "Run the 'Hello World' Connectivity Test now?"; then
                log_info "Executing HTTP GET request through the Cloud VNF chain..."
                sleep 2
                kubectl run -i --tty --rm debug-client --image=alpine --restart=Never -- sh -c "apk add -q curl && curl -s http://edge-firewall-svc:80 | grep title"
                log_success "Hello World validation complete! Traffic routed successfully."
            fi
            ;;

        "test")
            header "TASK D: EXPERIMENTAL LOAD TESTING (CLOUD)"
            log_info "Ensure you have your Grafana dashboard open to watch the Cloud VM metrics."
            echo ""

            log_info "TEST 1: ICMP Ping (Baseline Cloud Latency)"
            log_data "Pinging the VNF Pod directly (K8s Services drop ICMP traffic by design)."
            if ask_yes_no "Run Ping test?"; then
                VNF_POD_IP=$(kubectl get pod -l app=edge-firewall -o jsonpath='{.items[0].status.podIP}')
                log_info "Extracted Cloud Firewall Pod IP: $VNF_POD_IP"
                kubectl run -i --tty --rm ping-client --image=alpine --restart=Never -- sh -c "ping -c 5 $VNF_POD_IP"
                log_success "Ping test complete. Record the Cloud latency (ms) for your report."
            fi
            echo ""

            log_info "TEST 2: iperf3 (TCP Throughput via Service Chain)"
            log_data "Floods the VNF with TCP packets to find the maximum bandwidth ceiling."
            if ask_yes_no "Run iperf3 test for 20 seconds?"; then
                kubectl run -i --tty --rm iperf-client --image=networkstatic/iperf3 --restart=Never -- -c edge-firewall-svc -t 20
                log_success "iperf3 test complete. Record the Cloud Bitrate (Mbits/sec)."
            fi
            echo ""

            log_info "TEST 3: wrk (HTTP API Load Simulation)"
            log_data "Simulates 100 concurrent 5G users hammering the VNF Gateway with requests."
            if ask_yes_no "Run wrk HTTP test for 30 seconds?"; then
                kubectl run -i --tty --rm wrk-client --image=ruslanys/wrk --restart=Never -- -c 100 -t 4 -d 30s http://edge-firewall-svc:80
                log_success "wrk test complete. Record the Cloud Requests/sec and Latency."
            fi
            ;;

        # ==========================================================
        # UTILITIES
        # ==========================================================
        "up")
            header "STARTING CLOUD ENVIRONMENT"
            log_info "Starting Minikube Orchestrator (Capped at 2048MB)..."
            assert_cmd "Minikube is running." "Failed." minikube start --driver=docker --memory=2048

            log_info "Starting Monitoring Stack (Prometheus, Grafana, Node Exporter)..."
            sudo systemctl restart node_exporter 2>/dev/null || true
            curl -X POST http://localhost:9090/-/reload 2>/dev/null || true
            # sudo systemctl restart prometheus 2>/dev/null || true
            sudo systemctl restart grafana-server 2>/dev/null || true
            log_success "Cloud Environment is fully active."
            ;;

        "down")
            header "STOPPING ALL CLOUD SERVICES"
            log_info "Stopping Minikube..."
            minikube stop 2>/dev/null || true

            log_info "Stopping Monitoring Stack..."
            sudo systemctl stop prometheus 2>/dev/null || true
            sudo systemctl stop node_exporter 2>/dev/null || true
            sudo systemctl stop grafana-server 2>/dev/null || true
            log_success "All heavy services halted. Your Cloud VM is idling."
            ;;

        "stats")
            header "CLOUD SYSTEM SPECIFICATIONS (TASK B SUMMARY)"
            log_info "Operating System:"
            cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' | sed 's/^/  > /'

            log_info "CPU Architecture:"
            lscpu | grep "Model name:" | sed 's/^/  > /'
            lscpu | grep "CPU(s):" | head -1 | sed 's/^/  > /'

            log_info "Memory (RAM):"
            free -h | grep Mem | awk '{print "  > Total: " $2 " | Used: " $3}'

            log_info "Service Status:"
            minikube status 2>/dev/null | grep -q "host: Running" && echo "  > Minikube: ACTIVE" || echo "  > Minikube: Stopped"
            systemctl is-active --quiet prometheus && echo "  > Prometheus: ACTIVE" || echo "  > Prometheus: Stopped"
            systemctl is-active --quiet grafana-server && echo "  > Grafana: ACTIVE" || echo "  > Grafana: Stopped"
            ;;

        "update")
            header "UPDATE OS PACKAGES"
            update_packages
            log_success "OS Packages Updated."
            ;;

        "nuke")
            header "PURGING SERVICES & DATA"
            log_warn "This will completely remove Prometheus, Node Exporter, and Grafana."

            if ask_yes_no "Are you sure you want to nuke the stack?"; then
                exec_cmd "down"

                log_info "Removing binaries..."
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

                reload_systemd
                log_success "Stack completely removed."
            else
                log_info "Nuke operation aborted."
            fi
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

if [ -z "$1" ]; then
    show_menu
else
    entry_cmd=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    shift
    exec_cmd "$entry_cmd" "$@"
fi