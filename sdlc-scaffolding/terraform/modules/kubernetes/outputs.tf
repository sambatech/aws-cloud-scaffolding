output out_eks_cluster_endpoint {
    value = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
}

output out_eks_cluster_certificate_authority_data {
    value = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
}

output out_eks_cluster_auth_token {
    value = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
}