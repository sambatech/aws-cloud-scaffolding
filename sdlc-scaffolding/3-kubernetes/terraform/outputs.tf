output out_eks_cluster_id {
    value = module.eks.cluster_id
}

output out_eks_cluster_name {
    value = var.cluster_name
}

output out_eks_fargate_profiles {
    value = module.eks.fargate_profiles
}