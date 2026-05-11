# Network Monitoring Stack — OpenSearch Backend

Clean, modular open source network monitoring stack.
LibreNMS is **not included** — it connects as an external module
via the Prometheus Pushgateway only.

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│  EXTERNAL                                                   │
│  LibreNMS  ──── SNMP poll metrics ──► Pushgateway (:9091)  │
└─────────────────────────────────────────────────────────────┘
                                              │
┌─────────────────────────────────────────────▼───────────────┐
│  THIS STACK                                                 │
│                                                             │
│  Network Devices                                            │
│    │                                                        │
│    ├─ NetFlow/IPFIX (UDP 2055) ──┐                          │
│    ├─ sFlow        (UDP 6343) ───┤                          │
│    ├─ SNMP Traps   (UDP 162)  ───┼─► Logstash ──────┬──► OpenSearch
│    ├─ Syslog       (UDP 514)  ───┼─► Fluent Bit ────┤    (storage)
│    │                             │                   │
│    └─ Beats (TCP 5044) ──────────┘                   │
│                                                       │
│  SNMP Poll         ──► SNMP Exporter ──► Prometheus  │
│                                             │          │
│                                     Pushgateway ◄─────┘
│                                             │
│                               Redis (enrichment cache)
│                                             │
│          ┌─────────────────────────────────┴──────────┐
│          │                                            │
│   OpenSearch Dashboards ◄──┐                          │
│   (logs/flows/traps)       │                          │
│                            └─ Grafana (alternative UI)
└─────────────────────────────────────────────────────────────┘
```

---

## Collectors

| Collector       | Data Type          | Port(s)         | Destination  |
|-----------------|--------------------|-----------------|--------------|
| Logstash        | NetFlow v5/v9/IPFIX| UDP 2055        | OpenSearch   |
| Logstash        | sFlow              | UDP 6343        | OpenSearch   |
| Logstash        | SNMP Traps         | UDP 162→1062    | OpenSearch   |
| Logstash        | Winlogbeat/Filebeat| TCP 5044        | OpenSearch   |
| Logstash        | Syslog             | UDP/TCP 514→5140| OpenSearch   |
| Fluent Bit      | Syslog             | UDP/TCP 514→5140| OpenSearch   |
| SNMP Exporter   | SNMP polling       | UDP 161 out     | Prometheus   |
| Pushgateway     | LibreNMS metrics   | TCP 9091 in     | Prometheus   |

## Visualization

| Tool                      | Port | Data Source            |
|---------------------------|------|------------------------|
| OpenSearch Dashboards     | 5601 | OpenSearch (logs/flows)|
| OpenSearch Dashboards     | 5601 | Prometheus (metrics)   |
| Prometheus UI             | 9090 | Prometheus             |
| Grafana (optional)        | 3000 | OpenSearch + Prometheus|

---

## Services and Ports

| Service                   | Port(s)            | Protocol      | Purpose                        |
|---------------------------|--------------------|---------------|--------------------------------|
| OpenSearch                | 9200               | HTTPS         | Log/flow/trap storage API      |
| OpenSearch Dashboards     | 5601               | HTTP          | Web UI for log search          |
| Logstash (NetFlow/IPFIX)  | 2055               | UDP           | NetFlow v5/v9/IPFIX ingest     |
| Logstash (sFlow)          | 6343               | UDP           | sFlow telemetry ingest         |
| Logstash (SNMP Traps)     | 1062               | UDP           | SNMP trap ingest               |
| Logstash (Beats/Endpoint) | 5044               | TCP           | Winlogbeat/Filebeat ingest     |
| Logstash (Syslog)         | 5140/5141          | UDP/TCP       | Syslog ingest (via NAT from 514)|
| Fluent Bit (Syslog)       | 5140/5141          | UDP/TCP       | Alternative syslog path       |
| SNMP Exporter             | 9116               | HTTP          | Prometheus SNMP metrics        |
| Prometheus Pushgateway    | 9091               | HTTP          | Metrics push ingress (LibreNMS)|
| Prometheus                | 9090               | HTTP          | Metrics storage & query engine |
| Grafana                   | 3000               | HTTP          | Alternative dashboard UI       |
| Redis                     | 6379               | TCP           | IP/threat intel enrichment     |

**Device Configuration Quick Reference:**
```
NetFlow/IPFIX    → host:2055 (UDP)
sFlow            → host:6343 (UDP)
Syslog           → host:514 (UDP/TCP, NATed to 5140/5141)
SNMP Traps       → host:162 (UDP, NATed to 1062)
Beats agents     → host:5044 (TCP)
```

---

## Quick Start

```bash
cp .env.example .env
chmod +x setup.sh
./setup.sh
```

For production profile:

```bash
podman compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

The setup script now supports Linux and macOS hosts. Linux-only kernel and iptables
steps are skipped automatically on macOS.

---

## Configuring LibreNMS (External)

Run these commands on your LibreNMS server, pointing it at this host:

```bash
lnms config:set prometheus.enable true
lnms config:set prometheus.url 'http://<this-host-ip>:9091'
lnms config:set prometheus.job 'librenms'
lnms config:set prometheus.prefix 'librenms'
```

LibreNMS will then push all SNMP poll metrics to the Pushgateway
after every polling cycle (~5 min). Prometheus scrapes those and
makes them available in OpenSearch Dashboards.

---

## Configuring Your Network Devices

| Data Type    | Point devices to         |
|--------------|--------------------------|
| NetFlow/IPFIX| UDP `<host-ip>:2055`     |
| sFlow        | UDP `<host-ip>:6343`     |
| Syslog       | UDP/TCP `<host-ip>:514`  |
| SNMP Traps   | UDP `<host-ip>:162`      |

For SNMP Exporter polling: add device IPs to `prometheus/prometheus.yml`
under the `snmp-interfaces` and `snmp-system` jobs.

## Vendor Normalization Included

The syslog pipeline normalizes common fields from:

- FortiGate key/value logs (`srcip`, `dstip`, `srcport`, `dstport`, `action`)
- Palo Alto TRAFFIC/THREAT CSV logs
- Cisco IOS-style `%FACILITY-SEV-MNEMONIC` messages
- Generic CEF messages (commonly used by Microsoft security tooling)

Mapped fields are aligned into ECS-like paths such as `source.ip`,
`destination.ip`, `source.port`, `destination.port`, and observer metadata.

Action and severity normalization is applied to align vendor semantics into
shared fields (`event.action`, `event.severity`) for easier cross-vendor search.

## Windows and Linux Endpoint Collection

- Windows endpoints: use [agents/winlogbeat.yml.example](agents/winlogbeat.yml.example)
- Linux endpoints: use [agents/filebeat-linux.yml.example](agents/filebeat-linux.yml.example)
- Send both to Logstash on TCP `5044`
- Events are indexed to `endpoint-*`

---

## OpenSearch Dashboards First-Time Setup

1. Go to `http://your-host:5601` → login as `admin / Ch@ngeMe123!`
2. **Index patterns** → create:
   - `netflow-*` (flows)
   - `syslog-*` (syslog)
   - `snmp-traps-*` (traps)
   - `endpoint-*` (Windows/Linux endpoint telemetry)
3. **Datasources** → add Prometheus at `http://127.0.0.1:9090`
   (requires the Prometheus datasource plugin)
4. Build dashboards or import community ones

---

## File Structure

```text
network-monitoring-v2/
├── .env.example
├── docker-compose.prod.yml
├── docker-compose.yml
├── setup.sh
├── README.md
├── docs/
│   └── OPERATIONS.md
├── agents/
│   ├── filebeat-linux.yml.example
│   └── winlogbeat.yml.example
├── scripts/
│   └── bootstrap-opensearch.sh
├── logstash/
│   ├── Dockerfile
│   ├── config/logstash.yml
│   └── pipeline/
│       ├── endpoints.conf             Win/Linux Beats → OpenSearch
│       ├── netflow.conf               NetFlow/IPFIX/sFlow → OpenSearch
│       ├── snmp-trap.conf             SNMP Traps → OpenSearch
│       └── syslog.conf                Syslog → OpenSearch
├── grafana/
│   └── provisioning/
│       └── datasources/
│           └── datasources.yml
├── fluent-bit/
│   ├── fluent-bit.conf                Syslog → OpenSearch
│   ├── fluent-bit.prod.conf           TLS verify enabled profile
│   └── parsers.conf
├── prometheus/
│   ├── alerts.yml                     Alert rules
│   └── prometheus.yml                 Scrape config (add device IPs here)
└── snmp-exporter/
    └── snmp.yml                       SNMP OID definitions
```

---

## Security and Secrets

- Secrets are now sourced from `.env`.
- Do not commit `.env`.
- Rotate at minimum: `OPENSEARCH_ADMIN_PASSWORD`, `SNMP_TRAP_COMMUNITY`
- For production, use the override file and valid certificates: `docker-compose.prod.yml`

## Retention and Alerts

- OpenSearch retention policies are applied by `opensearch-bootstrap` for `netflow-*`, `syslog-*`, `snmp-traps-*`.
- Rollover is `1d` or `30gb`, delete is `90d`.
- Prometheus alerting rules are in `prometheus/alerts.yml`.

## Performance Tuning

- New OpenSearch indices now get single-node templates for `netflow-*`, `syslog-*`, `snmp-traps-*`, and `endpoint-*`.
- Templates set `number_of_shards=1`, `number_of_replicas=0`, `refresh_interval=30s`, and `codec=best_compression`.
- Result: lower disk usage, better ingest throughput, and fewer wasted shards on a single-node deployment.
- Note: these settings apply to newly created indices. Existing indices keep their current settings unless reindexed.
