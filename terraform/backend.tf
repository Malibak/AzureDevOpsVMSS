terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-backend-rg"
    storage_account_name = "terraformmadslilbaek"
    container_name       = "terraformbackend"
    key                  = "terraform.tfstate"
  }
}
