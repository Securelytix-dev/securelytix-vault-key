# Securelytix Data Vault

Deploy Securelytix Data Vault on Kubernetes or Docker Compose.

## Kubernetes (Helm)

```bash
helm repo add securelytix https://charts.securelytix.tech
helm repo update
helm install securelytix-vault securelytix/vault-sdk
```

## Requirements
- Kubernetes 1.20+
- Helm 3.0+
- PostgreSQL
- Redis
- Kafka
