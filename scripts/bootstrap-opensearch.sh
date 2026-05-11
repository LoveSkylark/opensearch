#!/bin/sh
set -eu

OS_URL="https://${OPENSEARCH_HOST:-127.0.0.1}:${OPENSEARCH_PORT:-9200}"
AUTH="${OPENSEARCH_ADMIN_USERNAME}:${OPENSEARCH_ADMIN_PASSWORD}"

echo "Waiting for OpenSearch at ${OS_URL}..."
until curl -k -s -u "${AUTH}" "${OS_URL}/_cluster/health" >/dev/null; do
  sleep 3
done

echo "Applying ISM policies..."
for prefix in netflow syslog snmp-traps; do
  curl -k -s -u "${AUTH}" -X PUT "${OS_URL}/_plugins/_ism/policies/${prefix}-retention" \
    -H 'Content-Type: application/json' \
    -d "{\"policy\":{\"description\":\"${prefix} retention\",\"default_state\":\"hot\",\"states\":[{\"name\":\"hot\",\"actions\":[{\"rollover\":{\"min_size\":\"30gb\",\"min_index_age\":\"1d\"}}],\"transitions\":[{\"state_name\":\"delete\",\"conditions\":{\"min_index_age\":\"90d\"}}]},{\"name\":\"delete\",\"actions\":[{\"delete\":{}}],\"transitions\":[]}],\"ism_template\":[{\"index_patterns\":[\"${prefix}-*\"],\"priority\":100}]}}" >/dev/null

done

echo "ISM bootstrap complete."
