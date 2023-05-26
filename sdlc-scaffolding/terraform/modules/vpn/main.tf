resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  key_name   = "openvpn-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_sensitive_file" "pem_file" {
  filename             = pathexpand("~/.ssh/id_openvpn-${var.vpn_aws_profile}.pem")
  file_permission      = "600"
  directory_permission = "700"
  content              = tls_private_key.ssh.private_key_pem
}

resource "aws_security_group" "instance" {
  name        = "sgr-openvpn"
  description = "OpenVPN security group"
  vpc_id      = var.vpn_subnet.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 943
    to_port     = 943
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 945
    to_port     = 945
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "aws_instance" "openvpn" {
  ami                         = var.vpn_ami_id
  instance_type               = "t2.micro"
  subnet_id                   = var.vpn_subnet.id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              admin_user=${var.vpn_server_username}
              admin_pw=${random_password.password.result}
              EOF

  tags = {
    Name = "ec2-openvpn"
  }
}