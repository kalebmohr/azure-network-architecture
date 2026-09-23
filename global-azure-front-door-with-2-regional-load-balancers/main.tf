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

variable "east_us_region" {
    description = "This is a variable that is used for resources being deployed in the East US region."
    type        = string
    default     = "eastus"
}

variable "west_us_region" {
    description = "This is a variable that is used for resources being deployed in the West US region."
    type        = string
    default     = "westus"
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

# LAB-WUS-RGNL-WEB-SERVICES-VNET
resource "azurerm_virtual_network" "lab_wus_rgnl_web_services_vnet" {
    name                = "LAB-WUS-RGNL-WEB-SERVICES-VNET"
    location            = var.west_us_region
    resource_group_name = data.azurerm_resource_group.this.name
    address_space       = ["10.1.0.0/16"]
}

# LAB-WUS-RGNL-WEB-SERVER-SNET for LAB-WUS-RGNL-WEB-SERVICES-VNET
resource "azurerm_subnet" "lab_wus_rgnl_web_server_snet" {
    name                 = "LAB-WUS-RGNL-WEB-SERVER-SNET"
    resource_group_name  = data.azurerm_resource_group.this.name
    virtual_network_name = azurerm_virtual_network.lab_wus_rgnl_web_services_vnet.name
    address_prefixes     = ["10.1.1.0/28"]
}

# LAB-EUS-RGNL-WEB-SERVICES-VNET
resource "azurerm_virtual_network" "lab_eus_rgnl_web_services_vnet" {
    name                = "LAB-EUS-RGNL-WEB-SERVICES-VNET"
    location            = var.east_us_region
    resource_group_name = data.azurerm_resource_group.this.name
    address_space       = ["10.0.0.0/16"]
}

# LAB-EUS-RGNL-WEB-SERVER-SNET for LAB-EUS-RGNL-WEB-SERVICES-VNET
resource "azurerm_subnet" "lab_eus_rgnl_web_server_snet" {
    name                 = "LAB-EUS-RGNL-WEB-SERVER-SNET"
    resource_group_name  = data.azurerm_resource_group.this.name
    virtual_network_name = azurerm_virtual_network.lab_eus_rgnl_web_services_vnet.name
    address_prefixes     = ["10.0.1.0/28"]
}


# Network Security Groups (NSGs)
# LAB-EUS-RGNL-WEB-NSG01
resource "azurerm_network_security_group" "lab_eus_rgnl_web_nsg01" {
    name                = "LAB-EUS-RGNL-WEB-NSG01"
    location            = var.east_us_region
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

resource "azurerm_subnet_network_security_group_association" "lab_eus_rgnl_web_nsg01_assoc" {
    subnet_id                 = azurerm_subnet.lab_eus_rgnl_web_server_snet.id
    network_security_group_id = azurerm_network_security_group.lab_eus_rgnl_web_nsg01.id
}

# LAB-WUS-RGNL-WEB-NSG01
resource "azurerm_network_security_group" "lab_wus_rgnl_web_nsg01" {
    name                = "LAB-WUS-RGNL-WEB-NSG01"
    location            = var.west_us_region
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

resource "azurerm_subnet_network_security_group_association" "lab_wus_rgnl_web_nsg01_assoc" {
    subnet_id                 = azurerm_subnet.lab_wus_rgnl_web_server_snet.id
    network_security_group_id = azurerm_network_security_group.lab_wus_rgnl_web_nsg01.id
}


# Public IP Addresses
# LAB-EUS-RGNL-PIP01
resource "azurerm_public_ip" "lab_eus_rgnl_pip01" {
    name                = "LAB-EUS-RGNL-PIP01"
    location            = var.east_us_region
    resource_group_name = data.azurerm_resource_group.this.name
    allocation_method   = "Static"
    sku                 = "Standard"
}

# LAB-WUS-RGNL-PIP01
resource "azurerm_public_ip" "lab_wus_rgnl_pip01" {
    name                = "LAB-WUS-RGNL-PIP01"
    location            = var.west_us_region
    resource_group_name = data.azurerm_resource_group.this.name
    allocation_method   = "Static"
    sku                 = "Standard"
}


# Network Interfaces
# LAB-WUS-RGNL-WEB01-NIC
resource "azurerm_network_interface" "lab_wus_rgnl_web01_nic" {
    name                           = "LAB-WUS-RGNL-WEB01-NIC"
    location                       = var.west_us_region
    resource_group_name            = data.azurerm_resource_group.this.name
    accelerated_networking_enabled = false

    ip_configuration {
        name                          = "ipconfig1"
        subnet_id                     = azurerm_subnet.lab_wus_rgnl_web_server_snet.id
        private_ip_address_allocation = "Dynamic"
        primary                       = true
    }
}

# LAB-WUS-RGNL-WEB02-NIC
resource "azurerm_network_interface" "lab_wus_rgnl_web02_nic" {
    name                           = "LAB-WUS-RGNL-WEB02-NIC"
    location                       = var.west_us_region
    resource_group_name            = data.azurerm_resource_group.this.name
    accelerated_networking_enabled = false

    ip_configuration {
        name                          = "ipconfig1"
        subnet_id                     = azurerm_subnet.lab_wus_rgnl_web_server_snet.id
        private_ip_address_allocation = "Dynamic"
        primary                       = true
    }
}

# LAB-EUS-RGNL-WEB01-NIC
resource "azurerm_network_interface" "lab_eus_rgnl_web01_nic" {
    name                           = "LAB-EUS-RGNL-WEB01-NIC"
    location                       = var.east_us_region
    resource_group_name            = data.azurerm_resource_group.this.name
    accelerated_networking_enabled = false

    ip_configuration {
        name                          = "ipconfig1"
        subnet_id                     = azurerm_subnet.lab_eus_rgnl_web_server_snet.id
        private_ip_address_allocation = "Dynamic"
        primary                       = true
    }
}

# LAB-EUS-RGNL-WEB02-NIC
resource "azurerm_network_interface" "lab_eus_rgnl_web02_nic" {
    name                           = "LAB-EUS-RGNL-WEB02-NIC"
    location                       = var.east_us_region
    resource_group_name            = data.azurerm_resource_group.this.name
    accelerated_networking_enabled = false

    ip_configuration {
        name                          = "ipconfig1"
        subnet_id                     = azurerm_subnet.lab_eus_rgnl_web_server_snet.id
        private_ip_address_allocation = "Dynamic"
        primary                       = true
    }
}


## Virtual Machines & Cloud-Inits ##
# LAB-WUS-RGNL-WEB01
resource "azurerm_linux_virtual_machine" "lab_wus_rgnl_web01" {
    name                            = "LAB-WUS-RGNL-WEB01"
    resource_group_name             = data.azurerm_resource_group.this.name
    location                        = var.west_us_region
    size                            = "Standard_B1s"
    admin_username                  = var.admin_username
    admin_password                  = var.admin_password
    disable_password_authentication = false

    network_interface_ids = [
        azurerm_network_interface.lab_wus_rgnl_web01_nic.id,
    ]

    custom_data = base64encode(<<-EOF
            #!/bin/bash
            apt-get update -y
            apt-get install -y apache2
            systemctl enable --now apache2
            echo '<h1>Hello from LAB-WUS-RGNL-WEB01!</h1>' > /var/www/html/index.html
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

# LAB-WUS-RGNL-WEB02
resource "azurerm_linux_virtual_machine" "lab_wus_rgnl_web02" {
    name                            = "LAB-WUS-RGNL-WEB02"
    resource_group_name             = data.azurerm_resource_group.this.name
    location                        = var.west_us_region
    size                            = "Standard_B1s"
    admin_username                  = var.admin_username
    admin_password                  = var.admin_password
    disable_password_authentication = false

    network_interface_ids = [
        azurerm_network_interface.lab_wus_rgnl_web02_nic.id,
    ]

    custom_data = base64encode(<<-EOF
            #!/bin/bash
            apt-get update -y
            apt-get install -y apache2
            systemctl enable --now apache2
            echo '<h1>Hello from LAB-WUS-RGNL-WEB02!</h1>' > /var/www/html/index.html
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

# LAB-EUS-RGNL-WEB01
resource "azurerm_linux_virtual_machine" "lab_eus_rgnl_web01" {
    name                            = "LAB-EUS-RGNL-WEB01"
    resource_group_name             = data.azurerm_resource_group.this.name
    location                        = var.east_us_region
    size                            = "Standard_B1s"
    admin_username                  = var.admin_username
    admin_password                  = var.admin_password
    disable_password_authentication = false

    network_interface_ids = [
        azurerm_network_interface.lab_eus_rgnl_web01_nic.id,
    ]

    custom_data = base64encode(<<-EOF
            #!/bin/bash
            apt-get update -y
            apt-get install -y apache2
            systemctl enable --now apache2
            echo '<h1>Hello from LAB-EUS-RGNL-WEB01!</h1>' > /var/www/html/index.html
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

# LAB-EUS-RGNL-WEB02
resource "azurerm_linux_virtual_machine" "lab_eus_rgnl_web02" {
    name                            = "LAB-EUS-RGNL-WEB02"
    resource_group_name             = data.azurerm_resource_group.this.name
    location                        = var.east_us_region
    size                            = "Standard_B1s"
    admin_username                  = var.admin_username
    admin_password                  = var.admin_password
    disable_password_authentication = false

    network_interface_ids = [
        azurerm_network_interface.lab_eus_rgnl_web02_nic.id,
    ]

    custom_data = base64encode(<<-EOF
            #!/bin/bash
            apt-get update -y
            apt-get install -y apache2
            systemctl enable --now apache2
            echo '<h1>Hello from LAB-EUS-RGNL-WEB02!</h1>' > /var/www/html/index.html
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


## Load Balancers ##
# LAB-WUS-RGNL-LB01
resource "azurerm_lb" "lab_wus_rgnl_lb01" {
    name                = "LAB-WUS-RGNL-LB01"
    location            = var.west_us_region
    resource_group_name = data.azurerm_resource_group.this.name
    sku                 = "Standard"

    frontend_ip_configuration {
        name                 = "LAB-WUS-RGNL-LB01-PIP"
        public_ip_address_id = azurerm_public_ip.lab_wus_rgnl_pip01.id
    }
}

resource "azurerm_lb_backend_address_pool" "lab_wus_rgnl_lb01_pool" {
    loadbalancer_id = azurerm_lb.lab_wus_rgnl_lb01.id
    name            = "LAB-WUS-RGNL-LB01-POOL"
}

resource "azurerm_network_interface_backend_address_pool_association" "wus_web01_association" {
    network_interface_id    = azurerm_network_interface.lab_wus_rgnl_web01_nic.id
    ip_configuration_name   = "ipconfig1"
    backend_address_pool_id = azurerm_lb_backend_address_pool.lab_wus_rgnl_lb01_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "wus_web02_association" {
    network_interface_id    = azurerm_network_interface.lab_wus_rgnl_web02_nic.id
    ip_configuration_name   = "ipconfig1"
    backend_address_pool_id = azurerm_lb_backend_address_pool.lab_wus_rgnl_lb01_pool.id
}

resource "azurerm_lb_probe" "lab_wus_rgnl_lb01_probe" {
    loadbalancer_id = azurerm_lb.lab_wus_rgnl_lb01.id
    name            = "lab-wus-rgnl-lb01-probe"
    protocol        = "Tcp"
    port            = 80
}

resource "azurerm_lb_rule" "wus_http_lb_distribution" {
    loadbalancer_id                = azurerm_lb.lab_wus_rgnl_lb01.id
    name                           = "http-lb-rule"
    protocol                       = "Tcp"
    frontend_port                  = 80
    backend_port                   = 80
    disable_outbound_snat          = true
    frontend_ip_configuration_name = "LAB-WUS-RGNL-LB01-PIP"
    probe_id                       = azurerm_lb_probe.lab_wus_rgnl_lb01_probe.id
    backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lab_wus_rgnl_lb01_pool.id]
}

resource "azurerm_lb_outbound_rule" "wus_snat_outbound" {
    name                    = "outbound-snat-rule"
    loadbalancer_id         = azurerm_lb.lab_wus_rgnl_lb01.id
    protocol                = "Tcp"
    backend_address_pool_id = azurerm_lb_backend_address_pool.lab_wus_rgnl_lb01_pool.id

    frontend_ip_configuration {
        name = "LAB-WUS-RGNL-LB01-PIP"
    }
}

# LAB-EUS-RGNL-LB01
resource "azurerm_lb" "lab_eus_rgnl_lb01" {
    name                = "LAB-EUS-RGNL-LB01"
    location            = var.east_us_region
    resource_group_name = data.azurerm_resource_group.this.name
    sku                 = "Standard"

    frontend_ip_configuration {
        name                 = "LAB-EUS-RGNL-LB01-PIP"
        public_ip_address_id = azurerm_public_ip.lab_eus_rgnl_pip01.id
    }
}

resource "azurerm_lb_backend_address_pool" "lab_eus_rgnl_lb01_pool" {
    loadbalancer_id = azurerm_lb.lab_eus_rgnl_lb01.id
    name            = "LAB-EUS-RGNL-LB01-POOL"
}

resource "azurerm_network_interface_backend_address_pool_association" "eus_web01_association" {
    network_interface_id    = azurerm_network_interface.lab_eus_rgnl_web01_nic.id
    ip_configuration_name   = "ipconfig1"
    backend_address_pool_id = azurerm_lb_backend_address_pool.lab_eus_rgnl_lb01_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "eus_web02_association" {
    network_interface_id    = azurerm_network_interface.lab_eus_rgnl_web02_nic.id
    ip_configuration_name   = "ipconfig1"
    backend_address_pool_id = azurerm_lb_backend_address_pool.lab_eus_rgnl_lb01_pool.id
}

resource "azurerm_lb_probe" "lab_eus_rgnl_lb01_probe" {
    loadbalancer_id = azurerm_lb.lab_eus_rgnl_lb01.id
    name            = "lab-eus-rgnl-lb01-probe"
    protocol        = "Tcp"
    port            = 80
}

resource "azurerm_lb_rule" "eus_http_lb_distribution" {
    loadbalancer_id                = azurerm_lb.lab_eus_rgnl_lb01.id
    name                           = "http-lb-rule"
    protocol                       = "Tcp"
    frontend_port                  = 80
    backend_port                   = 80
    disable_outbound_snat          = true
    frontend_ip_configuration_name = "LAB-EUS-RGNL-LB01-PIP"
    probe_id                       = azurerm_lb_probe.lab_eus_rgnl_lb01_probe.id
    backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lab_eus_rgnl_lb01_pool.id]
}

resource "azurerm_lb_outbound_rule" "eus_snat_outbound" {
    name                    = "outbound-snat-rule"
    loadbalancer_id         = azurerm_lb.lab_eus_rgnl_lb01.id
    protocol                = "Tcp"
    backend_address_pool_id = azurerm_lb_backend_address_pool.lab_eus_rgnl_lb01_pool.id

    frontend_ip_configuration {
        name = "LAB-EUS-RGNL-LB01-PIP"
    }
}


## Azure Front Door Profile ##
resource "azurerm_cdn_frontdoor_profile" "lab_web_azfd_01" {
  name                = "LAB-WEB-AZFD-01"
  resource_group_name = data.azurerm_resource_group.this.name
  sku_name            = "Standard_AzureFrontDoor"
}

# Front Door Endpoint
resource "azurerm_cdn_frontdoor_endpoint" "lab_web_endpoint" {
  name                     = "lab-web-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.lab_web_azfd_01.id
  enabled                  = true
}

# Origin Groups
# Primary Dual-Region Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "web_service_og" {
  name                     = "web-service-og"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.lab_web_azfd_01.id

  session_affinity_enabled = false

  health_probe {
    interval_in_seconds = 100
    path                = "/"
    protocol            = "Http"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

# East US Only Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "eus_web_services_og" {
  name                     = "eus-web-services-og"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.lab_web_azfd_01.id

  session_affinity_enabled = false

  health_probe {
    interval_in_seconds = 100
    path                = "/"
    protocol            = "Http"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

# West US Only Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "wus_web_services_og" {
  name                     = "wus-web-services-og"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.lab_web_azfd_01.id

  session_affinity_enabled = false

  health_probe {
    interval_in_seconds = 100
    path                = "/"
    protocol            = "Http"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

# Origins
# East US Origin in Primary Group
resource "azurerm_cdn_frontdoor_origin" "eus_web_public_ip" {
  name                          = "eus-web-public-ip"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.web_service_og.id
  enabled                       = true

  host_name                      = azurerm_public_ip.lab_eus_rgnl_pip01.ip_address
  origin_host_header             = azurerm_public_ip.lab_eus_rgnl_pip01.ip_address
  http_port                      = 80
  https_port                     = 443
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = false
}

# West US Origin in Primary Group
resource "azurerm_cdn_frontdoor_origin" "wus_web_public_ip" {
  name                          = "wus-web-public-ip"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.web_service_og.id
  enabled                       = true

  host_name                      = azurerm_public_ip.lab_wus_rgnl_pip01.ip_address
  origin_host_header             = azurerm_public_ip.lab_wus_rgnl_pip01.ip_address
  http_port                      = 80
  https_port                     = 443
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = false
}

# East US Dedicated Origin
resource "azurerm_cdn_frontdoor_origin" "eus_web_service_ip" {
  name                          = "eus-web-service-ip"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.eus_web_services_og.id
  enabled                       = true

  host_name                      = azurerm_public_ip.lab_eus_rgnl_pip01.ip_address
  origin_host_header             = azurerm_public_ip.lab_eus_rgnl_pip01.ip_address
  http_port                      = 80
  https_port                     = 443
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = false
}

# West US Dedicated Origin
resource "azurerm_cdn_frontdoor_origin" "wus_web_service_ip" {
  name                          = "wus-web-service-ip"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.wus_web_services_og.id
  enabled                       = true

  host_name                      = azurerm_public_ip.lab_wus_rgnl_pip01.ip_address
  origin_host_header             = azurerm_public_ip.lab_wus_rgnl_pip01.ip_address
  http_port                      = 80
  https_port                     = 443
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = false
}

# Rule Sets and Rules
resource "azurerm_cdn_frontdoor_rule_set" "device_type_handling" {
  name                     = "deviceTypeHandling"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.lab_web_azfd_01.id
}

# Mobile Rule to Steer to West US
resource "azurerm_cdn_frontdoor_rule" "route_mobile_to_west_us" {
  name                      = "routeMobileDeviceToWestUS"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.device_type_handling.id
  order                     = 100
  behavior_on_match         = "Stop"

  depends_on = [
    azurerm_cdn_frontdoor_origin.wus_web_service_ip
  ]

  conditions {
    is_device_condition {
      operator     = "Equal"
      match_values = ["Mobile"]
    }
  }

  actions {
    route_configuration_override_action {
      cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.wus_web_services_og.id
      forwarding_protocol           = "HttpOnly"
    }
  }
}

# Desktop Rule to Steer to East US
resource "azurerm_cdn_frontdoor_rule" "route_desktop_to_east_us" {
  name                      = "routeDesktopToEastUS"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.device_type_handling.id
  order                     = 200
  behavior_on_match         = "Continue"

  
  depends_on = [
    azurerm_cdn_frontdoor_origin.eus_web_service_ip
  ]

  conditions {
    is_device_condition {
      operator     = "Equal"
      match_values = ["Desktop"]
    }
  }

  actions {
    route_configuration_override_action {
      cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.eus_web_services_og.id
      forwarding_protocol           = "HttpOnly"
    }
  }
}

# Global Routing Rule
resource "azurerm_cdn_frontdoor_route" "web_services_global_route" {
  name                            = "web-services-global-route"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.lab_web_endpoint.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.web_service_og.id
  cdn_frontdoor_origin_ids        = [
    azurerm_cdn_frontdoor_origin.eus_web_public_ip.id,
    azurerm_cdn_frontdoor_origin.wus_web_public_ip.id
  ]
  cdn_frontdoor_rule_set_ids      = [azurerm_cdn_frontdoor_rule_set.device_type_handling.id]

  supported_protocols             = ["Http"]
  patterns_to_match               = ["/*"]
  forwarding_protocol             = "HttpOnly"
  link_to_default_domain          = true
  https_redirect_enabled          = false
  enabled                         = true
}
