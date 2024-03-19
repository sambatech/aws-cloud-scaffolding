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

resource "time_static" "momentum" {}

resource "null_resource" "generate_keypair" {
  triggers = {
    run = time_static.momentum.rfc3339
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    on_failure = fail
    command = <<-EOT
      openssl req -nodes -new -x509 \
        -keyout ${path.module}/teamcity.key \
        -out ${path.module}/teamcity.crt \
        -subj "/C=BR/ST=MG/L=Nova Lima/O=Samba/OU=Tech/CN=sonar.sambatech.net/emailAddress=admin@sonar.sambatech.net"
    EOT
  }
}

data "local_file" "private_key" {
  # 
  # openssl rsa -in teamcity.key -text -noout
  # 
  filename = "${path.module}/teamcity.key"

  depends_on = [ 
    null_resource.generate_keypair
  ]
}

data "local_file" "certificate" {
  #
  # openssl x509 -in teamcity.crt -text -noout
  #
  filename = "${path.module}/teamcity.crt"

  depends_on = [ 
    null_resource.generate_keypair
  ]
}

#
# @see https://registry.terraform.io/providers/mrparkers/keycloak/latest/docs/resources/saml_client
#
resource "keycloak_saml_client" "client" {
  realm_id                  = data.keycloak_realm.realm.id
  client_id                 = "teamcity"
  name                      = "teamcity"

  sign_documents            = true
  sign_assertions           = false
  encrypt_assertions        = false
  client_signature_required = true

  signing_certificate       = data.local_file.certificate.content
  signing_private_key       = data.local_file.private_key.content

  root_url                  = "https://${var.teamcity_host}/"
  base_url                  = "https://${var.teamcity_host}/"
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