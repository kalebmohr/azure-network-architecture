# Azure Multi-VM Web Load Balancer (Apache Web Servers) Lab

A load balancer lab that deploys a small web-tier architecture in Azure: three Linux
VMs running Apache behind a Standard SKU Load Balancer, all provisioned with
Infrastructure as Code.

This repo is meant as a **learning / portfolio project** — a hands-on way to
practice Azure networking, load balancing, and Terraform fundamentals in a
disposable sandbox environment.

> ⚠️ **Lab / demo purposes only. Do not deploy this to a production environment
> as-is.** See [Production Readiness](#production-readiness-not-included) below.

Architecture and code designed by **Kaleb Mohr**.

---

## What this deploys

- A dedicated VNet and subnet for the web tier
- Three Ubuntu 22.04 LTS VMs, each auto-provisioned with Apache via a
  CustomScript extension
- A Standard SKU public Load Balancer distributing inbound HTTP (port 80)
  traffic across all three VMs through a backend pool + health probe
- A Network Security Group allowing inbound HTTP from the internet
- An explicit outbound rule for VM egress (SNAT)

<img width="764" height="374" alt="AzureLBWebServerLabDiagram" src="https://github.com/user-attachments/assets/83daac98-e1b4-4b3d-8fea-fbe862298b67" />


---

## Prerequisites

- An Azure subscription or sandbox (e.g. Microsoft Learn's [Azure sandbox](https://learn.microsoft.com/training/support/azure-sandbox),
  A Cloud Guru, or your own subscription)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), authenticated (`az login`)

If you're using a training sandbox, it typically pre-provisions a single
resource group for you and blocks creating new ones — this config is written
to work with that constraint (see [Sandbox notes](#sandbox-notes) below).

---

## Getting started

1. **Clone the repo**

   ```bash
   git clone https://github.com/kalebmohr/azure-network-architecture/public-load-balancer-with-apache-web-servers.git
   cd public-load-balancer-with-apache-web-servers
   ```

2. **Set your variables**

   Edit the Terraform file and modify the following:

   ```hcl
   resource_group_name = "your-sandbox-resource-group-name"
   region_location      = "eastus"
   admin_username        = "your-preferred-username"
   ```

3. **Initialize Terraform**

   ```bash
   terraform init
   ```

4. **Plan**

   ```bash
   terraform plan (you will be prompted for the admin password)
   ```

5. **Apply**

   ```bash
   terraform apply (you will be prompted for the admin password)
   ```

   Type `yes` when prompted. Deployment takes a few minutes — the VMs need to
   boot and the CustomScript extension needs to install Apache on each.

6. **Test it**

   Grab the load balancer's public IP from the Azure Portal.
   Check to see if port 80 is open:
   <img width="863" height="88" alt="Port80OnLBIPOpen" src="https://github.com/user-attachments/assets/8dafd560-90ba-47ea-9b79-41dea4ece3bd" />
   Try accessing it in your web browser, one of your web servers should greet you:
   <img width="1512" height="982" alt="Screenshot 2026-08-17 at 3 58 02 PM" src="https://github.com/user-attachments/assets/bda20e1c-eb15-4752-8d69-48bab9ae920d" />
   You can also see if the health probe has determined healthy backend pool resources using the monitoring insights feature in the portal:
   <img width="1510" height="734" alt="Screenshot 2026-08-17 at 4 11 30 PM" src="https://github.com/user-attachments/assets/d7b0ab7b-c53c-4691-96cd-cf73c1854b62" />


8. **Tear it down**

   Don't forget this step, especially in a sandbox with time or cost limits:

   ```bash
   terraform destroy
   ```

---

## Sandbox notes

Some training sandboxes have quirks this config accounts for:

- **Pre-provisioned resource group** — the config uses a `data` source to
  look up an *existing* resource group rather than creating one, since many
  sandboxes don't allow `Microsoft.Resources/resourceGroups` creation.
- **`skip_provider_registration = true`** — sandbox accounts often lack
  permission to register resource providers; this avoids Terraform trying to
  do so automatically.
- **VM size** — `Standard_B1s` is used to stay within typical sandbox quota
  and cost limits. Bump it up if your environment allows more.

If `apt-get update` fails inside the CustomScript extension due to a flaky
mirror or stale package index (a known intermittent Ubuntu apt issue, not a
Terraform bug), retry with:

```bash
terraform taint azurerm_virtual_machine_extension.web01_install_apache
terraform apply -var="admin_password=<YourStrongPassword123!>"
```

(repeat for `web02_install_apache` / `web03_install_apache` as needed)

---

## Repo structure

```
.
├── main.tf                     # All resources: networking, VMs, LB
└── README.md
```

---

## Production readiness (not included)

This lab intentionally skips things you'd want in a real deployment:

- NSG rule opens HTTP to `Internet` with no scoping — fine for a public demo
  web server, not fine for anything holding real data
- No HTTPS / TLS termination
- No secrets management (admin credentials are passed as a Terraform
  variable, not pulled from Azure Key Vault)
- No monitoring, alerting, or diagnostic logging
- No backup or disaster recovery plan
- No Terraform remote state / locking (state is local by default)

## License

Feel free to fork and use this for your own learning. No warranty is provided in this lab. 
