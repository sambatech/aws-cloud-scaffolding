terraform {
  required_version = ">= 0.15"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.36"
    }
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "~> 4.4"
    }
  }
  backend "s3" {
    profile = "platform"
    bucket = "plat-engineering-terraform-st"
    key    = "sdlc/keycloak-extras.tfstate"
    region = "us-east-1"
  }
}

#
# 
# @see https://registry.terraform.io/providers/mrparkers/keycloak/latest/docs
#

provider "keycloak" {
    client_id     = var.keycloak_client_id
    client_secret = var.keycloak_client_secret
    url           = "https://${var.keycloak_host}"
}

resource "keycloak_realm" "realm" {
  realm             = var.keycloak_realm_name
  enabled           = true
  display_name      = upper(var.keycloak_realm_name)
  display_name_html = "<b>${upper(var.keycloak_realm_name)}</b>"

  login_theme          = "keycloak"
  account_theme        = "keycloak.v2"
  admin_theme          = "keycloak.v2"
  email_theme          = "keycloak"
  access_code_lifespan = "1h"

  ssl_required    = "external"
  password_policy = "upperCase(1) and length(8) and forceExpiredPasswordChange(365) and notUsername"

  internationalization {
    supported_locales = [
      "pt",
      "en",
      "es"
    ]
    default_locale    = "pt"
  }

  security_defenses {
    headers {
      x_frame_options                     = "DENY"
      content_security_policy             = "frame-src 'self'; frame-ancestors 'self'; object-src 'none';"
      content_security_policy_report_only = ""
      x_content_type_options              = "nosniff"
      x_robots_tag                        = "none"
      x_xss_protection                    = "1; mode=block"
      strict_transport_security           = "max-age=31536000; includeSubDomains"
    }
    brute_force_detection {
      permanent_lockout                 = false
      max_login_failures                = 5
      wait_increment_seconds            = 60
      quick_login_check_milli_seconds   = 1000
      minimum_quick_login_wait_seconds  = 60
      max_failure_wait_seconds          = 900
      failure_reset_time_seconds        = 43200
    }
  }

  web_authn_policy {
    relying_party_entity_name = "Example"
    relying_party_id          = "keycloak.example.com"
    signature_algorithms      = ["ES256", "RS256"]
  }
}

resource "keycloak_saml_identity_provider" "realm_saml_identity_provider" {
  realm                         = keycloak_realm.realm.id

  enabled                       = true
  display_name                  = "Sambatech Active Directory"
  alias                         = "azure"

  entity_id                     = "https://sso.sambatech.net/realms/samba"
  single_sign_on_service_url    = "https://login.microsoftonline.com/36fe91e0-f8f7-425c-a32c-852a2829f2c1/saml2"
  single_logout_service_url     = "https://login.microsoftonline.com/36fe91e0-f8f7-425c-a32c-852a2829f2c1/saml2"

  trust_email                   = true
  first_broker_login_flow_alias = "first broker login"
  name_id_policy_format         = "Email"
  post_binding_response         = true
  post_binding_authn_request    = true
  sync_mode                     = "IMPORT"
  backchannel_supported         = false
  post_binding_logout           = false
  store_token                   = false
  force_authn                   = false
}