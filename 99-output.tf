output "eks_cluster_info" {
  value = {
    name        = aws_eks_cluster.taaops_eks_cluster.name
    endpoint    = aws_eks_cluster.taaops_eks_cluster.endpoint
    description = "EKS cluster info"
  }
}

resource "local_file" "eks_kubeconfig" {
  content = jsonencode({
    apiVersion = "v1"
    clusters = [{
      cluster = {
        server                     = aws_eks_cluster.taaops_eks_cluster.endpoint
        certificate-authority-data = aws_eks_cluster.taaops_eks_cluster.certificate_authority[0].data
      }
      name = aws_eks_cluster.taaops_eks_cluster.name
    }]
    contexts = [{
      context = {
        cluster = aws_eks_cluster.taaops_eks_cluster.name
        user    = aws_eks_cluster.taaops_eks_cluster.name
      }
      name = aws_eks_cluster.taaops_eks_cluster.name
    }]
    current-context = aws_eks_cluster.taaops_eks_cluster.name
    kind            = "Config"
    preferences     = {}
    users = [{
      name = aws_eks_cluster.taaops_eks_cluster.name
      user = {}
    }]
  })
  filename = "${path.module}/example.kubeconfig"
}


resource "null_resource" "format_kubeconfig" {
  depends_on = [local_file.eks_kubeconfig]

  provisioner "local-exec" {
    command = "jq . ${local_file.eks_kubeconfig.filename} > ${local_file.eks_kubeconfig.filename}.pretty && mv ${local_file.eks_kubeconfig.filename}.pretty ${local_file.eks_kubeconfig.filename}"
  }
}


output "eks_node_group_summary" {
  value = format("Node group '%s' runs %s instance(s) of type %s",
    aws_eks_node_group.eks_private_nodes.node_group_name,
    aws_eks_node_group.eks_private_nodes.scaling_config[0].desired_size,
    join(", ", aws_eks_node_group.eks_private_nodes.instance_types)
  )
  description = "Summary of EKS node group configuration"
}


# Output: AWS IAM Open ID Connect Provider ARN
output "openid_connect_provider" {
  description = "AWS IAM Open ID Connect Provider ARN"
  value = {
    arn = aws_iam_openid_connect_provider.oidc_provider.arn
    url = aws_eks_cluster.taaops_eks_cluster.identity[0].oidc[0].issuer
  }
}
