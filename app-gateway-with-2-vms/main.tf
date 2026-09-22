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

# Variables
variable "resource_group_name" {
    description = "Existing resource group to be targeted for the lab architecture. All the lab resources will go here."
    type        = string
    default     = "PUT_YOUR_RESOURCE_GROUP_HERE"
}

variable "region_location" {
    description = "Region for all resources deployed. This is set to East US."
    type        = string
    default     = "eastus"
}

variable "admin_username" {
    description = "The username to be used for the compute VMs deployed in the lab."
    type        = string
    default     = "azureuser"
}

variable "admin_password" {
    description = "The password to be used for the compute VMs deployed in the lab."
    type        = string
    sensitive   = true
}

## Existing Resource Group ##
data "azurerm_resource_group" "this" {
    name = var.resource_group_name
}


## Networking ##

# Virtual Networks (VNets)
# LAB-EUS-APP-GW-VNET
resource "azurerm_virtual_network" "lab_eus_app_gw_vnet" {
    name                = "LAB-EUS-APP-GW-VNET"
    location            = var.region_location
    resource_group_name = data.azurerm_resource_group.this.name
    address_space       = ["10.0.62.0/27"]
}

# APP-GW-SUBNET FOR LAB-EUS-APP-GW-VNET
resource "azurerm_subnet" "app_gw_subnet" {
    name                 = "APP-GW-SUBNET"
    resource_group_name  = data.azurerm_resource_group.this.name
    virtual_network_name = azurerm_virtual_network.lab_eus_app_gw_vnet.name
    address_prefixes     = ["10.0.62.0/27"]
}

# LAB-EUS-WEB-APP-VNET01
resource "azurerm_virtual_network" "lab_eus_web_app_vnet01" {
    name                = "LAB-EUS-WEB-APP-VNET01"
    location            = var.region_location
    resource_group_name = data.azurerm_resource_group.this.name
    address_space       = ["10.0.82.64/28"]
}

# WEB-SERVICE-SUBNET01 FOR LAB-EUS-WEB-APP-VNET01
resource "azurerm_subnet" "web_service_subnet01" {
    name                 = "WEB-SERVICE-SUBNET01"
    resource_group_name  = data.azurerm_resource_group.this.name
    virtual_network_name = azurerm_virtual_network.lab_eus_web_app_vnet01.name
    address_prefixes     = ["10.0.82.64/28"]
}

# LAB-EUS-WEB-APP-VNET02
resource "azurerm_virtual_network" "lab_eus_web_app_vnet02" {
    name                = "LAB-EUS-WEB-APP-VNET02"
    location            = var.region_location
    resource_group_name = data.azurerm_resource_group.this.name
    address_space       = ["10.0.83.64/28"]
}

# WEB-SERVICE-SUBNET02 FOR LAB-EUS-WEB-APP-VNET02
resource "azurerm_subnet" "web_service_subnet02" {
    name                 = "WEB-SERVICE-SUBNET02"
    resource_group_name  = data.azurerm_resource_group.this.name
    virtual_network_name = azurerm_virtual_network.lab_eus_web_app_vnet02.name
    address_prefixes     = ["10.0.83.64/28"]
}


# VNet Peerings
# Peer from LAB-EUS-APP-GW-VNET to LAB-EUS-WEB-APP-VNET01
resource "azurerm_virtual_network_peering" "peer_app_gw_vnet_to_web_app_vnet01" {
    name                         = "PEER-TO-LAB-EUS-WEB-APP-VNET01"
    resource_group_name          = data.azurerm_resource_group.this.name
    virtual_network_name         = azurerm_virtual_network.lab_eus_app_gw_vnet.name
    remote_virtual_network_id    = azurerm_virtual_network.lab_eus_web_app_vnet01.id
    allow_virtual_network_access = true
    allow_forwarded_traffic      = true
}

# Peer from LAB-EUS-WEB-APP-VNET01 to LAB-EUS-APP-GW-VNET
resource "azurerm_virtual_network_peering" "peer_web_app_vnet01_to_app_gw_vnet" {
    name                         = "PEER-TO-LAB-EUS-APP-GW-VNET"
    resource_group_name          = data.azurerm_resource_group.this.name
    virtual_network_name         = azurerm_virtual_network.lab_eus_web_app_vnet01.name
    remote_virtual_network_id    = azurerm_virtual_network.lab_eus_app_gw_vnet.id
    allow_virtual_network_access = true
    allow_forwarded_traffic      = true
}

# Peer from LAB-EUS-APP-GW-VNET to LAB-EUS-WEB-APP-VNET02
resource "azurerm_virtual_network_peering" "peer_app_gw_vnet_to_web_app_vnet02" {
    name                         = "PEER-TO-LAB-EUS-WEB-APP-VNET02"
    resource_group_name          = data.azurerm_resource_group.this.name
    virtual_network_name         = azurerm_virtual_network.lab_eus_app_gw_vnet.name
    remote_virtual_network_id    = azurerm_virtual_network.lab_eus_web_app_vnet02.id
    allow_virtual_network_access = true
    allow_forwarded_traffic      = true
}

# Peer from LAB-EUS-WEB-APP-VNET02 to LAB-EUS-APP-GW-VNET
resource "azurerm_virtual_network_peering" "peer_web_app_vnet02_to_app_gw_vnet" {
    name                         = "PEER-TO-LAB-EUS-APP-GW-VNET"
    resource_group_name          = data.azurerm_resource_group.this.name
    virtual_network_name         = azurerm_virtual_network.lab_eus_web_app_vnet02.name
    remote_virtual_network_id    = azurerm_virtual_network.lab_eus_app_gw_vnet.id
    allow_virtual_network_access = true
    allow_forwarded_traffic      = true
}


# Network Security Groups (NSGs)
# LAB-EUS-WEB01-NSG
resource "azurerm_network_security_group" "lab_eus_web01_nsg" {
    name                = "LAB-EUS-WEB01-NSG"
    location            = var.region_location
    resource_group_name = data.azurerm_resource_group.this.name

    security_rule {
        name                       = "Allow-HTTP-Inbound-From-Internet"
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

resource "azurerm_subnet_network_security_group_association" "lab_eus_web01_nsg_subnet_assoc" {
    subnet_id                 = azurerm_subnet.web_service_subnet01.id
    network_security_group_id = azurerm_network_security_group.lab_eus_web01_nsg.id
}

# LAB-EUS-WEB02-NSG
resource "azurerm_network_security_group" "lab_eus_web02_nsg" {
    name                = "LAB-EUS-WEB02-NSG"
    location            = var.region_location
    resource_group_name = data.azurerm_resource_group.this.name

    security_rule {
        name                       = "Allow-HTTP-Inbound-From-Internet"
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

resource "azurerm_subnet_network_security_group_association" "lab_eus_web02_nsg_subnet_assoc" {
    subnet_id                 = azurerm_subnet.web_service_subnet02.id
    network_security_group_id = azurerm_network_security_group.lab_eus_web02_nsg.id
}


# Public IP
# LAB-EUS-WEB-PIP01
resource "azurerm_public_ip" "lab_eus_web_pip01" {
    name                = "LAB-EUS-WEB-PIP01"
    location            = var.region_location
    resource_group_name = data.azurerm_resource_group.this.name
    allocation_method   = "Static"
    sku                 = "Standard"
    zones               = ["1", "2", "3"]
}


# Network Interfaces
# LAB-EUS-WEB01-NIC
resource "azurerm_network_interface" "lab_eus_web01_nic" {
    name                           = "LAB-EUS-WEB01-NIC"
    location                       = var.region_location
    resource_group_name            = data.azurerm_resource_group.this.name
    accelerated_networking_enabled = false

    ip_configuration {
        name                          = "ipconfig1"
        subnet_id                     = azurerm_subnet.web_service_subnet01.id
        private_ip_address_allocation = "Dynamic"
        primary                       = true
    }
}

# LAB-EUS-WEB02-NIC
resource "azurerm_network_interface" "lab_eus_web02_nic" {
    name                           = "LAB-EUS-WEB02-NIC"
    location                       = var.region_location
    resource_group_name            = data.azurerm_resource_group.this.name
    accelerated_networking_enabled = false

    ip_configuration {
        name                          = "ipconfig1"
        subnet_id                     = azurerm_subnet.web_service_subnet02.id
        private_ip_address_allocation = "Dynamic"
        primary                       = true
    }
}


## Virtual Machines & Extensions ##
# LAB-EUS-WEB01
resource "azurerm_linux_virtual_machine" "lab_eus_web01" {
    name                            = "LAB-EUS-WEB01"
    resource_group_name             = data.azurerm_resource_group.this.name
    location                        = var.region_location
    size                            = "Standard_B1s"
    admin_username                  = var.admin_username
    admin_password                  = var.admin_password
    disable_password_authentication = false

    network_interface_ids = [
        azurerm_network_interface.lab_eus_web01_nic.id,
    ]

    custom_data = base64encode(<<-EOF
            #!/bin/bash
            apt-get update -y
            apt-get install -y apache2
            systemctl enable --now apache2
            echo '<h1>Hello from LAB-EUS-WEB01!</h1>' > /var/www/html/index.html
            EOF
    )

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

# LAB-EUS-WEB02
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

    custom_data = base64encode(<<-EOF
            #!/bin/bash
            apt-get update -y
            apt-get install -y apache2
            systemctl enable --now apache2
            echo '<h1>Hello from LAB-EUS-WEB02!</h1>' > /var/www/html/index.html
            EOF
    )

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

## Application Gateway ##

# LAB-EUS-APP-GW01
resource "azurerm_application_gateway" "lab_eus_app_gw01" {
    name                = "LAB-EUS-APP-GW01"
    resource_group_name = data.azurerm_resource_group.this.name
    location            = var.region_location

    sku {
        name     = "Standard_v2"
        tier     = "Standard_v2"
        capacity = 2
    }

    ssl_policy {
        policy_type = "Predefined"
        policy_name = "AppGwSslPolicy20220101"
    }

    gateway_ip_configuration {
        name      = "LAB-EUS-APP-GW01-IPCONFIG"
        subnet_id = azurerm_subnet.app_gw_subnet.id
    }

    frontend_ip_configuration {
        name                 = "LAB-EUS-APP-GW01-FRONTEND-IP"
        public_ip_address_id = azurerm_public_ip.lab_eus_web_pip01.id
    }

    frontend_port {
        name = "HTTP-INBOUND"
        port = 80
    }

    backend_address_pool {
        name = "LAB-EUS-WEB-APP-BE-POOL"
        ip_addresses = [
            azurerm_network_interface.lab_eus_web01_nic.private_ip_address,
            azurerm_network_interface.lab_eus_web02_nic.private_ip_address
        ]
    }

    backend_http_settings {
        name                  = "LAB-EUS-WEB-APP-BE-POOL-SETTINGS"
        protocol              = "Http"
        port                  = 80
        cookie_based_affinity = "Disabled"
        request_timeout       = 20
    }

    http_listener {
        name                           = "LAB-EUS-WEB-APP-GW01-LISTENER"
        frontend_ip_configuration_name = "LAB-EUS-APP-GW01-FRONTEND-IP"
        frontend_port_name             = "HTTP-INBOUND"
        protocol                       = "Http"
    }

    request_routing_rule {
        name                       = "WEB-TRAFFIC-RULE"
        priority                   = 1
        rule_type                  = "Basic"
        http_listener_name         = "LAB-EUS-WEB-APP-GW01-LISTENER"
        backend_address_pool_name  = "LAB-EUS-WEB-APP-BE-POOL"
        backend_http_settings_name = "LAB-EUS-WEB-APP-BE-POOL-SETTINGS"
    }
}
