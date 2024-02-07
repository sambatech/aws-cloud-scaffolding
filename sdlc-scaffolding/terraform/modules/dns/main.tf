resource "aws_route53_zone" "zona_hospedada" {
  name = var.domain-name
}

resource "aws_route53_record" "mi_registro_a" {
  zone_id = aws_route53_zone.zona_hospedada.zone_id
  name    = var.domain-name
  type    = "A"
  ttl     = "300"
  records = [var.domain-address]
}
