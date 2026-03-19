#!/bin/bash
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

VM_IP="http://40.120.43.27"

# --- UI Helpers ---
log_warn()      { echo -e " ${YELLOW}${BOLD}⚠${YELLOW} $1${NC}"; }
log_error()     { echo -e " ${RED}${BOLD}✗${RED} $1${NC}"; }
log_success()   { echo -e " ${GREEN}${BOLD}✓${NC} ${GREEN}$1${NC}"; }
log_data()      { echo -e " ${NC}${BOLD}  >${NC} $1${NC}"; }
log_info()      { echo -e " ${BLUE}${BOLD}i${BLUE} $1${NC}"; }
log_serious()   { echo -e " ${PURPLE}${BOLD}❗${PURPLE} $1${NC}"; }
header()        { echo -e "\n${PURPLE}${BOLD}=========== $1 ===========${NC}"; }
opt()           { echo -e "${CYAN}$1${NC}"; }

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
    curl -s "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/'
}

check_endpoint() {
    local name="$1"
    local url="$2"
    log_info "Testing $name endpoint ($url)..."
    if curl -s -I "$url" | grep -q "HTTP"; then
        log_success "$name is reachable and responding!"
    else
        log_error "$name failed to respond. Check service status."
    fi
}

wait_for_pods() {
    log_info "Waiting for all pods in default namespace to be ready (Timeout: 90s)..."
    kubectl wait --for=condition=ready pod --all --timeout=90s 2>/dev/null || true
}

update_packages() {
    log_info "Updating package lists..."
    sudo apt update -qq
    log_info "Upgrading packages..."
    sudo apt upgrade -y -qq
    log_success "OS Packages Updated."
}

# --- Interactive Menu ---
show_menu() {
    clear
    echo -e "${CYAN}${BOLD}☸️  CW2: EDGE CLIENT PROVISIONING (K3S)${NC}"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}📦 Base Setup (Task B)${NC}"
    echo -e "  01) $(opt "node")        Install Node Exporter    02) $(opt "k3s")         Install K3s Engine"
    echo -e "  03) $(opt "stress")      Install stress-ng        04) $(opt "all-base")    Install All Base Tools"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}🚀 VNF Operations (Task C & D)${NC}"
    echo -e "  05) $(opt "deploy")      Deploy 5G Service Chain & Run 'Hello World'"
    echo -e "  06) $(opt "test")        Run Experimental Load Tests (iperf3, wrk, ping)"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}📊 Utilities & Teardown${NC}"
    echo -e "  07) $(opt "stats")       View VM Specs & Internal IP (For Prometheus)"
    echo -e "  08) $(opt "update")      Update OS Packages"
    echo -e "  09) $(opt "down")        Stop Services (Idle VM)"
    echo -e "  10) $(opt "nuke")        Uninstall K3s & Purge Node Exporter"

    echo -ne "\n   q) ${NC}[${RED}Quit${NC}]        ${YELLOW}Select an option: ${NC}"

    read -r user_opt
    user_opt=$(echo "$user_opt" | tr '[:upper:]' '[:lower:]')

    case $user_opt in
        1|node)      run_script "node" ;;
        2|k3s)       run_script "k3s" ;;
        3|stress)    run_script "stress" ;;
        4|all-base)  run_script "node"; run_script "k3s"; run_script "stress" ;;
        5|deploy)    run_script "deploy" ;;
        6|test)      run_script "test" ;;
        7|stats)     run_script "stats" ;;
        8|update)    run_script "update" ;;
        9|down)      run_script "down" ;;
        10|nuke)     run_script "nuke" ;;
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
            sudo mv node_exporter-${NE_VERSION}.linux-amd64/node_exporter /usr/local/bin
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
            reload_systemd
            assert_cmd "Node Exporter enabled." "Failed to enable service." sudo systemctl enable --now node_exporter

            sleep 2
            log_success "Node Exporter running. Ensure Port 9100 is open in Azure NSG if crossing VNets."
            ;;

        "k3s")
            header "K3S (EDGE KUBERNETES) SETUP"
            log_info "Installing lightweight K3s engine..."
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
            log_info "Installing stress-ng for manual threshold testing..."
            sudo apt-get update -qq
            assert_cmd "stress-ng installed." "Failed to install stress-ng." sudo apt-get install -y -qq stress-ng
            log_success "stress-ng ready. Run manually via 'stress-ng --cpu 4 --timeout 1m'"
            ;;

        "deploy")
            header "TASK C: VNF DEPLOYMENT & HELLO WORLD (EDGE)"
            # Ensure kubectl uses the K3s config
            export KUBECONFIG=~/.kube/config

            if [ ! -f "5g-service-chain.yaml" ]; then
                log_error "5g-service-chain.yaml not found! Please create the Service Chain manifest first."
                exit 1
            fi

            log_info "Applying 5G Service Chain Manifests (Firewall -> Gateway -> Backend)..."
            assert_cmd "Manifests applied." "Apply failed." kubectl apply -f 5g-service-chain.yaml

            wait_for_pods

            log_info "Edge Pods Currently Running:"
            kubectl get pods | sed 's/^/  > /'

            if ask_yes_no "Run the 'Hello World' Connectivity Test now?"; then
                log_info "Executing HTTP GET request through the Firewall -> Gateway chain..."
                log_warn "If this succeeds, you will see the 'Welcome to nginx!' HTML."
                sleep 2
                kubectl run -i --tty --rm debug-client --image=alpine --restart=Never -- sh -c "apk add -q curl && curl -s http://edge-firewall-svc:80 | grep title"
                log_success "Hello World validation complete! Edge VNF chain is routing correctly."
            fi
            ;;

        "test")
            header "TASK D: EXPERIMENTAL LOAD TESTING (EDGE)"
            export KUBECONFIG=~/.kube/config
            log_info "Ensure you are watching the Edge VM metrics on your Cloud Grafana dashboard."
            echo ""

            log_info "TEST 1: ICMP Ping (Baseline Edge Latency)"
            log_data "Pinging the Edge Firewall Pod directly."
            if ask_yes_no "Run Ping test?"; then
                VNF_POD_IP=$(kubectl get pod -l app=edge-firewall -o jsonpath='{.items[0].status.podIP}')
                log_info "Extracted Firewall Pod IP: $VNF_POD_IP"
                kubectl run -i --tty --rm ping-client --image=alpine --restart=Never -- sh -c "ping -c 5 $VNF_POD_IP"
                log_success "Ping test complete. Record the Edge latency (ms)."
            fi
            echo ""

            log_info "TEST 2: iperf3 (TCP Throughput via Service Chain)"
            log_data "Floods the Edge Firewall with TCP packets to test the K3s bandwidth ceiling."
            if ask_yes_no "Run iperf3 test for 20 seconds?"; then
                kubectl run -i --tty --rm iperf-client --image=networkstatic/iperf3 --restart=Never -- -c edge-firewall-svc -t 20
                log_success "iperf3 test complete. Record the Edge Bitrate (Mbits/sec)."
            fi
            echo ""

            log_info "TEST 3: wrk (HTTP API Load Simulation)"
            log_data "Simulates 100 concurrent users hitting the Edge Service Chain."
            if ask_yes_no "Run wrk HTTP test for 30 seconds?"; then
                kubectl run -i --tty --rm wrk-client --image=ruslanys/wrk --restart=Never -- -c 100 -t 4 -d 30s http://edge-firewall-svc:80
                log_success "wrk test complete. Record the Edge Requests/sec and Latency."
            fi
            ;;

        "stats")
            header "EDGE SYSTEM SPECIFICATIONS (TASK B SUMMARY)"
            local internal_ip=$(hostname -I | awk '{print $1}')

            log_serious "CRITICAL NETWORKING INFO:"
            log_data "Internal IP: ${GREEN}${internal_ip}${NC}"
            log_warn "Ensure this IP is in your Cloud VM's prometheus.yml file!"
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

            log_success "Specs retrieved. Use these to define the Edge environment in your report."
            ;;

        "update")
            header "UPDATE OS PACKAGES"
            update_packages
            ;;

        "down")
            header "STOPPING EDGE SERVICES"
            log_info "Stopping services to reduce compute overhead..."
            sudo systemctl stop k3s 2>/dev/null || true
            sudo systemctl stop node_exporter 2>/dev/null || true
            log_success "K3s and Node Exporter stopped. VM is idling."
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