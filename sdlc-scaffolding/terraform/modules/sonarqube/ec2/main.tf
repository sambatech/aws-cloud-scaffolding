resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "sonarqube" {
  key_name   = "sonarqube-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_sensitive_file" "pem_file" {
  filename             = pathexpand("~/.ssh/id_sonarqube.pem")
  file_permission      = "600"
  directory_permission = "700"
  content              = tls_private_key.ssh.private_key_pem
}

resource "aws_security_group" "sonarqube" {
  name        = "sgr-sonarqube"
  vpc_id      = var.ec2_vpc.id
      
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ec2_vpc.cidr_block]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.ec2_vpc.cidr_block]
  }
  
  ingress {
    description = "EFS mount target"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.ec2_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "sonar_properties" {
  template = "${file("${path.module}/files/sonar.properties")}"
  vars = {
    sonar_jdbc_username = var.ec2_db_username
    sonar_jdbc_password = var.ec2_db_password
    sonar_jdbc_url      = "jdbc:postgresql://${var.ec2_db_endpoint}/sonarqube"
  }
}

data "cloudinit_config" "content" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-java-properties"
    filename     = "sonar.properties"
    content      = data.template_file.sonar_properties.rendered
  }
}

resource "aws_instance" "sonarqube" {
  ami                         = var.ec2_ami_id
  instance_type               = "t2.medium"
  subnet_id                   = var.ec2_subnet.id
  key_name                    = aws_key_pair.sonarqube.key_name
  vpc_security_group_ids      = [aws_security_group.sonarqube.id]

  # EC2 imposes a maximum user-data size of 64 kilobytes, 
  # so all of the encoded data together must fit within that limit.
  user_data = data.cloudinit_config.content.rendered

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
  tags = {
    Name = "ec2-sonarqube"
  }
}