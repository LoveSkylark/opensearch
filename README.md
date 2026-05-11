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
│    ├─ NetFlow/IPFIX (UDP 2055) ──► Logstash ──► OpenSearch  │
│    ├─ sFlow        (UDP 6343) ──► Logstash ──► OpenSearch   │
│    ├─ SNMP Traps   (UDP 162)  ──► Logstash ──► OpenSearch   │
│    ├─ Syslog       (UDP 514)  ──► Logstash ──► OpenSearch   │
│    │                          └─► Fluent Bit ─► OpenSearch  │
│    └─ SNMP Poll               ──► SNMP Exporter             │
│                                         │                   │
│                               Prometheus◄┘                  │
│                               + Pushgateway (LibreNMS in)   │
│                                    │                        │
│                          OpenSearch Dashboards              │
│                          (reads OpenSearch + Prometheus)    │
└─────────────────────────────────────────────────────────────┘
```text

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
│       ├── endpoints.conf     Win/Linux Beats → OpenSearch
│       ├── netflow.conf       NetFlow/IPFIX/sFlow → OpenSearch
│       ├── snmp-trap.conf     SNMP Traps → OpenSearch
│       └── syslog.conf        Syslog → OpenSearch
├── grafana/
│   └── provisioning/
│       └── datasources/
│           └── datasources.yml
├── fluent-bit/
│   ├── fluent-bit.conf        Syslog → OpenSearch
│   ├── fluent-bit.prod.conf   TLS verify enabled profile
│   └── parsers.conf
├── prometheus/
│   ├── alerts.yml             Alert rules
│   └── prometheus.yml         Scrape config (add device IPs here)
└── snmp-exporter/
    └── snmp.yml               SNMP OID definitions
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
