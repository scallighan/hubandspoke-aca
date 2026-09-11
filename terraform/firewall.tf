resource "azurerm_public_ip" "firewall" {
  name                = "pip-firewall-${local.unique_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_tags             = local.public_ip_tags
  tags                = local.tags
}

resource "azurerm_public_ip" "firewall_management" {
  name                = "pip-firewall-management-${local.unique_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_tags             = local.public_ip_tags
  tags                = local.tags
}

resource "azurerm_public_ip" "dmz_firewall" {
  name                = "pip-dmz-firewall-${local.unique_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_tags             = local.public_ip_tags
  tags                = local.tags
}

resource "azurerm_public_ip" "dmz_firewall_management" {
  name                = "pip-dmz-firewall-management-${local.unique_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_tags             = local.public_ip_tags
  tags                = local.tags
}

resource "azurerm_firewall_policy" "this" {
  name                = "afwp-${local.unique_name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  tags                = local.tags
}

resource "azurerm_firewall_policy" "dmz" {
  name                = "afwp-dmz-${local.unique_name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  tags                = local.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "this" {
  name               = "inter-spoke"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 100

  network_rule_collection {
    name     = "allow-nginx-to-app"
    priority = 100
    action   = "Allow"

    dynamic "rule" {
      for_each = { for rule in local.dmz_egress_network_rules : rule.name => rule }

      content {
        name                  = rule.value.name
        protocols             = rule.value.protocols
        source_addresses      = rule.value.source_addresses
        destination_addresses = rule.value.destination_addresses
        destination_ports     = rule.value.destination_ports
      }
    }
  }

  application_rule_collection {
    name     = "allow-container-apps-platform-fqdns"
    priority = 110
    action   = "Allow"

    dynamic "rule" {
      for_each = { for rule in local.dmz_egress_application_rules : rule.name => rule }

      content {
        name              = rule.value.name
        source_addresses  = rule.value.source_addresses
        destination_fqdns = rule.value.destination_fqdns

        protocols {
          type = "Https"
          port = 443
        }
      }
    }
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "dmz" {
  name               = "dmz-egress"
  firewall_policy_id = azurerm_firewall_policy.dmz.id
  priority           = 100

  network_rule_collection {
    name     = "allow-dmz-egress"
    priority = 100
    action   = "Allow"

    dynamic "rule" {
      for_each = { for rule in local.dmz_egress_network_rules : rule.name => rule }

      content {
        name                  = rule.value.name
        protocols             = rule.value.protocols
        source_addresses      = rule.value.source_addresses
        destination_addresses = rule.value.destination_addresses
        destination_ports     = rule.value.destination_ports
      }
    }
  }

  application_rule_collection {
    name     = "allow-container-apps-platform-fqdns"
    priority = 110
    action   = "Allow"

    dynamic "rule" {
      for_each = { for rule in local.dmz_egress_application_rules : rule.name => rule }

      content {
        name              = rule.value.name
        source_addresses  = rule.value.source_addresses
        destination_fqdns = rule.value.destination_fqdns

        protocols {
          type = "Https"
          port = 443
        }
      }
    }
  }
}

resource "azurerm_firewall" "this" {
  name                = "afw-${local.unique_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  tags                = local.tags

  ip_configuration {
    name                 = "firewall"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  management_ip_configuration {
    name                 = "management"
    subnet_id            = azurerm_subnet.firewall_management.id
    public_ip_address_id = azurerm_public_ip.firewall_management.id
  }

  depends_on = [
    azurerm_firewall_policy_rule_collection_group.this,
  ]
}

resource "azurerm_firewall" "dmz" {
  name                = "afw-dmz-${local.unique_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"
  firewall_policy_id  = azurerm_firewall_policy.dmz.id
  tags                = local.tags

  ip_configuration {
    name                 = "firewall"
    subnet_id            = azurerm_subnet.dmz_firewall.id
    public_ip_address_id = azurerm_public_ip.dmz_firewall.id
  }

  management_ip_configuration {
    name                 = "management"
    subnet_id            = azurerm_subnet.dmz_firewall_management.id
    public_ip_address_id = azurerm_public_ip.dmz_firewall_management.id
  }

  depends_on = [
    azurerm_firewall_policy_rule_collection_group.dmz,
    azurerm_subnet_route_table_association.dmz_firewall,
  ]
}
