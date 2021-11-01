#############################################################################
# TERRAFORM CONFIG
#############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "orTerraform"
    storage_account_name = "orterraformstate"
    container_name       = "prod-state"
    key                  = "terraform.tfstate"
  }
}

#############################################################################
# VARIABLES
#############################################################################

variable "resource_group_name" {
  type = string
}
variable "location" {
  type = string
}

variable "vnetName" {
  type = string
}

variable "vnet_cidr_range" {
  type = string
}
variable "subnet_prefixes" {
  type = list(string)
}

variable "subnet_names" {
  type = list(string)
}
variable "numberOfInstances" {
  type = number
}


#############################################################################
# PROVIDERS
#############################################################################

provider "azurerm" {
  features {}
}

#############################################################################
# RESOURCES
#############################################################################

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

module "orVnet-main" {
  source              = "Azure/vnet/azurerm"
  version             = "~> 2.0"
  resource_group_name = azurerm_resource_group.rg.name
  vnet_name           = var.vnetName
  address_space       = [var.vnet_cidr_range]
  subnet_prefixes     = var.subnet_prefixes
  subnet_names        = var.subnet_names
  nsg_ids             = {}

}

resource "azurerm_network_interface" "networkInterface" {
  count               = var.numberOfInstances
  name                = "nic-${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = element(module.orVnet-main.vnet_subnets, 0)
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_availability_set" "avb" {
  name                = "availabilitySet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_virtual_machine" "main" {
  count                 = var.numberOfInstances
  name                  = "${terraform.workspace}-Vm-${count.index}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.networkInterface[count.index].id]
  vm_size               = "Standard_DS1_v2"
  availability_set_id   = azurerm_availability_set.avb.id

  identity {
    type = "SystemAssigned"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${terraform.workspace}-myosdisk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = data.azurerm_key_vault_secret.main.value
      path     = "/home/testadmin/.ssh/authorized_keys"
    }
  }
}

data "azurerm_virtual_network" "bastion1" {
  name                = "bastion1"
  resource_group_name = "bastion1"
}

# resource "azurerm_virtual_network_peering" "example-1" {
#   name                      = "orToBastionTF"
#   resource_group_name       = azurerm_resource_group.bastion1.name
#   virtual_network_name      = azurerm_virtual_network.bastion1.name
#   remote_virtual_network_id = module.orVnet-main.vnet_name
# }

resource "azurerm_public_ip" "vm" {
  name                = "vm-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "vm" {
  name                = "TF-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"


  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vm.id
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.vm.id
  name                = "BackEndAddressPool"
}

resource "azurerm_network_interface_backend_address_pool_association" "example" {
  count                   = var.numberOfInstances
  network_interface_id    = azurerm_network_interface.networkInterface[count.index].id
  ip_configuration_name   = "testconfiguration1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bpepool.id
}

resource "azurerm_lb_probe" "vm" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.vm.id
  name                = "probe"
  port                = "80"
}

resource "azurerm_lb_rule" "lbnatrule" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.vm.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool.id
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.vm.id
}

resource "azurerm_key_vault" "kv" {
  name                = "orKeyVault20"
  location            = "eastus"
  resource_group_name = "orTerraform"
  tenant_id           = "812aea3a-56f9-4dcb-81f3-83e61357076e"
  sku_name            = "standard"
}

# Set access policies to the vm
resource "azurerm_key_vault_access_policy" "accessPolicies" {
  count        = var.numberOfInstances
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = "812aea3a-56f9-4dcb-81f3-83e61357076e"
  object_id    = azurerm_virtual_machine.main[count.index].identity.0.principal_id

  secret_permissions = [
    "Get",
  ]
}

#resource "azurerm_key_vault_secret" "example" {
  #name         = "ssh-key"
 # value        = file("C:\\Users\\orsho\\.ssh\\id_rsa")
  #key_vault_id = azurerm_key_vault.kv.id
#}

data "azurerm_key_vault_secret" "main" {
  name         = "ssh-public-key"
  key_vault_id = data.azurerm_key_vault.kv.id
}

#data "azurerm_key_vault_secret" "kvsecret" {
 # name         = "ssh-key" // Name of secret
  #key_vault_id = azurerm_key_vault.kv.id
#}

# resource "azurerm_virtual_machine_extension" "test" {
#   count                = var.numberOfInstances
#   name                 = "testadmin"
#   virtual_machine_id   = azurerm_virtual_machine.main[count.index].id
#   publisher            = "Microsoft.Azure.Extensions"
#   type                 = "CustomScript"
#   type_handler_version = "2.1"

#   protected_settings = <<PROTECTED_SETTINGS
# {
#     "script": "${base64encode(file("C:\\Users\\orsho\\Documents\\Course\\Terraform\\or-Terraform-task\\script.sh"))}"
# }
# PROTECTED_SETTINGS

# }

resource "azurerm_public_ip" "subnetIP" {
  name                = "MyIp"
  resource_group_name = "bastion1"
  location            = var.location
  allocation_method   = "Static"

}

# resource "azurerm_bastion_host" "bastion" {
#   name                = "bastion"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.rg.name

#   ip_configuration {
#     name                 = "configuration"
#     subnet_id            = "/subscriptions/0df0b217-e303-4931-bcbf-af4fe070d1ac/resourceGroups/bastion1/providers/Microsoft.Network/routeTables/_e41f87a2_AZBST_RT_2924c04e-b335-453e-8aa6-2604ddba5d42"
#     public_ip_address_id = "/subscriptions/0df0b217-e303-4931-bcbf-af4fe070d1ac/resourceGroups/bastion1/providers/Microsoft.Network/publicIPAddresses/MyIp"
#   }
# }

resource "null_resource" "example_provisioner" {
  provisioner "remote-exec" {
    inline = [
      "echo ${data.azurerm_key_vault_secret.kvsecret.value} >> /home/testadmin/.ssh/id_rsa"
    ]

    connection {
      type = "ssh"
      user = "testadmin"
      #host     = azurerm_network_interface.networkInterface[count.index].private_ip_address
      host = "23.0.0.5"
      bastion_host = "13.90.255.58"
      #bastion_host = azurerm_public_ip.subnetIP.ip_address
      private_key = file("C:\\Users\\orsho\\.ssh\\id_rsa")
    }
  }
}




