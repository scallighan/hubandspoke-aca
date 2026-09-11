data "azuread_client_config" "current" {}

resource "azuread_application" "easyauth" {
  display_name     = "easyauth-${local.unique_name}"
  owners           = [data.azuread_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg"

  web {
    homepage_url  = "https://${var.application_hostname}/"
    logout_url    = "https://${var.application_hostname}/.auth/logout"
    redirect_uris = ["https://${var.application_hostname}/.auth/login/aad/callback"]

    implicit_grant {
      id_token_issuance_enabled = true
    }
  }
}

resource "azuread_service_principal" "easyauth" {
  client_id = azuread_application.easyauth.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "easyauth" {
  application_id = azuread_application.easyauth.id
  display_name   = "container-app-easyauth"
}

resource "azapi_resource" "nginx_auth" {
  type      = "Microsoft.App/containerApps/authConfigs@2026-01-01"
  name      = "current"
  parent_id = azurerm_container_app.nginx.id

  body = {
    properties = {
      globalValidation = {
        excludedPaths               = ["/healthz"]
        redirectToProvider          = "azureActiveDirectory"
        unauthenticatedClientAction = "RedirectToLoginPage"
      }
      httpSettings = {
        forwardProxy = {
          convention = "Standard"
        }
        requireHttps = true
      }
      identityProviders = {
        azureActiveDirectory = {
          enabled = true
          registration = {
            clientId                = azuread_application.easyauth.client_id
            clientSecretSettingName = "easyauth-client-secret"
            openIdIssuer            = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0"
          }
          validation = {
            allowedAudiences = [azuread_application.easyauth.client_id]
          }
        }
      }
      platform = {
        enabled = true
      }
    }
  }

  depends_on = [
    azurerm_application_gateway.this,
    azuread_service_principal.easyauth,
  ]
}
