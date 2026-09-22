# Multi-VNet Azure Application Gateway Load Balancing Architecture

This repository contains a complete Infrastructure as Code (IaC) implementation in Terraform for a multi-VNet, load-balanced web architecture deployed in Azure (`East US`). 

The lab demonstrates enterprise-style networking concepts—including hub-and-spoke VNet peering, Layer 7 application load balancing, isolated backend workloads, and automated Linux web server bootstrapping.

---

## Architecture Overview
<img width="976" height="526" alt="Screenshot 2026-09-22 at 11 52 06 AM" src="https://github.com/user-attachments/assets/292ffef4-9926-4f9c-8aa5-4964743977b9" />

## Core Architecture & Components
- **Ingress & Layer 7 Load Balancing**: Azure Application Gateway (Standard_v2) acting as the public entry point, configured with explicit modern TLS policies `(AppGwSslPolicy20220101)`.
- **Hub-and-Spoke Network Topology**: Three dedicated Virtual Networks (`LAB-EUS-APP-GW-VNET`, `LAB-EUS-WEB-APP-VNET01`, and `LAB-EUS-WEB-APP-VNET02`) linked via *bi-directional VNet Peerings*.
- **Perimeter Security**: Isolated subnets with dedicated Network Security Groups (NSGs) allowing inbound HTTP traffic.
- **Automated Web Server Provisioning**: Ubuntu 22.04 LTS virtual machines bootstrapped dynamically at launch using custom_data (cloud-init) to run Apache and host custom landing pages.
- **Dynamic Backend Referencing**: Application Gateway backend pool dynamically fetches the primary private IP addresses of the backend NICs directly from the Terraform dependency graph.

## Tech Stack & Requirements
- Cloud Provider: `Microsoft Azure`
- IaC Tooling: `Terraform (>= 1.5.0)`
- AzureRM Provider: `~> 3.100`
- CLI: Azure CLI (`az cli`) authenticated to target subscription
- Resource Group: A pre-created and defined resource group in your target subscription

## Deployment Guide
### 1. Clone & Navigate to Repository
```bash
git clone https://github.com/kalebmohr/azure-network-architecture.git
cd azure-network-architecture/app-gateway-with-2-vms
```
### 2. Authenticate to Azure
```bash
az login
az account show
```
### 3. Initialize & Deploy Terraform
```bash
terraform init
```
Run a plan to inspect the 14 planned resources:
```bash
terraform plan
```
Deploy the infrastructure (you will be prompted to enter a secure VM admin password):
```bash
terraform apply
```
## Verification & Testing
1. Once deployment succeeds, grab the Public IP address of the Application Gateway:
```bash
az network public-ip show \
  --resource-group "PUT_YOUR_RESOURCE_GROUP_HERE" \
  --name "LAB-EUS-WEB-PIP01" \
  --query "ipAddress" -o tsv
```
2. Open your web browser and go to `http://[YOUR_PUBLIC_IP]`
3. Examine the basic HTML output in the webpage. Refresh multiple times to see the traffic route between the two VMs:
<img width="1512" height="834" alt="Screenshot 2026-09-22 at 10 10 16 AM" src="https://github.com/user-attachments/assets/b0bf7d0f-d39b-49c8-b333-d4a680af7f0f" />
<img width="1512" height="827" alt="Screenshot 2026-09-22 at 10 10 30 AM" src="https://github.com/user-attachments/assets/6a18b592-5e9c-48f6-80bf-6db32da01700" />

## Cleanup
To destroy all provisioned infrastructure and avoid incurring cloud costs, run this command in your terminal:
```bash
terraform destroy
```

## Disclaimer
This configuration is built strictly for educational, lab, and portfolio demonstration purposes. It utilizes local state tracking and basic HTTP configurations suitable for sandbox testing. Do not deploy directly into production without incorporating remote state storage, HTTPS/TLS certificates, and enterprise security controls.

## License
Feel free to fork and use this for your own learning. No warranty is provided in this lab.
