variable "subscription_id" {
  type        = string
  description = "Azure subscription in which the hub-and-spoke environment is created."
  sensitive   = true
}

variable "location" {
  type        = string
  description = "Azure region for all regional resources."
  default     = "EastUS2"
}

variable "gh_repo" {
  type        = string
  description = "owner/repo slug used for resource naming and tags."
  default     = "implodingduck/hubandspoke-aca"

  validation {
    condition     = length(split("/", var.gh_repo)) == 2
    error_message = "gh_repo must use the owner/repo format."
  }
}

variable "hub_vnet_address_space" {
  type        = string
  description = "Address space for the hub virtual network."
  default     = "10.0.0.0/16"
}

variable "dmz_vnet_address_space" {
  type        = string
  description = "Address space for the DMZ spoke virtual network."
  default     = "10.1.0.0/16"
}

variable "app_vnet_address_space" {
  type        = string
  description = "Address space for the application spoke virtual network."
  default     = "10.2.0.0/16"
}

variable "hub_firewall_subnet_prefix" {
  type        = string
  description = "CIDR for AzureFirewallSubnet. Azure Firewall requires /26 or larger."
  default     = "10.0.0.0/26"
}

variable "hub_firewall_management_subnet_prefix" {
  type        = string
  description = "CIDR for AzureFirewallManagementSubnet, required by Azure Firewall Basic."
  default     = "10.0.0.64/26"
}

variable "dmz_application_gateway_subnet_prefix" {
  type        = string
  description = "CIDR for the dedicated Application Gateway subnet."
  default     = "10.1.0.0/24"
}

variable "dmz_firewall_subnet_prefix" {
  type        = string
  description = "CIDR for the DMZ AzureFirewallSubnet. Azure Firewall requires /26 or larger."
  default     = "10.1.1.0/26"
}

variable "dmz_firewall_management_subnet_prefix" {
  type        = string
  description = "CIDR for the DMZ AzureFirewallManagementSubnet."
  default     = "10.1.1.64/26"
}

variable "dmz_container_apps_subnet_prefix" {
  type        = string
  description = "CIDR for the DMZ Container Apps environment infrastructure subnet."
  default     = "10.1.4.0/23"
}

variable "app_container_apps_subnet_prefix" {
  type        = string
  description = "CIDR for the application Container Apps environment infrastructure subnet."
  default     = "10.2.4.0/23"
}

variable "application_gateway_capacity" {
  type        = number
  description = "Fixed instance count for Application Gateway Standard_v2."
  default     = 1

  validation {
    condition     = var.application_gateway_capacity >= 1 && var.application_gateway_capacity <= 10
    error_message = "application_gateway_capacity must be between 1 and 10."
  }
}

variable "application_hostname" {
  type        = string
  description = "Public HTTPS hostname used by Application Gateway and Entra Easy Auth."
  default     = "easyauth.scallighan.com"
}

variable "acme_email_address" {
  type        = string
  description = "Contact email used to register the Let's Encrypt ACME account."
}

variable "acme_server_url" {
  type        = string
  description = "ACME directory endpoint used to issue the Application Gateway certificate."
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "acme_dns_zone_name" {
  type        = string
  description = "Delegated Azure DNS zone used for automated ACME DNS-01 challenges."
  default     = "easyauth.scallighan.com"
}
