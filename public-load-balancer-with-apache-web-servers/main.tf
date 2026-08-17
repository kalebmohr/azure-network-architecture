##############################################################################
# Azure Multi-VM Web Load Balancer — Lab Deployment
#
# This Terraform configuration deploys a demo web-tier architecture in
# Azure consisting of:
#   - A dedicated VNet and subnet for web servers
#   - Three Ubuntu Linux VMs, each provisioned with Apache via a
#     CustomScript extension
#   - A Standard SKU public Load Balancer distributing inbound HTTP (80)
#     traffic across all three VMs via a backend pool
#   - An NSG permitting inbound HTTP from the internet, and an explicit
#     outbound SNAT rule for VM egress
#
# Purpose: This is a LAB / PORTFOLIO DEMO environment intended to
# illustrate Azure networking, load balancing, and IaC patterns with
# Terraform. It is NOT hardened, NOT reviewed for production security
# posture, and NOT intended for production use.
#
#   ⚠ DO NOT DEPLOY THIS TO A PRODUCTION ENVIRONMENT AS-IS. ⚠
#
# Notably out of scope for production readiness: NSG rules are
# intentionally permissive (HTTP open to "Internet"), there's no HA
# validation beyond LB probes, no monitoring/alerting, no backup/DR,
# and admin credentials are passed via variable rather than a secrets
# vault (e.g. Azure Key Vault).
#
# Architecture and code designed by Kaleb Mohr.
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
  default     = "put-your-rg-here"
}

variable "region_location" {
  description = "Azure region for all lab resources."
  type        = string
  default     = "eastus"
}

variable "admin_username" {
  description = "Local admin username for all lab VMs."
  type        = string
  default     = "put-your-username-here"
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

resource "azurerm_virtual_network" "lab_eus_web_services_vnet" {
  name                = "lab-eus-web-services-vnet"
  location            = var.region_location
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "lab_eus_web_server_subnet" {
  name                 = "lab-eus-web-server-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.lab_eus_web_services_vnet.name
  address_prefixes     = ["10.1.0.0/28"]
}

# Allows inbound HTTP (80) from any source on the internet.
resource "azurerm_network_security_group" "lab_eus_web_nsg" {
  name                = "lab-eus-web-nsg"
  location            = var.region_location
  resource_group_name = data.azurerm_resource_group.this.name

  security_rule {
    name                       = "Allow-HTTP-Inbound-Internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "lab_eus_web_server_subnet_nsg" {
  subnet_id                 = azurerm_subnet.lab_eus_web_server_subnet.id
  network_security_group_id = azurerm_network_security_group.lab_eus_web_nsg.id
}

##############################################################################
# Public IP (attached to the load balancer's frontend)
##############################################################################

resource "azurerm_public_ip" "lab_eus_web_lb_public_ip" {
  name                = "lab-eus-web-lb-public-ip"
  location            = var.region_location
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

##############################################################################
# Network Interfaces
##############################################################################

resource "azurerm_network_interface" "lab_eus_web01_nic" {
  name                            = "lab-eus-web01-nic"
  location                        = var.region_location
  resource_group_name             = data.azurerm_resource_group.this.name
  accelerated_networking_enabled  = false

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.lab_eus_web_server_subnet.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

resource "azurerm_network_interface" "lab_eus_web02_nic" {
  name                            = "lab-eus-web02-nic"
  location                        = var.region_location
  resource_group_name             = data.azurerm_resource_group.this.name
  accelerated_networking_enabled  = false

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.lab_eus_web_server_subnet.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

resource "azurerm_network_interface" "lab_eus_web03_nic" {
  name                            = "lab-eus-web03-nic"
  location                        = var.region_location
  resource_group_name             = data.azurerm_resource_group.this.name
  accelerated_networking_enabled  = false

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.lab_eus_web_server_subnet.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

##############################################################################
# Virtual Machines & Extensions
##############################################################################

resource "azurerm_linux_virtual_machine" "lab_eus_web01" {
  name                            = "LAB-EUS-WEB01"
  resource_group_name             = data.azurerm_resource_group.this.name
  location                        = var.region_location
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false # Enables Password Auth (No SSH Keys required)

  network_interface_ids = [
    azurerm_network_interface.lab_eus_web01_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "web01_install_apache" {
  name                 = "install-apache"
  virtual_machine_id   = azurerm_linux_virtual_machine.lab_eus_web01.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = <<SETTINGS
    {
      "commandToExecute": "export DEBIAN_FRONTEND=noninteractive && (apt-get update -y || true) && apt-get install -y apache2 && systemctl enable --now apache2 && echo '<h1>Hello from LAB-EUS-WEB01</h1>' > /var/www/html/index.html"
    }
  SETTINGS
}

resource "azurerm_linux_virtual_machine" "lab_eus_web02" {
  name                            = "LAB-EUS-WEB02"
  resource_group_name             = data.azurerm_resource_group.this.name
  location                        = var.region_location
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.lab_eus_web02_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "web02_install_apache" {
  name                 = "install-apache"
  virtual_machine_id   = azurerm_linux_virtual_machine.lab_eus_web02.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = <<SETTINGS
    {
      "commandToExecute": "export DEBIAN_FRONTEND=noninteractive && (apt-get update -y || true) && apt-get install -y apache2 && systemctl enable --now apache2 && echo '<h1>Hello from LAB-EUS-WEB01</h1>' > /var/www/html/index.html"
    }
  SETTINGS
}

resource "azurerm_linux_virtual_machine" "lab_eus_web03" {
  name                            = "LAB-EUS-WEB03"
  resource_group_name             = data.azurerm_resource_group.this.name
  location                        = var.region_location
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.lab_eus_web03_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "web03_install_apache" {
  name                 = "install-apache"
  virtual_machine_id   = azurerm_linux_virtual_machine.lab_eus_web03.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = <<SETTINGS
    {
      "commandToExecute": "export DEBIAN_FRONTEND=noninteractive && (apt-get update -y || true) && apt-get install -y apache2 && systemctl enable --now apache2 && echo '<h1>Hello from LAB-EUS-WEB01</h1>' > /var/www/html/index.html"
    }
  SETTINGS
}

##############################################################################
# Load Balancer
##############################################################################

resource "azurerm_lb" "lab_eus_web_lb" {
  name                = "lab-eus-web-lb"
  location            = var.region_location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "lab-eus-web-lb-public-ip"
    public_ip_address_id = azurerm_public_ip.lab_eus_web_lb_public_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "lab_eus_web_lb_pool" {
  loadbalancer_id = azurerm_lb.lab_eus_web_lb.id
  name            = "lab-eus-web-lb-pool"
}

# ip_configuration_name must match the name defined on the NIC ("ipconfig1").
resource "azurerm_network_interface_backend_address_pool_association" "web01_pool_association" {
  network_interface_id    = azurerm_network_interface.lab_eus_web01_nic.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab_eus_web_lb_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "web02_pool_association" {
  network_interface_id    = azurerm_network_interface.lab_eus_web02_nic.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab_eus_web_lb_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "web03_pool_association" {
  network_interface_id    = azurerm_network_interface.lab_eus_web03_nic.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab_eus_web_lb_pool.id
}

resource "azurerm_lb_probe" "lab_eus_web_lb_probe" {
  loadbalancer_id = azurerm_lb.lab_eus_web_lb.id
  name            = "lab-eus-web-lb-probe"
  protocol        = "Tcp"
  port            = 80
}

# Distributes inbound HTTP (80) from the LB's public frontend across
# VMs in the backend pool.
resource "azurerm_lb_rule" "http_lb_distribution" {
  loadbalancer_id                = azurerm_lb.lab_eus_web_lb.id
  name                            = "http-lb-rule"
  protocol                        = "Tcp"
  frontend_port                   = 80
  backend_port                    = 80
  disable_outbound_snat           = true
  frontend_ip_configuration_name  = "lab-eus-web-lb-public-ip"
  probe_id                        = azurerm_lb_probe.lab_eus_web_lb_probe.id
  backend_address_pool_ids        = [azurerm_lb_backend_address_pool.lab_eus_web_lb_pool.id]
}

resource "azurerm_lb_outbound_rule" "snat_outbound" {
  name                     = "outbound-snat-rule"
  loadbalancer_id          = azurerm_lb.lab_eus_web_lb.id
  protocol                 = "Tcp"
  backend_address_pool_id  = azurerm_lb_backend_address_pool.lab_eus_web_lb_pool.id

  frontend_ip_configuration {
    name = "lab-eus-web-lb-public-ip"
  }
}
