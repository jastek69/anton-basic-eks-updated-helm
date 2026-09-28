# Connect to cluster (add proper context to kubeconfig)

resource "null_resource" "update_kubeconfig" {
    count = var.enable_kubeconfig ? 1 : 0

    provisioner "local-exec" {
        #interpreter = ["/bin/bash", "bash"]
        command     = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.demo.name}" #Authenticate kube config to run YAML files - must run terraform init if adding this line for first time
    }

    depends_on = [aws_eks_cluster.demo]  
}



# # Connect to cluster (add proper context to kubeconfig)

# resource "null_resource" "update_kubeconfig" {
#   # count = var.enable_kubeconfig ? 1 : 0

#   provisioner "local-exec" {
#     #interpreter = ["/bin/bash", "-c"]
#     command     = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.demo.name}" #Authenticate kube config to run YAML files - must run terraform init if adding this line for first time
#   }

#   depends_on = [aws_eks_cluster.demo]
# }

