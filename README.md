<p align="center">
  <img src="logo.png" alt="k8s-bunny-cert-manager" width="300">
</p>

<h1 align="center">k8s-bunny-cert-manager</h1>

<p align="center">
  All-in-one Helm chart for automated TLS certificate management with <a href="https://cert-manager.io/">cert-manager</a> and <a href="https://bunny.net/">Bunny.net</a> DNS on Kubernetes.
</p>

---

## Prerequisites

- Kubernetes cluster (1.24+)
- [Helm](https://helm.sh/) 3.x
- A domain with DNS managed by Bunny.net
- A Bunny.net API key
- [cert-manager](https://cert-manager.io/) — installed automatically if not already present

## Quick Start

```bash
helm install k8s-bunny-cert-manager . \
  -n cert-manager \
  --set bunny.apiKey=YOUR_BUNNY_API_KEY \
  --set domain=example.com \
  --set acme.email=admin@example.com
```

Your certificate will be issued and stored in a secret called `example-com-tls`.

## Configuration

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `bunny.apiKey` | Bunny.net API key | **Yes** | `""` |
| `domain` | Primary domain name | **Yes** | `""` |
| `acme.email` | Let's Encrypt registration email | **Yes** | `""` |
| `acme.server` | ACME server URL | No | Let's Encrypt production |
| `certificates.enabled` | Request a certificate for the root domain | No | `true` |
| `certificates.additionalDnsNames` | Extra domains to include on the certificate | No | `[]` |
| `certificates.renewBefore` | How early to renew before expiry | No | `720h` (30 days) |
| `wildcardCert.enabled` | Enable wildcard certificate generation | No | `false` |
| `wildcardCert.subdomains` | Parent subdomains (e.g. `us-east`, `eu-west`) | No | `[]` |
| `wildcardCert.childSubdomains` | Child subdomains under each parent (e.g. `api`, `app`) | No | `[]` |
| `webhook.image.repository` | Webhook container image | No | `ghcr.io/stackblaze/k8s-bunny-cert-manager` |
| `webhook.image.tag` | Webhook image tag | No | `latest` |
| `webhook.replicas` | Webhook replica count | No | `1` |
| `webhook.resources` | Webhook resource limits | No | `{}` |

> Certificates auto-renew 30 days before expiry by default. Let's Encrypt certs are valid for 90 days, so renewals happen roughly every 60 days.

## Certificate Options

| Option | What it does |
|--------|-------------|
| A — Manual | List the exact domains you want |
| B — Wildcard | Cover all subdomains at once with one cert |
| C — Per-Ingress | Issue a cert automatically for each service |
| D — Both | Wildcard for your services, per-cert for custom domains |

<details>
<summary><strong>Option A: Manual</strong></summary>

```bash
helm install k8s-bunny-cert-manager . \
  -n cert-manager \
  --set bunny.apiKey=YOUR_KEY \
  --set domain=example.com \
  --set acme.email=admin@example.com \
  --set 'certificates.additionalDnsNames={*.example.com,api.example.com}'
```

</details>

<details>
<summary><strong>Option B: Wildcard</strong></summary>

Generates SANs for every combination of `subdomains` × `childSubdomains`. Pattern: `*.<child>.<subdomain>.<domain>`

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

Produces: `*.api.us-east.example.com`, `*.app.us-east.example.com`, `*.api.eu-west.example.com`, `*.app.eu-west.example.com`

> Let's Encrypt allows up to 100 SANs per certificate.

</details>

<details>
<summary><strong>Option C: Per-Ingress</strong></summary>

No extra chart config needed. Just annotate your Ingress resources:

```yaml
annotations:
  cert-manager.io/cluster-issuer: <release>-k8s-bunny-cert-manager-letsencrypt
```

cert-manager will automatically issue and renew a certificate for that Ingress.

> **⚠️ Warning — operator-managed Ingresses:** Do **not** use Option C if the Ingress is created and managed by an operator (e.g. coroot-operator, Argo CD, or any controller that deletes and recreates Ingress resources on upgrades).
>
> cert-manager's ingress-shim sets an `ownerReference` on the Certificate pointing at the Ingress. When the operator deletes and recreates the Ingress, Kubernetes garbage-collects the Certificate with it. This forces a full ACME re-issuance — DNS01 can take 10–20 minutes — during which your ingress controller has no valid TLS secret and falls back to its built-in self-signed certificate (browsers show "Not Secure").
>
> **Use instead:** create a standalone `Certificate` resource (no `ownerReference`) that writes to the same `secretName`, and remove the `cert-manager.io/cluster-issuer` annotation from the Ingress. The secret then survives Ingress deletions and no re-issuance is triggered on each operator upgrade.
>
> ```yaml
> apiVersion: cert-manager.io/v1
> kind: Certificate
> metadata:
>   name: my-service-tls
>   namespace: my-namespace
>   # No ownerReferences — survives Ingress deletion
> spec:
>   secretName: my-service-tls
>   issuerRef:
>     name: <release>-k8s-bunny-cert-manager-letsencrypt
>     kind: ClusterIssuer
>     group: cert-manager.io
>   dnsNames:
>     - my-service.example.com
> ```

</details>

<details>
<summary><strong>Option D: Both</strong></summary>

Use wildcard certs (Option B) for known hostnames and per-ingress certs (Option C) for custom domains — no conflict, they work side by side.

```bash
helm install k8s-bunny-cert-manager . \
  -n cert-manager \
  --set bunny.apiKey=YOUR_KEY \
  --set domain=example.com \
  --set acme.email=admin@example.com \
  --set wildcardCert.enabled=true \
  --set 'wildcardCert.subdomains={us-east}'
```

Then annotate any Ingress with the cluster-issuer for custom domains.

</details>

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

# Uninstall
helm uninstall k8s-bunny-cert-manager -n cert-manager
```

---

The DNS01 webhook solver is based on [maximehuylebroeck/cert-manager-webhook-bunny](https://github.com/maximehuylebroeck/cert-manager-webhook-bunny). Licensed under Apache 2.0.
