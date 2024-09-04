#!/bin/bash -eu
set -o pipefail

ipvar="0.0.0.0"

# These should be set in the .env file
declare LinuxDR
declare WindowsDR
declare MacOSDR

declare COMPOSE

# Ignore following warning
# shellcheck disable=SC1091
. .env

HEADERS=(
  -H "kbn-version: ${STACK_VERSION}"
  -H "kbn-xsrf: kibana"
  -H 'Content-Type: application/json'
)

passphrase_reset() {
  if grep -Fq "changeme" .env; then
    echo "Sorry, looks like you haven't updated the passphrase from the default"
    echo "Please update the changeme passphrases in the .env file."
    exit 1
  else
    echo "Passphrase has been reset. Proceeding."
  fi
}

# Create the script usage menu
usage() {
  cat <<EOF | sed -e 's/^  //'
  usage: ./elastic-container.sh [-v] (stage|start|stop|restart|status|help)
  actions:
    stage     downloads all necessary images to local storage
    start     creates a container network and starts containers
    stop      stops running containers without removing them
    destroy   stops and removes the containers, the network, and volumes created
    restart   restarts all the stack containers
    status    check the status of the stack containers
    clear     clear all documents in logs and metrics indexes
    help      print this message
  flags:
    -v        enable verbose output
EOF
}

# Create a function to enable the Detection Engine and load prebuilt rules in Kibana
configure_kbn() {
  MAXTRIES=15
  i=${MAXTRIES}

  while [ $i -gt 0 ]; do
    STATUS=$(curl -I -k --silent "${LOCAL_KBN_URL}" | head -n 1 | cut -d ' ' -f2)
    echo
    echo "Attempting to enable the Detection Engine and install prebuilt Detection Rules."

    if [ "${STATUS}" == "302" ]; then
      echo
      echo "Kibana is up. Proceeding."
      echo
      output=$(curl -k --silent "${HEADERS[@]}" --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPOST "${LOCAL_KBN_URL}/api/detection_engine/index")
      [[ ${output} =~ '"acknowledged":true' ]] || (
        echo
        echo "Detection Engine setup failed :-("
        exit 1
      )

      echo "Detection engine enabled. Installing prepackaged rules."
      curl -k --silent "${HEADERS[@]}" --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${LOCAL_KBN_URL}/api/detection_engine/rules/prepackaged" 1>&2

      echo
      echo "Prepackaged rules installed!"
      echo
      if [[ "${LinuxDR}" -eq 0 && "${WindowsDR}" -eq 0 && "${MacOSDR}" -eq 0 ]]; then
        echo "No detection rules enabled in the .env file, skipping detection rules enablement."
        echo
        break
      else
        echo "Enabling detection rules"
        if [ "${LinuxDR}" -eq 1 ]; then

          curl -k --silent "${HEADERS[@]}" --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X POST "${LOCAL_KBN_URL}/api/detection_engine/rules/_bulk_action" -d'
            {
              "query": "alert.attributes.tags: (\"Linux\" OR \"OS: Linux\")",
              "action": "enable"
            }
            ' 1>&2
          echo
          echo "Successfully enabled Linux detection rules"
        fi
        if [ "${WindowsDR}" -eq 1 ]; then

          curl -k --silent "${HEADERS[@]}" --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X POST "${LOCAL_KBN_URL}/api/detection_engine/rules/_bulk_action" -d'
            {
              "query": "alert.attributes.tags: (\"Windows\" OR \"OS: Windows\")",
              "action": "enable"
            }
            ' 1>&2
          echo
          echo "Successfully enabled Windows detection rules"
        fi
        if [ "${MacOSDR}" -eq 1 ]; then

          curl -k --silent "${HEADERS[@]}" --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X POST "${LOCAL_KBN_URL}/api/detection_engine/rules/_bulk_action" -d'
            {
              "query": "alert.attributes.tags: (\"macOS\" OR \"OS: macOS\")",
              "action": "enable"
            }
            ' 1>&2
          echo
          echo "Successfully enabled MacOS detection rules"
        fi
      fi
      echo
      break
    else
      echo
      echo "Kibana still loading. Trying again in 40 seconds"
    fi

    sleep 40
    i=$((i - 1))
  done
  [ $i -eq 0 ] && echo "Exceeded MAXTRIES (${MAXTRIES}) to setup detection engine." && exit 1
  return 0
}

get_host_ip() {
  os=$(uname -s)
  if [ "${os}" == "Linux" ]; then
    ipvar=$(hostname -I | awk '{ print $1}')
  elif [ "${os}" == "Darwin" ]; then
    ipvar=$(ifconfig en0 | awk '$1 == "inet" {print $2}')
  fi
}

set_fleet_values() {
  # Get the current Fleet settings
  CURRENT_SETTINGS=$(curl -k -s -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X GET "${LOCAL_KBN_URL}/api/fleet/agents/setup" -H "Content-Type: application/json")

  # Check if Fleet is already set up
  if echo "$CURRENT_SETTINGS" | grep -q '"isInitialized": true'; then
    echo "Fleet settings are already configured."
    return
  fi

  echo "Fleet is not initialized, setting up Fleet..."
  
  fingerprint=$(${COMPOSE} exec -w /usr/share/elasticsearch/config/certs/ca elasticsearch cat ca.crt | openssl x509 -noout -fingerprint -sha256 | cut -d "=" -f 2 | tr -d :)
  printf '{"fleet_server_hosts": ["%s"]}' "https://${ipvar}:${FLEET_PORT}" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/settings" -d @- | jq
  printf '{"hosts": ["%s"]}' "https://${ipvar}:9200" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq
  printf '{"ca_trusted_fingerprint": "%s"}' "${fingerprint}" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq
  printf '{"config_yaml": "%s"}' "ssl.verification_mode: certificate" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq
  policy_id=$(printf '{"name": "%s", "description": "%s", "namespace": "%s", "monitoring_enabled": ["logs","metrics"], "inactivity_timeout": 1209600}' "Endpoint Policy" "" "default" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPOST "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/agent_policies?sys_monitoring=true" -d @- | jq -r '.item.id')
  pkg_version=$(curl -k --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XGET "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/epm/packages/endpoint" -d : | jq -r '.item.version')
  printf "{\"name\": \"%s\", \"description\": \"%s\", \"namespace\": \"%s\", \"policy_id\": \"%s\", \"enabled\": %s, \"inputs\": [{\"enabled\": true, \"streams\": [], \"type\": \"ENDPOINT_INTEGRATION_CONFIG\", \"config\": {\"_config\": {\"value\": {\"type\": \"endpoint\", \"endpointConfig\": {\"preset\": \"EDRComplete\"}}}}}], \"package\": {\"name\": \"endpoint\", \"title\": \"Elastic Defend\", \"version\": \"${pkg_version}\"}}" "Elastic Defend" "" "default" "${policy_id}" "true" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPOST "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/package_policies" -d @- | jq
}

clear_documents() {
  if (($(curl -k --silent "${HEADERS[@]}" --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X DELETE "https://${ipvar}:9200/_data_stream/logs-*" | grep -c "true") > 0)); then
    printf "Successfully cleared logs data stream"
  else
    printf "Failed to clear logs data stream"
  fi
  echo
  if (($(curl -k --silent "${HEADERS[@]}" --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X DELETE "https://${ipvar}:9200/_data_stream/metrics-*" | grep -c "true") > 0)); then
    printf "Successfully cleared metrics data stream"
  else
    printf "Failed to clear metrics data stream"
  fi
  echo
}

# Logic to enable the verbose output if needed
OPTIND=1 # Reset in case getopts has been used previously in the shell.

verbose=0

while getopts "v" opt; do
  case "$opt" in
  v)
    verbose=1
    ;;
  *) ;;
  esac
done

shift $((OPTIND - 1))

[ "${1:-}" = "--" ] && shift

ACTION="${*:-help}"

if [ $verbose -eq 1 ]; then
  exec 3<>/dev/stderr
else
  exec 3<>/dev/null
fi

if docker compose >/dev/null; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null; then
  COMPOSE="docker-compose"
else
  echo "elastic-container requires docker compose!"
  exit 2
fi

case "${ACTION}" in

"stage")
  # Collect the Elastic, Kibana, and Elastic-Agent Docker images
  docker pull "docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}"
  docker pull "docker.elastic.co/kibana/kibana:${STACK_VERSION}"
  docker pull "docker.elastic.co/beats/elastic-agent:${STACK_VERSION}"
  ;;

"start")
  passphrase_reset

  get_host_ip

  echo "Starting Elastic Stack network and containers."

  ${COMPOSE} up -d --no-deps 

  configure_kbn 1>&2 2>&3

  echo "Waiting 40 seconds for Fleet Server setup."
  echo

  sleep 40

  echo "Populating Fleet Settings."
  set_fleet_values > /dev/null 2>&1
  echo

  echo "READY SET GO!"
  echo
  echo "Browse to https://localhost:${KIBANA_PORT}"
  echo "Username: ${ELASTIC_USERNAME}"
  echo "Passphrase: ${ELASTIC_PASSWORD}"
  echo
  ;;

"stop")
  echo "Stopping running containers."

  ${COMPOSE} stop 
  ;;

"destroy")
  echo "#####"
  echo "Stopping and removing the containers, network, and volumes created."
  echo "#####"
  ${COMPOSE} down -v
  ;;

"restart")
  echo "#####"
  echo "Restarting all Elastic Stack components."
  echo "#####"
  ${COMPOSE} restart elasticsearch kibana fleet-server
  ;;

"status")
  ${COMPOSE} ps | grep -v setup
  ;;

"clear")
  clear_documents
  ;;

"help")
  usage
  ;;

*)
  echo -e "Proper syntax not used. See the usage\n"
  usage
  ;;
esac

# Close FD 3
exec 3>&-
