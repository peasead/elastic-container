#!/bin/bash

# Simple script to start an Elasticsearch and Kibana instance with Fleet and the Detection Engine. No data is retained. For information on customizing, see the Github repository.
#
# Usage:
# sh elastic-container.sh {option}
#
# Options:
# stage - download the Elasticsearch and Kibana nodes. This does not start them.
# start - start the Elasticsearch node and connected Kibana instance.
# stop - stop the Elasticsearch node and connected Kibana instance.
# restart - restart the Elasticsearch node and connected Kibana instance.
# status - get the status of the Elasticsearch node and connected Kibana instance.
#
# More information at https://github.com/peasead/elastic-container"

# Define variables
ELASTIC_PASSWORD="password"
ELASTICSEARCH_URL="http://elasticsearch:9200"
STACK_VERSION="7.13.0"
#STACK_VERSION="8.0.0-SNAPSHOT"

Help

if [ $1 == stage ] 2> /dev/null
then
docker pull docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
docker pull docker.elastic.co/kibana/kibana:${STACK_VERSION}

else
if [ $1 == start ] 2> /dev/null
then
docker network create elastic 2> /dev/null
docker run -d --network elastic --rm --name elasticsearch -p 9200:9200 -p 9300:9300 \
-e "discovery.type=single-node" \
-e "xpack.security.enabled=true" \
-e "xpack.security.authc.api_key.enabled=true" \
-e "ELASTIC_PASSWORD=${ELASTIC_PASSWORD}" \
docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
docker run -d --network elastic --rm --name kibana -p 5601:5601 \
-v $(pwd)/kibana.yml:/usr/share/kibana/config/kibana.yml \
-e "ELASTICSEARCH_HOSTS=${ELASTICSEARCH_URL}" \
-e "ELASTICSEARCH_USERNAME=elastic" \
-e "ELASTICSEARCH_PASSWORD=${ELASTIC_PASSWORD}" \
docker.elastic.co/kibana/kibana:${STACK_VERSION}

else
if [ $1 == stop ] 2> /dev/null
then
docker stop elasticsearch 2> /dev/null
docker stop kibana 2> /dev/null
docker network rm elastic 2> /dev/null

else
if [ $1 == restart ] 2> /dev/null
then
docker restart elasticsearch 2> /dev/null
docker restart kibana 2> /dev/null

else
if [ $1 == status ] 2> /dev/null
then
docker ps -f "name=kibana" -f "name=elasticsearch" --format "table {{.Names}}: {{.Status}}"

else
echo "Proper syntax not used. Try ./elastic-container {stage,start,stop,restart,status}"
fi
fi
fi
fi
fi
