output out_keycloak_realm_saml_endpoint {
  value     = "https://${var.keycloak_host}/realms/${var.keycloak_realm_name}/protocol/saml/descriptor"
}

output "keycloak_identity_provider_certificate" {
  value = data.keycloak_realm_keys.realm_keys.keys.0.certificate
}

output keycloak_service_provider_private_key {
  value     = nonsensitive(trimspace(tls_private_key.saml.private_key_pem_pkcs8))
}

output keycloak_service_provider_certificate {
  value = trimspace(keycloak_saml_client.client.signing_certificate)
}