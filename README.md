# Elastic Container

*Note: * The Elastic Container project is not sponsored or maintained by the Elastic company.

Stand up simple Elastic containers with Elasticsearch, Kibana, the Elastic Agent (acting as a Fleet server), and the Detection Engine.

![elastic-container](https://user-images.githubusercontent.com/7442091/182709910-bd50c87e-0407-478d-8216-c883631cbda9.png)

## Requirements

Requirements are minimal: \*NIX or macOS, [docker](https://docs.docker.com/get-docker/), [docker-compose](https://docs.docker.com/compose/), [jq](https://stedolan.github.io/jq/download/), [curl](https://curl.se/download.html), and [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git).

You can use the links above, other methods you prefer, or if you're using macOS (and have [Homebrew](https://brew.sh/))

```
brew install jq git curl docker-compose
brew install docker --cask
```

## Usage

This uses default creds of `elastic:elastic`, change this in the `.env` file. Don't be that person that leaves default creds.

This uses basic authentication and self-signed TLS certificates; if you are planning on using this in production, you should use valid TLS certificates.

The concept is to use for testing -> see the Elastic [documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/secure-cluster.html) on securing the stack.

### Starting

Starting this will:
- create a Docker network called `elastic-container-default`
- download the Elasticsearch, Kibana, and Elastic-Agent Docker images defined in the script
- start Elasticsearch, Kibana, and the Elastic-Agent configured as a Fleet Server w/all settings needed for Fleet and the Detection Engine

```
$ ./elastic-container.sh start

99e03383cf824cd2e04d061fcf59c057fc78616bb877929309f2e1db76e9ea73
ccf21bd36ccbfcca885ed519ace053cc5506cf1248e9dd854f4e22582e0cfef1
a7214e3c112fd330e32404dbf1b01eeef2733e3629ac897a964e829dad6981dd
24ad732eb62e0c69e4bb0f204a5150251f1d78cf3f286780d26d3478b3b7fec1
```
After a few minutes browse to https://localhost:5601 and log in with `elastic:elastic` (or whatever you changed it to in `.env` - you DID change it right?).

### Destroying

Destroying this will:
- stop the Elasticsearch and Kibana containers
- delete the Elasticsearch and Kibana containers
- delete the `elastic-container-default` container network
- delete the created volumes

```
$ ./elastic-container.sh destroy

fleet-server
kibana
elasticsearch
elastic
```

### Stopping

Stopping this will:
- stop the Elasticsearch and Kibana containers without deleting them

```
$ ./elastic-container.sh stop

fleet-server
kibana
elasticsearch
elastic
```

### Restarting

Restarting this will:
- restart the containers

```
$ ./elastic-container.sh restart

elasticsearch
kibana
fleet-server
```

### Status

Return the status of the containers.

```
$ ./elastic-container.sh status

NAMES: STATUS
fleet-server: Up 6 minutes
kibana: Up 6 minutes
elasticsearch: Up 6 minutes
```

### Staging

Download container images, but not start them.

```
$ ./elastic-container.sh stage

8.3.0: Pulling from elasticsearch/elasticsearch
7aabcb84784a: Already exists
e3f44495617d: Downloading [====> ]  916.5kB/11.26MB
52008db3f842: Download complete
551b59c59fdc: Downloading [>     ]  527.4kB/366.9MB
25ee26aa662e: Download complete
7a85d02d9264: Download complete
...
```

## Modifying

In `elastic-container.sh`, the variables are defined, any can be changed.
```
ELASTIC_PASSWORD="elastic"
KIBANA_PASSWORD="kibana"
STACK_VERSION="8.3.0"
```

If you want to change the default values, simply replace whatever is appropriate in the variable declaration.

If you want to use different Elastic Stack versions, you can change those as well. Optional values are on Elastic's Docker hub:

- [Elasticsearch](https://hub.docker.com/r/elastic/elasticsearch/tags?page=1&ordering=last_updated)
- [Kibana](https://hub.docker.com/r/elastic/kibana/tags?page=1&ordering=last_updated)
- [Elastic-Agent](https://hub.docker.com/r/elastic/elastic-agent/tags?page=1&ordering=last_updated)
