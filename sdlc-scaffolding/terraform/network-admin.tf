provider "aws" {
  alias   = "network"
  profile = "network"
  region  = var.aws_region
}

data "aws_alb" "eks_alb_ingress" {
  name = var.load_balancer_name

  depends_on = [
    module.sonarqube,
    module.keycloak
  ]
}

data "aws_route53_zone" "sambatech_net" {
  provider     = aws.network
  name         = "sambatech.net"
  private_zone = false
}

resource "aws_route53_record" "a_sambatech_net" {
  provider = aws.network
  zone_id  = data.aws_route53_zone.sambatech_net.zone_id

  name     = "*.sambatech.net"
  type     = "A"

  alias {
    name                   = data.aws_alb.eks_alb_ingress.dns_name
    zone_id                = data.aws_alb.eks_alb_ingress.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "aaaa_sambatech_net" {
  provider = aws.network
  zone_id  = data.aws_route53_zone.sambatech_net.zone_id

  name     = "*.sambatech.net"
  type     = "AAAA"
  
  alias {
    name                   = data.aws_alb.eks_alb_ingress.dns_name
    zone_id                = data.aws_alb.eks_alb_ingress.zone_id
    evaluate_target_health = true
  }
}