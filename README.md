# Elastic Container

Stand up a simple Elastic container with Kibana, Fleet, and the Detection Engine

## Usage

This uses default creds of `elastic:password` and is intended purely for rapid testing a local Elastic stack.

There is zero security enabled, beyond basic auth, and this should not be Internet exposed or used anywhere in production.

There is zero saved data, everything is wiped when the containers are stopped. Again, not meant for anything but testing.

### Starting

Running this will:
- create a network called `elastic`
- download the Elasticsearch, Kibana, and Elastic-Agent Docker images defined in the script
- start Elasticsearch, Kibana, and the Elastic-Agent configured as a Fleet Server w/all settings needed for Fleet and the Detection Engine

```
$ sh elastic-container.sh start

99e03383cf824cd2e04d061fcf59c057fc78616bb877929309f2e1db76e9ea73
ccf21bd36ccbfcca885ed519ace053cc5506cf1248e9dd854f4e22582e0cfef1
a7214e3c112fd330e32404dbf1b01eeef2733e3629ac897a964e829dad6981dd
24ad732eb62e0c69e4bb0f204a5150251f1d78cf3f286780d26d3478b3b7fec1
```
After a few minutes browse to http://localhost:5601 and log in with `elastic:password`.

### Stopping

Stopping this will:
- stop the Elasticsearch and Kibana containers
- delete the Elasticsearch and Kibana containers
- delete the `elastic` container network

```
$ sh elastic-container.sh stop

fleet-server
kibana
elasticsearch
elastic
```

### Restarting

Stopping this will:
- restart the containers

```
$ sh elastic-container.sh restart

elasticsearch
kibana
fleet-server
```

### Status

Return the status of the containers.

```
$ sh elastic-container.sh status

NAMES: STATUS
fleet-server: Up 6 minutes
kibana: Up 6 minutes
elasticsearch: Up 6 minutes
```

### Staging

Download container images, but not start them.

```
$ sh elastic-container.sh stage

7.15.0: Pulling from elasticsearch/elasticsearch
e7bd69ff4774: Pull complete
d0a0f12aaf30: Pull complete
...
```

## Modifying

In `elastic-container.sh`, the variables are defined, any can be changed.
```
ELASTIC_PASSWORD="password"
ELASTICSEARCH_URL="http://elasticsearch:9200"
KIBANA_PASSWORD="password"
KIBANA_URL="http://kibana:5601"
STACK_VERSION="7.15.0"
```

If you want to change the default values, simply replace whatever is appropriate in the variable declaration.

If you want to use different Elastic Stack versions, you can change those as well. Optional values are on Elastic's Docker hub:

- [Elasticsearch](https://hub.docker.com/r/elastic/elasticsearch/tags?page=1&ordering=last_updated)
- [Kibana](https://hub.docker.com/r/elastic/kibana/tags?page=1&ordering=last_updated)
- [Elastic-Agent](https://hub.docker.com/r/elastic/elastic-agent/tags?page=1&ordering=last_updated)

If you want to retain the data in Elasticsearch, remove the `--rm` from the `docker run` lines in `elastic-container.sh`. This is not recommended as there are no mounted volumes.

## Questions

1. But...why?  
To test data feeds, ingest pipelines, detection rules, Fleet configs...w/e. Something I could blow away fast but had the bare necessities.

1. Why don't you use Docker Compose?  
Old habbits.

1. This is horrible, why can't you write better scripts?  
Function over beauty.

1. I suppose I can use this, can I change the creds or stack version?  
Of course.

1. Elastic-Agent or Fleet Server, what's the difference?  
The Elastic-Agent acts as the Fleet Server role. More information can be found on the [official documentation](https://www.elastic.co/guide/en/fleet/current/fleet-server.html).
