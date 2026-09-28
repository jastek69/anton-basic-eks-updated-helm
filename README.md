# EKS with EBS CSI, Kong Ingress, and Prometheus

![IaC](https://img.shields.io/badge/IaC-Terraform-orange)
![EKS](https://img.shields.io/badge/Kubernetes-Amazon%20EKS-FF9900?logo=amazoneks)
![Helm](https://img.shields.io/badge/Packages-Helm-0F1689?logo=helm)
![Kong](https://img.shields.io/badge/Ingress-Kong%203.9-003459?logo=kong)
![k6](https://img.shields.io/badge/Load%20test-k6-7D64FF?logo=k6)

A Terraform-built Amazon EKS cluster plus the platform layer that workloads need on top of it: persistent volumes through the EBS CSI driver with IRSA, Kong as the single ingress with API-key auth and rate limiting, and kube-prometheus-stack for monitoring.

> Cluster command notes (kubectl, Helm, Grafana access, teardown): [`docs/CLUSTER-COMMANDS.md`](docs/CLUSTER-COMMANDS.md) · Kong lab: [`Kong_README.md`](Kong_README.md) · Runbook: [`kube_runbook.md`](kube_runbook.md)

---

# Executive Summary

Terraform provisions a VPC across two AZs, public and private subnets, NAT, an EKS control plane in `API` authentication mode, and a private on-demand node group. It adds an IAM OIDC provider and installs the **EBS CSI driver via the Helm provider** with an IRSA role, then points `kubectl` at the new cluster automatically.

On that platform, **Kong Ingress Controller** routes `/hello` to an echo service behind **key-auth** and a **5-requests-per-minute rate limit**, verified under load with **k6**. Monitoring is **kube-prometheus-stack** (Prometheus, Grafana, Alertmanager) on EBS-backed volumes.

About 30 Terraform resources. Correctness is verified by `terraform validate` in CI and by captured k6 and curl evidence of key and rate-limit enforcement in `Reports/`.

---

## Problem

- **A bare EKS cluster can't run stateful workloads.** PersistentVolumes need the EBS CSI driver, and the driver needs an IAM role scoped to its ServiceAccount, not the node role.
- **Exposing every service directly scatters policy.** Each app would re-implement auth, rate limits, and routing.
- **Ingress policy has to be proven.** "The plugin is installed" isn't evidence that keyless or over-limit requests are actually refused.

---

## Solution

- **Terraform from VPC to kubeconfig.** Numbered files build network → EKS → node group → OIDC → storage IAM → Helm release. A `null_resource` runs `aws eks update-kubeconfig` after apply.
- **IRSA for the CSI driver.** An OIDC provider plus a role trusted only by `system:serviceaccount:kube-system:ebs-csi-controller-sa`. Nodes don't get EBS permissions.
- **Isolated Helm provider state.** `repository_config_path` and `repository_cache` point inside the module, so a stale local `helm repo` can't break the apply.
- **Kong as the front door.** Ingress routes, a `KongConsumer` with a key-auth credential, a rate-limiting plugin, the Gateway API CRDs that KIC 3.x requires, and RBAC for cross-namespace credential Secrets.

Governing constraint: **policy lives at the edge, not in the app.** Services stay plain HTTP echo apps, and Kong decides who gets in and how often.

---

## Architecture

```
                         ┌──────────── VPC 10.100.0.0/16 (us-west-2a, us-west-2b) ────────────┐
Client + apikey ──► Kong proxy (LB) ──► Ingress /hello ──► hello Service ──► echo Pods      │
                         │  key-auth · rate-limit 5/min                                       │
                         │                                                                    │
  EKS control plane (auth mode API) ──► private node group (t3.large, on-demand)              │
                         │     ├─ kube-system: EBS CSI controller  (IRSA → ebs_csi_iam_role)  │
                         │     └─ observability: Prometheus · Grafana · Alertmanager (gp2 PVs)│
                         └────────────────────────────────────────────────────────────────────┘
k6 / curl loops ──► Kong  (evidence → Reports/)
```

Diagrams: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

---

## Technologies

| Domain | Services |
|---|---|
| IaC | Terraform (AWS + Helm providers), numbered root files `00`–`99` |
| Kubernetes | Amazon EKS (auth mode `API`), managed node group, IAM OIDC / IRSA |
| Storage | AWS EBS CSI driver (Helm), gp2 StorageClass |
| Ingress | Kong Ingress Controller 3.x (Kong 3.9), Gateway API CRDs v1.1, key-auth + rate-limiting plugins |
| Observability | kube-prometheus-stack (Prometheus, Grafana, Alertmanager) via Helm |
| Testing | k6 (JavaScript), bash curl loops |

---

## Deployment

**Prerequisites:** Terraform, AWS CLI, kubectl, Helm, and k6. State is **local** (the S3 backend block in `backend.tf` is commented out).

```bash
terraform init
terraform apply                        # VPC → EKS → nodes → OIDC → EBS CSI; updates kubeconfig
kubectl get nodes
kubectl get pods -n kube-system        # ebs-csi-controller / -node Running
```

Platform layer (see [`Kong_README.md`](Kong_README.md) and [`docs/CLUSTER-COMMANDS.md`](docs/CLUSTER-COMMANDS.md)):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
helm install kong kong/ingress -n kong --create-namespace
kubectl apply -f yaml/kong_controller_secrets_rbac.yaml
kubectl apply -f yaml/kong_helloapp.yaml -f yaml/kong_helloservice.yaml -f yaml/kong_helloingress.yaml
```

**Teardown order matters:** `helm uninstall` releases and delete the `observability` namespace **before** `terraform destroy`. Otherwise Helm-created LoadBalancers and EBS volumes orphan outside Terraform and keep billing. **Idle cost:** EKS control plane plus `t3.large` nodes plus NAT.

---

## Security

- **IRSA, not node permissions.** Only the CSI controller's ServiceAccount can assume the EBS role.
- **Private nodes.** The node group runs in private subnets. Egress goes through NAT.
- **Access entries.** `authentication_mode = "API"` with bootstrap cluster-creator admin, so there's no `aws-auth` ConfigMap to hand-edit.
- **Edge policy:** Kong key-auth plus rate-limiting in front of services.
- **Lab relaxations:** the cluster API endpoint is **public** (no VPN in this lab), and the demo Kong API key is committed in `yaml/galactus_key.yaml`. See [`SECURITY.md`](SECURITY.md).

---

## Repository Structure

```
.
├── 00-variables.tf … 12-runtime.tf, 99-output.tf   VPC, subnets, IGW, NAT, routes, EKS, nodes, OIDC, EBS CSI IAM + Helm, kubeconfig
├── yaml/            Namespaces, basic pod/deployment/service, Kong app/service/ingress, plugins, consumer, RBAC
├── javascript/      k6 tests: rate_test.js, key_rate_test.js
├── bash/            curl loops: simpleloop.sh, keyloop.sh
├── Reports/         Evidence: Kong install, hello route, k6 key and rate tests
├── prometheus/      kube-prometheus-stack values + notes
├── namespaces/      Namespace manifests
└── docs/            Cluster commands, architecture, testing
```

| Document | Covers |
|---|---|
| [`docs/CLUSTER-COMMANDS.md`](docs/CLUSTER-COMMANDS.md) | Original README: kubectl basics, Prometheus Helm install, Grafana/Prometheus URLs, teardown |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Mermaid diagrams: Terraform build order, IRSA trust, Kong request path |
| [`docs/TESTING.md`](docs/TESTING.md) | CI checks, platform verification, k6 and curl tests with evidence, known gaps |
| [`SECURITY.md`](SECURITY.md) | Vulnerability reporting, controls, lab relaxations, secrets |
| [`Kong_README.md`](Kong_README.md) | Kong lab: phases, Ingress, plugins, reflection |
| [`kube_runbook.md`](kube_runbook.md) | Requirements, Gateway API CRDs, controller RBAC, k6 install |
| [`prometheus/prometheus_README.md`](prometheus/prometheus_README.md) | Monitoring stack notes |

---

## Lessons Learned

**KIC 3.x needs the Gateway API CRDs even for classic `Ingress`.** Its CRDs, including `KongConsumer`, use Gateway API status conditions. Without the CRDs installed, consumer and credential reconciliation silently never completes: no error, and the key simply never works.

**Controller RBAC is namespace-scoped by default.** The `kong-controller` ServiceAccount couldn't read credential Secrets in `default` until an explicit Role and RoleBinding were added. Restart the controller after either fix so it re-reads.

**Isolate the Helm provider's repository state.** A stale or missing index for an unrelated repo added by hand (`helm repo add prometheus-community …`) blocked Terraform's chart resolution. Pointing the provider at a module-local repository config fixed it for good.

**Helm-created cloud resources are invisible to Terraform.** LoadBalancers from `Service type=LoadBalancer` and EBS volumes from PVCs block VPC and subnet deletion if they're still there at `destroy`.

**Rate-limit headers are the evidence.** `X-RateLimit-Remaining-Minute` counting down to 0, then a 429, proves enforcement far better than "the plugin is attached".

---

## Future Improvements

- **Private API endpoint** plus a bastion, VPN, or SSM path, and remove public endpoint access.
- **Template the demo API key.** Generate `galactus_key.yaml` from a Secret created at deploy time (or External Secrets) instead of committing the value.
- **Enable the S3 backend** with lockfile for shared state.
- **Move Kong and monitoring into Terraform** (Helm releases) so teardown order is enforced by the dependency graph.
- **gp3 StorageClass** as the default, instead of gp2.
- **CI-run k6** against an ephemeral cluster, asserting 401 without a key and 429 over the limit.
- **OPA / Gatekeeper, Argo CD, Splunk:** local work-in-progress folders exist and aren't yet committed or documented.
