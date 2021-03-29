#!/bin/bash
# Usage: 
# "./elastic-container.sh start" to start an Elasticsearch node and connected Kibana instance.
# "./elastic-container.sh stop" to stop an Elasticsearch node and connected Kibana instance.
# "./elastic-container.sh status" to get the status of the Elasticsearch node and connected Kibana instance.
# No data is retained!

if [ $1 == start ]
then
docker network create elastic
docker run -d --network elastic --rm --name elasticsearch -p 9200:9200 -p 9300:9300 \
-e "discovery.type=single-node" \
-e "xpack.security.enabled=true" \
-e "xpack.security.authc.api_key.enabled=true" \
-e "ELASTIC_PASSWORD=password" \
docker.elastic.co/elasticsearch/elasticsearch:8.0.0-SNAPSHOT
docker run -d --network elastic --rm --name kibana -p 5601:5601 \
-v $(pwd)/kibana.yml:/usr/share/kibana/config/kibana.yml \
-e "ELASTICSEARCH_HOSTS=http://elasticsearch:9200" \
-e "ELASTICSEARCH_USERNAME=elastic" \
-e "ELASTICSEARCH_PASSWORD=password" \
docker.elastic.co/kibana/kibana:8.0.0-SNAPSHOT

else
if [ $1 == stop ]
then
docker stop elasticsearch
docker stop kibana
docker network rm elastic

else
if [ $1 == status ]
then
docker ps -f "name=kibana" -f "name=elasticsearch" --format "table {{.Names}}: {{.Status}}"

else
echo "Proper syntax not used. Try ./elastic-container {start,stop,status}"
fi
fi
fi
