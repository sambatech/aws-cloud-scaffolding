output out_keycloak_realm_saml_endpoint {
  value     = <<-EOT
    ############################################
    # NOTE: To configure SonarQube you need to get info from url below
    # (Keycloak > Realm ${var.keycloak_realm_name} > Realm Settings > General > Endpoints > SAML 2.0 Identity Provider Metadata)
    ############################################

    ${module.deploy.out_keycloak_realm_saml_endpoint}
  EOT
}

output keycloak_identity_provider_certificate {
  value = <<-EOT
    ############################################
    # NOTE: Identity provider certificate 
    # (Keycloak > Realm ${var.keycloak_realm_name} > Realm Settings > Keys > RS256)
    ############################################

    ${module.deploy.keycloak_identity_provider_certificate}
  EOT
}

output keycloak_service_provider_private_key {
  sensitive = false
  value = <<-EOT
    ############################################
    # NOTE: Service provider private key (PKCS#8)
    # (Keycloak > Realm ${var.keycloak_realm_name} > Clients > sonarqube > keys > Certificate export)
    # SonarQube configuration supports only PKCS#8 format
    ############################################

    ${module.deploy.keycloak_service_provider_private_key}
  EOT
}

output keycloak_service_provider_certificate {
  value = <<-EOT
    ############################################
    # NOTE: Service provider certificate
    # (Keycloak > Realm ${var.keycloak_realm_name} > Clients > sonarqube > keys > Certificate)
    ############################################

    ${module.deploy.keycloak_service_provider_certificate}
  EOT
}