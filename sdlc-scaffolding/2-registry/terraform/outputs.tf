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

    ECR repository url: ${module.ecr.repository_url}
  
  EOF
}