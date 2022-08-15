# The Elastic Container Project

Stand up a 100% containerized Elastic stack, TLS secured, with Elasticsearch, Kibana, Fleet, and the Detection Engine all pre-configured, enabled and ready to use, within minutes.

[![elastic-container.png](https://i.postimg.cc/J7TpsqKJ/elastic-container.png)](https://postimg.cc/NLH6VR3f)

## Requirements

### Operating System: 

- Linux or MacOS 

### Prerequisites: 

- [docker](https://docs.docker.com/get-docker/), [docker-compose](https://docs.docker.com/compose/), [jq](https://stedolan.github.io/jq/download/), [curl](https://curl.se/download.html), and [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git).

You can use the links above, the Linux package install commands below, or [Homebrew](https://brew.sh/) if your'e on MacOS

NOTE! You might want to assume that some of these tools (like curl or jq) are present by default on your OS or distrobution of choice, DON'T. If you attempt to start this project and it hangs or errors out you can assume that you are missing a neccessary prerequisite.

MacOS:
```
brew install docker jq git curl docker-compose
```
Debian or Ubuntu:
```
apt install docker jq git curl docker-compose
```
Fedora or CentOS:
```
yum install docker jq git curl docker-compose
```

## Steps

1. Install required pre-reqs 

2. Git clone this repo

3. Cd (change directory) into the elastic-container/ folder

4. Execute the elastic-container.sh shell script with the start argument ./elastic-container start

5. Wait for the prompt to tell you to browse to https://localhost:5601

## Usage

This uses default creds of `elastic:elastic` and is intended purely for security research on a local Elastic stack.

This should not be Internet exposed or used in a production environment.

### Starting

Starting will:
- create a network called `elastic`
- download the Elasticsearch, Kibana, and Elastic-Agent Docker images defined in the script
- start Elasticsearch, Kibana, and the Elastic-Agent configured as a Fleet Server w/all settings needed for Fleet and the Detection Engine

```
$ ./elastic-container.sh start

99e03383cf824cd2e04d061fcf59c057fc78616bb877929309f2e1db76e9ea73
ccf21bd36ccbfcca885ed519ace053cc5506cf1248e9dd854f4e22582e0cfef1
a7214e3c112fd330e32404dbf1b01eeef2733e3629ac897a964e829dad6981dd
24ad732eb62e0c69e4bb0f204a5150251f1d78cf3f286780d26d3478b3b7fec1
```
After a few minutes, when prompted, browse to https://localhost:5601 and log in with `elastic:elastic`.

### Destroying

Destroying will:
- stop the Elasticsearch and Kibana containers
- delete the Elasticsearch and Kibana containers
- delete the `elastic` container network
- delete the created volumes

```
$ ./elastic-container.sh destroy

fleet-server
kibana
elasticsearch
elastic
```

### Stopping

Stopping will:
- stop the Elasticsearch and Kibana containers without deleting them

```
$ ./elastic-container.sh stop

fleet-server
kibana
elasticsearch
elastic
```

### Restarting

Restarting will:
- restart all the containers

```
$ ./elastic-container.sh restart

elasticsearch
kibana
fleet-server
```

### Status

Requesting the status will:
- return the current status of the running containers

```
$ ./elastic-container.sh status

NAMES: STATUS
fleet-server: Up 6 minutes
kibana: Up 6 minutes
elasticsearch: Up 6 minutes
```

### Staging

Staging the container images will:
- download all container images to your local system, but will not start them

```
$ ./elastic-container.sh stage

7.15.0: Pulling from elasticsearch/elasticsearch
e7bd69ff4774: Pull complete
d0a0f12aaf30: Pull complete
...
```

## Modifying

In `elastic-container.sh`, the variables are defined, any can be changed.
```
ELASTIC_PASSWORD="elastic"
KIBANA_PASSWORD="elastic"
STACK_VERSION="8.3.2"
```

If you want to change the default values, simply replace whatever is appropriate in the variable declaration.

If you want to use different Elastic Stack versions, you can change those as well. Optional values are on Elastic's Docker hub:

- [Elasticsearch](https://hub.docker.com/r/elastic/elasticsearch/tags?page=1&ordering=last_updated)
- [Kibana](https://hub.docker.com/r/elastic/kibana/tags?page=1&ordering=last_updated)
- [Elastic-Agent](https://hub.docker.com/r/elastic/elastic-agent/tags?page=1&ordering=last_updated)

## Questions

1. But...why?  
To be able to quickly stand up and take down an Elastic Stack with everything already configured allowing me to focus on what I need to do.

2. This is horrible, why can't you write better scripts?  
Function over beauty.

3. I suppose I can use this, can I change the creds or stack version?  
Of course.

4. Elastic-Agent or Fleet Server, what's the difference?  
The Elastic-Agent acts as the Fleet Server role. More information can be found on the [official documentation](https://www.elastic.co/guide/en/fleet/current/fleet-server.html).
