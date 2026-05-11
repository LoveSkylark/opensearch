FROM opensearchproject/logstash-oss-with-opensearch-output-plugin:8.6.1

# NetFlow v5/v9/IPFIX codec
RUN bin/logstash-plugin install logstash-codec-netflow

# GeoIP enrichment
RUN bin/logstash-plugin install logstash-filter-geoip

USER root
RUN mkdir -p /usr/share/logstash/GeoIP
USER logstash
