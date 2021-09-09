resource "azurerm_resource_group" "agentpool1_rg" {
  name     = "ado-agentpool-1-rg"
  location = "West Europe"
}

resource "azurerm_virtual_network" "agentpool1_vnet1" {
  name                = "ado-agentpool-1-vnet-1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.agentpool1_rg.location
  resource_group_name = azurerm_resource_group.agentpool1_rg.name
}

resource "azurerm_subnet" "agentpool1_vnet1_subnet1" {
  name                 = "ado-agentpool-1-vnet-1-subnet-1"
  resource_group_name  = azurerm_resource_group.agentpool1_rg.name
  virtual_network_name = azurerm_virtual_network.agentpool1_vnet1.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_public_ip" "agentpool1_pip1" {
  name                = "ado-agentpool-1-pip-1"
  location            = azurerm_resource_group.agentpool1_rg.location
  resource_group_name = azurerm_resource_group.agentpool1_rg.name
  allocation_method   = "Static"
  domain_name_label   = azurerm_resource_group.agentpool1_rg.name
}

resource "azurerm_lb" "agentpool1_lb" {
  name                = "ado-agentpool-1-lb"
  location            = azurerm_resource_group.agentpool1_rg.location
  resource_group_name = azurerm_resource_group.agentpool1_rg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.agentpool1_pip1.id
  }
}

resource "azurerm_lb_backend_address_pool" "agentpool1_lb_backendpool" {
  loadbalancer_id     = azurerm_lb.agentpool1_lb.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_pool" "agentpool1_lb_natpool" {
  resource_group_name            = azurerm_resource_group.agentpool1_rg.name
  name                           = "ssh"
  loadbalancer_id                = azurerm_lb.agentpool1_lb.id
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_lb_probe" "agentpool1_lb_probe1" {
  resource_group_name = azurerm_resource_group.agentpool1_rg.name
  loadbalancer_id     = azurerm_lb.agentpool1_lb.id
  name                = "http-probe"
  protocol            = "Http"
  request_path        = "/health"
  port                = 8080
}

resource "azurerm_virtual_machine_scale_set" "agentpool1_vmss1" {
  name                = "ado-agentpool-1-vmss-1"
  location            = azurerm_resource_group.agentpool1_rg.location
  resource_group_name = azurerm_resource_group.agentpool1_rg.name

  # automatic rolling upgrade
  automatic_os_upgrade = false
  upgrade_policy_mode  = "Rolling"

  rolling_upgrade_policy {
    max_batch_instance_percent              = 20
    max_unhealthy_instance_percent          = 20
    max_unhealthy_upgraded_instance_percent = 5
    pause_time_between_batches              = "PT5M"
  }

  # required when using rolling upgrade policy
  health_probe_id = azurerm_lb_probe.agentpool1_lb_probe1.id

  sku {
    name     = "Standard_B1s"
    tier     = "Standard"
    capacity = 3
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "adoagentpool1vm"
    admin_username       = "admin"
    admin_password       = "bnid!SjkKn@S78Kf"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name    = "agentpool1_vmss1_networkprofile"
    primary = true

    ip_configuration {
      name                                   = "TestIPConfiguration"
      primary                                = true
      subnet_id                              = azurerm_subnet.agentpool1_vnet1_subnet1.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.agentpool1_lb_backendpool.id]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.agentpool1_lb_natpool.id]
    }
  }
}
