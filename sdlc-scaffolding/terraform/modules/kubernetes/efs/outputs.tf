output out_efs_filesystem_id {
    description = "value of the EFS filesystem id"
    value = aws_efs_file_system.sonarqube_efs.id
}