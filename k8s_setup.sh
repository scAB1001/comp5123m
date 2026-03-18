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

# --- Interactive Menu ---
show_menu() {
    clear
    echo -e "${CYAN}${BOLD}☸️  KUBERNETES ORCHESTRATION SETUP${NC}"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}🛠️  Installation Base${NC}"
    echo -e "  01) $(opt "docker")      Install Docker Engine    02) $(opt "kubectl")     Install Kubectl CLI"
    echo -e "  03) $(opt "minikube")    Install Minikube (Cloud) 04) $(opt "k3s")         Install K3s (Edge)"
    echo -e "  05) $(opt "install-all") Install Everything Above"
    echo -e "-------------------------------------------------------------------------------------"
    echo -e "${BOLD}🔄  Environment Toggle (Ensures Clean Metrics)${NC}"
    echo -e "  06) $(opt "cloud")       Start Cloud (Minikube)   07) $(opt "edge")        Start Edge (K3s)"
    echo -e "  08) $(opt "stop-all")    Halt All K8s Clusters"

    echo -ne "\n   q) ${NC}[${RED}Quit${NC}]        ${YELLOW}Select an option: ${NC}"

    read -r user_opt
    user_opt=$(echo "$user_opt" | tr '[:upper:]' '[:lower:]')

    case $user_opt in
        1|docker)      run_script "docker" ;;
        2|kubectl)     run_script "kubectl" ;;
        3|minikube)    run_script "minikube" ;;
        4|k3s)         run_script "k3s" ;;
        5|install-all)
            run_script "docker"
            run_script "kubectl"
            run_script "minikube"
            run_script "k3s"
            ;;
        6|cloud)       run_script "cloud" ;;
        7|edge)        run_script "edge" ;;
        8|stop-all)    run_script "stop-all" ;;
        q|quit|exit)   log_success "Exiting..."; exit 0 ;;
        *)             log_error "Invalid option"; sleep 1; show_menu ;;
    esac
}

# --- Command Logic ---
exec_cmd() {
    case "$1" in
        "docker")
            header "DOCKER ENGINE SETUP"
            log_info "Adding Docker's official GPG key..."
            sudo apt-get update -qq
            sudo apt-get install -y -qq ca-certificates curl > /dev/null
            sudo install -m 0755 -d /etc/apt/keyrings
            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            sudo chmod a+r /etc/apt/keyrings/docker.asc

            log_info "Adding repository to Apt sources..."
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

            log_info "Installing Docker Engine..."
            sudo apt-get update -qq
            assert_cmd "Docker installed." "Docker installation failed." sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null

            log_info "Adding $USER to the docker group..."
            sudo usermod -aG docker $USER || true
            log_warn "You may need to log out and log back in (or run 'newgrp docker') for group changes to take effect."
            ;;

        "kubectl")
            header "KUBECTL CLI SETUP"
            log_info "Downloading latest stable kubectl..."
            assert_cmd "Download complete." "Failed to download." curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

            log_info "Installing to /usr/local/bin..."
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm kubectl

            local k_ver=$(kubectl version --client | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            log_success "Kubectl installed: $k_ver"
            ;;

        "minikube")
            header "MINIKUBE (CLOUD) SETUP"
            log_info "Downloading latest Minikube release..."
            assert_cmd "Download complete." "Failed to download." curl -sLO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

            log_info "Installing to /usr/local/bin..."
            sudo install minikube-linux-amd64 /usr/local/bin/minikube
            rm minikube-linux-amd64
            log_success "Minikube binaries installed."
            ;;

        "k3s")
            header "K3S (EDGE) SETUP"
            log_info "Installing K3s without starting the service automatically (to prevent clashes)..."

            # INSTALL_K3S_SKIP_START=true ensures it installs but stays dead until we need it
            assert_cmd "K3s installed." "Failed to install." bash -c 'curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -'

            log_info "Fixing permissions for the K3s config file..."
            sudo mkdir -p /etc/rancher/k3s
            sudo touch /etc/rancher/k3s/k3s.yaml
            sudo chmod 644 /etc/rancher/k3s/k3s.yaml

            log_success "K3s installation complete. Service is currently dormant."
            ;;

        "cloud")
            header "ACTIVATING CLOUD ENVIRONMENT (MINIKUBE)"
            log_info "Ensuring K3s is strictly disabled..."
            sudo systemctl stop k3s 2>/dev/null || true

            log_info "Starting Minikube via Docker driver..."
            # We enforce the docker driver to keep it containerised
            assert_cmd "Minikube is running." "Failed to start Minikube." minikube start --driver=docker

            log_info "Updating your kubeconfig context..."
            kubectl config use-context minikube
            log_data "Current nodes:"
            kubectl get nodes
            ;;

        "edge")
            header "ACTIVATING EDGE ENVIRONMENT (K3S)"
            log_info "Ensuring Minikube is strictly disabled..."
            minikube stop 2>/dev/null || true

            log_info "Starting K3s service directly on host..."
            assert_cmd "K3s is running." "Failed to start K3s." sudo systemctl start k3s

            log_info "Updating your kubeconfig context..."
            sleep 3 # Give the API server a moment to spin up
            export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
            log_warn "Notice: For K3s, you may need to run 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' in new terminal sessions."

            log_data "Current nodes:"
            sudo k3s kubectl get nodes
            ;;

        "stop-all")
            header "HALTING ALL KUBERNETES ENVIRONMENTS"
            log_info "Stopping Minikube..."
            minikube stop 2>/dev/null || true
            log_info "Stopping K3s..."
            sudo systemctl stop k3s 2>/dev/null || true
            log_success "All orchestration engines halted. VM is idling."
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