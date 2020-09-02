# Create a Resource Group for the new Virtual Machine
data "azurerm_resource_group" "main" {
  name     = "${var.prefix}_rg"
  #location = "${var.location}"
}

data "azurerm_subnet" "cyber" {
  name                 = "mgmt"
  virtual_network_name = "f5lab_vnet"
  resource_group_name  = "f5lab_rg"
}


locals {
  depends_on = [data.azurerm_subnet.cyber]
  ext_gw     = cidrhost(data.azurerm_subnet.cyber.address_prefix, 1)
}

# Create a Network Security Group with some rules
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  security_rule {
    name                       = "allow_SSH"
    description                = "Allow SSH access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_HTTPS"
    description                = "Allow HTTPS access"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_APP_HTTPS"
    description                = "Allow HTTPS access"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Name        = "${var.environment}-bigip-nsg"
  }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = data.azurerm_subnet.cyber.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_network_interface" "core-gads-agent-nic" {
  name                      = "${var.prefix}-core-gads-agent-nic"
  location                  = data.azurerm_resource_group.main.location
  resource_group_name       = data.azurerm_resource_group.main.name
# network_security_group_id = azurerm_network_security_group.main.id

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.cyber.id
    private_ip_address_allocation = "static"
    private_ip_address            = var.core-gads-agent
    primary                       = true
  }

  tags = {
    Name        = "${var.environment}-core-gads-agent"
  }
}

resource "azurerm_virtual_machine" "core-gads-agent" {
  name                         = "core-gads-agent"
  location                     = data.azurerm_resource_group.main.location
  resource_group_name          = data.azurerm_resource_group.main.name
  network_interface_ids        = [azurerm_network_interface.core-gads-agent-nic.id]
  vm_size                      = var.instance_type

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  
  storage_os_disk {
    name              = "${var.prefix}core-gads-agent-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }


  os_profile {
    computer_name  = "core-gads-agent"
    admin_username = var.uname
    admin_password = var.upassword
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    Name        = "${var.environment}-f5vmadvwaf01"
  }
}

output "sg_id" {
  value = data.azurerm_subnet.cyber.id
}

output "sg_name" {
  value = data.azurerm_subnet.cyber.name
}

output "ext_subnet_gw" {
  value = local.ext_gw
}