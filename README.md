# Azure hub-and-spoke with Container Apps

Terraform deploys a small hub-and-spoke environment that demonstrates
controlled application traffic through Azure Firewall Basic.

```text
Internet
   |
   v
+-------------------- DMZ spoke (10.1.0.0/16) --------------------+
| Application Gateway Standard_v2                                 |
|   -> internal NGINX Container App                               |
|        -> DMZ Azure Firewall Basic                              |
+-------------------------------+----------------------------------+
                                |
                                | all DMZ egress
                                v
+------------------------ Hub (10.0.0.0/16) -----------------------+
| Azure Firewall Basic                                            |
+-------------------------------+----------------------------------+
                                |
                                | HTTPS through UDR
                                v
+------------------- Application spoke (10.2.0.0/16) -------------+
| internal hello-world Container App                              |
+------------------------------------------------------------------+
```

The NGINX proxy and hello-world application use the Azure Linux NGINX image
hosted in Microsoft Artifact Registry:

- `mcr.microsoft.com/azurelinux/base/nginx:1`

All traffic leaving the DMZ Container Apps subnet first traverses the DMZ
Azure Firewall. Private `10.0.0.0/8` destinations then traverse the hub Azure
Firewall, while public internet traffic exits directly from the DMZ firewall.
Return traffic from the application spoke follows the reverse path through
both firewalls. Both firewalls send resource-specific logs and metrics to the
shared Log Analytics workspace.

## Prerequisites

- Terraform 1.6 or later.
- Azure CLI authenticated to the target subscription.
- Permissions to create networking, Container Apps, Application Gateway,
  private DNS, and role-free infrastructure resources.
- Azure Firewall Basic and Application Gateway v2 availability in the selected
  region.

## Deploy

```bash
cd terraform
cp env.sample .env
source .env

terraform init
terraform apply
```

After deployment, open the `application_url` output. Application Gateway sends
the request to NGINX, and NGINX proxies it through Azure Firewall to the
hello-world application.

## Entra Easy Auth and HTTPS

The public NGINX Container App is protected by Container Apps Easy Auth using
Microsoft Entra ID. Application Gateway terminates TLS for the hostname set by
`application_hostname` and redirects HTTP requests to HTTPS.

The TLS certificate is issued by Let's Encrypt. Terraform manages the
application's delegated public DNS zone set by `acme_dns_zone_name`, including
the apex A record and ACME DNS-01 challenge records. Before the first
certificate request, replace the application's A record in the parent public
DNS zone with an NS delegation using the name servers from the
`acme_dns_name_servers` output. The full record is also shown by the
`acme_dns_delegation` output.

The ACME provider uses the current Azure CLI login to create temporary TXT
challenge records in the delegated zone. Set `TF_VAR_acme_email_address` before
running Terraform.

## Validate

```bash
curl "$(terraform output -raw application_url)"
```

Application Gateway and Azure Firewall can each take several minutes to
provision. This example uses HTTP on the public frontend and HTTPS for both
Container Apps backend hops.

## Clean up

```bash
terraform destroy
```
