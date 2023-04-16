
variable "virtual_machines" {
  type = list(object({
    name            = string
    subnet_id       = string
    availability_set_name = string
    vm_size         = string
    admin_username  = string
    admin_password  = string
  }))

  
  default = [
    {
      name                = "web-vm"
      subnet_id           = "/subscriptions/7ce19ec8-a6d2-4e78-bd7d-eddbc3806b77/resourceGroups/azure-stack/providers/Microsoft.Network/virtualNetworks/vnet01/subnets/web-subnet"
      availability_set_name = "web_availabilty_set"
      vm_size             = "Standard_A1_v2"
      admin_username      = "sysadmin"
      admin_password      = "Sysadmin@123"
    },
    {
      name                = "app-vm"
      subnet_id           = "/subscriptions/7ce19ec8-a6d2-4e78-bd7d-eddbc3806b77/resourceGroups/azure-stack/providers/Microsoft.Network/virtualNetworks/vnet01/subnets/app-subnet"
      availability_set_name = "app_availabilty_set"
      vm_size             = "Standard_A1_v2"
      admin_username      = "sysadmin"
      admin_password      = "Sysadmin@123"
    }
  ]
}

locals {
  availability_sets = distinct([for vm in var.virtual_machines : vm.availability_set_name])
}

resource "azurerm_availability_set" "availability_set" {
  for_each = { for set in local.availability_sets : set => set }
  name                = each.key
  location            = var.location
  resource_group_name = var.resource_group
}

resource "azurerm_network_interface" "network_interface" {
  for_each = { for vm in var.virtual_machines : vm.name => vm }
  name                = "${each.value.name}-network"
  resource_group_name = var.resource_group
  location            = var.location

  ip_configuration {
    name                          = "${each.value.name}-webserver"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "virtual_machine" {
  for_each = { for vm in var.virtual_machines : vm.name => vm }
  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group
  network_interface_ids = [
    azurerm_network_interface.network_interface[each.key].id
  ]
  availability_set_id = azurerm_availability_set.availability_set[each.value.availability_set_name].id
  vm_size             = each.value.vm_size
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${each.value.name}-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name   = each.value.name
    admin_username  = each.value.admin_username
    admin_password  = each.value.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}
