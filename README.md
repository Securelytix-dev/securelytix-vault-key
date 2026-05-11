# Securelytix Dev SDK

Deploy Securelytix Dev SDK on Kubernetes using Helm.

## Prerequisites
- Kubernetes 1.20+
- Helm 3.0+
- PostgreSQL database
- Securelytix API key (get one at https://securelytix.tech)

## Quick Start

```bash
helm repo add securelytix https://charts.securelytix.tech
helm repo update
helm install dev-sdk securelytix/dev-sdk \
  --set secrets.hmacKey="<your-hmac-key>" \
  --set secrets.databaseUrl="postgresql://user:pass@host:5432/dbname?sslmode=disable" \
  --set secrets.licenseBaseUrl="https://website-backend.securelytix.tech" \
  --set secrets.apiKey="<your-api-key>"
```

## Configuration

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `secrets.hmacKey` | HMAC key for token signing | Yes | - |
| `secrets.databaseUrl` | PostgreSQL connection string | Yes | - |
| `secrets.licenseBaseUrl` | License server base URL | Yes | - |
| `secrets.apiKey` | API key for license validation | Yes | - |
| `config.port` | Server port | No | 8080 |
| `config.logLevel` | Log level (debug/info/warn/error) | No | info |
| `config.requestLimit` | Max requests allowed | No | 25 |
| `config.usageSyncIntervalSec` | Usage sync interval in seconds | No | 10 |
| `config.licenseRequestTimeoutSec` | License request timeout in seconds | No | 5 |
| `replicaCount` | Number of replicas | No | 1 |
| `persistence.enabled` | Enable persistent storage | No | true |
| `persistence.size` | Storage size | No | 1Gi |
| `persistence.storageClass` | Storage class | No | default |

## Health Check

The SDK exposes a health endpoint at `/health`:

```bash
curl http://localhost:8080/health
# {"status":"ok","timestamp":"...","postgres":"ok"}
```

## Uninstall

```bash
helm uninstall dev-sdk
```

## Support
- Email: support@securelytix.tech
- Website: https://securelytix.tech
