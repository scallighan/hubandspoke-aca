output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "application_url" {
  description = "Public URL exposed by Application Gateway."
  value       = "https://${var.application_hostname}"
}

output "acme_dns_name_servers" {
  description = "Name servers to delegate for the ACME DNS challenge zone."
  value       = azurerm_dns_zone.acme.name_servers
}

output "acme_dns_delegation" {
  description = "NS delegation to create in the parent DNS zone before issuing the certificate."
  value = {
    name         = azurerm_dns_zone.acme.name
    name_servers = azurerm_dns_zone.acme.name_servers
  }
}

output "easyauth_client_id" {
  description = "Microsoft Entra application client ID used by Container Apps Easy Auth."
  value       = azuread_application.easyauth.client_id
}

output "application_gateway_public_ip" {
  description = "Public IP address of Application Gateway."
  value       = azurerm_public_ip.application_gateway.ip_address
}

output "nginx_fqdn" {
  description = "Internal FQDN of the NGINX proxy Container App."
  value       = azurerm_container_app.nginx.ingress[0].fqdn
}

output "hello_world_fqdn" {
  description = "Internal FQDN of the hello-world Container App."
  value       = azurerm_container_app.hello_world.ingress[0].fqdn
}

output "firewall_private_ip" {
  description = "Private IP used as the next hop for inter-spoke traffic."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "Public IP assigned to Azure Firewall."
  value       = azurerm_public_ip.firewall.ip_address
}

output "dmz_firewall_private_ip" {
  description = "Private IP used as the first DMZ egress hop."
  value       = azurerm_firewall.dmz.ip_configuration[0].private_ip_address
}

output "dmz_firewall_public_ip" {
  description = "Public IP assigned to the DMZ Azure Firewall."
  value       = azurerm_public_ip.dmz_firewall.ip_address
}
