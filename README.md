# Securelytix Dev SDK

Deploy Securelytix Dev SDK on Kubernetes using Helm.

## Prerequisites
- Kubernetes 1.20+
- Helm 3.0+
- Securelytix API key (get one at https://securelytix.tech)
- PostgreSQL database (or use the bundled one)

## Quick Start

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
  --set imagePullSecrets[0].name=securelytix-dockerhub
```

## Health Check
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
