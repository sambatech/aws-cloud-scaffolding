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
  value = <<-EOF

    ****************************************
    * CONFIG NOTICE
    ****************************************

    You need to use the WAF ARN bellow and set the variable 'waf_arn' in 
    .../0-envs/platform.tfvars file to be used for others modules.

    waf_arn = ${module.waf.out_waf_arn}

  EOF
}