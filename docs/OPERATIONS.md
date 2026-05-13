# Operations Runbook (Helm/Kubernetes)

## Deploy and upgrade

```bash
helm dependency build ./opensearch-helm
helm upgrade --install opensearch-stack ./opensearch-helm -n netmon --create-namespace
```

## Validate chart

```bash
helm lint ./opensearch-helm
helm template test-release ./opensearch-helm > /tmp/opensearch-helm-render.yaml
```

## Rollout status

```bash
kubectl get pods -n netmon
kubectl rollout status statefulset/opensearch -n netmon
kubectl rollout status deployment/opensearch-dashboards -n netmon
kubectl rollout status deployment/logstash -n netmon
kubectl rollout status deployment/prometheus -n netmon
kubectl rollout status deployment/snmp-exporter -n netmon
kubectl rollout status deployment/pushgateway -n netmon
kubectl rollout status deployment/grafana -n netmon
```

## Useful checks

```bash
kubectl logs -n netmon deploy/logstash --tail=200
kubectl logs -n netmon statefulset/opensearch --tail=200
kubectl get job -n netmon opensearch-bootstrap
kubectl logs -n netmon job/opensearch-bootstrap --tail=200
```

## Backup guidance

- OpenSearch: use snapshot repository and scheduled snapshots.
- Prometheus: back up the volume used by `prometheus-data` PVC.
- Grafana: back up the volume used by `grafana-data` PVC.

## Restore testing

Run periodic restores in staging and verify:

- OpenSearch indices are readable
- Prometheus targets and historical queries work
- Dashboards and datasources load correctly
