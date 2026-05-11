#!/bin/bash
# =============================================================
#  Network Monitoring Stack — Setup Script
#  Run once on the host BEFORE docker compose up
# =============================================================
set -e

echo "=== Pre-flight checks ==="

# 1. Initialize environment file
echo "[1/5] Ensuring .env exists..."
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example. Update secrets before production use."
fi

# 2. Host tuning and NAT rules (Linux only)
OS_NAME=$(uname -s)
if [ "$OS_NAME" = "Linux" ]; then
  echo "[2/5] Setting vm.max_map_count for OpenSearch..."
  if ! grep -q 'vm.max_map_count=262144' /etc/sysctl.conf; then
    echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
  fi
  sudo sysctl -p

  echo "[3/5] Setting up iptables NAT rules..."

  # Syslog 514 -> 5140 (UDP) and 5141 (TCP)
  sudo iptables -t nat -C PREROUTING -p udp --dport 514 -j REDIRECT --to-port 5140 2>/dev/null \
    || sudo iptables -t nat -A PREROUTING -p udp --dport 514 -j REDIRECT --to-port 5140

  sudo iptables -t nat -C PREROUTING -p tcp --dport 514 -j REDIRECT --to-port 5141 2>/dev/null \
    || sudo iptables -t nat -A PREROUTING -p tcp --dport 514 -j REDIRECT --to-port 5141

  # SNMP Traps 162 -> 1062 (UDP)
  sudo iptables -t nat -C PREROUTING -p udp --dport 162 -j REDIRECT --to-port 1062 2>/dev/null \
    || sudo iptables -t nat -A PREROUTING -p udp --dport 162 -j REDIRECT --to-port 1062
else
  echo "[2/5] Skipping Linux kernel and iptables changes on ${OS_NAME}."
  echo "      On macOS/Podman, expose 5140/5141 and 1062 directly or configure host port forwarding."
fi

# 4. Build and start
echo "[4/5] Building and starting stack..."
docker compose up -d --build
docker compose run --rm opensearch-bootstrap

# 5. Summary
echo "[5/5] Done!"
echo ""
echo "==================================================="
echo "  Stack is starting up. Allow ~60s for OpenSearch."
echo "==================================================="
echo ""
HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
if [ -z "${HOST_IP}" ]; then
  HOST_IP=$(ipconfig getifaddr en0 2>/dev/null || true)
fi
if [ -z "${HOST_IP}" ]; then
  HOST_IP="127.0.0.1"
fi
echo "  OpenSearch Dashboards : http://${HOST_IP}:5601"
echo "    Login               : ${OPENSEARCH_ADMIN_USERNAME:-admin} / (from .env)"
echo "  Prometheus            : http://${HOST_IP}:9090"
echo "  Pushgateway           : http://${HOST_IP}:9091"
echo "  Grafana (optional)    : http://${HOST_IP}:3000"
echo "  OpenSearch API        : https://${HOST_IP}:9200"
echo ""
echo "  Device configuration:"
echo "    NetFlow / IPFIX     → UDP ${HOST_IP}:2055"
echo "    sFlow               → UDP ${HOST_IP}:6343"
echo "    Syslog              → UDP/TCP ${HOST_IP}:514"
echo "    SNMP Traps          → UDP ${HOST_IP}:162"
echo "    Win/Linux agents    → TCP ${HOST_IP}:5044 (Beats)"
echo ""
echo "  LibreNMS (external) setup:"
echo "    lnms config:set prometheus.enable true"
echo "    lnms config:set prometheus.url 'http://${HOST_IP}:9091'"
echo "    lnms config:set prometheus.job 'librenms'"
echo "    lnms config:set prometheus.prefix 'librenms'"
echo ""
echo "  Next steps:"
echo "    1. Open OpenSearch Dashboards at :5601"
echo "    2. Create index patterns: netflow-*, syslog-*, snmp-traps-*"
echo "    3. Add Prometheus as a datasource for SNMP/LibreNMS metrics"
echo "    4. Edit prometheus/prometheus.yml with your device IPs"
echo "    5. Edit .env and rotate all default secrets before production use"
