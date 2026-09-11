resource "azurerm_dns_zone" "acme" {
  name                = var.acme_dns_zone_name
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_dns_a_record" "application" {
  name                = "@"
  zone_name           = azurerm_dns_zone.acme.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 300
  records             = [azurerm_public_ip.application_gateway.ip_address]
}

resource "acme_registration" "this" {
  email_address = var.acme_email_address
}

resource "random_password" "certificate" {
  length  = 32
  special = true
}

resource "acme_certificate" "application_gateway" {
  account_key_pem          = acme_registration.this.account_key_pem
  common_name              = var.application_hostname
  certificate_p12_password = random_password.certificate.result
  min_days_remaining       = 30
  pre_check_delay          = 60
  recursive_nameservers    = ["1.1.1.1:53", "8.8.8.8:53"]

  dns_challenge {
    provider = "azuredns"

    config = {
      AZURE_AUTH_METHOD         = "cli"
      AZURE_SUBSCRIPTION_ID     = var.subscription_id
      AZURE_RESOURCE_GROUP      = azurerm_resource_group.this.name
      AZURE_ZONE_NAME           = azurerm_dns_zone.acme.name
      AZURE_PROPAGATION_TIMEOUT = "300"
    }
  }
}
