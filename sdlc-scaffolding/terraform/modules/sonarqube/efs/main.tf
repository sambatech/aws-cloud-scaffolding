resource "aws_efs_file_system" "sonarqube_efs" {
  creation_token   = "sonarqube-efs"
  throughput_mode  = "bursting"
  performance_mode = "generalPurpose"

#  lifecycle {
#    prevent_destroy = true
#  }

  tags = {
    Name = "sonarqube-fs"
  }
}

resource "aws_efs_mount_target" "sonarqube_efs_mount_target" {
  count           = length(var.efs_subnet_ids)
  security_groups = [var.efs_sg_id]
  subnet_id       = var.efs_subnet_ids[count.index]
  file_system_id  = aws_efs_file_system.sonarqube_efs.id
}