terraform {
  required_version = ">= 0.13"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    local = {
      source = "hashicorp/local"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}