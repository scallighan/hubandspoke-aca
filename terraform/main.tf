terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.67.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 3.9.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "= 2.12.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "= 3.0.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.6.3"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}

provider "azapi" {
  subscription_id = var.subscription_id
}

provider "azuread" {}

provider "acme" {
  server_url = var.acme_server_url
}

resource "random_string" "unique" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.repo_name}-${random_string.unique.result}-${local.location_slug}"
  location = var.location
  tags     = local.tags
}
