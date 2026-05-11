# ClickHouse NetFlow table schema
# Run this manually or via initialization script to set up analytics tables

CREATE TABLE IF NOT EXISTS netflow_events (
    timestamp DateTime,
    src_ip String,
    dst_ip String,
    src_port UInt16,
    dst_port UInt16,
    protocol UInt8,
    bytes_in Int64,
    bytes_out Int64,
    packets_in Int64,
    packets_out Int64,
    action String,
    observer_vendor String,
    observer_product String,
    source_geo_country_code String,
    destination_geo_country_code String
) ENGINE = MergeTree()
ORDER BY timestamp
TTL timestamp + INTERVAL 1 YEAR;

CREATE TABLE IF NOT EXISTS netflow_events_1h AS SELECT * FROM netflow_events
ENGINE = SummingMergeTree()
ORDER BY (timestamp, src_ip, dst_ip, src_port, dst_port)
PARTITION BY toYYYYMM(timestamp)
TTL timestamp + INTERVAL 3 YEAR;
