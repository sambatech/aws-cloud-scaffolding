provider "keycloak" {
    client_id     = var.keycloak_client_id
    client_secret = var.keycloak_client_secret
    url           = "https://${var.keycloak_host}"
}

data "keycloak_realm" "realm" {
    realm = var.keycloak_realm_name
}

data "keycloak_realm_keys" "realm_keys" {
  realm_id   = data.keycloak_realm.realm.id
  algorithms = ["RS256"]
  status     = ["ACTIVE"]
}

resource "tls_private_key" "saml" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#
# @see https://docs.sonarsource.com/sonarqube/latest/instance-administration/authentication/saml/how-to-set-up-keycloak/
# @see https://registry.terraform.io/providers/mrparkers/keycloak/latest/docs/resources/saml_client
#
resource "keycloak_saml_client" "client" {
  realm_id                  = data.keycloak_realm.realm.id
  client_id                 = "sonarqube"
  name                      = "sonarqube"

  sign_documents            = false
  sign_assertions           = true
  encrypt_assertions        = true
  client_signature_required = true

  signing_certificate = trimspace(tls_private_key.saml.public_key_pem)
  signing_private_key = trimspace(tls_private_key.saml.private_key_pem)

  root_url                  = "https://${var.sonarqube_host}/"
  base_url                  = "https://${var.sonarqube_host}/"
  valid_redirect_uris       = ["*"]
}

resource "keycloak_saml_client_default_scopes" "cleanup_default_scopes" {
  realm_id  = data.keycloak_realm.realm.id
  client_id = keycloak_saml_client.client.id

  # Remove role_list
  default_scopes = []
}

resource "keycloak_saml_user_property_protocol_mapper" "login_user_property_mapper" {
  realm_id  = data.keycloak_realm.realm.id
  client_id = keycloak_saml_client.client.id
  name      = "Login"

  user_property              = "Username"
  saml_attribute_name        = "login"
  saml_attribute_name_format = "Unspecified"
}

resource "keycloak_saml_user_property_protocol_mapper" "name_user_property_mapper" {
  realm_id  = data.keycloak_realm.realm.id
  client_id = keycloak_saml_client.client.id
  name      = "Name"

  user_property              = "Username"
  saml_attribute_name        = "name"
  saml_attribute_name_format = "Unspecified"
}

resource "keycloak_saml_user_property_protocol_mapper" "email_user_property_mapper" {
  realm_id  = data.keycloak_realm.realm.id
  client_id = keycloak_saml_client.client.id
  name      = "Email"

  user_property              = "Email"
  saml_attribute_name        = "email"
  saml_attribute_name_format = "Unspecified"
}