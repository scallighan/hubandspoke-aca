resource "azurerm_public_ip" "application_gateway" {
  name                = "pip-appgw-${local.unique_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_tags             = local.public_ip_tags
  tags                = local.tags
}

resource "azurerm_application_gateway" "this" {
  name                = "agw-${local.unique_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  http2_enabled       = true
  tags                = local.tags

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = var.application_gateway_capacity
  }

  gateway_ip_configuration {
    name      = "gateway"
    subnet_id = azurerm_subnet.application_gateway.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_port {
    name = "https"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.application_gateway.id
  }

  ssl_certificate {
    name     = "easyauth"
    data     = acme_certificate.application_gateway.certificate_p12
    password = random_password.certificate.result
  }

  backend_address_pool {
    name  = "nginx"
    fqdns = [azurerm_container_app.nginx.ingress[0].fqdn]
  }

  probe {
    name                                      = "nginx"
    protocol                                  = "Https"
    path                                      = "/healthz"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-399"]
    }
  }

  backend_http_settings {
    name                                = "nginx-https"
    cookie_based_affinity               = "Disabled"
    affinity_cookie_name                = "ApplicationGatewayAffinity"
    protocol                            = "Https"
    port                                = 443
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
    probe_name                          = "nginx"
  }

  http_listener {
    name                           = "public-http"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  http_listener {
    name                           = "public-https"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "https"
    protocol                       = "Https"
    host_name                      = var.application_hostname
    ssl_certificate_name           = "easyauth"
  }

  redirect_configuration {
    name                 = "http-to-https"
    redirect_type        = "Permanent"
    target_listener_name = "public-https"
    include_path         = true
    include_query_string = true
  }

  rewrite_rule_set {
    name = "easyauth-forwarded-headers"

    rewrite_rule {
      name          = "set-forwarded-host-and-proto"
      rule_sequence = 100

      request_header_configuration {
        header_name  = "X-Forwarded-Host"
        header_value = var.application_hostname
      }

      request_header_configuration {
        header_name  = "X-Forwarded-Proto"
        header_value = "https"
      }
    }
  }

  request_routing_rule {
    name                        = "redirect-http-to-https"
    rule_type                   = "Basic"
    http_listener_name          = "public-http"
    redirect_configuration_name = "http-to-https"
    priority                    = 100
  }

  request_routing_rule {
    name                       = "nginx-https"
    rule_type                  = "Basic"
    http_listener_name         = "public-https"
    backend_address_pool_name  = "nginx"
    backend_http_settings_name = "nginx-https"
    rewrite_rule_set_name      = "easyauth-forwarded-headers"
    priority                   = 110
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.dmz_zone_to_dmz,
    azurerm_subnet_network_security_group_association.application_gateway,
  ]
}
