# Azure hub-and-spoke with Container Apps

Terraform deploys a public Application Gateway and two internal Azure
Container Apps environments across a hub-and-spoke network. Requests enter
through the DMZ spoke, while traffic from the NGINX proxy to the application
spoke traverses two Azure Firewall Basic instances.

```text
Internet
   |
   | HTTPS (HTTP redirects to HTTPS)
   v
+----------------------- DMZ spoke (10.1.0.0/16) -----------------------+
| Public Application Gateway Standard_v2                               |
|   | HTTPS over the DMZ VNet (does not traverse a firewall)           |
|   v                                                                   |
| NGINX Container App in an internal Container Apps environment        |
|   | default route                                                    |
|   v                                                                   |
| DMZ Azure Firewall Basic                                             |
+-------------------------------+---------------------------------------+
                                |
                                | private 10.0.0.0/8 route
                                v
+-------------------------- Hub (10.0.0.0/16) --------------------------+
| Hub Azure Firewall Basic                                             |
+-------------------------------+---------------------------------------+
                                |
                                | HTTPS over hub-to-app VNet peering
                                v
+-------------------- Application spoke (10.2.0.0/16) -----------------+
| Hello-world Container App in an internal Container Apps environment  |
+------------------------------------------------------------------------+

Return path: application spoke -> hub firewall -> DMZ firewall -> NGINX
```

The NGINX proxy and hello-world application use the Azure Linux NGINX image
hosted in Microsoft Artifact Registry:

- `mcr.microsoft.com/azurelinux/base/nginx:1`

Both Container Apps environments use internal load balancers. Their apps set
`external_enabled = true`, which makes ingress reachable from their virtual
networks through the environment's private IP; it does not expose either
Container App directly to the internet. Application Gateway is the only public
application entry point.

All traffic leaving the DMZ Container Apps subnet first traverses the DMZ
firewall. The DMZ firewall sends private `10.0.0.0/8` traffic to the hub
firewall and sends public traffic directly to the internet. The application
spoke routes return traffic destined for the DMZ spoke through the hub
firewall, which routes it through the DMZ firewall. Both firewalls send all
logs and metrics to the shared Log Analytics workspace.

## Prerequisites

- Terraform 1.6 or later.
- Azure CLI authenticated to the target subscription.
- Permissions to create networking, Container Apps, Application Gateway,
  public and private DNS, and monitoring resources.
- Microsoft Entra permissions to create an application registration, service
  principal, and client secret.
- Azure Firewall Basic and Application Gateway v2 availability in the selected
  region.
- Access to create an NS delegation in the parent public DNS zone for
  `acme_dns_zone_name`.

## Deploy

```bash
cd terraform
cp env.sample .env
source .env

terraform init
```

Create the Azure DNS zone first:

```bash
terraform apply -target=azurerm_dns_zone.acme
terraform output acme_dns_delegation
```

Create the displayed NS delegation in the parent public DNS zone, then deploy
the complete environment:

```bash
terraform apply
```

This ordering is required because Let's Encrypt must be able to resolve the
delegated zone before Terraform can complete the DNS-01 certificate challenge.

## Request and authentication flow

Application Gateway is public, terminates TLS for `application_hostname`, and
redirects HTTP requests to HTTPS. It connects over HTTPS to the private NGINX
Container App. NGINX is protected by Container Apps Easy Auth using Microsoft
Entra ID and proxies authenticated requests over HTTPS to the private
hello-world Container App.

The TLS certificate is issued by Let's Encrypt. Terraform manages the
application's delegated public DNS zone set by `acme_dns_zone_name`, including
the apex A record pointing to Application Gateway and temporary ACME DNS-01
challenge records.

The ACME provider uses the current Azure CLI login to create temporary TXT
challenge records in the delegated zone.

## Validate

The unauthenticated health endpoint verifies the public Application Gateway to
private NGINX path:

```bash
curl "$(terraform output -raw application_url)/healthz"
```

Open the application URL in a browser to sign in with Microsoft Entra ID and
reach the hello-world application:

```bash
terraform output -raw application_url
```

An unauthenticated request to the root URL receives a redirect to the Microsoft
Entra login flow. Application Gateway and Azure Firewall can each take several
minutes to provision.

## Downstream identity claims

After authentication, Easy Auth injects the signed-in user's claims into the
NGINX request. NGINX explicitly overwrites and forwards the trusted header to
the hello-world application:

```text
X-MS-CLIENT-PRINCIPAL: <Base64-encoded JSON claims>
```

The hello-world application can Base64-decode the header and parse the JSON
claims. It must not accept this header through any route that bypasses Easy
Auth and NGINX.

The DMZ NGINX structured access log records a broad safe allowlist of request,
content-negotiation, forwarding, browser fetch-metadata, and tracing headers.
It records `principal_present` and the Base64-encoded
`X-MS-CLIENT-PRINCIPAL` value. Authorization values, cookies, provider token
headers, arbitrary custom headers, and query strings are deliberately
excluded. The principal value contains user identity claims and must be
protected as personal data in Log Analytics.

The hello-world app also records `principal_present` and the forwarded
`X-MS-CLIENT-PRINCIPAL` value so the identity propagation across both
Container Apps can be verified.

## Clean up

```bash
terraform destroy
```
