#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <source-index> [target-index]" >&2
  echo "Example: $0 syslog-2026.05.10 syslog-2026.05.10-tuned" >&2
  exit 1
fi

SOURCE_INDEX="$1"
TARGET_INDEX="${2:-${SOURCE_INDEX}-tuned}"

OS_URL="https://${OPENSEARCH_HOST:-127.0.0.1}:${OPENSEARCH_PORT:-9200}"
AUTH="${OPENSEARCH_ADMIN_USERNAME}:${OPENSEARCH_ADMIN_PASSWORD}"

echo "Waiting for OpenSearch at ${OS_URL}..."
until curl -k -s -u "${AUTH}" "${OS_URL}/_cluster/health" >/dev/null; do
  sleep 3
done

SOURCE_STATUS=$(curl -k -s -o /dev/null -w '%{http_code}' -u "${AUTH}" "${OS_URL}/${SOURCE_INDEX}")
if [ "${SOURCE_STATUS}" != "200" ]; then
  echo "Source index not found: ${SOURCE_INDEX}" >&2
  exit 1
fi

TARGET_STATUS=$(curl -k -s -o /dev/null -w '%{http_code}' -u "${AUTH}" "${OS_URL}/${TARGET_INDEX}")
if [ "${TARGET_STATUS}" = "200" ]; then
  echo "Target index already exists: ${TARGET_INDEX}" >&2
  exit 1
fi

echo "Creating target index ${TARGET_INDEX}..."
curl -k -s -u "${AUTH}" -X PUT "${OS_URL}/${TARGET_INDEX}" \
  -H 'Content-Type: application/json' \
  -d '{}' >/dev/null

echo "Reindexing ${SOURCE_INDEX} -> ${TARGET_INDEX}..."
curl -k -s -u "${AUTH}" -X POST "${OS_URL}/_reindex?wait_for_completion=true&refresh=true" \
  -H 'Content-Type: application/json' \
  -d "{\"source\":{\"index\":\"${SOURCE_INDEX}\"},\"dest\":{\"index\":\"${TARGET_INDEX}\"}}" >/dev/null

SOURCE_COUNT=$(curl -k -s -u "${AUTH}" "${OS_URL}/${SOURCE_INDEX}/_count" | sed -n 's/.*"count":\([0-9][0-9]*\).*/\1/p')
TARGET_COUNT=$(curl -k -s -u "${AUTH}" "${OS_URL}/${TARGET_INDEX}/_count" | sed -n 's/.*"count":\([0-9][0-9]*\).*/\1/p')

echo "Source docs: ${SOURCE_COUNT:-unknown}"
echo "Target docs: ${TARGET_COUNT:-unknown}"
echo "Done. Review ${TARGET_INDEX}, then switch dashboards or aliases before deleting ${SOURCE_INDEX}."