# GenAI troubleshooting

## Direct Relevance to the Coursework Data for every lecture

This theory is the missing puzzle piece for your Task E report. Here is exactly how to weave this lecture into your findings:
1. Connecting "Server Consolidation" to your Edge Results
Your 3-VNF Service Chain on K3s is a perfect microcosm of Server Consolidation. You packed a Firewall, a DPI Inspector, and a Gateway tightly together on a single, resource-constrained Edge VM. The lecture notes that consolidation creates "Hotspots." However, your data proved that because you used lightweight, memory-optimized container proxies (NGINX/HAProxy), you achieved extreme consolidation without creating a CPU hotspot. The Edge node handled 1000+ Req/sec effortlessly.

2. Connecting "Network-Aware Scheduling" to Minikube's Failure
The lecture mentions "Network-aware" scheduling, which tries to minimize data transfer times. Your Cloud VM (Minikube with Docker) failed this concept. By forcing traffic through the heavy Docker virtual bridge network, the "transfer time" between your Firewall Pod and Gateway Pod was artificially inflated, resulting in your HTTP latency hitting 151ms. K3s bypassed this heavy virtualization, aligning with optimal network-aware performance.

3. Connecting "Scaling" to your 3-VNF Experiment
When we added the DPI Emulator to your chain, we executed a Scale Out strategy. Instead of making the Firewall bigger (Scale Up) to handle Deep Packet Inspection, we chained a dedicated horizontal node to distribute the architecture. Your data proves that K3s handles this Service Function Chain Scale-Out with zero loss in bandwidth.

This theory perfectly validates the architecture you just built and tested. Here is how you map this lecture to your Task E report:
1. The "Container Runtime Engine" defines your Edge vs. Cloud performance. The lecture states the Container Runtime physically manages the containers. On your Cloud VM, Minikube uses Docker as its runtime, which requires a heavy, background daemon. On your Edge VM, K3s strips out Docker and uses containerd, a highly streamlined runtime. This theoretical difference is the exact reason your Edge VM handled HTTP routing with 40% lower latency.

2. The Role of kube-proxy in your 3-VNF Chain.
When you chained your Firewall → DPI Inspector → Gateway, you didn't use IP addresses; you used K8s Services (e.g., http://dpi-inspector-svc:80). The lecture notes that kube-proxy manages this translation via iptables. You can mention in your report that K3s manages these iptables rules far more efficiently on a single node than Minikube does, preventing network bottlenecks during deep Service Function Chaining.

3. Nephio and the "Free5GC" Decision.
The lecture highlights Nephio and Free5GC as standard 5G telco tools. However, these tools require robust Control Planes to orchestrate. Because your Edge VM simulates a constrained Raspberry Pi 5, deploying a full Free5GC core would overwhelm the kube-scheduler (which would see no available capacity via bin-packing). This justifies your decision to build a lightweight, proxy-based UPF emulator instead.

This lecture is the theoretical "skeleton" that supports the "meat" of the Kubernetes experiments you just completed. Here is how you map this directly into your Task E report:
1. You Built an ETSI MANO Implementation:
    In the ETSI architecture, the Orchestrator manages the lifecycle of the VNFs. In your coursework, Kubernetes (Minikube/K3s) is the Orchestrator.
    When you wrote kubectl apply -f 5g-service-chain.yaml, you were acting as the MANO layer, translating an intent into a deployment.

2. You Built a VNF Service Chain (Service Graph):
    The lecture explicitly mentions that after VNFs are instantiated, they must be "connected to other programs to form the so-called service chain."
    This is exactly what you did when you wired your NGINX Firewall to your NGINX DPI Emulator, and finally to your HAProxy UPF Gateway. Using this exact terminology ("We constructed a 3-VNF Service Graph consisting of...") will heavily impress the examiner.

3. You Proved the NFV Edge Computing Thesis:
    The lecture states that NFV replaces specialized hardware with standard servers. However, running heavy telecom routing on standard servers introduces latency.
    Your data proves that pushing this NFV Service Chain to the Edge (K3s) using lightweight containerization mitigates that latency, achieving a highly efficient 90ms response time compared to the Cloud's 143ms. You have empirically validated the core goal of 5G Edge NFV.

Synthesis: The Final Report Structure
You now have the data, the architecture, and the theoretical backing.
To maximize your marks, your final Task E: Results and Discussion should be structured exactly like this:
    Architectural Context: Define your setup using ETSI terminology (Kubernetes as the MANO layer, NGINX/HAProxy as the VNFs, forming a 5G Service Graph).
    The Environment Duel (Minikube vs. K3s): Use the theory from Lecture 1 (Resource Management) and Lecture 2 (Container Management) to explain why you chose Minikube for the Cloud and K3s for the Edge.
    Data Analysis (The Core): Present your tables. Discuss why K3s won (native containerd routing vs. Docker overhead).
    The Complexity Stress Test: Discuss the addition of the DPI Emulator (Scale-Out strategy). Explain why the Edge node survived the consolidation without creating a CPU hotspot.
    Conclusion & Literature Contrast: Wrap up by stating how your findings align with current academic research on Edge NFV efficiency.

This lecture provides fantastic contrast for your coursework methodology. You can use these concepts in your report to critique your own setup and suggest enterprise-grade improvements.

1. You Used "Declarative IaC" for your VNFs (Task C & D)
When you wrote 5g-service-chain.yaml and ran kubectl apply -f, you were strictly practicing Declarative Infrastructure as Code. You defined the desired end state (3 VNFs, specific resource limits), and Kubernetes figured out how to pull the images and route the traffic.

2. You Used "Imperative Configuration" for your VMs (Task B)
To build your Azure VMs (vm-ab and vm-edge) and open the network ports (9100, 22), you likely used the Azure GUI or Azure CLI. Furthermore, your exec.sh scripts are imperative Bash scripts.
    The Report Talking Point: In a professional environment, manual VM creation is an anti-pattern. You should explicitly mention in your report: "While this coursework utilized Bash scripts and manual Azure provisioning for Task B, a production-grade 5G Edge deployment would utilize an IaC tool like Terraform to dynamically provision the Azure Virtual Networks and VMs, completely eliminating configuration drift between the Cloud and Edge nodes."

3. The Role of "Provisioners" in your Scripts
Your exec.sh scripts act exactly like a Terraform Provisioner or an Ansible playbook. They log into a raw, empty VM and install the necessary software (Docker, K3s, Prometheus). Framing your master scripts as "imperative configuration management tools" shows the examiner you deeply understand the DevOps landscape.

While your coursework focused on deploying "Microservices" (HAProxy and NGINX) rather than Serverless "Nanoservices," understanding FaaS is critical for the architectural comparison section of your report or potential interview questions.
1. The "Scale to Zero" Contrast:
    In your coursework, you used standard Kubernetes Deployments. Your HAProxy pod was running 24/7, consuming RAM even when you weren't running wrk tests.
    If you had deployed HAProxy using Knative, it would have scaled down to zero pods when you stopped testing, freeing up 100% of your Edge VM's memory. When you started wrk again, Knative would have caught the traffic, held it for a second, spun up the Pod (experiencing a Cold Start), and then routed the traffic.

2. The Microservice vs. Nanoservice Distinction:
    Your VNF (HAProxy) is a Microservice. It is a long-running, state-aware network router that handles multiple concurrent connections simultaneously inside a single Pod.
    A Nanoservice (FaaS) would be a single Python script that executes one specific math calculation and immediately dies

While your coursework focused on network orchestration rather than data processing, this lecture ties directly into the administrative choices you made:
1. Connecting AMIs to your Azure Setup (Task B):
    The lecture heavily discusses AWS AMIs (Amazon Machine Images). In your coursework, you used the exact Azure equivalent: Azure Marketplace Images. When you selected "Ubuntu Server 22.04 LTS" for your Cloud VM, you were using a Public Image. Mentioning the AWS (AMI) vs. Azure (Marketplace Image) parallel in your report shows a strong, cross-platform understanding of cloud provisioning.

2. The Service Lifecycle & Kubernetes Manifests (Task C):
    The lecture states that defining "Capacity (CPU, memory...)" is a core part of the Service Lifecycle. You executed this perfectly in your 5g-service-chain.yaml by using the resources: limits: { memory: "100Mi", cpu: "200m" } block. You can explicitly state in your report that your Kubernetes manifests fulfill the "Service Requirement Definition" phase of the Cloud Lifecycle.

3. The Go Language Foundation:
    Your Edge node runs K3s, and your monitoring stack uses Prometheus. Both of these tools are famously written in Go. The lecture specifically highlights Go as the language of choice for cloud tools due to its concurrent operations. This is a subtle but excellent point to drop into your methodology defense for why these tools are so lightweight and efficient on the Edge.