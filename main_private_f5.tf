# Create a Resource Group for the new Virtual Machine
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}_rg"
  location = var.location
}

data "azurerm_subnet" "External" {
  name                 = "Cyber-Eng-DevTest"
  virtual_network_name = "Cybersecurity-Engineering-DevTest-vnet"
  resource_group_name  = "Networking-DevTest-RG"
}

locals {
  depends_on = [data.azurerm_subnet.External]
  ext_gw     = cidrhost(data.azurerm_subnet.External.address_prefix, 1)
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


# Create the second network interface card for External
resource "azurerm_network_interface" "vm01-ext-nic" {
  name                      = "${var.prefix}-vm01-ext-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.External.id
    private_ip_address_allocation = "dynamic"
    primary                       = true
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

data "template_file" "vm01_do_json" {
  template = file("${path.module}/cluster_synconly.json")

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


data "template_file" "as3_json" {
  template = file("${path.module}/as3_no_service_discovery.json")

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
  primary_network_interface_id = azurerm_network_interface.vm01-ext-nic.id
  network_interface_ids        = [azurerm_network_interface.vm01-ext-nic.id]
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
    computer_name  = "${var.prefix}vm01"
    admin_username = var.uname
    admin_password = var.upassword
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



resource "null_resource" "filecopy_as3_vm01" {
   depends_on = [azurerm_virtual_machine.f5vm01]

  provisioner "file" {
    source      = "f5-appsvcs-3.18.0-4.noarch.rpm"
    destination = "/var/tmp/f5-appsvcs-3.18.0-4.noarch.rpm"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = "${azurerm_network_interface.vm01-ext-nic.private_ip_address}"
    }  
  }
  
}

resource "null_resource" "filecopy_do_vm01" {
   depends_on = [azurerm_virtual_machine.f5vm01]

  provisioner "file" {
    source      = "f5-declarative-onboarding-1.11.1-1.noarch.rpm"
    destination = "/var/tmp/f5-declarative-onboarding-1.11.1-1.noarch.rpm"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = "${azurerm_network_interface.vm01-ext-nic.private_ip_address}"
    }  
  }
  
}

resource "azurerm_virtual_machine_extension" "f5vm01-reset-httpd" {
  name = "${var.environment}-f5vm01-run-startup-cmd"
  depends_on =  [azurerm_virtual_machine.f5vm01,null_resource.filecopy_do_vm01,null_resource.filecopy_as3_vm01]
  #location             = var.region
  #resource_group_name  = azurerm_resource_group.main.name
  virtual_machine_id = azurerm_virtual_machine.f5vm01.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "tmsh modify sys httpd ssl-port 443; sudo bigstart restart restnoded; exit 0"
    }
  
SETTINGS


  tags = {
    Name        = "${var.environment}-f5vm02-startup-cmd"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}


/*resource "null_resource" "f5vm01_do_installer" {
  depends_on =  [azurerm_virtual_machine.f5vm01,null_resource.filecopy_do_vm01,null_resource.filecopy_as3_vm01]
  provisioner "local-exec" {
        
        command = "powershell.exe sleep 180"
  }
  provisioner "local-exec" {
        #curl command to install DO
        command = "curl https://${azurerm_network_interface.vm01-ext-nic.private_ip_address}/mgmt/shared/iapp/package-management-tasks -u admin:${var.upassword} -d ${var.do_data} -k"
  }
}



resource "null_resource" "f5vm01_as3_installer" {
  depends_on =  [null_resource.f5vm01_do_installer]
  

  provisioner "local-exec" {
        #curl command to install AS3
        command = "curl https://${azurerm_network_interface.vm01-ext-nic.private_ip_address}/mgmt/shared/iapp/package-management-tasks -u admin:${var.upassword} -d ${var.as3_data} -k"
  }
}


resource "azurerm_virtual_machine_extension" "f5vm01-run-startup-cmd" {
  name = "${var.environment}-f5vm01-run-startup-cmd"
  depends_on = [
    null_resource.f5vm01_as3_installer
  ]
  #location             = var.region
  #resource_group_name  = azurerm_resource_group.main.name
  virtual_machine_id = azurerm_virtual_machine.f5vm01.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "sudo bigstart restart restnoded"
    }
  
SETTINGS


  tags = {
    Name        = "${var.environment}-f5vm01-startup-cmd"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
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
  depends_on =  [azurerm_virtual_machine_extension.f5vm01-run-startup-cmd]
  # Running DO REST API
  provisioner "local-exec" {
       command = "curl https://${azurerm_network_interface.vm01-ext-nic.private_ip_address}${var.rest_do_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_vm01_do_file} -k"
    
  }
}

 resource "null_resource" "f5vm01-run-AS3" {
  depends_on =  [null_resource.f5vm01_as3_installer]
  
  provisioner "local-exec" {
    command = "curl https://${azurerm_network_interface.vm01-ext-nic.private_ip_address}${var.rest_as3_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_vm_as3_file} -k"

  }

 }*/


output "sg_id" {
  value = data.azurerm_subnet.External.id
}

output "sg_name" {
  value = data.azurerm_subnet.External.name
}

output "ext_subnet_gw" {
  value = local.ext_gw
}

output "f5vm01_id" {
  value = azurerm_virtual_machine.f5vm01.id
}

output "f5vm01_ext_private_ip" {
  value = azurerm_network_interface.vm01-ext-nic.private_ip_address
}
