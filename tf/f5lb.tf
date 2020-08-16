
# Create the second network interface card for External
resource "azurerm_network_interface" "vm03-ext-nic" {
  name                      = "${var.prefix}-vm03-ext-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  network_security_group_id = azurerm_network_security_group.main.id
  depends_on                = [azurerm_lb_backend_address_pool.backend_pool]

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.External.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm03ext
    primary                       = true
  }

  ip_configuration {
    name                          = "secondary"
    subnet_id                     = azurerm_subnet.External.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm03ext_sec
  }

  tags = {
    Name        = "${var.environment}-vm03-ext-int"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

# Create a Public IP for the Virtual Machines
resource "azurerm_public_ip" "vm03mgmtpip" {
  name                = "${var.prefix}-vm03-mgmt-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"

  tags = {
    Name        = "${var.environment}-vm03-mgmt-public-ip"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}


# Create F5 BIGIP VMs
resource "azurerm_virtual_machine" "f5vm03" {
  name                         = "${var.prefix}-f5vm03"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  primary_network_interface_id = azurerm_network_interface.vm03-mgmt-nic.id
  network_interface_ids        = [azurerm_network_interface.vm03-mgmt-nic.id, azurerm_network_interface.vm03-ext-nic.id]
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
    name              = "${var.prefix}vm03-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
os_profile {
    computer_name  = "${var.prefix}vm03"
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
    Name        = "${var.environment}-f5vm03"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

# Run Startup Script
resource "azurerm_virtual_machine_extension" "f5vm03-run-startup-cmd" {
  name = "${var.environment}-f5vm03-run-startup-cmd"
  depends_on = [
    azurerm_virtual_machine.f5vm03,
    azurerm_virtual_machine.backendvm,
  ]
  location             = var.region
  resource_group_name  = azurerm_resource_group.main.name
  virtual_machine_name = azurerm_virtual_machine.f5vm03.name
  publisher            = "Microsoft.OSTCExtensions"
  type                 = "CustomScriptForLinux"
  type_handler_version = "1.2"

  # publisher            = "Microsoft.Azure.Extensions"
  # type                 = "CustomScript"
  # type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "bash /var/lib/waagent/CustomData"
    }
  
SETTINGS
tags = {
    Name        = "${var.environment}-f5vm03-startup-cmd"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

