# GenAI Troubleshooting Log

**Tool Used:** M365 Microsoft Copilot (In-line completions and Chat)

**Statement of Compliance:** In accordance with the coursework regulations, Generative AI was used strictly in an assistive capacity for troubleshooting, diagnosing system faults, and clarifying error messages. All core architectural designs, infrastructure-as-code (IaC) scripts, ETSI MANO Kubernetes manifests, and experimental data analyses are original contributions.

---

### Incident 1: Kubernetes API Connection Refusal

**Issue Encountered:** When attempting to verify the running status of the VNFs on the Cloud VM, the terminal returned a fatal error, preventing access to the cluster state.
* **Error Message:** `The connection to the server localhost:8080 was refused - did you specify the right host or port?`

**GenAI Prompt:**
> I deployed Minikube successfully, but when I run 'sudo kubectl get pods', I get a connection refused error on localhost:8080. Why is it failing to connect?

**AI Diagnostic Output:** Copilot explained that this is a Linux user-context issue. `kubectl` relies on a configuration file located at `~/.kube/config` to authenticate with the API server. By prepending the command with `sudo`, the command executes as the `root` user, which looks for the config in `/root/.kube/config`. Since Minikube was installed under the standard `azureuser` account, the root directory lacked the certificates, causing `kubectl` to default to an unencrypted, closed port (8080).

**Application & Resolution:** I dropped the `sudo` prefix from my testing commands. I updated my internal documentation to ensure all cluster queries (`kubectl get pods`, `kubectl run`) were executed purely within the `azureuser` context, which solved the problem.

---

### Incident 2: Bash Script Execution Hangs

**Issue Encountered:** During the development of the interactive `bootstrap-cloud.sh` script, selecting Option `05` (Start Cloud Services) would cause the terminal to hang indefinitely if Minikube was already running, requiring a hard reset of the SSH session.

**GenAI Prompt:**
> My bash script runs 'minikube start' and 'systemctl start prometheus'. If the services are already running, the script hangs and freezes the terminal. Why is this happening and how can I prevent this?

**AI Diagnostic Output:** Copilot suggested that running startup commands on active services forces the orchestrator to re-verify container images and network bridges, which can stall resource-constrained Azure VMs. It recommended implementing **idempotency** (checking the state of the service before attempting to start it). It provided the syntax for checking systemd states (`systemctl is-active`).

**Application & Resolution:** Instead of having the AI rewrite the script, I wrapped the suggested diagnostic commands around my utility functions. I implemented `if minikube status 2>/dev/null | grep -q "host: Running"; then` to verify the state, allowing the script to skip the startup sequence if the environment was already active.

---

### Incident 3: Orphaned Kubernetes Resources

**Issue Encountered:** After optimising the `5g-service-chain.yaml` manifest to combine the `iperf3` and `nginx` backend servers into a single deployment (`target-servers`), applying the manifest to the Cloud VM resulted in 6 running pods instead of the expected 4.

**GenAI Prompt:**
> I updated my Kubernetes YAML to combine two deployments into one. When I run 'kubectl apply -f manifest.yaml', the new combined pod starts, but the two old pods from yesterday are still running. Why didn't apply remove them?

**AI Diagnostic Output:** Copilot clarified the difference between declarative and imperative Kubernetes management. It explained that `kubectl apply` only updates resources that currently exist in the YAML file. If a block of code (like the old `iperf-server` deployment) is deleted from the file, Kubernetes ignores it rather than destroying it, leaving "orphaned" resources running in the cluster.

**Application & Resolution:** Understanding this behaviour, I searched the kubectl Quick Reference page and discovered  `kubectl delete deployment` command. I ran this on the Cloud VM to eradicate the orphaned pods. This restored parity between the Cloud and Edge environments, ensuring a fair and accurate baseline for the load testing.

---

### Incident 4: SSH Timeout due to Azure JIT Network Security Rules

**Issue Encountered:** SSH connections to the Azure VMs timed out entirely when working from my personal Lenovo machine, despite connecting flawlessly the previous day from the university lab machine.
* **Error Message:** `ssh: connect to host 20.90.75.243 port 22: Connection timed out`

**GenAI Prompt:**
> My SSH connection to my Azure VM is suddenly timing out from my personal laptop, but it worked yesterday on the lab PC. I checked my Azure Network Security Group and there is a rule called 'MicrosoftDefenderForCloud-JITRule' blocking port 22. What is this rule and how is it affecting my connection?

**AI Diagnostic Output:** Copilot explained that Microsoft Defender for Cloud's Just-In-Time (JIT) VM access secures management ports by dynamically restricting inbound traffic to specific, known IP addresses. Because my development started on the lab PC (which operates on a static IP), the JIT rule locked SSH access to that specific location. When I transitioned to my Lenovo laptop (which operates on a dynamically changing home network IP), the existing JIT rule did not recognise the new source IP and proactively dropped the packets.

**Application & Resolution:** I navigated to the Microsoft Azure Portal and increased the priority of the SSH rule so that it would accept my connection. Copilot suggested against this but given this is a development environment, I felt safe in making the decision.
