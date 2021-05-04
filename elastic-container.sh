#!/bin/bash
# Usage:
# "./elastic-container.sh start" to start the Elasticsearch node and connected Kibana instance.
# "./elastic-container.sh stop" to stop the Elasticsearch node and connected Kibana instance.
# "./elastic-container.sh stop" to restart the Elasticsearch node and connected Kibana instance.
# "./elastic-container.sh status" to get the status of the Elasticsearch node and connected Kibana instance.
# No data is retained!

# Define variables
ELASTIC_PASSWORD="password"
ELASTICSEARCH_URL="http://elasticsearch:9200"
STACK_VERSION="7.12.1"
#STACK_VERSION="8.0.0-SNAPSHOT"

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
echo "Proper syntax not used. Try ./elastic-container {start,stop,restart,status}"
fi
fi
fi
fi
