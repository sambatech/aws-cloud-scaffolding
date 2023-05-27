output "out_vpc" {
  value = aws_vpc.main
}

output "out_public_subnets" {
  value = aws_subnet.public_subnets
}

output "out_private_subnets" {
  value = aws_subnet.private_subnets
}