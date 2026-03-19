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

# --- UI Helpers ---
log_warn()      { echo -e " ${YELLOW}${BOLD}⚠${YELLOW} $1${NC}"; }
log_error()     { echo -e " ${RED}${BOLD}✗${RED} $1${NC}"; }
log_success()   { echo -e " ${GREEN}${BOLD}✓${NC} ${GREEN}$1${NC}"; }
log_data()      { echo -e " ${NC}${BOLD}  >${NC} $1${NC}"; }
log_info()      { echo -e " ${BLUE}${BOLD}i${BLUE} $1${NC}"; }
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

wait_for_pods() {
    log_info "Waiting for all pods in default namespace to be ready..."
    kubectl wait --for=condition=ready pod --all --timeout=90s 2>/dev/null || true
}

# --- Interactive Menu ---
show_menu() {
    clear
    echo -e "${CYAN}${BOLD}☸️  CW2: CLOUD & EDGE VNF ORCHESTRATION${NC}"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}📦 Base Setup${NC}"
    echo -e "  01) $(opt "docker")      Install Docker           02) $(opt "kubectl")     Install Kubectl"
    echo -e "  03) $(opt "minikube")    Install Minikube         04) $(opt "k3s")         Install K3s"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}🔄 Task B: Environment Toggle (Ensure Clean Metrics)${NC}"
    echo -e "  05) $(opt "cloud")       Start Cloud (Minikube)   06) $(opt "edge")        Start Edge (K3s)"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}🚀 Task C & D: Deployment and Experimental Testing${NC}"
    echo -e "  07) $(opt "deploy")      Deploy VNF & Run 'Hello World' Test"
    echo -e "  08) $(opt "test")        Run Experimental Load Tests (iperf3, wrk, ping)"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}📊 Stats & Teardown${NC}"
    echo -e "  09) $(opt "stats")       View VM Specs & Service Status"
    echo -e "  10) $(opt "stop-all")    Halt All Environments & Monitoring Services"

    echo -ne "\n   q) ${NC}[${RED}Quit${NC}]        ${YELLOW}Select an option: ${NC}"

    read -r user_opt
    user_opt=$(echo "$user_opt" | tr '[:upper:]' '[:lower:]')

    case $user_opt in
        1|docker)      run_script "docker" ;;
        2|kubectl)     run_script "kubectl" ;;
        3|minikube)    run_script "minikube" ;;
        4|k3s)         run_script "k3s" ;;
        5|cloud)       run_script "cloud" ;;
        6|edge)        run_script "edge" ;;
        7|deploy)      run_script "deploy" ;;
        8|test)        run_script "test" ;;
        9|stats)       run_script "stats" ;;
        10|stop-all)   run_script "stop-all" ;;
        q|quit|exit)   log_success "Exiting..."; exit 0 ;;
        *)             log_error "Invalid option"; sleep 1; show_menu ;;
    esac
}

# --- Command Logic ---
exec_cmd() {
    case "$1" in
        "docker")
            header "DOCKER ENGINE SETUP"
            if ask_yes_no "Do you want to log into Docker Hub now?"; then
                log_info "Enter your Docker Hub credentials:"
                log_data "$:tyjcVSFL8>~hF"
                docker login -u scab1001
                log_success "Logged into Docker registry."
            fi

            log_info "Adding Docker's official GPG key & Repo..."
            sudo apt-get update -qq
            sudo apt-get install -y -qq ca-certificates curl > /dev/null
            sudo install -m 0755 -d /etc/apt/keyrings
            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            sudo chmod a+r /etc/apt/keyrings/docker.asc
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

            log_info "Installing Docker Engine..."
            sudo apt-get update -qq
            assert_cmd "Docker installed." "Docker installation failed." sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null

            log_info "Adding $USER to the docker group..."
            sudo usermod -aG docker $USER || true
            log_success "Docker setup complete."
            log_serious "CRITICAL: You MUST run 'newgrp docker' in your terminal right now, or log out and back in, for group permissions to apply!"
            ;;

        "kubectl")
            header "KUBECTL CLI SETUP"
            log_info "Downloading latest stable kubectl..."
            assert_cmd "Download complete." "Failed to download." curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

            log_info "Installing to /usr/local/bin..."
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm -f kubectl

            local k_ver=$(kubectl version --client | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            log_success "Kubectl installed successfully: $k_ver"
            ;;

        "minikube")
            header "MINIKUBE (CLOUD) SETUP"
            log_info "Downloading latest Minikube release..."
            assert_cmd "Download complete." "Failed to download." curl -sLO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

            log_info "Installing to /usr/local/bin..."
            sudo install minikube-linux-amd64 /usr/local/bin/minikube
            rm -f minikube-linux-amd64
            log_success "Minikube binaries installed."
            ;;

        "k3s")
            header "K3S (EDGE) SETUP"
            log_info "Installing K3s without starting the service automatically (to prevent metric clashes)..."
            assert_cmd "K3s installed." "Failed to install." bash -c 'curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -'

            log_info "Fixing permissions for the K3s config file..."
            sudo mkdir -p /etc/rancher/k3s
            sudo touch /etc/rancher/k3s/k3s.yaml
            sudo chmod 644 /etc/rancher/k3s/k3s.yaml
            log_success "K3s installation complete. Service is currently dormant."
            ;;

        "cloud")
            header "ACTIVATING CLOUD ENVIRONMENT (MINIKUBE)"
            log_info "Ensuring K3s is strictly disabled to prevent metric contamination..."
            sudo systemctl stop k3s 2>/dev/null || true

            log_info "Starting Minikube via Docker driver (Memory capped at 2048MB)..."
            assert_cmd "Minikube is running." "Failed to start Minikube." minikube start --driver=docker --memory=2048

            log_info "Updating your kubeconfig context..."
            kubectl config use-context minikube > /dev/null
            log_success "Cloud Environment Active. Ready for Task C."
            ;;

        "edge")
            header "ACTIVATING EDGE ENVIRONMENT (K3S)"
            log_info "Ensuring Minikube is strictly disabled to prevent metric contamination..."
            minikube stop 2>/dev/null || true

            log_info "Starting K3s Edge node..."
            assert_cmd "K3s is running." "Failed to start K3s." sudo systemctl start k3s

            log_info "Waiting for API server..."
            sleep 5
            export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
            log_success "Edge Environment Active. Ready for Task C."
            log_serious "CRITICAL: You MUST run 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' in your terminal manually if kubectl commands fail!"
            ;;

        "deploy")
            header "TASK C: VNF DEPLOYMENT & HELLO WORLD"
            if [ ! -f "mec-gateway.yaml" ]; then
                log_error "mec-gateway.yaml not found in current directory! Please create it first."
                exit 1
            fi

            log_info "Applying VNF Manifests (HAProxy Gateway + Backends)..."
            assert_cmd "Manifests applied." "Apply failed." kubectl apply -f mec-gateway.yaml
            assert_cmd "Manifests applied." "Apply failed." kubectl apply -f 5g-service-chain.yaml

            wait_for_pods

            log_info "Pods Currently Running:"
            kubectl get pods | sed 's/^/  > /'

            if ask_yes_no "Run the 'Hello World' Connectivity Test now?"; then
                log_info "Executing HTTP GET request through the VNF Gateway from a temporary pod..."
                log_warn "If this succeeds, you will see the 'Welcome to nginx!' raw HTML."
                sleep 2
                kubectl run -i --tty --rm debug-client --image=alpine --restart=Never -- sh -c "apk add -q curl && curl -s http://mec-gateway-svc:80 | grep title"
                log_success "Hello World validation complete! The VNF is routing traffic correctly."
            fi
            ;;

        "test")
            header "TASK D: EXPERIMENTAL LOAD TESTING"
            log_info "Ensure you have your Grafana dashboard open to watch the CPU/Memory spikes."
            log_warn "Tests should be run in both Cloud and Edge environments to compare results."
            echo ""

            # log_info "TEST 1: ICMP Ping (Baseline Network Latency)"
            # log_data "This tests the base orchestration overhead before hitting the application layer."
            # if ask_yes_no "Run Ping test?"; then
            #     kubectl run -i --tty --rm ping-client --image=alpine --restart=Never -- sh -c "ping -c 5 mec-gateway-svc"

            #     log_success "Ping test complete. Record the avg latency (ms) for your report."
            # fi
            # echo ""

            log_info "TEST 1: ICMP Ping (Baseline Network Latency)"
            log_data "Pinging the VNF Pod directly (K8s Services drop ICMP traffic)."
            if ask_yes_no "Run Ping test?"; then
                # Dynamically extract the Pod IP of the HAProxy VNF
                VNF_POD_IP=$(kubectl get pod -l app=mec-gateway -o jsonpath='{.items[0].status.podIP}')
                log_info "Extracted VNF Pod IP: $VNF_POD_IP"
                kubectl run -i --tty --rm ping-client --image=alpine --restart=Never -- sh -c "ping -c 5 $VNF_POD_IP"
                log_success "Ping test complete. Record the avg latency (ms) for your report."
            fi
            echo ""

            # TODO: Separate tests.
            log_info "TEST 2: iperf3 (TCP Throughput via VNF)"
            log_data "This floods the VNF with TCP packets to find the maximum bandwidth ceiling."
            if ask_yes_no "Run iperf3 test for 20 seconds?"; then
                kubectl run -i --tty --rm iperf-client --image=networkstatic/iperf3 --restart=Never -- -c mec-gateway-svc -t 20
                kubectl run -i --tty --rm iperf-client --image=networkstatic/iperf3 --restart=Never -- -c edge-firewall-svc -t 20
                log_success "iperf3 test complete. Record the Bitrate (e.g. Mbits/sec) for your report."
            fi
            echo ""

            log_info "TEST 3: wrk (HTTP API Load Simulation)"
            log_data "Simulates 100 concurrent 5G users hammering the VNF Gateway with requests."
            if ask_yes_no "Run wrk HTTP test for 30 seconds?"; then
                kubectl run -i --tty --rm wrk-client --image=ruslanys/wrk --restart=Never -- -c 100 -t 4 -d 30s http://mec-gateway-svc:80
                kubectl run -i --tty --rm wrk-client --image=ruslanys/wrk --restart=Never -- -c 100 -t 4 -d 30s http://edge-firewall-svc:80
                log_success "wrk test complete. Record the Requests/sec and Latency for your report."
            fi
            ;;

        "stats")
            header "SYSTEM SPECIFICATIONS (TASK B SUMMARY)"
            log_info "Operating System:"
            cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' | sed 's/^/  > /'

            log_info "CPU Architecture:"
            lscpu | grep "Model name:" | sed 's/^/  > /'
            lscpu | grep "CPU(s):" | head -1 | sed 's/^/  > /'

            log_info "Memory (RAM):"
            free -h | grep Mem | awk '{print "  > Total: " $2 " | Used: " $3}'

            log_info "Environment Status:"
            minikube status 2>/dev/null | grep -q "host: Running" && echo "  > Minikube (Cloud): ACTIVE" || echo "  > Minikube (Cloud): Stopped"
            systemctl is-active --quiet k3s && echo "  > K3s (Edge): ACTIVE" || echo "  > K3s (Edge): Stopped"
            systemctl is-active --quiet prometheus && echo "  > Prometheus: Running" || echo "  > Prometheus: Stopped"
            systemctl is-active --quiet grafana-server && echo "  > Grafana: Running" || echo "  > Grafana: Stopped"

            log_success "Specs retrieved. Use these exactly in your report."
            ;;

        "stop-all")
            header "HALTING ALL ENVIRONMENTS & SERVICES"
            log_warn "This will stop all K8s engines AND your monitoring stack to save VM resources."
            if ask_yes_no "Proceed?"; then
                log_info "Stopping Orchestrators..."
                minikube stop 2>/dev/null || true
                sudo systemctl stop k3s 2>/dev/null || true

                log_info "Stopping Monitoring Stack..."
                sudo systemctl stop prometheus 2>/dev/null || true
                sudo systemctl stop node_exporter 2>/dev/null || true
                sudo systemctl stop grafana-server 2>/dev/null || true

                log_success "All heavy services halted. Your VM is idling."
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