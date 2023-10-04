output kubectl_list_contexts {
  value = "kubectl config get-contexts"
}

output kubectl_unset_context {
  value = "kubectl config unset contexts.<the old context name>"
}

output update_kube_config_command {
  value = "aws eks update-kubeconfig --name ${var.eks_cluster_name} --region ${var.aws_region} --profile ${var.aws_profile}"
}