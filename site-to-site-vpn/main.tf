##############################################################################
# Site-to-Site (VNet-to-VNet) VPN lab
# Converted from Azure Bicep -> Terraform (azurerm provider)
#
# Notes on the conversion:
# - Bicep templates exported from an existing deployment don't include a
#   resource group or VM admin credentials (they're "existing" values in the
#   real subscription). This file adds both as variables so it's actually
#   deployable. Update names/values to fit your lab.
# - Static public IPs: the original file pinned specific IP addresses
#   (e.g. 128.203.105.60). Azure allocates Standard SKU static IPs itself;
#   you cannot request a specific address, so those literal IPs are dropped.
# - Bastion "Developer" SKU (VNet-B) has no dnsName/ipConfigurations exposed
#   the same way in azurerm; it's modeled as azurerm_bastion_host with the
#   dev SKU where supported by your provider version.
##############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

##############################################################################
# Variables
##############################################################################

variable "resource_group_name" {
  description = "Existing resource group that will hold all lab resources (sandbox subscriptions provide this pre-made)."
  type        = string
  default     = "(Drop your resource group name here)"
}

variable "location_a" {
  description = "Region for VNet-A (and its dependent resources)."
  type        = string
  default     = "eastus"
}

variable "location_b" {
  description = "Region for VNet-B (and its dependent resources)."
  type        = string
  default     = "eastus2"
}

variable "admin_username" {
  description = "Local admin username for all lab VMs."
  type        = string
  default     = "CloudAdmin"
}

variable "admin_password" {
  description = "Local admin password for all lab VMs. Not present in the source Bicep (it was an existing deployment) - supply via TF_VAR_admin_password or a secrets store."
  type        = string
  sensitive   = true
}

variable "vpn_shared_key" {
  description = "Pre-shared key (PSK) used by both VNet-to-VNet connections. Not present in the source Bicep - supply via TF_VAR_vpn_shared_key or a secrets store."
  type        = string
  sensitive   = true
}

##############################################################################
# Resource Group
# Sandbox subscriptions pre-provision a single resource group and don't
# allow creating new ones, so this is looked up rather than created.
##############################################################################

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

##############################################################################
# Virtual Networks & Subnets
##############################################################################

resource "azurerm_virtual_network" "vnet_a" {
  name                = "VNet-A"
  location            = var.location_a
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "vnet_a_default" {
  name                 = "Default-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet_a.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_subnet" "vnet_a_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet_a.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "vnet_a_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet_a.name
  address_prefixes     = ["10.1.2.0/26"]
}

resource "azurerm_virtual_network" "vnet_b" {
  name                = "VNet-B"
  location            = var.location_b
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = ["10.2.0.0/16"]
}

resource "azurerm_subnet" "vnet_b_default" {
  name                 = "Default-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet_b.name
  address_prefixes     = ["10.2.0.0/24"]
}

resource "azurerm_subnet" "vnet_b_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet_b.name
  address_prefixes     = ["10.2.1.0/24"]
}

# VNet-B has a "Developer" Bastion SKU in the source file, which does not
# use AzureBastionSubnet/public IP - it attaches directly to the VNet.
# No dedicated subnet is created for it here to mirror that.

##############################################################################
# Public IP Addresses
##############################################################################

resource "azurerm_public_ip" "vnet_a_bastion_ip" {
  name                = "VNet-A-IPv4"
  location            = var.location_a
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_public_ip" "vnet_a_vpn_ip" {
  name                = "VNet-A-VPN-PublicIP"
  location            = var.location_a
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_public_ip" "vnet_b_vpn_ip" {
  name                = "VNet-B-VPN-PublicIP"
  location            = var.location_b
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

##############################################################################
# Network Interfaces
##############################################################################

resource "azurerm_network_interface" "vnet_a_vm1_nic" {
  name                          = "vnet-a-vm1413_z1"
  location                      = var.location_a
  resource_group_name           = data.azurerm_resource_group.this.name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.vnet_a_default.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

resource "azurerm_network_interface" "vnet_a_vm2_nic" {
  name                          = "vnet-a-vm2623_z1"
  location                      = var.location_a
  resource_group_name           = data.azurerm_resource_group.this.name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.vnet_a_default.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

resource "azurerm_network_interface" "vnet_b_vm1_nic" {
  name                          = "vnet-b-vm1672_z1"
  location                      = var.location_b
  resource_group_name           = data.azurerm_resource_group.this.name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.vnet_b_default.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

resource "azurerm_network_interface" "vnet_b_vm2_nic" {
  name                          = "vnet-b-vm2965_z1"
  location                      = var.location_b
  resource_group_name           = data.azurerm_resource_group.this.name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.vnet_b_default.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

##############################################################################
# Virtual Machines (Windows Server 2025 Datacenter - Azure Edition)
##############################################################################

resource "azurerm_windows_virtual_machine" "vnet_a_vm1" {
  name                = "VNet-A-VM1"
  location            = var.location_a
  resource_group_name = data.azurerm_resource_group.this.name
  zone                = "1"
  size                = "Standard_DS1_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.vnet_a_vm1_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb          = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }

  patch_mode                  = "AutomaticByPlatform"
  patch_assessment_mode       = "ImageDefault"
  hotpatching_enabled         = false
  provision_vm_agent          = true
  enable_automatic_updates    = true

  boot_diagnostics {
    storage_account_uri = null
  }
}

resource "azurerm_windows_virtual_machine" "vnet_a_vm2" {
  name                = "VNet-A-VM2"
  location            = var.location_a
  resource_group_name = data.azurerm_resource_group.this.name
  zone                = "1"
  size                = "Standard_DS1_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.vnet_a_vm2_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb          = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }

  patch_mode                  = "AutomaticByPlatform"
  patch_assessment_mode       = "ImageDefault"
  hotpatching_enabled         = false
  provision_vm_agent          = true
  enable_automatic_updates    = true

  boot_diagnostics {
    storage_account_uri = null
  }
}

resource "azurerm_windows_virtual_machine" "vnet_b_vm1" {
  name                = "VNet-B-VM1"
  location            = var.location_b
  resource_group_name = data.azurerm_resource_group.this.name
  zone                = "1"
  size                = "Standard_DS1_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.vnet_b_vm1_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb          = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }

  patch_mode                  = "AutomaticByPlatform"
  patch_assessment_mode       = "ImageDefault"
  hotpatching_enabled         = false
  provision_vm_agent          = true
  enable_automatic_updates    = true

  boot_diagnostics {
    storage_account_uri = null
  }
}

resource "azurerm_windows_virtual_machine" "vnet_b_vm2" {
  name                = "VNet-B-VM2"
  location            = var.location_b
  resource_group_name = data.azurerm_resource_group.this.name
  zone                = "1"
  size                = "Standard_DS1_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.vnet_b_vm2_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb          = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }

  patch_mode                  = "AutomaticByPlatform"
  patch_assessment_mode       = "ImageDefault"
  hotpatching_enabled         = false
  provision_vm_agent          = true
  enable_automatic_updates    = true

  boot_diagnostics {
    storage_account_uri = null
  }
}

##############################################################################
# Azure Bastion
##############################################################################

resource "azurerm_bastion_host" "vnet_a_bastion" {
  name                = "VNet-A-bastion"
  location            = var.location_a
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "Standard"

  ip_configuration {
    name                 = "IpConf"
    subnet_id            = azurerm_subnet.vnet_a_bastion.id
    public_ip_address_id = azurerm_public_ip.vnet_a_bastion_ip.id
  }
}

# VNet-B uses the "Developer" Bastion SKU in the source template. The
# Developer SKU does not use AzureBastionSubnet or a dedicated public IP -
# it's associated directly with the VNet.
resource "azurerm_bastion_host" "vnet_b_bastion" {
  name                = "VNet-B-bastion"
  location            = var.location_b
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "Developer"

  virtual_network_id = azurerm_virtual_network.vnet_b.id
}

##############################################################################
# VPN Gateways
##############################################################################

resource "azurerm_virtual_network_gateway" "vnet_a_gateway" {
  name                = "VNet-A-gateway"
  location            = var.location_a
  resource_group_name = data.azurerm_resource_group.this.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = "VpnGw2AZ"
  generation = "Generation2"

  active_active = false
  enable_bgp    = true

  ip_configuration {
    name                          = "default"
    public_ip_address_id          = azurerm_public_ip.vnet_a_vpn_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vnet_a_gateway.id
  }

  bgp_settings {
    asn         = 65515
    peer_weight = 0

    peering_addresses {
      ip_configuration_name = "default"
    }
  }
}

resource "azurerm_virtual_network_gateway" "vnet_b_gateway" {
  name                = "VNet-B-gateway"
  location            = var.location_b
  resource_group_name = data.azurerm_resource_group.this.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = "VpnGw2AZ"
  generation = "Generation2"

  active_active = false
  enable_bgp    = true

  ip_configuration {
    name                          = "default"
    public_ip_address_id          = azurerm_public_ip.vnet_b_vpn_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vnet_b_gateway.id
  }

  bgp_settings {
    asn         = 65515
    peer_weight = 0

    peering_addresses {
      ip_configuration_name = "default"
    }
  }
}

##############################################################################
# VNet-to-VNet Connections
##############################################################################

resource "azurerm_virtual_network_gateway_connection" "a_to_b" {
  name                = "VNet-A-to-VNet-B-VPN"
  location            = var.location_a
  resource_group_name = data.azurerm_resource_group.this.name

  type                       = "Vnet2Vnet"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vnet_a_gateway.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.vnet_b_gateway.id

  shared_key   = var.vpn_shared_key
  enable_bgp   = false
  dpd_timeout_seconds = 45
}

resource "azurerm_virtual_network_gateway_connection" "b_to_a" {
  name                = "VNet-B-to-VNet-A-VPN"
  location            = var.location_b
  resource_group_name = data.azurerm_resource_group.this.name

  type                       = "Vnet2Vnet"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vnet_b_gateway.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.vnet_a_gateway.id

  shared_key   = var.vpn_shared_key
  enable_bgp   = false
  dpd_timeout_seconds = 45
}

##############################################################################
# Outputs
##############################################################################

output "vnet_a_gateway_public_ip" {
  value = azurerm_public_ip.vnet_a_vpn_ip.ip_address
}

output "vnet_b_gateway_public_ip" {
  value = azurerm_public_ip.vnet_b_vpn_ip.ip_address
}

output "vnet_a_bastion_fqdn" {
  value = azurerm_bastion_host.vnet_a_bastion.dns_name
}
