# GenAI Troubleshooting Log

**Tool Used:** M365 Microsoft Copilot (In-line completions and Chat)

**Statement of Compliance:** In accordance with the coursework regulations, Generative AI was used strictly in an assistive capacity for troubleshooting, diagnosing system faults, and clarifying error messages. Core architectural designs, infrastructure-as-code (IaC) scripts, ETSI MANO Kubernetes manifests and experimental data analyses are original contributions.

---

## Incidents

| Incident | Problem Encountered | GenAI Proposed Solution | Application & Outcome | Worked? |
| :--- | :--- | :--- | :--- | :--- |
| **1. K8s API Connection Refusal** | Running `sudo kubectl get pods` on the Cloud VM returned a fatal connection refused error on `localhost:8080`. | Explained that `kubectl` relies on `~/.kube/config` for authentication. Using `sudo` forces the command to look in the `/root` directory instead of the `azureuser` directory, causing it to default to an unencrypted, closed port. | Dropped the `sudo` prefix from all testing commands. All cluster queries were executed purely within the `azureuser` context. | **Yes** |
| **2. Bash Script Execution Hangs** | Selecting Option `05` in `bootstrap-cloud.sh` caused the terminal to hang indefinitely if Minikube or Prometheus were already running. | Suggested implementing idempotency. Running startup commands on active services stalls the orchestrator; the AI provided syntax for checking systemd states (`systemctl is-active`) before execution. | Wrapped diagnostic commands around utility functions (e.g., `if minikube status...`) to verify the state and skip the startup sequence if the environment was already active. | **Yes** |
| **3. Orphaned Kubernetes Resources** | Applying an updated `5g-service-chain.yaml` manifest (combining two deployments into one) left the old, deleted deployments running as orphaned pods. | Clarified the difference between declarative and imperative management. `kubectl apply` only updates existing blocks; it ignores code deleted from the YAML rather than destroying the associated resources. | Used the imperative `kubectl delete deployment` command on the Cloud VM to manually eradicate the orphaned pods, restoring parity for load testing. | **Yes** |
| **4. SSH Timeout (Azure JIT)** | SSH connections to the Azure VM timed out from a personal laptop, despite working on a university lab PC the previous day. | Explained that Microsoft Defender for Cloud's Just-In-Time (JIT) rule locked inbound SSH access to the lab PC's static IP. The rule proactively dropped packets from the dynamic home network IP. | Navigated to the Azure Portal and manually increased the priority of the SSH rule to accept the connection. (GenAI advised against this, but it was deemed safe for a temporary development environment). | **Yes** |

## Technical Opinion on the Effectiveness of GenAI

Generative AI is a highly effective tool for accelerating mundane development tasks, such as code completion, information retrieval, and initial error diagnosis. It excels at quickly parsing log files and explaining the underlying mechanics of standard system faults.

However, its utility drops sharply when dealing with complex or highly specific architectural configurations. The AI frequently proposes solutions that include technical inaccuracies, flawed logic, or directions that actively derail the troubleshooting process. Because of this unreliability, GenAI cannot be trusted blindly; it requires constant, critical oversight and manual verification by the developer to ensure the proposed solutions are both secure and contextually appropriate.
