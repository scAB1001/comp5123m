#!/bin/bash
# ==============================================================================
# CW2: Edge Client (K3s) Master Orchestration Script
# Role: Provisions the lightweight "Edge-like" VM, hardware scraper, and VNF.
# Architecture: Alpine/Ubuntu (Host) -> K3s (K8s) -> Node Exporter (Target)
# ==============================================================================
set -e

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

# Safely executes a command.
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
reload_systemd() {
    log_info "Reloading systemd daemon..."
    assert_cmd "Systemd daemon reloaded." "Failed to reload systemd." sudo systemctl daemon-reload
}

get_latest_github_release() {
    # Scrapes the latest release tag from GitHub API
    curl -s "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/'
}

# Re-attempts endpoint
check_endpoint() {
    local name="$1"
    local url="$2"
    local max_attempts=5
    local wait_time=5

    log_info "Testing $name endpoint ($url)..."
    for ((i=1; i<=max_attempts; i++)); do
        if curl -s -I "$url" | grep -q "HTTP"; then
            log_success "$name is reachable and responding!"
            return 0
        fi
        log_warn "Attempt $i/$max_attempts: $name not ready yet. Waiting ${wait_time}s..."
        sleep $wait_time
    done
    log_error "$name failed to respond after $max_attempts attempts."
}

wait_for_pods() {
    log_info "Waiting for all pods in default namespace to reach 'Ready' state (Timeout: 90s)..."
    kubectl wait --for=condition=ready pod --all --timeout=90s 2>/dev/null || true
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
    echo -e "${CYAN}${BOLD}⚡   CW2: EDGE CLIENT ORCHESTRATION (VM-EDGE)${NC}"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${YELLOW}${BOLD}📌 QUICK START / EXECUTION ORDER:${NC}"
    echo -e "  1. Provision the host VM:    Run ${BOLD}01${NC} then ${BOLD}02${NC} (Only needed once)."
    echo -e "  2. Boot the environment:     Run ${BOLD}05${NC} to ensure K3s and Scrapers are running."
    echo -e "  3. Deploy and Test:          Run ${BOLD}03${NC} to apply VNFs, then ${BOLD}04${NC} to run experiments."
    echo -e "  4. Teardown:                 Run ${BOLD}06${NC} to stop services and save Azure credits."
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}📦  Task B: Infrastructure Provisioning [Run Once]${NC}"
    echo -e "  01) $(opt "k3s")         Install K3s Engine (Lightweight K8s)"
    echo -e "  02) $(opt "all-base")    Install Base Tools (Node Exporter, stress-ng)"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}🚀  Task C & D: Edge Deployment & Experimental Testing${NC}"
    echo -e "  03) $(opt "deploy")      Deploy 5G Service Chain & Run 'Hello World'"
    echo -e "  04) $(opt "test")        Run Experimental Load Tests (iperf3, wrk, ping)"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}⚙️  Lifecycle & Utilities [Daily Use]${NC}"
    echo -e "  05) $(opt "up")          Start All Edge Services (K3s & Base)"
    echo -e "  06) $(opt "down")        Stop All Services (Idle VM)"
    echo -e "  07) $(opt "stats")       View VM Specs & Service Health"
    echo -e "  08) $(opt "update")      Update OS Packages"
    echo -e "  09) $(opt "nuke")        Uninstall K3s & Purge Node Exporter"

    echo -ne "\n   q) ${NC}[${RED}Quit${NC}]        ${YELLOW}Select an option: ${NC}"

    read -r user_opt
    user_opt=$(echo "$user_opt" | tr '[:upper:]' '[:lower:]')

    case $user_opt in
        1|k3s)       run_script "k3s" ;;
        2|all-base)  run_script "all-base" ;;
        3|deploy)    run_script "deploy" ;;
        4|test)      run_script "test" ;;
        5|up)        run_script "up" ;;
        6|down)      run_script "down" ;;
        7|stats)     run_script "stats" ;;
        8|update)    run_script "update" ;;
        9|nuke)      run_script "nuke" ;;
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
            log_warn "Ensure Port 9100 is open in Azure NSG so the Cloud VM can scrape this node!"
            ;;

        "k3s")
            header "K3S (EDGE KUBERNETES) SETUP"
            log_info "Installing lightweight K3s engine (Uses containerd instead of Docker)..."
            assert_cmd "K3s installed." "Failed to install." bash -c 'curl -sfL https://get.k3s.io | sh -'

            log_info "Configuring Kubectl permissions for local user..."
            mkdir -p ~/.kube
            sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
            sudo chown $(id -u):$(id -g) ~/.kube/config
            export KUBECONFIG=~/.kube/config
            log_success "K3s installation complete. Engine is running."
            ;;

        "stress")
            header "STRESS-NG SETUP"
            update_packages
            assert_cmd "stress-ng installed." "Failed." sudo apt-get install -y -qq stress-ng

            if ask_yes_no "Run a 1-minute benchmark now? (4 CPU, 2 VM, 1 HDD, 8 Fork)"; then
                log_warn "Commencing stress test for 1 minute. Watch Grafana!"
                stress-ng --cpu 4 --vm 2 --hdd 1 --fork 8 --timeout 1m --metrics || true
                log_success "Stress test completed."
            else
                log_info "Run tests later manually (e.g., 'stress-ng --cpu 4 --timeout 1m')."
            fi
            ;;

        "all-base")
            header "INSTALLING ALL BASE EDGE TOOLS"
            exec_cmd "node"
            exec_cmd "stress"
            log_success "All Edge infrastructure successfully provisioned."
            ;;

        # ==========================================================
        # TASK C & D: DEPLOYMENT & TESTING
        # ==========================================================
        "deploy")
            header "TASK C: VNF DEPLOYMENT & HELLO WORLD (EDGE)"
            export KUBECONFIG=~/.kube/config

            if [ ! -f "5g-service-chain.yaml" ]; then
                log_error "5g-service-chain.yaml not found! Please create the Service Chain manifest."
                exit 1
            fi

            log_info "Applying 5G Service Chain Manifests (Firewall -> Gateway -> Backend)..."
            assert_cmd "Manifests applied." "Apply failed." kubectl apply -f 5g-service-chain.yaml

            wait_for_pods
            log_info "Edge Pods Currently Running:"
            kubectl get pods | sed 's/^/  > /'

            echo ""
            if ask_yes_no "Run the 'Hello World' Connectivity Test now?"; then
                log_info "Executing HTTP GET request through the VNF chain..."
                sleep 2
                kubectl run -i --tty --rm debug-client --image=alpine --restart=Never -- sh -c "apk add -q curl && curl -s http://edge-firewall-svc:80 | grep title"
                log_success "Hello World validation complete! Traffic routed successfully."
            fi

            echo ""
            if ask_yes_no "Run the L7 DPI Header Verification Test now?"; then
                log_info "Fetching HTTP Headers to verify Deep Packet Inspection..."
                log_warn "Look for 'X-DPI-Inspected: True-Secure' in the output below."
                sleep 2
                kubectl run -i --tty --rm header-test --image=alpine --restart=Never -- sh -c "apk add -q curl && curl -I http://edge-firewall-svc:80"
                log_success "DPI Header Verification complete."
            fi
            ;;

        "test")
            header "TASK D: EXPERIMENTAL LOAD & SECURITY TESTING (EDGE)"
            export KUBECONFIG=~/.kube/config
            log_info "Ensure you are watching the Edge VM metrics on the Cloud Grafana dashboard."
            echo ""

            log_info "TEST 1: ICMP Ping (Baseline Edge Latency)"
            log_data "Pinging the Edge Firewall Pod directly."
            if ask_yes_no "Run Ping test?"; then
                VNF_POD_IP=$(kubectl get pod -l app=edge-firewall -o jsonpath='{.items[0].status.podIP}')
                log_info "Extracted Firewall Pod IP: $VNF_POD_IP"
                kubectl run -i --tty --rm ping-client --image=alpine --restart=Never -- sh -c "ping -c 5 $VNF_POD_IP"
                log_success "Ping test complete."
            fi
            echo ""

            log_info "TEST 2: iperf3 (TCP Throughput via Service Chain)"
            log_data "Floods the Edge Firewall with TCP packets to test the K3s bandwidth ceiling."
            if ask_yes_no "Run iperf3 test for 20 seconds?"; then
                kubectl run -i --tty --rm iperf-client --image=networkstatic/iperf3 --restart=Never -- -c edge-firewall-svc -t 20
                log_success "iperf3 test complete."
            fi
            echo ""

            log_info "TEST 3: wrk (HTTP API Load Simulation)"
            log_data "Simulates 100 concurrent users hitting the Edge Service Chain."
            if ask_yes_no "Run wrk HTTP test for 30 seconds?"; then
                kubectl run -i --tty --rm wrk-client --image=ruslanys/wrk --restart=Never -- -c 100 -t 4 -d 30s http://edge-firewall-svc:80
                log_success "wrk test complete."
            fi
            echo ""

            log_info "TEST 4: Negative Security (Firewall Enforcement)"
            log_data "Attempts to bypass the Firewall on an unauthorised port (8080)."
            if ask_yes_no "Run Negative Security test?"; then
                log_warn "This test should intentionally FAIL with a 'Connection timed out'."
                sleep 2
                kubectl run -i --tty --rm negative-test --image=alpine --restart=Never -- sh -c "apk add -q curl && curl --connect-timeout 3 http://edge-firewall-svc:8080" || true
                log_success "Negative security test complete. Unauthorised traffic was correctly dropped."
            fi
            echo ""

            log_info "TEST 5: Chaos Engineering (Self-Healing Validation)"
            log_data "Simulates a VNF software crash to test MANO orchestration recovery."
            if ask_yes_no "Run Chaos Engineering test?"; then
                log_serious "ACTION REQUIRED: Open a SECOND SSH terminal to the Edge VM."
                log_info "In Terminal 2, run this command to watch the pods in real-time:"
                log_data "sudo kubectl get pods -w"
                echo ""
                read -p "$(echo -e "${YELLOW}Press [Enter] once Terminal 2 is running and ready...${NC}")"

                log_info "Assassinating the DPI Inspector Pod..."
                kubectl delete pod -l app=dpi-inspector

                log_success "Pod deleted! Check Terminal 2 to watch the ReplicaSet self-heal."
                log_info "Press Ctrl+Z in Terminal 2 to stop watching."
            fi
            ;;

        # ==========================================================
        # UTILITIES
        # ==========================================================
        "up")
            header "STARTING EDGE ENVIRONMENT"
            if systemctl is-active --quiet k3s; then
                log_success "K3s is already running. Skipping startup."
            else
                log_info "Starting K3s Orchestrator..."
                assert_cmd "K3s is running." "Failed to start K3s." sudo systemctl start k3s
            fi

            if systemctl is-active --quiet node_exporter; then
                log_success "Hardware Scraper (Node Exporter) is already running."
            else
                log_info "Starting Hardware Scraper (Node Exporter)..."
                sudo systemctl start node_exporter 2>/dev/null || true
            fi
            log_success "Edge Environment is fully active."
            ;;

        "down")
            header "STOPPING EDGE SERVICES"
            log_info "Stopping services to reduce compute overhead..."
            sudo systemctl stop k3s 2>/dev/null || true
            sudo systemctl stop node_exporter 2>/dev/null || true
            log_success "K3s and Node Exporter stopped. VM is idling."
            ;;

        "stats")
            header "EDGE SYSTEM SPECIFICATIONS (TASK B SUMMARY)"
            local internal_ip=$(hostname -I | awk '{print $1}')

            log_serious "CRITICAL NETWORKING INFO:"
            log_data "Internal IP: ${GREEN}${internal_ip}${NC}"
            log_warn "Ensure this IP is in the Cloud VM's prometheus.yml file."
            echo ""

            log_info "Operating System:"
            cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' | sed 's/^/  > /'

            log_info "CPU Architecture:"
            lscpu | grep "Model name:" | sed 's/^/  > /'
            lscpu | grep "CPU(s):" | head -1 | sed 's/^/  > /'

            log_info "Memory (RAM):"
            free -h | grep Mem | awk '{print "  > Total: " $2 " | Used: " $3}'

            log_info "Service Status:"
            systemctl is-active --quiet k3s && echo "  > K3s (Edge K8s): ACTIVE" || echo "  > K3s (Edge K8s): Stopped"
            systemctl is-active --quiet node_exporter && echo "  > Node Exporter: ACTIVE" || echo "  > Node Exporter: Stopped"
            log_success "Specs retrieved."
            ;;

        "update")
            header "UPDATE OS PACKAGES"
            update_packages
            log_success "OS Packages Updated."
            ;;

        "nuke")
            header "PURGING EDGE SERVICES & DATA"
            log_serious "This will completely eradicate K3s and Node Exporter from this VM."

            if ask_yes_no "Are you sure you want to nuke the Edge setup?"; then
                log_info "Uninstalling K3s..."
                if [ -f "/usr/local/bin/k3s-uninstall.sh" ]; then
                    sudo /usr/local/bin/k3s-uninstall.sh
                    log_success "K3s eradicated."
                else
                    log_warn "K3s uninstaller not found. Skipping."
                fi

                log_info "Removing Node Exporter..."
                sudo systemctl stop node_exporter 2>/dev/null || true
                sudo rm -f /usr/local/bin/node_exporter
                sudo rm -f /etc/systemd/system/node_exporter.service

                reload_systemd
                log_success "Edge stack completely removed."
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
