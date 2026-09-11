locals {
  location_slug = lower(replace(var.location, " ", ""))
  repo_name     = split("/", var.gh_repo)[1]
  unique_name   = "hsa${random_string.unique.result}"

  hub_vnet_name = "vnet-hub-${local.unique_name}"
  dmz_vnet_name = "vnet-dmz-${local.unique_name}"
  app_vnet_name = "vnet-app-${local.unique_name}"

  firewall_private_ip     = cidrhost(var.hub_firewall_subnet_prefix, 4)
  dmz_firewall_private_ip = cidrhost(var.dmz_firewall_subnet_prefix, 4)
  service_tag_region      = replace(var.location, " ", "")

  nginx_image = "mcr.microsoft.com/azurelinux/base/nginx:1"

  dmz_egress_network_rules = [
    {
      name                  = "https-to-app-spoke"
      protocols             = ["TCP"]
      source_addresses      = [var.dmz_container_apps_subnet_prefix]
      destination_addresses = [var.app_vnet_address_space]
      destination_ports     = ["443"]
    },
    {
      name             = "container-apps-https-dependencies"
      protocols        = ["TCP"]
      source_addresses = [var.dmz_container_apps_subnet_prefix]
      destination_addresses = [
        "AzureActiveDirectory",
        "AzureCloud",
        "AzureFrontDoor.FirstParty",
        "AzureMonitor",
        "MicrosoftContainerRegistry",
        "Storage.${local.service_tag_region}",
      ]
      destination_ports = ["443"]
    },
    {
      name                  = "container-apps-event-hubs"
      protocols             = ["TCP"]
      source_addresses      = [var.dmz_container_apps_subnet_prefix]
      destination_addresses = ["EventHub.${local.service_tag_region}"]
      destination_ports     = ["5671", "5672"]
    },
    {
      name                  = "container-apps-control-plane-tcp"
      protocols             = ["TCP"]
      source_addresses      = [var.dmz_container_apps_subnet_prefix]
      destination_addresses = ["AzureCloud.${local.service_tag_region}"]
      destination_ports     = ["9000"]
    },
    {
      name                  = "container-apps-control-plane-udp"
      protocols             = ["UDP"]
      source_addresses      = [var.dmz_container_apps_subnet_prefix]
      destination_addresses = ["AzureCloud.${local.service_tag_region}"]
      destination_ports     = ["1194"]
    },
    {
      name                  = "container-apps-dns"
      protocols             = ["TCP", "UDP"]
      source_addresses      = [var.dmz_container_apps_subnet_prefix]
      destination_addresses = ["168.63.129.16"]
      destination_ports     = ["53"]
    },
    {
      name                  = "container-apps-ntp"
      protocols             = ["UDP"]
      source_addresses      = [var.dmz_container_apps_subnet_prefix]
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    },
  ]

  dmz_egress_application_rules = [
    {
      name             = "container-apps-platform-fqdns"
      source_addresses = [var.dmz_container_apps_subnet_prefix]
      destination_fqdns = [
        "acs-mirror.azureedge.net",
        "mcr.microsoft.com",
        "packages.aks.azure.com",
        "*.data.mcr.microsoft.com",
      ]
    },
  ]

  public_ip_tags = {
    FirstPartyUsage = "/Unprivileged"
  }

  tags = {
    managed_by = "terraform"
    repo       = var.gh_repo
  }
}
