# Securelytix Dev SDK

Deploy Securelytix Dev SDK on Kubernetes using Helm.

## Helm Repository

```bash
helm repo add securelytix https://charts.securelytix.tech
helm repo update
```

## Install

```bash
helm install dev-sdk securelytix/dev-sdk \
  --set secrets.hmacKey="<your-hmac-key>" \
  --set secrets.databaseUrl="<your-db-url>" \
  --set secrets.licenseBaseUrl="<license-base-url>" \
  --set secrets.apiKey="<your-api-key>"
```

## Requirements
- Kubernetes 1.20+
- Helm 3.0+

## Configuration

| Parameter | Description | Required |
|-----------|-------------|----------|
| `secrets.hmacKey` | HMAC key for token signing | Yes |
| `secrets.databaseUrl` | Database connection URL | Yes |
| `secrets.licenseBaseUrl` | License server base URL | Yes |
| `secrets.apiKey` | API key for license validation | Yes |
| `config.port` | Server port | No (default: 8080) |
| `config.logLevel` | Log level | No (default: info) |
| `config.requestLimit` | Request limit | No (default: 25) |
| `persistence.enabled` | Enable persistent storage | No (default: true) |
| `persistence.size` | Storage size | No (default: 1Gi) |

## Support
- Email: support@securelytix.tech
- Website: https://securelytix.tech
