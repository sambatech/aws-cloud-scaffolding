output "aws_ecr_name" {
  value = aws_ecr_repository.reg.name
}

output "aws_ecr_url" {
  value = aws_ecr_repository.reg.repository_url
}