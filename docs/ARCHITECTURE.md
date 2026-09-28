# Architecture

Diagrams for the EKS platform layer. Narrative: [`../README.md`](../README.md).

## Terraform build order

```mermaid
flowchart LR
    V[02-vpc] --> S[03-subnets<br/>2 private · 2 public] --> IGW[04-igw] --> NAT[05-nat] --> RT[06-rtb]
    S --> EKS["07-eks<br/>auth mode API"]
    EKS --> NG["08-node<br/>private node group"]
    EKS --> OIDC[10-iam-oidc]
    OIDC --> IAM[11a-storage-iam<br/>EBS CSI role]
    NG & IAM --> HELM[11b-storage-helm<br/>aws-ebs-csi-driver]
    EKS --> KC[12-runtime<br/>update-kubeconfig]
    KC --> HELM
```

## IRSA trust for the EBS CSI driver

```mermaid
sequenceDiagram
    participant Pod as ebs-csi-controller pod
    participant SA as SA kube-system/ebs-csi-controller-sa
    participant STS as AWS STS
    participant EBS as EC2 / EBS API
    Pod->>SA: projected token (OIDC, audience sts.amazonaws.com)
    Pod->>STS: AssumeRoleWithWebIdentity(ebs_csi_iam_role, token)
    STS->>STS: trust policy: issuer = cluster OIDC, sub = system:serviceaccount:kube-system:ebs-csi-controller-sa
    STS-->>Pod: temporary credentials
    Pod->>EBS: CreateVolume / AttachVolume
```

Nodes never hold EBS permissions. Only this ServiceAccount does.

## Kong request path

```mermaid
flowchart LR
    C["Client"] -->|"GET /hello + apikey"| P[Kong proxy Service<br/>type LoadBalancer]
    P --> KA{key-auth}
    KA -->|missing / wrong key| E401[401]
    KA -->|"consumer galactus"| RL{"rate-limiting<br/>5 / minute"}
    RL -->|over limit| E429[429]
    RL -->|ok| ING[Ingress /hello] --> SVC[hello Service] --> POD[http-echo Pods]
    subgraph kong ns
        CTRL["kong-controller<br/>(Role → read Secrets in default)"]
    end
    CTRL -. reconciles KongConsumer + credential Secret .-> KA
```
