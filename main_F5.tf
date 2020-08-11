# Create a Resource Group for the new Virtual Machine
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}_rg"
  location = var.location
}

# Create a Virtual Network within the Resource Group
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = [var.cidr]
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# Create the first Subnet within the Virtual Network
resource "azurerm_subnet" "Mgmt" {
  name                 = "Mgmt"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefix       = var.subnets["subnet1"]
}

# Create the second Subnet within the Virtual Network
resource "azurerm_subnet" "External" {
  name                 = "External"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefix       = var.subnets["subnet2"]
}

# Obtain Gateway IP for each Subnet
locals {
  depends_on = ["azurerm_subnet.Mgmt", "azurerm_subnet.External"]
  mgmt_gw    = cidrhost(azurerm_subnet.Mgmt.address_prefix, 1)
  ext_gw     = cidrhost(azurerm_subnet.External.address_prefix, 1)
}

# Create a Public IP for the Virtual Machines
resource "azurerm_public_ip" "vm01mgmtpip" {
  name                = "${var.prefix}-vm01-mgmt-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"

  tags = {
    Name        = "${var.environment}-vm01-mgmt-public-ip"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}


# Create Availability Set
resource "azurerm_availability_set" "avset" {
  name                         = "${var.prefix}avset"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

# Create a Network Security Group with some rules
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

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
    Name        = "${var.environment}-bigip-sg"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

# Create the first network interface card for Management 
resource "azurerm_network_interface" "vm01-mgmt-nic" {
  name                      = "${var.prefix}-vm01-mgmt-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.Mgmt.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm01mgmt
    public_ip_address_id          = azurerm_public_ip.vm01mgmtpip.id
  }

  tags = {
    Name        = "${var.environment}-vm01-mgmt-int"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

# Create the second network interface card for External
resource "azurerm_network_interface" "vm01-ext-nic" {
  name                      = "${var.prefix}-vm01-ext-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.External.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm01ext
    primary                       = true
  }

  ip_configuration {
    name                          = "secondary"
    subnet_id                     = azurerm_subnet.External.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm01ext_sec
  }

  tags = {
    Name        = "${var.environment}-vm01-ext-int"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

resource "azurerm_network_interface_security_group_association" "mgmt" {
    network_interface_id      = azurerm_network_interface.vm01-mgmt-nic.id
    network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_network_interface_security_group_association" "ext" {
    network_interface_id      = azurerm_network_interface.vm01-ext-nic.id
    network_security_group_id = azurerm_network_security_group.main.id
}

# Setup Onboarding scripts
  data "template_file" "vm_onboard" {
  template = file("${path.module}/onboard_f5.tpl")

  vars = {
    uname          = var.uname
    upassword      = var.upassword
    DO_onboard_URL = var.DO_onboard_URL
    AS3_URL        = var.AS3_URL
    libs_dir       = var.libs_dir
    onboard_log    = var.onboard_log
  }
}

data "template_file" "vm01_do_json" {
  template = file("${path.module}/initial_onboard.json")

  vars = {
    host1          = var.host1_name
    host2          = var.host2_name
    local_host     = var.host1_name
    local_selfip   = var.f5vm01ext
    remote_host    = var.host2_name
    remote_selfip  = var.f5vm02ext
    gateway        = local.ext_gw
    dns_server     = var.dns_server
    ntp_server     = var.ntp_server
    timezone       = var.timezone
    admin_user     = var.uname
    admin_password = var.upassword
  }
  #Uncomment the following line for BYOL
  #local_sku	    = "${var.license1}"
}

data "template_file" "vm02_do_json" {
  template = file("${path.module}/initial_onboard.json")

  vars = {
    host1          = var.host1_name
    host2          = var.host2_name
    local_host     = var.host2_name
    local_selfip   = var.f5vm02ext
    remote_host    = var.host1_name
    remote_selfip  = var.f5vm01ext
    gateway        = local.ext_gw
    dns_server     = var.dns_server
    ntp_server     = var.ntp_server
    timezone       = var.timezone
    admin_user     = var.uname
    admin_password = var.upassword
  }
  #Uncomment the following line for BYOL
  #local_sku      = "${var.license2}"
}

data "template_file" "as3_json" {
  template = file("${path.module}/as3.json")

  vars = {
    rg_name         = azurerm_resource_group.main.name
    subscription_id = var.SP["subscription_id"]
    tenant_id       = var.SP["tenant_id"]
    client_id       = var.SP["client_id"]
    client_secret   = var.SP["client_secret"]
  }
}

# Create F5 BIGIP VMs
resource "azurerm_virtual_machine" "f5vm01" {
  name                         = "${var.prefix}-f5vm01"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  primary_network_interface_id = azurerm_network_interface.vm01-mgmt-nic.id
  network_interface_ids        = [azurerm_network_interface.vm01-mgmt-nic.id, azurerm_network_interface.vm01-ext-nic.id]
  vm_size                      = var.instance_type
  availability_set_id          = azurerm_availability_set.avset.id

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "f5-networks"
    offer     = var.product
    sku       = var.image_name
    version   = var.bigip_version
  }

  storage_os_disk {
    name              = "${var.prefix}vm01-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.prefix}-f5vm01"
    admin_username = var.uname
    admin_password = var.upassword
    custom_data    = data.template_file.vm_onboard.rendered
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  plan {
    name      = var.image_name
    publisher = "f5-networks"
    product   = var.product
  }

  tags = {
    Name        = "${var.environment}-f5vm01"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}
resource "null_resource" "filecopy_as3" {
   depends_on = [azurerm_virtual_machine.f5vm01]

  provisioner "file" {
    source      = "f5-appsvcs-3.18.0-4.noarch.rpm"
    destination = "/var/tmp/f5-appsvcs-3.18.0-4.noarch.rpm"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = "${azurerm_public_ip.vm01mgmtpip.ip_address}"
    }  
  }
  
}

resource "null_resource" "filecopy_do" {
   depends_on = [azurerm_virtual_machine.f5vm01]

  provisioner "file" {
    source      = "f5-declarative-onboarding-1.11.1-1.noarch.rpm"
    destination = "/var/tmp/f5-declarative-onboarding-1.11.1-1.noarch.rpm"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = "${azurerm_public_ip.vm01mgmtpip.ip_address}"
    }  
  }
  
}

resource "null_resource" "f5vm01_do_installer" {
  depends_on =  [azurerm_virtual_machine.f5vm01,null_resource.filecopy_do,null_resource.filecopy_as3]
  provisioner "local-exec" {
        
        command = "powershell.exe sleep 180"
  }
  provisioner "local-exec" {
        #curl command to install DO
        command = "curl https://${azurerm_public_ip.vm01mgmtpip.ip_address}/mgmt/shared/iapp/package-management-tasks -u ${var.uname}:${var.upassword} -d ${var.do_data} -k"
  }
} 

resource "null_resource" "f5vm01_as3_installer" {
  depends_on =  [azurerm_virtual_machine.f5vm01,null_resource.f5vm01_do_installer]
  provisioner "local-exec" {
        
        command = "powershell.exe sleep 180"
  }

  provisioner "local-exec" {
        #curl command to install AS3
        command = "curl https://${azurerm_public_ip.vm01mgmtpip.ip_address}/mgmt/shared/iapp/package-management-tasks -u ${var.uname}:${var.upassword} -d ${var.as3_data} -k"
  }
}

resource "azurerm_virtual_machine_extension" "f5vm01-restart" {
  name = "${var.environment}-f5vm01-run-startup-cmd"
  depends_on = [null_resource.f5vm01_as3_installer]
  #location             = var.region
  #resource_group_name  = azurerm_resource_group.main.name
  virtual_machine_id = azurerm_virtual_machine.f5vm01.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"
   
settings = <<SETTINGS
    {
        "commandToExecute": "sudo bigstart restart restnoded"
  
    }
  
SETTINGS
}

# Run REST API for configuration
resource "local_file" "vm01_do_file" {
  content  = data.template_file.vm01_do_json.rendered
  filename = "${path.module}/vm01_do_data.json"
}

resource "local_file" "vm_as3_file" {
  content  = data.template_file.as3_json.rendered
  filename = "${path.module}/vm_as3_data.json"
}

resource "null_resource" "f5vm01-run-DO" {
 depends_on =  [azurerm_virtual_machine_extension.f5vm01-restart]
  # Running DO REST API
  provisioner "local-exec" {
       command = "curl https://${azurerm_public_ip.vm01mgmtpip.ip_address}${var.rest_do_uri} -u ${var.uname}:${var.upassword} -k -d @${var.rest_vm01_do_file}"
    
  }
}

 resource "null_resource" "f5vm01-run-AS3" {
  depends_on =  [null_resource.f5vm01-run-DO]
  
  provisioner "local-exec" {
    command = "curl -k -X ${var.rest_as3_method} https://${azurerm_public_ip.vm01mgmtpip.ip_address}${var.rest_as3_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_vm_as3_file}"

  }

 }

 

 

## OUTPUTS ###

output "sg_id" {
  value = azurerm_network_security_group.main.id
}

output "sg_name" {
  value = azurerm_network_security_group.main.name
}
