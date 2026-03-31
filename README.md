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
2. Creates the API key secret (with the correct field names)
3. Creates a ClusterIssuer for Let's Encrypt
4. Requests your TLS certificate
5. Auto-renews 30 days before expiry (configurable)

## Prerequisites

- Kubernetes cluster (1.24+)
- [cert-manager](https://cert-manager.io/) installed
- [Helm](https://helm.sh/) 3.x
- A domain with DNS managed by Bunny.net
- A Bunny.net API key

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

## Using the Certificate

Reference the TLS secret in your Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
spec:
  tls:
  - hosts:
    - example.com
    secretName: example-com-tls
  rules:
  - host: example.com
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

## Additional DNS Names (SANs)

Request a certificate that covers multiple domains or wildcards:

```bash
helm install k8s-bunny-cert-manager . \
  -n cert-manager \
  --set bunny.apiKey=YOUR_KEY \
  --set domain=example.com \
  --set acme.email=admin@example.com \
  --set 'certificates.additionalDnsNames={*.example.com,*.us-west-1.example.com}'
```

## Configuration

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `bunny.apiKey` | Bunny.net API key | **Yes** | `""` |
| `domain` | Primary domain name | **Yes** | `""` |
| `acme.email` | Let's Encrypt registration email | **Yes** | `""` |
| `acme.server` | ACME server URL | No | Let's Encrypt production |
| `certificates.enabled` | Request a certificate | No | `true` |
| `certificates.additionalDnsNames` | Extra SANs (wildcards, subdomains) | No | `[]` |
| `certificates.renewBefore` | Renew this long before expiry | No | `720h` (30 days) |
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

## Using the ClusterIssuer Directly

You can also skip the built-in certificate and use the ClusterIssuer directly in your own Certificate resources or Ingress annotations:

```yaml
# Via Ingress annotation
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

## Troubleshooting

```bash
# Check certificate status
kubectl get certificate -n cert-manager

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

## License

Apache 2.0
