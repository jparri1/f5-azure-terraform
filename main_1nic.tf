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

# Create Availability Set
resource "azurerm_availability_set" "avset" {
  name                         = "${var.prefix}avset"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

resource "azurerm_lb" "lb" {
  name                = "${var.prefix}lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
	  private_ip_address_allocation = "Static"
    private_ip_address            = var.azlbip
    subnet_id            = data.azurerm_subnet.cyber.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  name                = "BackendPool1"
  resource_group_name = azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name = azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "tcpProbe"
  protocol            = "tcp"
  port                = 8443
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "LBRule"
  resource_group_name            = azurerm_resource_group.main.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "tcp"
  frontend_port                  = 443
  backend_port                   = 8443
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  enable_floating_ip             = false
  backend_address_pool_id        = azurerm_lb_backend_address_pool.backend_pool.id
  idle_timeout_in_minutes        = 5
  probe_id                       = azurerm_lb_probe.lb_probe.id
  depends_on                     = [azurerm_lb_probe.lb_probe]
}


# Create the first network interface card for Management 
resource "azurerm_network_interface" "vm01-mgmt-nic" {
  name                      = "${var.prefix}-vm01-mgmt-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.cyber.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm01mgmt
    primary                       = true
  }

  ip_configuration {
    name                          = "secondary"
    subnet_id                     = data.azurerm_subnet.cyber.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm01mgmt_sec
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


resource "azurerm_network_interface" "vm02-mgmt-nic" {
  name                      = "${var.prefix}-vm02-mgmt-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.cyber.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm02mgmt
    primary                       = true
  }

   ip_configuration {
    name                          = "secondary"
    subnet_id                     = data.azurerm_subnet.cyber.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm02mgmt_sec
  }

  tags = {
    Name        = "${var.environment}-vm02-mgmt-int"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

resource "azurerm_network_interface" "backendvm01-ext-nic" {
  name                      = "${var.prefix}-backendvm01-ext-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.cyber.id
    private_ip_address_allocation = "static"
    private_ip_address            = var.backendvm01ext
    primary                       = true
  }

  tags = {
    Name        = "${var.environment}-backendvm01-ext-int"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = "app1"
  }
} 
  resource "azurerm_network_interface" "backend02-ext-nic" {
  name                      = "${var.prefix}-backend02-ext-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.cyber.id
    private_ip_address_allocation = "static"
    private_ip_address            = var.backend02ext
    primary                       = true
  }

  tags = {
    Name        = "${var.environment}-backend02-ext-int"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = "app2"
  }
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

# Associate the Network Interface to the BackendPool
resource "azurerm_network_interface_backend_address_pool_association" "bpool_assc_vm01" {
  depends_on = [
    azurerm_lb_backend_address_pool.backend_pool,
    azurerm_network_interface.vm01-mgmt-nic
  ]
  network_interface_id    = azurerm_network_interface.vm01-mgmt-nic.id
  ip_configuration_name   = "secondary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "bpool_assc_vm02" {
  depends_on = [
    azurerm_network_interface_backend_address_pool_association.bpool_assc_vm01,
    azurerm_network_interface.vm02-mgmt-nic
  ]
  network_interface_id    = azurerm_network_interface.vm02-mgmt-nic.id
  ip_configuration_name   = "secondary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}

# Setup Onboarding scripts
data "template_file" "vm_onboard_backend" {
  template = file("${path.module}/onboard_backend.tpl")

  vars = {
    onboard_log    = var.onboard_log
  }
}

data "template_file" "vm_onboard_f5" {
  template = file("${path.module}/onboard_f5_modifyhttpd.tpl")

  vars = {
    onboard_log    = var.onboard_log
  }
}

data "template_file" "vm01_do_json" {
  template = file("${path.module}/cluster_active_active_1nic.json")
  depends_on = [azurerm_network_interface.vm02-mgmt-nic,azurerm_network_interface.vm01-mgmt-nic]

  vars = {
    host1          = var.host1_name
    host2          = var.host2_name
    local_host     = var.host1_name
    local_selfip   = var.f5vm01mgmt
    remote_host    = var.host2_name
    remote_selfip  = var.f5vm02mgmt
    gateway        = local.ext_gw
    dns_server     = var.dns_server
    ntp_server     = var.ntp_server
    timezone       = var.timezone
    admin_user     = var.uname
    admin_password = var.upassword
    #local_sku	     = var.license1
  }
  #Uncomment the following line for BYOL
  
}

data "template_file" "vm02_do_json" {
  template = file("${path.module}/cluster_active_active_1nic.json")
  depends_on = [azurerm_network_interface.vm02-mgmt-nic,azurerm_network_interface.vm01-mgmt-nic]

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
  primary_network_interface_id = azurerm_network_interface.vm01-mgmt-nic.id
  network_interface_ids        = [azurerm_network_interface.vm01-mgmt-nic.id]
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

resource "azurerm_virtual_machine" "f5vm02" {
  name                         = "${var.prefix}-f5vm02"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  primary_network_interface_id = azurerm_network_interface.vm02-mgmt-nic.id
  network_interface_ids        = [azurerm_network_interface.vm02-mgmt-nic.id]
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
    name              = "${var.prefix}vm02-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.prefix}vm02"
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
    Name        = "${var.environment}-f5vm02"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
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


provider "bigip" {
  address = "10.216.8.30"
  username = var.uname
  password = var.upassword
}

resource "bigip_as3"  "as3-asm" {
    as3_json = "${file("policy-1_v1.2")}"

}

# Docker VM for pool members
resource "azurerm_virtual_machine" "backendvm03" {
    name                  = "backendvm03"
    location              = azurerm_resource_group.main.location
    resource_group_name   = azurerm_resource_group.main.name
    network_interface_ids = [azurerm_network_interface.backend03-ext-nic.id]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "backendOs3Disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "backendvm03"
        admin_username = "azureuser"
        admin_password = var.upassword
        custom_data    = <<-EOF
            #!/bin/bash
            apt-get update -y
            apt-get install -y docker.io
            docker run -d -p 80:80 --net=host --restart unless-stopped -e F5DEMO_APP=website -e F5DEMO_NODENAME='F5 Azure' -e F5DEMO_COLOR=ffd734 -e F5DEMO_NODENAME_SSL='F5 Azure (SSL)' -e F5DEMO_COLOR_SSL=a0bf37 chen23/f5-demo-app:ssl
        EOF
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    tags = {
        Name        = "${var.environment}-backendvm03"
        environment = var.environment
        owner       = var.owner
        group       = var.group
        costcenter  = var.costcenter
        application = var.application
    }
}

resource "azurerm_virtual_machine" "jumpbox" {
    name                  = "jb01"
    location              = azurerm_resource_group.main.location
    resource_group_name   = azurerm_resource_group.main.name
    network_interface_ids = [azurerm_network_interface.jb_nic.id]
    vm_size               = "Standard_DC8_v2"

    # Uncomment this line to delete the OS disk automatically when deleting the VM
    # if this is set to false there are behaviors that will require manual intervention
    # if tainting the virtual machine
    delete_os_disk_on_termination = true

    # Uncomment this line to delete the data disks automatically when deleting the VM
    delete_data_disks_on_termination = true
    storage_os_disk {
        name              = "jbosdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "jb01"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = file(var.publickeyfile)
        }
    }

    tags = {
        environment = "${var.environment}-jb01vm"
    }
}

# Create network interface
resource "azurerm_network_interface" "jb_nic" {
    name                      = "${var.prefix}-jb01-nic"
    location                  = azurerm_resource_group.main.location
    resource_group_name       = azurerm_resource_group.main.name
    #network_security_group_id = azurerm_network_security_group.jb_sg.id

    ip_configuration {
        name                          = "primary"
        subnet_id                     = data.azurerm_subnet.cyber.id
        private_ip_address_allocation = "static"
        private_ip_address            = var.jb01
    }

    tags = {
        environment = "${var.environment}-jb01-nic"
    }
}

resource "azurerm_virtual_machine" "backendvm02" {
    name                  = "backendvm02"
    location              = azurerm_resource_group.main.location
    resource_group_name   = azurerm_resource_group.main.name
    network_interface_ids = [azurerm_network_interface.backendvm02_nic.id]
    vm_size               = "Standard_DS2_v2"

    # Uncomment this line to delete the OS disk automatically when deleting the VM
    # if this is set to false there are behaviors that will require manual intervention
    # if tainting the virtual machine
    delete_os_disk_on_termination = true

    # Uncomment this line to delete the data disks automatically when deleting the VM
    delete_data_disks_on_termination = true
    storage_os_disk {
        name              = "backendvm02"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

 #   storage_image_reference {
 #       publisher = "nginxinc"
 #       offer = "nginx-plus-v1"
 #       sku = "nginx-plus-ub1804"
 #       version = "latest"
 # }

  storage_image_reference {
        publisher = "nginxinc"
        offer = "nginx-plus-v1"
        sku = "nginx-plus-centos7"
        version = "latest"
  }

  os_profile {
    computer_name  = "backendvm02"
    admin_username = "azureuser"
    admin_password = var.upassword
	  #custom_data    = data.template_file.vm_onboard_backend.rendered
  }

 # plan {
 #   name = "nginx-plus-ub1804"
 #   publisher = "nginxinc"
 #   product = "nginx-plus-v1"
 # }
  plan {
    name = "nginx-plus-centos7"
    publisher = "nginxinc"
    product = "nginx-plus-v1"
  }


  os_profile_linux_config {
    disable_password_authentication = false
  }

    tags = {
        environment = "${var.environment}-backendvm02"
    }
}

# Create network interface
resource "azurerm_network_interface" "backendvm02_nic" {
    name                      = "${var.prefix}-backendvm02-nic"
    location                  = azurerm_resource_group.main.location
    resource_group_name       = azurerm_resource_group.main.name
    #network_security_group_id = azurerm_network_security_group.jb_sg.id

    ip_configuration {
        name                          = "primary"
        subnet_id                     = data.azurerm_subnet.cyber.id
        private_ip_address_allocation = "static"
        private_ip_address            = var.backendvm02
    }

    tags = {
        environment = "${var.environment}-backendvm02-nic"
    }
}

resource "azurerm_virtual_machine" "nginxplus" {
    name                  = "nginxplus"
    location              = azurerm_resource_group.main.location
    resource_group_name   = azurerm_resource_group.main.name
    network_interface_ids = [azurerm_network_interface.nginxplus_nic.id]
    vm_size               = "Standard_DS2_v2"

    # Uncomment this line to delete the OS disk automatically when deleting the VM
    # if this is set to false there are behaviors that will require manual intervention
    # if tainting the virtual machine
    delete_os_disk_on_termination = true

    # Uncomment this line to delete the data disks automatically when deleting the VM
    delete_data_disks_on_termination = true
    storage_os_disk {
        name              = "nginxplus"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "nginxinc"
        offer = "nginx-plus-v1"
        sku = "nginx-plus-ub1804"
        version = "latest"
  }

  os_profile {
    computer_name  = "nginxplus"
    admin_username = "azureuser"
    admin_password = var.upassword
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  plan {
    name = "nginx-plus-ub1804"
    publisher = "nginxinc"
    product = "nginx-plus-v1"
  }

    tags = {
        environment = "${var.environment}-nginxplus"
    }
}

# Create network interface
resource "azurerm_network_interface" "nginxplus_nic" {
    name                      = "${var.prefix}-nginxplus-nic"
    location                  = azurerm_resource_group.main.location
    resource_group_name       = azurerm_resource_group.main.name
    #network_security_group_id = azurerm_network_security_group.jb_sg.id

    ip_configuration {
        name                          = "primary"
        subnet_id                     = data.azurerm_subnet.cyber.id
        private_ip_address_allocation = "static"
        private_ip_address            = var.nginxplus
    }

    tags = {
        environment = "${var.environment}-nginxplus-nic"
    }
}

resource "azurerm_virtual_machine" "atower" {
    name                  = "atower"
    location              = azurerm_resource_group.main.location
    resource_group_name   = azurerm_resource_group.main.name
    network_interface_ids = [azurerm_network_interface.atower_nic.id]
    vm_size               = "Standard_D2s_v3"

    # Uncomment this line to delete the OS disk automatically when deleting the VM
    # if this is set to false there are behaviors that will require manual intervention
    # if tainting the virtual machine
    delete_os_disk_on_termination = true

    # Uncomment this line to delete the data disks automatically when deleting the VM
    delete_data_disks_on_termination = true
    storage_os_disk {
        name              = "atower"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "7.8"
        version   = "latest"
    }

    os_profile {
    computer_name  = "atower"
    admin_username = "azureuser"
    admin_password = var.upassword
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

   #plan {
   # name = "7.8"
   # publisher = "RedHat"
   # product = "RHEL"
  #}

    tags = {
        environment = "${var.environment}-atower"
    }
}

# Create network interface
resource "azurerm_network_interface" "atower_nic" {
    name                      = "${var.prefix}-atower-nic"
    location                  = azurerm_resource_group.main.location
    resource_group_name       = azurerm_resource_group.main.name
    #network_security_group_id = azurerm_network_security_group.jb_sg.id

    ip_configuration {
        name                          = "primary"
        subnet_id                     = data.azurerm_subnet.cyber.id
        private_ip_address_allocation = "static"
        private_ip_address            = var.atower
    }

    tags = {
        environment = "${var.environment}-atower-nic"
    }
}
# backend VM
resource "azurerm_virtual_machine" "backendvm01" {
  name                = "backendvm01"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.backendvm01-ext-nic.id]
  vm_size               = "Standard_DS2_v2"

  storage_os_disk {
    name              = "backendvm01OsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
        publisher = "nginxinc"
        offer = "nginx-plus-v1"
        sku = "nginx-plus-centos7"
        version = "latest"
  }

  os_profile {
    computer_name  = "backendvm01"
    admin_username = "azureuser"
    admin_password = var.upassword
	  #custom_data    = data.template_file.vm_onboard_backend.rendered
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  
  plan {
    name = "nginx-plus-centos7"
    publisher = "nginxinc"
    product = "nginx-plus-v1"
  }

  tags = {
    Name        = "${var.environment}-backendvm01"
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
    host     = var.f5vm01mgmt
    }  
  }
  
}

resource "null_resource" "filecopy_do_vm01" {
   depends_on = [azurerm_virtual_machine.f5vm01]

  provisioner "file" {
    source      = "f5-declarative-onboarding-1.12.0-1.noarch.rpm"
    destination = "/var/tmp/f5-declarative-onboarding-1.12.0-1.noarch.rpm"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = var.f5vm01mgmt
    }  
  }
  
}

resource "null_resource" "filecopy_as3_vm02" {
   depends_on = [azurerm_virtual_machine.f5vm02]

  provisioner "file" {
    source      = "f5-appsvcs-3.18.0-4.noarch.rpm"
    destination = "/var/tmp/f5-appsvcs-3.18.0-4.noarch.rpm"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = var.f5vm02mgmt
    }  
  }
  
}

resource "null_resource" "filecopy_do_vm02" {
   depends_on = [azurerm_virtual_machine.f5vm02]

  provisioner "file" {
    source      = "f5-declarative-onboarding-1.11.1-1.noarch.rpm"
    destination = "/var/tmp/f5-declarative-onboarding-1.11.1-1.noarch.rpm"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = var.f5vm02mgmt
    }  
  }
  
}

resource "azurerm_virtual_machine_extension" "f5vm01-reset-httpd" {
  name = "${var.environment}-f5vm01-reset-httpd"
  depends_on =  [azurerm_virtual_machine.f5vm01,null_resource.filecopy_do_vm01,null_resource.filecopy_as3_vm01]
  #location             = var.region
  #resource_group_name  = azurerm_resource_group.main.name
  virtual_machine_id = azurerm_virtual_machine.f5vm01.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "tmsh modify sys httpd ssl-port 443; tmsh modify /sys db configsync.allowmanagement value enable; exit 0"
    }
  
SETTINGS


  tags = {
    Name        = "${var.environment}-f5vm01-reset-httpd"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

resource "azurerm_virtual_machine_extension" "f5vm02-reset-httpd" {
  name = "${var.environment}-f5vm02-run-reset-httpd"
  depends_on =  [azurerm_virtual_machine.f5vm02,null_resource.filecopy_do_vm02,null_resource.filecopy_as3_vm02]
  #location             = var.region
  #resource_group_name  = azurerm_resource_group.main.name
  virtual_machine_id = azurerm_virtual_machine.f5vm02.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "tmsh modify sys httpd ssl-port 443; tmsh modify /sys db configsync.allowmanagement value enable; exit 0"
    }
  
SETTINGS


  tags = {
    Name        = "${var.environment}-f5vm02-reset-httpd"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}


resource "null_resource" "f5vm01_do_installer" {
  depends_on =  [azurerm_virtual_machine_extension.f5vm01-reset-httpd]
  provisioner "local-exec" {
        
        command = "powershell.exe sleep 60"
  }
  provisioner "local-exec" {
        #curl command to install DO
        command = "curl https://${azurerm_network_interface.vm01-mgmt-nic.private_ip_address}/mgmt/shared/iapp/package-management-tasks -u admin:${var.upassword} -d ${var.do_data} -k"
  }
}

resource "null_resource" "f5vm02_do_installer" {
  depends_on =  [azurerm_virtual_machine_extension.f5vm02-reset-httpd]
  provisioner "local-exec" {
        
        command = "powershell.exe sleep 60"
  }
  provisioner "local-exec" {
        #curl command to install DO
        command = "curl https://${azurerm_network_interface.vm02-mgmt-nic.private_ip_address}/mgmt/shared/iapp/package-management-tasks -u admin:${var.upassword} -d ${var.do_data} -k"
  }
}



resource "null_resource" "f5vm01_as3_installer" {
  depends_on =  [null_resource.f5vm01_do_installer]
  

  provisioner "local-exec" {
        #curl command to install AS3
        command = "curl https://${azurerm_network_interface.vm01-mgmt-nic.private_ip_address}/mgmt/shared/iapp/package-management-tasks -u admin:${var.upassword} -d ${var.as3_data} -k"
  }
}

resource "null_resource" "f5vm02_as3_installer" {
  depends_on =  [null_resource.f5vm02_do_installer]
  

  provisioner "local-exec" {
        #curl command to install AS3
        command = "curl https://${azurerm_network_interface.vm02-mgmt-nic.private_ip_address}/mgmt/shared/iapp/package-management-tasks -u admin:${var.upassword} -d ${var.as3_data} -k"
  }
}

resource "null_resource" "bigiq_as3_installer" {

  provisioner "local-exec" {
        #curl command to install AS3
        command = "curl https://10.216.8.9/mgmt/shared/iapp/package-management-tasks -u admin:${var.bigiqpass} -d ${var.as3_data} -k"
  }
}


# Run REST API for configuration
resource "local_file" "vm01_do_file" {
  content  = data.template_file.vm01_do_json.rendered
  filename = "${path.module}/vm01_do_data.json"
}

resource "local_file" "vm02_do_file" {
  content  = data.template_file.vm02_do_json.rendered
  filename = "${path.module}/vm02_do_data.json"
}

resource "local_file" "vm_as3_file" {
  content  = data.template_file.as3_json.rendered
  filename = "${path.module}/vm_as3_data.json"
}

resource "null_resource" "f5vm01-run-DO" {
depends_on =  [null_resource.f5vm01_as3_installer]
provisioner "local-exec" {
        
        command = "powershell.exe sleep 30"
  }
  # Running DO REST API
  provisioner "local-exec" {
       command = "curl https://${azurerm_network_interface.vm01-mgmt-nic.private_ip_address}${var.rest_do_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_vm01_do_file} -k"
    
  }
}


resource "null_resource" "f5vm02-run-DO" {
  depends_on =  [null_resource.f5vm01-run-DO]
  # Running DO REST API
  provisioner "local-exec" {
        
        command = "powershell.exe sleep 180"
  }
  provisioner "local-exec" {
       command = "curl https://${azurerm_network_interface.vm02-mgmt-nic.private_ip_address}${var.rest_do_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_vm02_do_file} -k"
    
  }
}

 resource "null_resource" "f5vm01-run-AS3" {
  depends_on =  [null_resource.f5vm02-run-DO]
  
  provisioner "local-exec" {
    command = "curl https://${azurerm_network_interface.vm01-mgmt-nic.private_ip_address}${var.rest_as3_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_vm_as3_file} -k"

  }

 }

 resource "null_resource" "f5vm02-run-AS3" {
  depends_on =  [null_resource.f5vm01-run-AS3,null_resource.f5vm01_as3_installer]
  
  provisioner "local-exec" {
    command = "curl https://${azurerm_network_interface.vm02-mgmt-nic.private_ip_address}${var.rest_as3_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_vm_as3_file} -k"

  }

 }

 resource "null_resource" "filecopy_backendvm01" {
   depends_on = [azurerm_virtual_machine.backendvm01]

  provisioner "file" {
    source      = "conf"
    destination = "/var/tmp"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = "${azurerm_network_interface.backendvm01-ext-nic.private_ip_address}"
    }  
  }
  
}

resource "null_resource" "backendvm01-remote" {
  depends_on = [null_resource.filecopy_backendvm01]

provisioner "remote-exec" {
    inline = [
					"sudo mkdir -p /etc/nginx/api_conf.d",
					"sudo mkdir -p /etc/node-rest",
					"sudo mkdir -p /etc/nginx/ssl/keys",
			    "sudo mkdir -p /etc/nginx/ssl/certs",
					"sudo cp /var/tmp/conf/warehouse_api_simple.conf /etc/nginx/api_conf.d/",
					"sudo cp /var/tmp/conf/api_backends.conf /etc/nginx/",
					"sudo cp /var/tmp/conf/api_gateway.conf /etc/nginx/",
					"sudo cp /var/tmp/conf/api_json_errors.conf /etc/nginx/",
					"sudo cp /var/tmp/conf/nginx.conf /etc/nginx/",
					"sudo cp /var/tmp/conf/jwk.json /etc/nginx/",
					"sudo cp /var/tmp/conf/test.crt /etc/nginx/ssl/certs/",
					"sudo cp /var/tmp/conf/test.key /etc/nginx/ssl/keys/",
					"cd /etc/node-rest",
					"sudo cp /var/tmp/conf/index.js /etc/node-rest/",
					"sudo curl --silent --location https://rpm.nodesource.com/setup_12.x | sudo bash -",
					"sudo yum install -y nodejs",
					"sudo npm install express --save",
					"sudo npm install nodemon -g",
          "sudo cd ",
          "sudo npm install pm2@latest -g",
          "sudo pm2 start index.js",
          "sudo pm2 startup systemd",
          "sudo pm2 save",
          "exit"
        
    ]
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = "${azurerm_network_interface.backendvm01-ext-nic.private_ip_address}"
    }  
  }
}

resource "null_resource" "filecopy_backendvm02" {
   depends_on = [azurerm_virtual_machine.backendvm02]

  provisioner "file" {
    source      = "conf"
    destination = "/var/tmp"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = "${azurerm_network_interface.backendvm02_nic.private_ip_address}"
    }  
  }
  
}

resource "null_resource" "backendvm02-remote" {
  depends_on = [null_resource.filecopy_backendvm02]

provisioner "remote-exec" {
    inline = [
					"sudo mkdir -p /etc/nginx/api_conf.d",
					"sudo mkdir -p /etc/node-rest",
					"sudo mkdir -p /etc/nginx/ssl/keys",
			    "sudo mkdir -p /etc/nginx/ssl/certs",
					"sudo cp /var/tmp/conf/warehouse_api_simple.conf /etc/nginx/api_conf.d/",
					"sudo cp /var/tmp/conf/api_backends.conf /etc/nginx/",
					"sudo cp /var/tmp/conf/api_gateway.conf /etc/nginx/",
					"sudo cp /var/tmp/conf/api_json_errors.conf /etc/nginx/",
					"sudo cp /var/tmp/conf/nginx.conf /etc/nginx/",
					"sudo cp /var/tmp/conf/jwk.json /etc/nginx/",
					"sudo cp /var/tmp/conf/server.crt /etc/nginx/ssl/certs/",
					"sudo cp /var/tmp/conf/server.key /etc/nginx/ssl/keys/",
					"cd /etc/node-rest",
					"sudo cp /var/tmp/conf/index.js /etc/node-rest/",
					"sudo curl --silent --location https://rpm.nodesource.com/setup_12.x | sudo bash -",
					"sudo yum install -y nodejs",
					"sudo npm install express --save",
					"sudo npm install nodemon -g",
          "sudo cd ",
          "sudo npm install pm2@latest -g",
          "sudo pm2 start index.js",
          "sudo pm2 startup systemd",
          "sudo pm2 save",
          "exit"
        
    ]
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = "${azurerm_network_interface.backendvm02_nic.private_ip_address}"
    }  
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

output "f5vm01_id" {
  value = azurerm_virtual_machine.f5vm01.id
}

output "f5vm01_ext_private_ip" {
  value = azurerm_network_interface.vm01-mgmt-nic.private_ip_address
}

output "f5vm02_id" {
  value = azurerm_virtual_machine.f5vm02.id
}

output "f5vm02_ext_private_ip" {
  value = azurerm_network_interface.vm02-mgmt-nic.private_ip_address
}

output "backendvm_ext_private_ip" {
  value = azurerm_network_interface.backend01-ext-nic.private_ip_address
}