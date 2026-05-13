# OpenSearch Deployment (Helm/Kubernetes)

This folder is now a minimal support folder for the Kubernetes deployment.

## What remains here

- `logstash/Dockerfile`: custom Logstash image build (netflow + geoip plugins)
- `scripts/reindex-opensearch.sh`: optional maintenance utility for OpenSearch

## Active deployment source

The active Kubernetes deployment is in:

- `opensearch-helm/`

Use that chart for all install, upgrade, and configuration changes.

## Build custom Logstash image

```bash
docker build -t your-registry/logstash-netflow:8.6.1 ./opensearch/logstash
docker push your-registry/logstash-netflow:8.6.1
```

Then set `logstash.image` in `opensearch-helm/values.yaml`.
