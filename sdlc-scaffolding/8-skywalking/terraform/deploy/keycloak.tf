
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

resource "keycloak_openid_client" "client" {
  realm_id              = data.keycloak_realm.realm.id
  client_id             = "skywalking"
  name                  = "skywalking"
  access_type           = "CONFIDENTIAL"
  root_url              = "https://${var.skywalking_host}/"
  base_url              = "https://${var.skywalking_host}/"
  standard_flow_enabled = true
  valid_redirect_uris   = ["*"]
}