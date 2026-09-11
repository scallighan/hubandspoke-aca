resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${local.unique_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_container_app_environment" "dmz" {
  name                           = "cae-dmz-${local.unique_name}"
  location                       = azurerm_resource_group.this.location
  resource_group_name            = azurerm_resource_group.this.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  infrastructure_subnet_id       = azurerm_subnet.dmz_container_apps.id
  internal_load_balancer_enabled = true
  zone_redundancy_enabled        = false
  tags                           = local.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  lifecycle {
    ignore_changes = [infrastructure_resource_group_name]
  }

  depends_on = [
    azurerm_subnet_route_table_association.dmz_container_apps,
    azurerm_virtual_network_peering.dmz_to_hub,
    azurerm_virtual_network_peering.hub_to_dmz,
  ]
}

resource "azurerm_container_app_environment" "app" {
  name                           = "cae-app-${local.unique_name}"
  location                       = azurerm_resource_group.this.location
  resource_group_name            = azurerm_resource_group.this.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  infrastructure_subnet_id       = azurerm_subnet.app_container_apps.id
  internal_load_balancer_enabled = true
  zone_redundancy_enabled        = false
  tags                           = local.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  lifecycle {
    ignore_changes = [infrastructure_resource_group_name]
  }

  depends_on = [
    azurerm_subnet_route_table_association.app_container_apps,
    azurerm_virtual_network_peering.app_to_hub,
    azurerm_virtual_network_peering.hub_to_app,
  ]
}

resource "azurerm_private_dns_zone" "dmz" {
  name                = azurerm_container_app_environment.dmz.default_domain
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone" "app" {
  name                = azurerm_container_app_environment.app.default_domain
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_a_record" "dmz_apex" {
  name                = "@"
  zone_name           = azurerm_private_dns_zone.dmz.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 60
  records             = [azurerm_container_app_environment.dmz.static_ip_address]
}

resource "azurerm_private_dns_a_record" "dmz_wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.dmz.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 60
  records             = [azurerm_container_app_environment.dmz.static_ip_address]
}

resource "azurerm_private_dns_a_record" "app_apex" {
  name                = "@"
  zone_name           = azurerm_private_dns_zone.app.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 60
  records             = [azurerm_container_app_environment.app.static_ip_address]
}

resource "azurerm_private_dns_a_record" "app_wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.app.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 60
  records             = [azurerm_container_app_environment.app.static_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "dmz_zone_to_dmz" {
  name                  = "link-dmz-zone-to-dmz"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.dmz.name
  virtual_network_id    = azurerm_virtual_network.dmz.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "app_zone_to_dmz" {
  name                  = "link-app-zone-to-dmz"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.app.name
  virtual_network_id    = azurerm_virtual_network.dmz.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "app_zone_to_app" {
  name                  = "link-app-zone-to-app"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.app.name
  virtual_network_id    = azurerm_virtual_network.app.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_container_app" "hello_world" {
  name                         = "ca-hello-${local.unique_name}"
  container_app_environment_id = azurerm_container_app_environment.app.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.tags

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 8080
    transport                  = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 1
    max_replicas = 2

    container {
      name    = "hello-world"
      image   = local.nginx_image
      cpu     = 0.25
      memory  = "0.5Gi"
      command = ["/bin/bash", "-c"]
      args = [<<-EOT
        cat > /etc/nginx/html/index.html <<'HTML'
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Hub and Spoke ACA</title>
        </head>
        <body>
          <h1>Hub and Spoke ACA setup Hello World success</h1>
        </body>
        </html>
        HTML

        cat > /etc/nginx/nginx.conf.default <<'NGINX'
        map $http_x_ms_client_principal $principal_present {
          default true;
          ""      false;
        }

        log_format hello escape=json
          '{"timestamp":"$time_iso8601",'
          '"request_id":"$http_x_request_id",'
          '"client":"$remote_addr",'
          '"forwarded_for":"$http_x_forwarded_for",'
          '"method":"$request_method",'
          '"principal_present":$principal_present,'
          '"client_principal":"$http_x_ms_client_principal",'
          '"uri":"$uri",'
          '"status":$status,'
          '"request_time":$request_time}';

        access_log /dev/stdout hello;
        error_log /dev/stderr warn;

        server {
          listen 8080;
          root /etc/nginx/html;

          location / {
            try_files $uri $uri/ /index.html;
          }
        }
        NGINX

        exec nginx -g 'daemon off;'
      EOT
      ]
    }
  }

  depends_on = [
    azurerm_private_dns_a_record.app_apex,
    azurerm_private_dns_a_record.app_wildcard,
    azurerm_private_dns_zone_virtual_network_link.app_zone_to_app,
    azurerm_firewall.this,
  ]
}

resource "azurerm_container_app" "nginx" {
  name                         = "ca-nginx-${local.unique_name}"
  container_app_environment_id = azurerm_container_app_environment.dmz.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.tags

  secret {
    name  = "easyauth-client-secret"
    value = azuread_application_password.easyauth.value
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 8080
    transport                  = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 1
    max_replicas = 2

    container {
      name    = "nginx"
      image   = local.nginx_image
      cpu     = 0.25
      memory  = "0.5Gi"
      command = ["/bin/bash", "-c"]
      args = [<<-EOT
        cat > /etc/nginx/nginx.conf.default <<'NGINX'
        map $http_x_ms_client_principal $principal_present {
          default true;
          ""      false;
        }

        log_format flow escape=json
          '{"timestamp":"$time_iso8601",'
          '"request_id":"$request_id",'
          '"inbound_request_id":"$http_x_request_id",'
          '"traceparent":"$http_traceparent",'
          '"client":"$remote_addr",'
          '"forwarded_for":"$http_x_forwarded_for",'
          '"forwarded_host":"$http_x_forwarded_host",'
          '"forwarded_port":"$http_x_forwarded_port",'
          '"forwarded_proto":"$http_x_forwarded_proto",'
          '"method":"$request_method",'
          '"host":"$host",'
          '"origin":"$http_origin",'
          '"user_agent":"$http_user_agent",'
          '"accept":"$http_accept",'
          '"accept_encoding":"$http_accept_encoding",'
          '"accept_language":"$http_accept_language",'
          '"cache_control":"$http_cache_control",'
          '"content_type":"$content_type",'
          '"content_length":"$content_length",'
          '"sec_fetch_dest":"$http_sec_fetch_dest",'
          '"sec_fetch_mode":"$http_sec_fetch_mode",'
          '"sec_fetch_site":"$http_sec_fetch_site",'
          '"sec_fetch_user":"$http_sec_fetch_user",'
          '"principal_present":$principal_present,'
          '"client_principal":"$http_x_ms_client_principal",'
          '"uri":"$uri",'
          '"status":$status,'
          '"request_time":$request_time,'
          '"upstream_address":"$upstream_addr",'
          '"upstream_status":"$upstream_status",'
          '"upstream_connect_time":"$upstream_connect_time",'
          '"upstream_response_time":"$upstream_response_time"}';

        access_log /dev/stdout flow;
        error_log /dev/stderr warn;

        server {
          listen 8080;

          location = /healthz {
            access_log off;
            default_type text/plain;
            return 200 'healthy\n';
          }

          location / {
            proxy_http_version 1.1;
            proxy_set_header Host ${azurerm_container_app.hello_world.ingress[0].fqdn};
            proxy_set_header X-Forwarded-For $${proxy_add_x_forwarded_for};
            proxy_set_header X-Forwarded-Proto $${scheme};
            proxy_set_header X-Request-ID $request_id;
            proxy_set_header X-MS-CLIENT-PRINCIPAL $${http_x_ms_client_principal};
            proxy_ssl_name ${azurerm_container_app.hello_world.ingress[0].fqdn};
            proxy_ssl_server_name on;
            proxy_pass https://${azurerm_container_app.hello_world.ingress[0].fqdn};
            add_header X-Flow-Request-ID $request_id always;
          }
        }
        NGINX

        exec nginx -g 'daemon off;'
      EOT
      ]
    }
  }

  depends_on = [
    azurerm_private_dns_a_record.dmz_apex,
    azurerm_private_dns_a_record.dmz_wildcard,
    azurerm_private_dns_zone_virtual_network_link.dmz_zone_to_dmz,
    azurerm_private_dns_zone_virtual_network_link.app_zone_to_dmz,
    azurerm_firewall.this,
  ]
}
