data "aws_eks_cluster_auth" "eks_cluster_auth" {
  name = aws_eks_cluster.taaops_eks_cluster.name
}

locals {
  ebs_csi_driver_image_repository = "602401143452.dkr.ecr.${var.region}.amazonaws.com/eks/aws-ebs-csi-driver"
}

# HELM Provider
# repository_config_path/repository_cache isolate this provider's chart-repo bookkeeping
# from the ambient Helm repo config (e.g. `helm repo add prometheus-community ...` run
# manually for the README's Grafana/Prometheus steps) so a stale/missing index for an
# unrelated repo can't block this resource's chart resolution.
provider "helm" {
  repository_config_path = "${path.module}/.helm/repositories.yaml"
  repository_cache       = "${path.module}/.helm/cache"

  kubernetes {
    host                   = aws_eks_cluster.taaops_eks_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.taaops_eks_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks_cluster_auth.token
  }
}

# Install EBS CSI Driver using HELM
# Resource: Helm Release 
resource "helm_release" "ebs_csi_driver" {
  depends_on = [
    aws_iam_role.ebs_csi_iam_role,
    aws_iam_openid_connect_provider.oidc_provider,
    aws_eks_cluster.taaops_eks_cluster,
    aws_eks_node_group.eks_private_nodes,
    null_resource.update_kubeconfig
  ]

  name       = "${var.cluster_name}-aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"

  set {
    name  = "image.repository"
    value = local.ebs_csi_driver_image_repository
  }
  # Changes based on Region - This is for us-west-2 (Oregon) - see: https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html    

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.ebs_csi_iam_role.arn
  }

}
