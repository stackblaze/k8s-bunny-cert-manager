<p align="center">
  <img src="logo.png" alt="k8s-bunny-cert-manager" width="300">
</p>

<h1 align="center">k8s-bunny-cert-manager</h1>

<p align="center">
  All-in-one Helm chart for automated TLS certificate management with <a href="https://cert-manager.io/">cert-manager</a> and <a href="https://bunny.net/">Bunny.net</a> DNS on Kubernetes.
</p>

---

## What It Does

Automates the entire setup for issuing and **auto-renewing** Let's Encrypt TLS certificates using Bunny.net DNS-01 challenges:

1. Deploys the Bunny DNS webhook solver
2. Creates the API key secret
3. Creates a ClusterIssuer for Let's Encrypt
4. Requests your TLS certificate (with optional auto-generated wildcard SANs)
5. Auto-renews 30 days before expiry (configurable)

Supports three certificate strategies:

- **Option A (Wildcard Certificate)** — Pre-provision a single certificate covering wildcard SANs for every combination of subdomain and child subdomain
- **Option B (Per-Ingress Dynamic)** — Let cert-manager issue certificates on-demand when Ingress resources are annotated
- **Option C (Both Together)** — Use wildcard certs for known hostnames and per-ingress certs for custom domains

## Prerequisites

- Kubernetes cluster (1.24+)
- [Helm](https://helm.sh/) 3.x
- A domain with DNS managed by Bunny.net
- A Bunny.net API key

> **Note:** If [cert-manager](https://cert-manager.io/) is not already installed, the chart will automatically install it for you.

## Quick Start

```bash
git clone https://github.com/stackblaze/k8s-bunny-cert-manager.git
cd k8s-bunny-cert-manager

helm install k8s-bunny-cert-manager . \
  -n cert-manager \
  --set bunny.apiKey=YOUR_BUNNY_API_KEY \
  --set domain=example.com \
  --set acme.email=admin@example.com
```

That's it. Your certificate will be issued and stored in a secret called `example-com-tls`.

<details>
<summary><strong>Option A: Wildcard Certificate</strong></summary>

Auto-generate wildcard SANs for every combination of subdomain and child subdomain. A single certificate covers all matching hostnames — no per-host cert issuance delay.

The generated SAN pattern is: `*.<childSubdomain>.<subdomain>.<domain>`

```bash
helm install k8s-bunny-cert-manager . \
  -n cert-manager \
  --set bunny.apiKey=YOUR_KEY \
  --set domain=example.com \
  --set acme.email=admin@example.com \
  --set wildcardCert.enabled=true \
  --set 'wildcardCert.subdomains={us-east,eu-west}' \
  --set 'wildcardCert.childSubdomains={api,app}'
```

This generates a certificate with SANs:

```
example.com
*.api.us-east.example.com
*.app.us-east.example.com
*.api.eu-west.example.com
*.app.eu-west.example.com
```

Reference the wildcard cert secret in your Ingress or Traefik TLSStore:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
spec:
  tls:
  - hosts:
    - my-app.api.us-east.example.com
    secretName: example-com-tls
  rules:
  - host: my-app.api.us-east.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

> **Note:** Let's Encrypt allows up to 100 SANs per certificate. With 10 child subdomains and 10 subdomains you'd hit 100 SANs — plan accordingly.

</details>

<details>
<summary><strong>Option B: Per-Ingress Dynamic Certificates</strong></summary>

The ClusterIssuer created by this chart can issue certificates on-demand. Annotate any Ingress and cert-manager handles the rest:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: k8s-bunny-cert-manager-letsencrypt
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: app-example-com-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

cert-manager will automatically:
1. Detect the annotation on the Ingress
2. Create a Certificate resource
3. Solve the DNS-01 challenge via Bunny.net
4. Store the issued cert in the specified secret
5. Auto-renew before expiry

> **Note:** The issuer name follows the pattern `<release>-k8s-bunny-cert-manager-letsencrypt`. Check `helm status` or the install notes for the exact name.

</details>

<details>
<summary><strong>Option C: Using Both Options Together</strong></summary>

Option A and B are not mutually exclusive. A common pattern:

- **Option A** covers all pre-known hostnames via wildcard SANs
- **Option B** covers custom or user-supplied domains per-ingress

```bash
helm install k8s-bunny-cert-manager . \
  -n cert-manager \
  --set bunny.apiKey=YOUR_KEY \
  --set domain=example.com \
  --set acme.email=admin@example.com \
  --set wildcardCert.enabled=true \
  --set 'wildcardCert.subdomains={us-east}'
```

Hosts under the wildcard cert use `example-com-tls`. When a custom domain is added, the Ingress gets the `cert-manager.io/cluster-issuer` annotation and receives its own dedicated cert.

</details>

## Configuration

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `bunny.apiKey` | Bunny.net API key | **Yes** | `""` |
| `domain` | Primary domain name | **Yes** | `""` |
| `acme.email` | Let's Encrypt registration email | **Yes** | `""` |
| `acme.server` | ACME server URL | No | Let's Encrypt production |
| `certificates.enabled` | Request a certificate for the root domain | No | `true` |
| `certificates.additionalDnsNames` | Extra SANs (wildcards, subdomains) | No | `[]` |
| `certificates.renewBefore` | Renew this long before expiry | No | `720h` (30 days) |
| `wildcardCert.enabled` | Auto-generate wildcard SANs from subdomains × childSubdomains | No | `false` |
| `wildcardCert.subdomains` | Parent subdomains (e.g. `us-east`, `eu-west`, `prod`) | No | `[]` |
| `wildcardCert.childSubdomains` | Child subdomains nested under each parent (e.g. `api`, `app`) | No | `[]` |
| `webhook.image.repository` | Webhook container image | No | `ghcr.io/stackblaze/k8s-bunny-cert-manager` |
| `webhook.image.tag` | Webhook image tag | No | `latest` |
| `webhook.replicas` | Webhook replica count | No | `1` |
| `webhook.resources` | Webhook resource limits | No | `{}` |

## Auto-Renewal

Certificates auto-renew automatically. cert-manager checks certificate expiry and triggers a new DNS-01 challenge 30 days before expiry (configurable via `certificates.renewBefore`).

Let's Encrypt certificates are valid for 90 days, so with the default 30-day renewal window, your cert renews every ~60 days.

To verify renewal is configured:

```bash
kubectl get certificate -n cert-manager
# READY should be True, RENEWAL TIME shows when it will renew
```

## Troubleshooting

```bash
# Check certificate status
kubectl get certificate -n cert-manager

# Check per-ingress certs across all namespaces
kubectl get certificate --all-namespaces

# Check if challenges are pending
kubectl get challenge -A

# Check webhook logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=k8s-bunny-cert-manager-webhook

# Describe a certificate for events
kubectl describe certificate <name> -n cert-manager
```

## Uninstall

```bash
helm uninstall k8s-bunny-cert-manager -n cert-manager
```

## Credits

The DNS01 webhook solver is based on the work by [maximehuylebroeck/cert-manager-webhook-bunny](https://github.com/maximehuylebroeck/cert-manager-webhook-bunny), originally derived from [digilolnet/cert-manager-webhook-bunny](https://github.com/digilolnet/cert-manager-webhook-bunny).

## License

Apache 2.0
