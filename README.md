# Securelytix Dev SDK

Securelytix Dev SDK is a **PII tokenization service** for Kubernetes. Instead of passing real personal data (names, emails, phone numbers, etc.) between your services, the SDK replaces sensitive values with secure tokens. Your services exchange only tokens — the actual data never leaves the vault.

> **Note:** Currently supports structured data only (database fields, JSON payloads, form inputs).

## How It Works

1. A service sends a sensitive value (e.g. a user's phone number) to the SDK.
2. The SDK stores the real value securely and returns a token.
3. All other services receive and pass around only the token.
4. The real value is only retrieved when absolutely necessary, through the SDK.

This ensures PII is never exposed in logs, queues, or inter-service communication.

---

Deploy Securelytix Dev SDK on Kubernetes using Helm.

## Prerequisites
- Kubernetes 1.20+
- Helm 3.0+
- Securelytix API key (get one at https://securelytix.tech)
- PostgreSQL database (or use the bundled one)

---

## Quick Start

### Option 0 — Interactive installer (recommended)
```bash
curl -fsSL https://charts.securelytix.tech/install.sh | bash
```
The installer will guide you through the full setup interactively — credentials, database config, namespace, and DockerHub pull secret.

### Option 1 — With bundled PostgreSQL (no external DB needed)
```bash
helm repo add securelytix https://charts.securelytix.tech
helm repo update
helm install dev-sdk securelytix/dev-sdk \
  --set secrets.apiKey="<your-api-key>" \
  --set postgresql.enabled=true
```

### Option 2 — With your own PostgreSQL
```bash
helm repo add securelytix https://charts.securelytix.tech
helm repo update
helm install dev-sdk securelytix/dev-sdk \
  --set secrets.apiKey="<your-api-key>" \
  --set secrets.databaseUrl="postgresql://user:pass@host:5432/dbname?sslmode=disable"
```

---

## Configuration

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `secrets.apiKey` | API key for license validation | Yes | - |
| `secrets.databaseUrl` | PostgreSQL connection string | Only if postgresql.enabled=false | - |
| `secrets.licenseBaseUrl` | License server base URL | No | https://website-backend.securelytix.tech |
| `secrets.hmacKey` | HMAC key (optional, deprecated) | No | - |
| `postgresql.enabled` | Enable bundled PostgreSQL | No | false |
| `postgresql.auth.username` | PostgreSQL username | No | vault |
| `postgresql.auth.password` | PostgreSQL password | No | vault |
| `postgresql.auth.database` | PostgreSQL database name | No | vault |
| `config.port` | Server port | No | 8080 |
| `config.logLevel` | Log level | No | info |
| `config.requestLimit` | Max requests allowed | No | 25 |
| `imagePullSecrets` | DockerHub pull secret name | No | - |
| `persistence.enabled` | Enable persistent storage | No | true |
| `persistence.size` | Storage size | No | 1Gi |

---

## DockerHub Credentials

The image is hosted privately on DockerHub. Contact Utkarsh or Bhawna to get access credentials, then:

```bash
kubectl create secret docker-registry securelytix-dockerhub \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=securelytix2026 \
  --docker-password=<PAT_TOKEN>

helm install dev-sdk securelytix/dev-sdk \
  --set secrets.apiKey="<your-api-key>" \
  --set postgresql.enabled=true \
  --set "imagePullSecrets[0].name=securelytix-dockerhub"
```

> **zsh users:** Wrap `imagePullSecrets[0].name` in double quotes (as shown above) to avoid shell glob errors.

---

## Health Check
```bash
curl http://localhost:8080/health
# {"status":"ok","timestamp":"...","postgres":"ok"}
```

---

## Uninstall

### Interactive uninstaller (recommended)
```bash
curl -fsSL https://charts.securelytix.tech/uninstall.sh | bash
```

### Manual
```bash
helm uninstall dev-sdk
```

---

## Support
- Email: support@securelytix.tech
- Website: https://securelytix.tech
