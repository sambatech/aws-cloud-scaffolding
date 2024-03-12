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

    1) NOTE: Follow the instructions in the link below to manually finish the configuration

    https://docs.sonarsource.com/sonarqube/latest/instance-administration/authentication/saml/how-to-set-up-keycloak/

    2) NOTE: To configure SonarQube you need to get info from url below
             (Keycloak > Realm ${var.keycloak_realm_name} > Realm Settings > General > Endpoints > SAML 2.0 Identity Provider Metadata)

    ${module.deploy.out_keycloak_realm_saml_endpoint}

    3) NOTE: Identity provider certificate 
             (Keycloak > Realm ${var.keycloak_realm_name} > Realm Settings > Keys > RS256)

    ${module.deploy.keycloak_identity_provider_certificate}

    4) NOTE: Service provider private key (PKCS#8)
             (Keycloak > Realm ${var.keycloak_realm_name} > Clients > sonarqube > keys > Certificate export)
             SonarQube configuration supports only PKCS#8 format

    ${module.deploy.keycloak_service_provider_private_key}

    5) NOTE: Service provider certificate
             (Keycloak > Realm ${var.keycloak_realm_name} > Clients > sonarqube > keys > Certificate)

    ${module.deploy.keycloak_service_provider_certificate}
  EOF
}