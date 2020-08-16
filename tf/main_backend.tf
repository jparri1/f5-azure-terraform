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

# Create the second Subnet within the Virtual Network
resource "azurerm_subnet" "External" {
  name                 = "External"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefix       = var.subnets["subnet2"]
}

resource "azurerm_public_ip" "backendpip" {
  name                = "${var.prefix}-backendpip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"

  tags = {
    Name        = "${var.environment}-backendpip"
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
    name                       = "allow_RDP"
    description                = "Allow RDP access"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
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

resource "azurerm_network_interface" "backend01-ext-nic" {
  name                      = "${var.prefix}-backend01-ext-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.External.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.backend01ext
    primary                       = true
    public_ip_address_id          = azurerm_public_ip.backendpip.id
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

resource "azurerm_network_interface_security_group_association" "backend" {
    network_interface_id      = azurerm_network_interface.backend01-ext-nic.id
    network_security_group_id = azurerm_network_security_group.main.id
}

# Setup Onboarding scripts
  data "template_file" "vm_onboard" {
  template = file("${path.module}/onboard_backend.tpl")

  vars = {
    onboard_log    = var.onboard_log
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
        sku = "nginx-plus-centos7"
        version = "latest"
  }

  os_profile {
    computer_name  = "backend01"
    admin_username = "azureuser"
    admin_password = var.upassword
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  
  plan {
    name          = "nginx-plus-centos7"
    publisher     = "nginxinc" 
    product       = "nginx-plus-v1"
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

resource "null_resource" "filecopy" {
   depends_on = [azurerm_virtual_machine.backendvm]

  provisioner "file" {
    source      = "conf"
    destination = "/var/tmp"
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = "${azurerm_public_ip.backendpip.ip_address}"
    }  
  }
  provisioner "remote-exec" {
    inline = [
				"sudo setsebool httpd_can_network_connect on",
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
				"sleep 10",
				"sudo curl -sL https://rpm.nodesource.com/setup_10.x | sudo bash -",
				"sudo yum install -y nodejs",
                "sleep 10",
				"sudo npm install express --save",
				"sudo npm install nodemon -g",
                "sudo systemctl restart nginx",
        
    ]
    
    connection {
    type     = "ssh"
    user     = "${var.uname}"
    password = "${var.upassword}"
    host     = "${azurerm_public_ip.backendpip.ip_address}"
    }  
  }
}



 

## OUTPUTS ###

output "sg_id" {
  value = azurerm_network_security_group.main.id
}

output "sg_name" {
  value = azurerm_network_security_group.main.name
}
