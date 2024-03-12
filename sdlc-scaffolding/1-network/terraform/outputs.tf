output "a_module_title" {
  value = <<-EOF
      ______   .______    _______ .__   __.         _______.     ___      .___  ___. .______        ___      
     /  __  \  |   _  \  |   ____||  \ |  |        /       |    /   \     |   \/   | |   _  \      /   \     
    |  |  |  | |  |_)  | |  |__   |   \|  |       |   (----`   /  ^  \    |  \  /  | |  |_)  |    /  ^  \    
    |  |  |  | |   ___/  |   __|  |  . `  |        \   \      /  /_\  \   |  |\/|  | |   _  <    /  /_\  \   
    |  `--'  | |  |      |  |____ |  |\   |    .----)   |    /  _____  \  |  |  |  | |  |_)  |  /  _____  \  
     \______/  | _|      |_______||__| \__|    |_______/    /__/     \__\ |__|  |__| |______/  /__/     \__\ 
                                                                                                             
  EOF
}

output "b_module_config_notice" {
  sensitive = false
  value = <<-EOF

    ****************************************
    * CONFIG NOTICE
    ****************************************

    VPC id.......................: ${module.vpc.vpc_id}
    VPC cidr.....................: ${module.vpc.vpc_cidr_block}
    VPC availability zones.......: ${jsonencode(var.availability_zones)}
    
    VPC public subnet ids........: ${jsonencode(module.vpc.public_subnets)}
    VPC public ipv4 subnet cidrs.: ${jsonencode(module.vpc.public_subnets_cidr_blocks)}
    VPC public ipv6 subnet cidrs.: ${jsonencode(module.vpc.public_subnets_ipv6_cidr_blocks)}

    VPC private subnet ids.......: ${jsonencode(module.vpc.private_subnets)}
    VPC private ipv4 subnet cidrs: ${jsonencode(module.vpc.private_subnets_cidr_blocks)}
    VPC private ipv6 subnet cidrs: ${jsonencode(module.vpc.private_subnets_ipv6_cidr_blocks)}
  
  EOF
}