output "eks_cluster_info" {
  value = {
    name        = aws_eks_cluster.demo.name
    endpoint    = aws_eks_cluster.demo.endpoint
    description = "EKS cluster info"
  }
}

resource "local_file" "example_kubeconfig" {
  content = jsonencode({
    apiVersion = "v1"
    clusters = [{
      cluster = {
        server                     = aws_eks_cluster.demo.endpoint
        certificate-authority-data = aws_eks_cluster.demo.certificate_authority[0].data
      }
      name = aws_eks_cluster.demo.name
    }]
    contexts = [{
      context = {
        cluster = aws_eks_cluster.demo.name
        user    = aws_eks_cluster.demo.name
      }
      name = aws_eks_cluster.demo.name
    }]
    current-context = aws_eks_cluster.demo.name
    kind            = "Config"
    preferences     = {}
    users = [{
      name = aws_eks_cluster.demo.name
      user = {}
    }]
  })
  filename = "${path.module}/example.kubeconfig"
}


resource "null_resource" "format_kubeconfig" {
  depends_on = [local_file.example_kubeconfig]

  provisioner "local-exec" {
    command = "jq . ${local_file.example_kubeconfig.filename} > ${local_file.example_kubeconfig.filename}.pretty && mv ${local_file.example_kubeconfig.filename}.pretty ${local_file.example_kubeconfig.filename}"
  }
}


output "eks_node_group_summary" {
  value = format("Node group '%s' runs %s instance(s) of type %s",
    aws_eks_node_group.private-nodes.node_group_name,
    aws_eks_node_group.private-nodes.scaling_config[0].desired_size,
    join(", ", aws_eks_node_group.private-nodes.instance_types)
  )
  description = "Summary of EKS node group configuration"
}


# Output: AWS IAM Open ID Connect Provider ARN
output "openid_connect_provider" {
  description = "AWS IAM Open ID Connect Provider ARN"
  value = {
    arn = aws_iam_openid_connect_provider.oidc_provider.arn 
    url = aws_eks_cluster.demo.identity[0].oidc[0].issuer
  }
}
