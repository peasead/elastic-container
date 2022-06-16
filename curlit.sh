#!/bin/bash

# Define variables
ELASTIC_USERNAME="elastic"
ELASTIC_PASSWORD="elastic"
ELASTICSEARCH_URL="http://elasticsearch:9200"
LOCAL_ES_URL="http://127.0.0.1:9200"
KIBANA_URL="https://kibana:5601"
LOCAL_KBN_URL="https://127.0.0.1:5601"
FLEET_URL="http://fleet-server:8220"
STACK_VERSION="8.2.0"
HEADERS=(
  -H "kbn-version: ${STACK_VERSION}"
  -H "kbn-xsrf: fleet"
  -H 'Content-Type: application/json'
)

fleet_server_host=$(printf '{"fleet_server_hosts": ["%s"]}' "${FLEET_URL}" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/settings" -d @- | jq)

fleet_output_hosts=$(printf '{"hosts": ["%s"]}' "${ELASTICSEARCH_URL}" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq)

ca_fingerprint=$(printf '{"ca_trusted_fingerprint": "%s"}' "TESTING" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq)

ssl_verification_mode=$(printf '{"config_yaml": "%s"}' "ssl.verification.mode: certificate" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq)


echo
echo "Fleet Server Host Value Set - ${fleet_server_host}"
echo 
echo "Fleet Settings Output Hosts Set - ${fleet_output_hosts}"
echo
echo "CA Trusted Fingerprint Set - ${ca_fingerprint}"
echo
echo "SSL Verification Mode Set - ${ssl_verification_mode}"
