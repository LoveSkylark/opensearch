# Operations Runbook

## Environments

- Dev/default: `podman compose up -d --build`
- Production: `podman compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build`
- Apply index retention manually: `podman compose run --rm opensearch-bootstrap`

## Backups

### OpenSearch snapshots (recommended)

1. Register a snapshot repository (S3/NFS/shared FS) in OpenSearch.
2. Trigger snapshots on schedule (daily suggested).
3. Keep at least 7 to 30 restore points based on retention policy.

Example API flow:

```bash
curl -k -u "$OPENSEARCH_ADMIN_USERNAME:$OPENSEARCH_ADMIN_PASSWORD" \
  -H 'Content-Type: application/json' \
  -X PUT "https://127.0.0.1:9200/_snapshot/main_repo" \
  -d '{"type":"fs","settings":{"location":"/usr/share/opensearch/snapshots","compress":true}}'

curl -k -u "$OPENSEARCH_ADMIN_USERNAME:$OPENSEARCH_ADMIN_PASSWORD" \
  -X PUT "https://127.0.0.1:9200/_snapshot/main_repo/nightly-$(date +%F)?wait_for_completion=true"
```

### Prometheus backups

- Stop Prometheus and back up the data volume (`prometheus-data`) at the storage layer.
- Keep `prometheus/prometheus.yml` and `prometheus/alerts.yml` in version control.

## Restore Testing

- Run quarterly restore tests in a staging environment.
- Validate:
  - NetFlow, syslog, and trap index visibility.
  - Prometheus query results for critical devices.
  - Dashboards loading with historical data.
