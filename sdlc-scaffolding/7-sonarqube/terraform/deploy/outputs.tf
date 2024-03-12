output out_keycloak_realm_saml_endpoint {
  value     = "https://${var.keycloak_host}/realms/${var.keycloak_realm_name}/protocol/saml/descriptor"
}

output keycloak_identity_provider_certificate {
  value = data.keycloak_realm_keys.realm_keys.keys.0.certificate
}

output keycloak_service_provider_private_key {
  value = keycloak_saml_client.client.signing_private_key
}

output keycloak_service_provider_certificate {
  value = keycloak_saml_client.client.signing_certificate
}