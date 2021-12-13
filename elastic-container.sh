#!/bin/bash

# Simple script to start an Elasticsearch and Kibana instance with Fleet and the Detection Engine. No data is retained. For information on customizing, see the Github repository.
#
# Usage:
# sh elastic-container.sh [OPTION]
#
# Options:
# stage - download the Elasticsearch, Kibana, and Elastic-Agent Docker images. This does not start them.
# start - start the Elasticsearch node, connected Kibana instance, and start the Elastic-Agent as a Fleet Server.
# stop - stop the Elasticsearch node, connected Kibana instance, and Fleet Server.
# restart - restart the Elasticsearch, connected Kibana instance, and Fleet Server.
# status - get the status of the Elasticsearch node, connected Kibana instance, and Fleet Server.
#
# More information at https://github.com/peasead/elastic-container"

# Define variables
ELASTIC_PASSWORD="password"
ELASTICSEARCH_URL="http://elasticsearch:9200"
KIBANA_URL="http://kibana:5601"
KIBANA_PASSWORD="password"
STACK_VERSION="7.16.1"

# Collect the Elastic, Kibana, and Elastic-Agent Docker images
if [ $1 == stage ] 2> /dev/null
then
docker pull docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
docker pull docker.elastic.co/kibana/kibana:${STACK_VERSION}
docker pull docker.elastic.co/beats/elastic-agent:${STACK_VERSION}

# Create the Docker network
else
if [ $1 == start ] 2> /dev/null
then
docker network create elastic 2> /dev/null

# Start the Elasticsearch container
docker run -d --network elastic --rm --name elasticsearch -p 9200:9200 -p 9300:9300 \
-e "discovery.type=single-node" \
-e "xpack.security.enabled=true" \
-e "xpack.security.authc.api_key.enabled=true" \
-e "ELASTIC_PASSWORD=${ELASTIC_PASSWORD}" \
docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}

# Start the Kibana container
docker run -d --network elastic --rm --name kibana -p 5601:5601 \
-v $(pwd)/kibana.yml:/usr/share/kibana/config/kibana.yml \
-e "ELASTICSEARCH_HOSTS=${ELASTICSEARCH_URL}" \
-e "ELASTICSEARCH_USERNAME=elastic" \
-e "ELASTICSEARCH_PASSWORD=${ELASTIC_PASSWORD}" \
docker.elastic.co/kibana/kibana:${STACK_VERSION}

# Start the Elastic Fleet Server container
docker run -d --network elastic --rm --name fleet-server -p 8220:8220 \
-e "KIBANA_HOST=${KIBANA_URL}" \
-e "KIBANA_USERNAME=elastic" \
-e "KIBANA_PASSWORD=${KIBANA_PASSWORD}" \
-e "ELASTICSEARCH_HOSTS=${ELASTICSEARCH_URL}" \
-e "ELASTICSEARCH_USERNAME=elastic" \
-e "ELASTICSEARCH_PASSWORD=${ELASTIC_PASSWORD}" \
-e "KIBANA_FLEET_SETUP=1" \
-e "FLEET_SERVER_ENABLE=1" \
-e "FLEET_SERVER_INSECURE_HTTP=1" \
docker.elastic.co/beats/elastic-agent:${STACK_VERSION}
echo
echo "Browse to http://localhost:5601"
echo "Username: elastic"
echo "Passphrase: ${ELASTIC_PASSWORD}"

# Stop and remove the Elastic containers and network
else
if [ $1 == stop ] 2> /dev/null
then
echo "#####"
echo "Stopping and removing all Elastic Stack components."
echo "#####"
docker stop fleet-server 2> /dev/null
docker stop kibana 2> /dev/null
docker stop elasticsearch 2> /dev/null
docker network rm elastic 2> /dev/null

# Restart the Elastic containers
else
if [ $1 == restart ] 2> /dev/null
then
echo "#####"
echo "Restarting all Elastic Stack components."
echo "#####"
docker restart elasticsearch 2> /dev/null
docker restart kibana 2> /dev/null
docker restart fleet-server 2> /dev/null

# Get the status of the Elastic containers
else
if [ $1 == status ] 2> /dev/null
then
docker ps -f "name=kibana" -f "name=elasticsearch" -f "name=fleet-server" --format "table {{.Names}}: {{.Status}}"

# Usage helper
else
echo "Proper syntax not used. Try ./elastic-container {stage,start,stop,restart,status}"
fi
fi
fi
fi
fi
