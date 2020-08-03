# Create a Resource Group for the new Virtual Machine
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}_rg"
  location = "${var.location}"
}

data "azurerm_subnet" "cyber" {
  name                 = "Cyber-Eng-DevTest"
  virtual_network_name = "Cybersecurity-Engineering-DevTest-vnet"
  resource_group_name  = "Networking-DevTest-RG"
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
  
}

data "template_file" "awaf_as3_json" {
  template = file("${path.module}/as3_awaf.json")

}

resource "azurerm_network_interface" "advwaf01-nic" {
  name                      = "${var.prefix}-advwaf01-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.cyber.id
    private_ip_address_allocation = "static"
    private_ip_address            = var.advwaf01
    primary                       = true
  }

  tags = {
    Name        = "${var.environment}-advwaf01"
  }
}

resource "azurerm_virtual_machine" "f5vmadvwaf01" {
  name                         = "${var.prefix}-f5vmadvwaf01"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
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
      version = "15.0.104000"
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
    count                = length(var.azs)
    name                 = format("%s-bigip-startup-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    #location             = azurerm_resource_group.main.location
    #resource_group_name  = azurerm_resource_group.main.name
    #virtual_machine_name = azurerm_virtual_machine.f5bigip[count.index].name
    virtual_machine_id   = azurerm_virtual_machine.f5vmadvwaf01.id
    publisher            = "Microsoft.OSTCExtensions"
    type                 = "CustomScriptForLinux"
    type_handler_version = "1.2"

    settings = <<SETTINGS
        {
            "commandToExecute": "bash /var/lib/waagent/CustomData"
        }
    SETTINGS

    tags = {
        Name           = format("%s-bigip-startup-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        environment    = var.environment
    }
}

/*
resource "null_resource" "filecopy_as3_awaf" {
   depends_on = [azurerm_virtual_machine.f5vmadvwaf01]

  provisioner "file" {
    source      = "f5-appsvcs-3.18.0-4.noarch.rpm"
    destination = "/var/tmp/f5-appsvcs-3.18.0-4.noarch.rpm"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = var.f5vmadvwaf01
    }  
  }
  
}

resource "null_resource" "filecopy_do_awaf" {
   depends_on = [azurerm_virtual_machine.f5vmadvwaf01]

  provisioner "file" {
    source      = "f5-declarative-onboarding-1.12.0-1.noarch.rpm"
    destination = "/var/tmp/f5-declarative-onboarding-1.12.0-1.noarch.rpm"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = var.f5vmadvwaf01
    }  
  }
  
}


resource "null_resource" "f5vmadvwaf01_do_installer" {
  provisioner "local-exec" {
        
        command = "powershell.exe sleep 60"
  }
  provisioner "local-exec" {
        #curl command to install DO
        command = "curl https://${azurerm_network_interface.vm01-mgmt-nic.private_ip_address}/mgmt/shared/iapp/package-management-tasks -u admin:${var.upassword} -d ${var.do_data} -k"
  }
}

resource "null_resource" "f5vmadvwaf01_as3_installer" {
  depends_on =  [null_resource.f5vmadvwaf01_do_installer]
  

  provisioner "local-exec" {
        #curl command to install AS3
        command = "curl https://${azurerm_network_interface.vm01-mgmt-nic.private_ip_address}/mgmt/shared/iapp/package-management-tasks -u admin:${var.upassword} -d ${var.as3_data} -k"
  }
}
*/
# Run REST API for configuration
resource "local_file" "f5vmadvwaf01_do_file" {
  content  = data.template_file.vm01_do_json.rendered
  filename = "${path.module}/f5vmadvwaf01_do_data.json"
}

resource "local_file" "f5vmadvwaf01_as3_file" {
  content  = data.template_file.as3_json.rendered
  filename = "${path.module}/f5vmadvwaf01_as3_data.json"
}

resource "null_resource" "f5vmadvwaf01-run-DO" {
depends_on =  [azurerm_virtual_machine_extension.run_startup_cmd]
provisioner "local-exec" {
        
        command = "powershell.exe sleep 30"
  }
  # Running DO REST API
  provisioner "local-exec" {
       command = "curl https://${azurerm_network_interface.advwaf01-nic.private_ip_address}${var.rest_do_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_f5vmadvwaf01_do_file} -k"
    
  }
}

 resource "null_resource" "f5vmadvwaf01-run-AS3" {
  depends_on =  [null_resource.f5vm02-run-DO]
  
  provisioner "local-exec" {
    command = "curl https://${azurerm_network_interface.advwaf01-nic.private_ip_address}${var.rest_as3_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_f5vmadvwaf01_as3_file} -k"

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

output "f5vmadvwaf01_id" {
  value = azurerm_virtual_machine.f5vmadvwaf01.id
}

output "f5vmadvwaf01_ext_private_ip" {
  value = azurerm_network_interface.advwaf01-nic.private_ip_address
}