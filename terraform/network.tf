resource "azurerm_virtual_network" "hub" {
  name                = local.hub_vnet_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.hub_vnet_address_space]
  tags                = local.tags
}

resource "azurerm_virtual_network" "dmz" {
  name                = local.dmz_vnet_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.dmz_vnet_address_space]
  tags                = local.tags
}

resource "azurerm_virtual_network" "app" {
  name                = local.app_vnet_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.app_vnet_address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_firewall_subnet_prefix]
}

resource "azurerm_subnet" "firewall_management" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_firewall_management_subnet_prefix]
}

resource "azurerm_subnet" "application_gateway" {
  name                 = "snet-application-gateway"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.dmz.name
  address_prefixes     = [var.dmz_application_gateway_subnet_prefix]
}

resource "azurerm_network_security_group" "application_gateway" {
  name                = "nsg-appgw-${local.unique_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  security_rule {
    name                       = "AllowClientTraffic"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGatewayManager"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "application_gateway" {
  subnet_id                 = azurerm_subnet.application_gateway.id
  network_security_group_id = azurerm_network_security_group.application_gateway.id
}

resource "azurerm_subnet" "dmz_firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.dmz.name
  address_prefixes     = [var.dmz_firewall_subnet_prefix]
}

resource "azurerm_subnet" "dmz_firewall_management" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.dmz.name
  address_prefixes     = [var.dmz_firewall_management_subnet_prefix]
}

resource "azurerm_subnet" "dmz_container_apps" {
  name                 = "snet-container-apps"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.dmz.name
  address_prefixes     = [var.dmz_container_apps_subnet_prefix]

  delegation {
    name = "Microsoft.App.environments"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "app_container_apps" {
  name                 = "snet-container-apps"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = [var.app_container_apps_subnet_prefix]

  delegation {
    name = "Microsoft.App.environments"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_virtual_network_peering" "hub_to_dmz" {
  name                      = "peer-hub-to-dmz"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.dmz.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "dmz_to_hub" {
  name                      = "peer-dmz-to-hub"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.dmz.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "hub_to_app" {
  name                      = "peer-hub-to-app"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.app.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "app_to_hub" {
  name                      = "peer-app-to-hub"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.app.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

resource "azurerm_route_table" "dmz" {
  name                          = "rt-dmz-${local.unique_name}"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  bgp_route_propagation_enabled = false
  tags                          = local.tags

  route {
    name                   = "all-egress-via-dmz-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.dmz_firewall_private_ip
  }

  depends_on = [azurerm_firewall.dmz]
}

resource "azurerm_route_table" "dmz_firewall" {
  name                          = "rt-dmz-firewall-${local.unique_name}"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  bgp_route_propagation_enabled = false
  tags                          = local.tags

  route {
    name                   = "local-egress-via-hub-firewall"
    address_prefix         = "10.0.0.0/8"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.firewall_private_ip
  }

  route {
    name           = "alloutinternet"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

resource "azurerm_route_table" "hub_firewall" {
  name                          = "rt-hub-firewall-${local.unique_name}"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  bgp_route_propagation_enabled = false
  tags                          = local.tags

  route {
    name                   = "dmz-return-via-dmz-firewall"
    address_prefix         = var.dmz_vnet_address_space
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.dmz_firewall_private_ip
  }

  depends_on = [azurerm_firewall.dmz]
}

resource "azurerm_route_table" "app" {
  name                          = "rt-app-${local.unique_name}"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  bgp_route_propagation_enabled = false
  tags                          = local.tags

  route {
    name                   = "dmz-spoke-via-firewall"
    address_prefix         = var.dmz_vnet_address_space
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "dmz_container_apps" {
  subnet_id      = azurerm_subnet.dmz_container_apps.id
  route_table_id = azurerm_route_table.dmz.id
}

resource "azurerm_subnet_route_table_association" "dmz_firewall" {
  subnet_id      = azurerm_subnet.dmz_firewall.id
  route_table_id = azurerm_route_table.dmz_firewall.id
}

resource "azurerm_subnet_route_table_association" "hub_firewall" {
  subnet_id      = azurerm_subnet.firewall.id
  route_table_id = azurerm_route_table.hub_firewall.id
}

resource "azurerm_subnet_route_table_association" "app_container_apps" {
  subnet_id      = azurerm_subnet.app_container_apps.id
  route_table_id = azurerm_route_table.app.id
}
