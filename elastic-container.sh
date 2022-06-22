#!/bin/bash -eu 
set -o pipefail

ipvar="0.0.0.0"

. .env

HEADERS=(
  -H "kbn-version: ${STACK_VERSION}"
  -H "kbn-xsrf: kibana"
  -H 'Content-Type: application/json'
)

# Create the script usage menu
usage() {
  cat <<EOF | sed -e 's/^  //'
  usage: ./elastic-container.sh [-v] (stage|start|stop|restart|status|help)
  actions:
    stage     downloads all necessary images to local storage
    start     creates network and starts containers 
    stop      stops running containers without removing them 
    destroy   stops and removes the containers, the network and volumes created
    restart   simply restarts all the stack containers
    status    check the status of the stack containers
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
    echo "Attempting to enable the Detection Engine and Prebuilt-Detection Rules"

    if [ "${STATUS}" == "302" ]; then
      echo
      echo "Kibana is up. Proceeding"
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
      echo "Prebuilt Detections Enabled!"
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
  if [ ${os} == "Linux" ]; then
    ipvar=$(hostname -I | awk '{ print $1}')
  elif [ ${os} == "Darwin" ]; then
    ipvar=$(ifconfig en0 | awk '$1 == "inet" {print $2}')
  fi
}

set_fleet_values() {
  fingerprint=$(docker compose exec -w /usr/share/elasticsearch/config/certs/ca elasticsearch cat ca.crt | openssl x509 -noout -fingerprint -sha256 | cut -d "=" -f 2 | tr -d :)
  printf '{"fleet_server_hosts": ["%s"]}' "https://${ipvar}:${FLEET_PORT}" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/settings" -d @- | jq 
  printf '{"hosts": ["%s"]}' "https://${ipvar}:9200" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq 
  printf '{"ca_trusted_fingerprint": "%s"}' "${fingerprint}" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq 
  # printf '{"config_yaml": "%s"}' "ssl.verification_mode: none" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq 
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

case "${ACTION}" in

"stage")
  # Collect the Elastic, Kibana, and Elastic-Agent Docker images
  docker pull "docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}"
  docker pull "docker.elastic.co/kibana/kibana:${STACK_VERSION}"
  docker pull "docker.elastic.co/beats/elastic-agent:${STACK_VERSION}"
  ;;

"start")
  get_host_ip

  echo "Starting Elastic Stack network and containers"

  docker-compose up -d --no-deps

  configure_kbn 1>&2 2>&3

  echo "Waiting 40 seconds for Fleet Server setup"
  echo

  sleep 40

  echo "Populating Fleet Settings"
  set_fleet_values > /dev/null 2>&1
  echo

  echo "READY SET GO!"
  echo
  echo "Browse to https://localhost:5601"
  echo "Username: ${ELASTIC_USERNAME}"
  echo "Passphrase: ${ELASTIC_PASSWORD}"
  echo
  ;;

"stop")
  echo "Stopping running containers."
  
  docker-compose stop
  ;;

"destroy")
  echo "#####"
  echo "Stopping and removing the containers, network and volumes created."
  echo "#####"
  docker-compose down -v
  ;;

"restart")
  echo "#####"
  echo "Restarting all Elastic Stack components."
  echo "#####"
  docker-compose restart 2>&3
  ;;

"status")
  docker-compose ps -a
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