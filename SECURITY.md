# Security Policy

## Reporting a vulnerability

Please **don't** open a public issue. Email **jastek.sweeney@gmail.com** with the affected file and details.

This is a **public** lab repository. The cluster is meant to be short-lived.

---

## Controls in place

| Area | Control |
|---|---|
| Storage IAM | IRSA. The EBS CSI role is trusted only by `kube-system/ebs-csi-controller-sa`. Nodes have no EBS permissions. |
| Nodes | Private subnets, managed node group, AWS-managed worker, CNI, and ECR read-only policies |
| Cluster access | EKS access entries (`authentication_mode = "API"`), no `aws-auth` ConfigMap |
| Ingress | Kong key-auth + rate limiting (5/min) in front of services |
| Kong controller | Explicit Role and RoleBinding to read credential Secrets cross-namespace, instead of a ClusterRole |

## Lab relaxations (change before real use)

| Relaxation | Why it's here | Production |
|---|---|---|
| **Public EKS API endpoint** (`endpoint_public_access = true`, private access off) | No VPN or bastion in the lab | Private endpoint + VPN, SSM, or bastion, or restrict `public_access_cidrs` |
| **Demo Kong API key committed** in `yaml/galactus_key.yaml` (reused by `javascript/` and `bash/` tests) | Reproducible lab tests | Generate at deploy time (`kubectl create secret`, External Secrets), and read the test key from an env var |
| Local Terraform state | S3 backend commented out | Enable the S3 backend with `encrypt` + `use_lockfile` (already drafted in `backend.tf`) |
| Grafana / Prometheus exposed as `LoadBalancer` | Quick access | ClusterIP + port-forward, or behind Kong with auth |

## Secrets and repository hygiene

- Gitignored: `*.tfstate` (including `errored.tfstate` and `prometheus/terraform.tfstate`), `*.tfvars`, and local kubeconfigs (`example.kubeconfig`).
- Never commit a kubeconfig. It embeds cluster endpoints, and with some auth plugins, credentials.
- Treat the committed Kong key as **burned**. Never reuse that value anywhere else.

## Recommended checks

```bash
terraform validate
checkov -d . --framework terraform,kubernetes
kubectl auth can-i --list --as=system:serviceaccount:kong:kong-controller -n default
```
