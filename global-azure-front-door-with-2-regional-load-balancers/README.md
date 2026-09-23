# Dual-Region Azure Front Door Global Load Balancing & Device Steering Architecture
This repository contains a complete Infrastructure as Code (IaC) implementation in Terraform for a multi-region, globally load-balanced web infrastructure deployed across Azure (`East US` and `West US`).

The lab demonstrates enterprise-grade global traffic management concepts—including Azure Front Door (Standard) edge routing, regional Standard Load Balancers, device-based traffic steering (Mobile vs. Desktop), and automated multi-region Linux web server bootstrapping (cloud-init).

## Architecture Overview
<img width="971" height="547" alt="Screenshot 2026-09-23 at 4 26 32 PM" src="https://github.com/user-attachments/assets/89617f9a-0664-49ba-9cb5-a47bf5aa784b" />

## Core Architecture & Components
- **Global Edge Ingress & Anycast Routing:** Azure Front Door (Standard Tier) acting as the single global entry point (lab-web-endpoint), providing Anycast routing and global HTTP health monitoring across both regions.
- **Device-Based Traffic Steering**: Custom Front Door Rule Set (`deviceTypeHandling`) configured to inspect incoming client device headers:
  -  **Mobile Devices:** Automatically overridden and steered to the `West US` regional origin group.
  -  **Desktop Devices:** Automatically steered to the `East US` regional origin group.
- **Dual-Region Regional Load Balancing:** Independent Azure Standard Load Balancers deployed in East US and West US, each fronting two isolated Ubuntu 22.04 LTS virtual machines.
- **Automated Web Server Provisioning:** Linux virtual machines (LAB-EUS-RGNL-WEB01/02 and LAB-WUS-RGNL-WEB01/02) bootstrapped dynamically at boot using custom_data (cloud-init) to run Apache and display region-specific landing pages.
- **Declarative Dependency Management:** Explicit Terraform dependency ordering (depends_on) applied to Front Door rules to enforce Azure API validation requirements before binding origins to rule sets.

## Tech Stack & Requirements
- **Cloud Provider:** Microsoft Azure

- **IaC Tooling:** Terraform (`>= 1.5.0`)

- **AzureRM Provider:** `~> 3.100`

- **CLI:** Azure CLI (`az cli`) authenticated to target subscription

- **Resource Group:** A pre-created and defined resource group in your target subscription

## Deployment Guide
### 1. Clone & Navigate to Repository
```bash
git clone https://github.com/kalebmohr/azure-network-architecture.git
cd azure-network-architecture/global-azure-front-door-with-2-regional-load-balancers
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
Run a plan to inspect the planned multi-region resources:
```bash
terraform plan
```
Deploy the infrastructure (you will be prompted to enter a secure VM admin password):
```bash
terraform apply
```

## Verification & Testing
1. Once deployment succeeds, grab the global Azure Front Door endpoint hostname:
```bash
az afd endpoint show \
  --resource-group "PUT_YOUR_RESOURCE_GROUP_HERE" \
  --profile-name "LAB-WEB-AZFD-01" \
  --endpoint-name "lab-web-endpoint" \
  --query "hostName" -o tsv
```
2. Open your web browser and go to `http://[YOUR_FRONT_DOOR_ENDPOINT]` (e.g. `http://lab-web-endpoint-a3f9hwggbzb0ehe9.a03.azurefd.net`)
3. Verify Device Steering:
  - **Desktop Device**: Verify that you see a response from the `East US` Web Servers.

<img width="1512" height="819" alt="Screenshot 2026-09-23 at 4 40 25 PM" src="https://github.com/user-attachments/assets/66a31289-ee4f-4189-a379-10cfdcd8b7c4" />

  - **Mobile Device**: Verify that you see a response from the `West US` Web Servers.

<img width="660" height="1434" alt="IMG_3040" src="https://github.com/user-attachments/assets/79453209-03b8-4efe-b78e-2cec90388bc5" />

## Cleanup
To destroy all provisioned infrastructure and avoid incurring cloud costs, run this command in your terminal:
```bash
terraform destroy
```

## Disclaimer
This configuration is built strictly for educational, lab, and portfolio demonstration purposes. It utilizes local state tracking and basic HTTP configurations suitable for sandbox testing. Do not deploy directly into production without incorporating remote state storage, HTTPS/TLS certificates, custom domain bindings, and Web Application Firewall (WAF) security policies.
## License
Feel free to fork and use this for your own learning. No warranty is provided in this lab.
