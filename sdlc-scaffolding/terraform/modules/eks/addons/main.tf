#resource "aws_eks_addon" "eks_addon_coredns" {
#  addon_name        = "coredns"
#  addon_version     = "v1.10.1-eksbuild.2"
#  resolve_conflicts = "OVERWRITE"
#  cluster_name      = var.eks_cluster_name
#}

resource "aws_eks_addon" "eks_addon_vpc_cni" {
  addon_name        = "vpc-cni"
  addon_version     = "v1.13.2-eksbuild.1"
  resolve_conflicts = "OVERWRITE"
  cluster_name      = var.eks_cluster_name
}

resource "aws_eks_addon" "eks_addon_kube_proxy" {
  addon_name        = "kube-proxy"
  addon_version     = "v1.27.3-eksbuild.1"
  resolve_conflicts = "OVERWRITE"
  cluster_name      = var.eks_cluster_name
}
