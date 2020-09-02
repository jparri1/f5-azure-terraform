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

# Setup Onboarding scripts
data "template_file" "vm_onboard_awaf" {
  template = file("${path.module}/onboard_awaf.tpl")

  vars = {
        uname       = var.uname
        # replace this with a reference to the secret id
        upassword   = var.upassword
        DO_URL      = var.DO_URL
        AS3_URL     = var.AS3_URL
        TS_URL      = var.TS_URL
        libs_dir    = var.libs_dir
        onboard_log = var.onboard_log
    }
}

data "template_file" "awaf_do_json" {
  template = file("${path.module}/awaf_do_data.json")
  depends_on = [azurerm_network_interface.advwaf01-nic]
/*
  vars = {
    host1          = var.host1_name
    host2          = var.host2_name
    local_host     = var.host2_name
    local_selfip   = var.f5vm02mgmt
    remote_host    = var.host1_name
    remote_selfip  = var.f5vm01mgmt
    gateway        = local.ext_gw
    dns_server     = var.dns_server
    ntp_server     = var.ntp_server
    timezone       = var.timezone
    admin_user     = var.uname
    admin_password = var.upassword
    #local_sku      = var.license2
  }
  #Uncomment the following line for BYOL
 */ 
}

data "template_file" "awaf_as3_json" {
  template = file("${path.module}/as3_awaf.json")

}

terraform {
    backend "azurerm" {
        storage_account_name = "f5labtfstate"
        container_name       = "tfstate"
        key                  = "terraform.tfstate"
    }
}

resource "azurerm_public_ip" "advwaf01pip" {
  name                = "${var.prefix}-advwaf01-pip"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"

  tags = {
    Name        = "${var.environment}-advwaf01-public-ip"
  }
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
    name                       = "allow_HTTP"
    description                = "Allow HTTP access"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
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
    Name        = "${var.environment}-bigip-sg"
  }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = data.azurerm_subnet.cyber.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_network_interface" "advwaf01-nic" {
  name                      = "${var.prefix}-advwaf01-nic"
  location                  = data.azurerm_resource_group.main.location
  resource_group_name       = data.azurerm_resource_group.main.name
# network_security_group_id = azurerm_network_security_group.main.id

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.cyber.id
    private_ip_address_allocation = "static"
    private_ip_address            = var.advwaf01
    primary                       = true
    public_ip_address_id          = azurerm_public_ip.advwaf01pip.id
  }

  tags = {
    Name        = "${var.environment}-advwaf01"
  }
}

resource "azurerm_virtual_machine" "f5vmadvwaf01" {
  name                         = "${var.prefix}-f5vmadvwaf01"
  location                     = data.azurerm_resource_group.main.location
  resource_group_name          = data.azurerm_resource_group.main.name
  network_interface_ids        = [azurerm_network_interface.advwaf01-nic.id]
  vm_size                      = var.instance_type

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  
  storage_os_disk {
    name              = "${var.prefix}advwaf01-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
      publisher = "f5-networks"
      offer = "f5-big-ip-advanced-waf"
      sku = "f5-bigip-virtual-edition-25m-waf-hourly"
      version = "15.1.004000"
  }


  os_profile {
    computer_name  = "${var.prefix}advwaf01"
    admin_username = var.uname
    admin_password = var.upassword
    custom_data    = data.template_file.vm_onboard_awaf.rendered
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  plan {
    name = "f5-bigip-virtual-edition-25m-waf-hourly"
    publisher = "f5-networks"
    product = "f5-big-ip-advanced-waf"
  }

  tags = {
    Name        = "${var.environment}-f5vmadvwaf01"
  }
}

resource "azurerm_virtual_machine_extension" "run_startup_cmd" {
    name = "${var.environment}-f5vmadvwaf01-run-startup-cmd"
    depends_on = [
    azurerm_virtual_machine.f5vmadvwaf01
    ]
    virtual_machine_id = azurerm_virtual_machine.f5vmadvwaf01.id
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"

    settings = <<SETTINGS
        {
            "commandToExecute": "bash /var/lib/waagent/CustomData; exit 0;"
        }
    SETTINGS

    tags = {
        Name           = "${var.environment}-f5vmadvwaf01"
        
    }
}

# Run REST API for configuration
resource "local_file" "f5vmadvwaf01_do_file" {
  content  = data.template_file.awaf_do_json.rendered
  filename = "f5vmadvwaf01_do_data.json"
}

resource "local_file" "f5vmadvwaf01_as3_file" {
  content  = data.template_file.awaf_as3_json.rendered
  filename = "f5vmadvwaf01_as3_data.json"
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

output "f5vmadvwaf01_id" {
  value = azurerm_virtual_machine.f5vmadvwaf01.id
}

output "f5vmadvwaf01_ext_private_ip" {
  value = azurerm_network_interface.advwaf01-nic.private_ip_address
}

output "f5vmadvwaf01_pip" {
  value = azurerm_public_ip.advwaf01pip.ip_address
}