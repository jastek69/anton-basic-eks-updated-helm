# Kubernetes Basics

The purpose of this repository is to present working examples of basic Kubernetes applications for learning purposes.

In this guide, I’ll walk you through creating your first namespace, your first service account, your first pod, your first deployment, and finally configuring a service to create a canary deployment—then expanding that canary deployment.

> #### For deployment instructions, scroll to the **"Deploying this Repository"** section.

---

## What is a Namespace?

> 📖 Reference: [Kubernetes Docs – Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
>
> *"In Kubernetes, namespaces provide a mechanism for isolating groups of resources within a single cluster. Names of resources need to be unique within a namespace, but not across namespaces."*

A Kubernetes cluster functions like its own virtual private cloud (VPC), built on the communication and coordination of the node or nodes that make up the cluster. One of these nodes takes on the role of the **control plane**, which acts as the central command center. The control plane hosts key components—such as the API server, scheduler, controller manager, and `etcd`—that manage the cluster’s behavior, resources, and application lifecycle.

To deploy applications in an organized and scalable way, we use **namespaces**. From a cloud perspective, a namespace is similar to a **VPC** or a logically isolated environment—a sandbox—that separates workloads, permissions, and resources. This is especially helpful when managing environments like `dev`, `test`, `prod`, or monitoring services within the same cluster.

Just like you wouldn’t launch a virtual machine without first defining its network, you shouldn’t deploy Kubernetes resources without first defining the **namespace** context they live in.

> 🔍 View all namespaces:

```shell
kubectl get namespaces -A
```

---

## What is a Service Account?

> 📖 Reference: [Kubernetes Docs – Service Accounts](https://kubernetes.io/docs/concepts/security/service-accounts/)
>
> *"A service account is a type of non-human account that, in Kubernetes, provides a distinct identity in a Kubernetes cluster. Application Pods, system components, and entities inside and outside the cluster can use a specific ServiceAccount's credentials to identify as that ServiceAccount."*

Similar to service accounts and IAM identities in cloud providers, **Kubernetes service accounts** give us a way to uniquely identify and assign permissions to applications, workloads, and users within a cluster.

Just like in AWS or GCP, we can deploy applications with **restricted permissions**—limiting what resources they can create, modify, or view—either within their namespace or across the cluster. We can also define access boundaries for users and create service identities for internal or external agents like Jenkins, CI/CD tools like Harness, or APIs interacting with the cluster.

As with IAM in any cloud provider, it’s critical to be **intentional and restrictive** when assigning roles and permissions—especially in production environments. Follow the principle of **least privilege**.

> 🔍 View all service accounts:

```shell
kubectl get sa -A
```

---

## What are Pods and Deployments?

> 📖 Reference:
>
> * [Kubernetes Docs – Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
> * [Kubernetes Docs – Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
>
> *"Pods are the smallest deployable units of computing that you can create and manage in Kubernetes."*
> *"A Deployment manages a set of Pods to run an application workload, usually one that doesn't maintain state."*

**Pods** are the smallest logical units we can deploy in Kubernetes. They’re designed to host one or more application containers. In short, pods are the **runtime environments** for the Docker images we want to deploy.

From the container’s point of view, each pod acts like its own **individual machine**. You can define configurations at the pod level that control how the containers inside it run. While a pod often contains just one container, later you’ll learn about **multi-container pods**, where helper containers (sidecars) assist the main app with tasks like logging, monitoring, or communication.

A **Deployment** is used to manage a group of identical pods. It behaves similarly to a **managed instance group** or **autoscaling group** in cloud platforms. It handles updates, restarts, and scales your application as needed while ensuring high availability.

> 🔍 View all pods:

```shell
kubectl get pods -A
```

---

## What is a Service?

> 📖 Reference: [Kubernetes Docs – Services](https://kubernetes.io/docs/concepts/services-networking/service/)
>
> *"In Kubernetes, a Service is a method for exposing a network application that is running as one or more Pods in your cluster."*

A **Service** in Kubernetes is used to expose one or more applications running in your cluster—either internally to other workloads, or externally to the internet.

Think of a Service like a **virtual load balancer or router** that connects traffic to the right pods, regardless of how many replicas exist or where they’re scheduled. It groups pods using labels and forwards traffic based on port definitions, protocols, and connectivity rules.

This allows you to:

* Expose a **single application**
* Group multiple **related components**
* Enable **backend services** to be reachable via a stable DNS name

Services can be:

* **Internal only** (using `ClusterIP`)
* **Externally exposed** via `LoadBalancer` or `NodePort`

You can also define different connection types (like TCP or UDP), and route from one port to another using `port` and `targetPort`.

In short, a Service is the **network glue** that binds your pods to the cluster or the outside world.

---

## Deploying This Repository

Follow the steps below to provision your namespace, service account, pods, deployment, and service.

> 💡 Be sure to read the inline notes in each manifest for explanations of field values and behavior.

```shell
# Create a namespace
kubectl create ns my-first-ns

# Create a service account
kubectl create sa -n my-first-ns my-app-id

# Deploy your first pod
kubectl apply -f basic-pod.yaml

# Deploy your first deployment
kubectl apply -f basic-deployment.yaml

# Deploy your first service
kubectl apply -f basic-service.yaml

# View your active services to access your application
kubectl get svc -n my-first-ns
```

---

We’ll cover **imperative command usage** in our upcoming Zoom meeting.
