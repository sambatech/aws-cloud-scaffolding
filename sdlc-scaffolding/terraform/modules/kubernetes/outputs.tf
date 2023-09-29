output "out_efs_filesystem_id" {
    value = module.efs.out_efs_filesystem_id
}

output out_eks_cluster_endpoint {
    value = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
}

output out_eks_cluster_certificate_authority_data {
    value = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
}

output out_eks_cluster_auth_token {
    value = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
}

output out_waf_arn {
    value = module.waf.out_waf_arn
}