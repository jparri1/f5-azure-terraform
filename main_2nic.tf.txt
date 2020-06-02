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

data "azurerm_subnet" "external" {
  name                 = "external"
  virtual_network_name = "f5lab_network"
  resource_group_name  = "Networking-DevTest-RG"
}


locals {
  depends_on = [data.azurerm_subnet.cyber]
  ext_gw     = cidrhost(data.azurerm_subnet.cyber.address_prefix, 1)
}

resource "azurerm_lb" "lb" {
  name                = "${var.prefix}lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
	  private_ip_address_allocation = "Static"
    private_ip_address            = var.azlbip
    subnet_id            = data.azurerm_subnet.external.id
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

resource "azurerm_network_interface" "vm01-ext-nic" {
  name                      = "${var.prefix}-vm01-ext-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.external.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm01ext
    primary                       = true
  }

  ip_configuration {
    name                          = "secondary"
    subnet_id                     = data.azurerm_subnet.external.id
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

resource "azurerm_network_interface" "vm02-mgmt-nic" {
  name                      = "${var.prefix}-vm02-mgmt-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.cyber.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm02mgmt
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

resource "azurerm_network_interface" "vm02-ext-nic" {
  name                      = "${var.prefix}-vm02-ext-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.external.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm02ext
    primary                       = true
  }

  ip_configuration {
    name                          = "secondary"
    subnet_id                     = data.azurerm_subnet.external.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm02ext_sec
  }

  tags = {
    Name        = "${var.environment}-vm02-ext-int"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

resource "azurerm_network_interface" "backend01-ext-nic" {
  name                      = "${var.prefix}-backend01-ext-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.cyber.id
    private_ip_address_allocation = "static"
    private_ip_address            = var.backend01ext
    primary                       = true
  }

  tags = {
    Name        = "${var.environment}-backend01-ext-int"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = "app1"
  }
}

# Associate the Network Interface to the BackendPool
resource "azurerm_network_interface_backend_address_pool_association" "bpool_assc_vm01" {
  depends_on = [
    azurerm_lb_backend_address_pool.backend_pool,
    azurerm_network_interface.vm01-ext-nic
  ]
  network_interface_id    = azurerm_network_interface.vm01-ext-nic.id
  ip_configuration_name   = "secondary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "bpool_assc_vm02" {
  depends_on = [
    azurerm_network_interface_backend_address_pool_association.bpool_assc_vm01,
    azurerm_network_interface.vm02-ext-nic
  ]
  network_interface_id    = azurerm_network_interface.vm02-ext-nic.id
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
    local_selfip   = var.f5vm01ext
    remote_host    = var.host2_name
    remote_selfip  = var.f5vm02ext
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
    local_selfip   = var.f5vm02ext
    remote_host    = var.host1_name
    remote_selfip  = var.f5vm01ext
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
  network_interface_ids        = [azurerm_network_interface.vm01-mgmt-nic.id, azurerm_network_interface.vm01-ext-nic.id]
  vm_size                      = var.instance_type
  #availability_set_id          = azurerm_availability_set.avset.id

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
  network_interface_ids        = [azurerm_network_interface.vm02-mgmt-nic.id, azurerm_network_interface.vm02-ext-nic.id]
  vm_size                      = var.instance_type
  #availability_set_id          = azurerm_availability_set.avset.id

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

# backend VM
resource "azurerm_virtual_machine" "backendvm" {
  name                = "backendvm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.backend01-ext-nic.id]
  vm_size               = "Standard_DS2_v2"

  storage_os_disk {
    name              = "backendOsDisk"
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
    computer_name  = "backend01"
    admin_username = "azureuser"
    admin_password = var.upassword
	  #custom_data    = data.template_file.vm_onboard_backend.rendered
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
    Name        = "${var.environment}-backend01"
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
        "commandToExecute": "tmsh modify sys httpd ssl-port 443; exit 0"
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
        "commandToExecute": "tmsh modify sys httpd ssl-port 443; exit 0"
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

 resource "null_resource" "filecopy_backend" {
   depends_on = [azurerm_virtual_machine.backendvm]

   provisioner "local-exec" {
        
        command = "powershell.exe sleep 180"
  }

  provisioner "file" {
    source      = "conf"
    destination = "/var/tmp"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = "${azurerm_network_interface.backend01-ext-nic.private_ip_address}"
    }  
  }
  
}

resource "null_resource" "backendvm-remote" {
  depends_on = [null_resource.filecopy_backend]

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
					"curl -sL https://deb.nodesource.com/setup_13.x | sudo -E bash -",
          "sudo rm /var/lib/dpkg/lock*",
					"sudo apt-get install -y nodejs",
					"sudo npm install express --save",
					"sudo npm install nodemon -g",
          "sudo systemctl restart nginx",
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
    host     = "${azurerm_network_interface.backend01-ext-nic.private_ip_address}"
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
