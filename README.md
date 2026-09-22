# Azure Network Architecture, Global Networking, & Hybrid Transit Lab ☁️🌐

This repository contains design documentation, topology diagrams, and Infrastructure as Code (IaC) configurations for enterprise Azure networking scenarios. This is an active working personal project as I go through my Azure cloud networking studies.

## 🎯 Focus Areas
In general, this repository focuses on the following core technologies:
- **Hub-and-Spoke Topology:** Azure VNets, VNet Peering, and Transit Hubs
- **Custom Routing:** User-Defined Routes (UDRs) and Forced Tunneling
- **Perimeter & Security:** Network Security Groups (NSGs) & Azure Firewall Integration
- **Hybrid Interconnects:** Azure ExpressRoute & Site-to-Site VPN Gateway Architectures
- **Application & Content Delivery:** Azure Load Balancer, Application Gateway, Azure Front Door, and Traffic Manager

Note: This repository is actively updated as I build and document new lab topologies. Topics marked above reflect current lab modules and upcoming design architectures.


## 🛠️ Tech Stack
- **Cloud:** Microsoft Azure
- **IaC:** Terraform / Bicep
- **Tooling:** Azure CLI, Git

## 💡 Reuse
If you are looking to reuse any of the architecture labs in this repository, I recommend first creating a resource group in your **LAB** Azure cloud environment first. Once you've cloned this git repo, edit the `main.tf` files you see in the project folder you're interested in, and adjust the following variable block:
```terraform
variable "resource_group_name" {
    description = "Existing resource group to be targeted for the lab architecture. All the lab resources will go here."
    type        = string
    default     = "PUT_YOUR_RESOURCE_GROUP_HERE" # Modify this string value to be the name of your resource group you created.
}
```
I try to keep my IaC standardized so it's easily transferrable between Azure topologies. Once you have modified the resource group name, it should work in your Azure lab environment (as long as you have authenticated via `az cli` of course!)

## ⚠️ A Word of Caution
While these lab configurations represent functional, working architectures, they are designed strictly for sandbox and educational environments.

They serve as foundational stepping stones rather than production-ready cloud designs and do not include enterprise hardening, remote state management, or compliance controls. Deploy at your own risk.
