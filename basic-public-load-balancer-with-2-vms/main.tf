##############################################################################
# Azure Lab Environment - Load-Balanced Windows VMs with Public RDP
#
# Deploys two Windows Server 2025 VMs behind a Standard Load Balancer, with
# a public IP and NSG rule exposing RDP (3389) to the internet.
#
# WARNING: This configuration intentionally opens RDP to 0.0.0.0/0.
# It is intended for short-lived, disposable lab/sandbox environments only.
# Do not reuse this NSG rule in any environment that holds real data.
# By: Kaleb Mohr
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
  skip_provider_registration = true
}

##############################################################################
# Variables
# Note: Update your admin username and resource group names to fit your Azure lab.
##############################################################################

variable "resource_group_name" {
  description = "Existing resource group that will hold all lab resources."
  type        = string
  default     = "update-this-resource-group-name-to-your-target-rg"
}

variable "region_location" {
  description = "Azure region for all lab resources."
  type        = string
  default     = "eastus"
}

variable "admin_username" {
  description = "Local admin username for all lab VMs."
  type        = string
  default     = "update-this-admin-username-to-your-preference"
}

variable "admin_password" {
  description = "Local admin password for all lab VMs. Passed at runtime, never hardcoded."
  type        = string
  sensitive   = true
}

##############################################################################
# Resource Group
#
# Sandbox subscriptions pre-provision a single resource group and don't
# allow creating new ones, so it's looked up here rather than created.
##############################################################################

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

##############################################################################
# Networking - VNet, Subnet, NSG
##############################################################################

resource "azurerm_virtual_network" "lab_eus_vnet" {
  name                = "lab-eus-vnet"
  location            = var.region_location
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "lab_eus_vnet_subnet" {
  name                 = "lab-resource-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.lab_eus_vnet.name
  address_prefixes     = ["10.1.0.0/24"]
}

# Allows inbound RDP (3389) from any source on the internet.
# LAB ONLY - see warning at the top of this file.
resource "azurerm_network_security_group" "lab_eus_nsg" {
  name                = "lab-eus-nsg"
  location            = var.region_location
  resource_group_name = data.azurerm_resource_group.this.name

  security_rule {
    name                       = "Allow-RDP-Inbound-Internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "lab_eus_subnet_nsg" {
  subnet_id                 = azurerm_subnet.lab_eus_vnet_subnet.id
  network_security_group_id = azurerm_network_security_group.lab_eus_nsg.id
}

##############################################################################
# Public IP (attached to the load balancer's frontend)
##############################################################################

resource "azurerm_public_ip" "lab_eus_lb_pip" {
  name                = "lab-eus-lb-pip"
  location            = var.region_location
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

##############################################################################
# Network Interfaces
##############################################################################

resource "azurerm_network_interface" "lab_eus_vm01_nic" {
  name                            = "lab-eus-vm01-nic"
  location                        = var.region_location
  resource_group_name             = data.azurerm_resource_group.this.name
  accelerated_networking_enabled  = false

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.lab_eus_vnet_subnet.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

resource "azurerm_network_interface" "lab_eus_vm02_nic" {
  name                            = "lab-eus-vm02-nic"
  location                        = var.region_location
  resource_group_name             = data.azurerm_resource_group.this.name
  accelerated_networking_enabled  = false

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.lab_eus_vnet_subnet.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

##############################################################################
# Virtual Machines - Windows Server 2025 Datacenter (Azure Edition)
#
# Standard_DS2_v2 is required (not DS1_v2) because accelerated networking
# needs 2+ vCPUs.
##############################################################################

resource "azurerm_windows_virtual_machine" "lab_eus_vm01" {
  name                = "LAB-EUS-VM01"
  location            = var.region_location
  resource_group_name = data.azurerm_resource_group.this.name
  zone                = "1"
  size                = "Standard_DS1_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.lab_eus_vm01_nic.id,
  ]

  os_disk {
    caching               = "ReadWrite"
    storage_account_type  = "Premium_LRS"
    disk_size_gb          = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }

  patch_mode                = "AutomaticByPlatform"
  patch_assessment_mode     = "ImageDefault"
  hotpatching_enabled       = false
  provision_vm_agent        = true
  enable_automatic_updates  = true

  boot_diagnostics {
    storage_account_uri = null
  }
}

resource "azurerm_windows_virtual_machine" "lab_eus_vm02" {
  name                = "LAB-EUS-VM02"
  location            = var.region_location
  resource_group_name = data.azurerm_resource_group.this.name
  zone                = "1"
  size                = "Standard_DS1_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.lab_eus_vm02_nic.id,
  ]

  os_disk {
    caching               = "ReadWrite"
    storage_account_type  = "Premium_LRS"
    disk_size_gb          = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }

  patch_mode                = "AutomaticByPlatform"
  patch_assessment_mode     = "ImageDefault"
  hotpatching_enabled       = false
  provision_vm_agent        = true
  enable_automatic_updates  = true

  boot_diagnostics {
    storage_account_uri = null
  }
}

##############################################################################
# Load Balancer
##############################################################################

resource "azurerm_lb" "lab_eus_lb01" {
  name                = "lab-eus-lb01"
  location            = var.region_location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "lab-eus-lb01-public-ip"
    public_ip_address_id = azurerm_public_ip.lab_eus_lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "lab_eus_lb01_pool" {
  loadbalancer_id = azurerm_lb.lab_eus_lb01.id
  name            = "lab-eus-lb01-pool"
}

# ip_configuration_name must match the name defined on the NIC ("ipconfig1").
resource "azurerm_network_interface_backend_address_pool_association" "vm01_pool_association" {
  network_interface_id    = azurerm_network_interface.lab_eus_vm01_nic.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab_eus_lb01_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "vm02_pool_association" {
  network_interface_id    = azurerm_network_interface.lab_eus_vm02_nic.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab_eus_lb01_pool.id
}

resource "azurerm_lb_probe" "lab_eus_lb01_probe" {
  loadbalancer_id = azurerm_lb.lab_eus_lb01.id
  name            = "lab-eus-lb01-probe"
  protocol        = "Tcp"
  port            = 3389
}

# Distributes inbound RDP (3389) from the LB's public frontend across both
# VMs in the backend pool.
resource "azurerm_lb_rule" "rdp_lb_distribution" {
  loadbalancer_id                = azurerm_lb.lab_eus_lb01.id
  name                            = "rdp-lb-rule"
  protocol                        = "Tcp"
  frontend_port                   = 3389
  backend_port                    = 3389
  disable_outbound_snat           = true
  frontend_ip_configuration_name  = "lab-eus-lb01-public-ip"
  probe_id                        = azurerm_lb_probe.lab_eus_lb01_probe.id
  backend_address_pool_ids        = [azurerm_lb_backend_address_pool.lab_eus_lb01_pool.id]
}

resource "azurerm_lb_outbound_rule" "snat_outbound" {
  name                     = "outbound-snat-rule"
  loadbalancer_id          = azurerm_lb.lab_eus_lb01.id
  protocol                 = "Tcp"
  backend_address_pool_id  = azurerm_lb_backend_address_pool.lab_eus_lb01_pool.id

  frontend_ip_configuration {
    name = "lab-eus-lb01-public-ip"
  }
}

