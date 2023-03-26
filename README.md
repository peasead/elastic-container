# The Elastic Container Project

Stand up a 100% containerized Elastic stack, TLS secured, with Elasticsearch, Kibana, Fleet, and the Detection Engine all pre-configured, enabled and ready to use, within minutes.

If you're interested in more details regarding this project and what to do once you have it running, check out our [blog post](https://www.elastic.co/security-labs/the-elastic-container-project) on the Elastic Security Labs site.

:warning: This is not an Elastic created, sponsored, or maintained project. Elastic is not responsible for this projects design or implementation.

[![elastic-container.png](https://i.postimg.cc/J7TpsqKJ/elastic-container.png)](https://postimg.cc/NLH6VR3f)

## Steps

1. `Git clone` this repo
2. Install prerequisites (see below)
3. Change into the `elastic-container/` folder
4. Change the default password of "changeme" in the `.env` file 
5. Bulk enable pre-built detection rules by OS in the `.env` file (not required, see usage below)
6. Make the `elastic-container.sh` shell script executable by running `chmod +x elastic-container.sh`
7. Execute the `elastic-container.sh` shell script with the start argument `./elastic-container start`
8. Wait for the prompt to tell you to browse to https://localhost:5601 \
(You may be presented a browser warning due to the self-signed certificates. You can type `thisisnotsafe` or click to proceed after which you will be directed to the Elastic log in screen)

## Requirements

### Operating System: 

- Linux or MacOS 

### Prerequisites: 

- [Docker suite](https://docs.docker.com/get-docker/), [jq](https://stedolan.github.io/jq/download/), [curl](https://curl.se/download.html), and [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git).

You can use the links above, the Linux package install commands below, or [Homebrew](https://brew.sh/) if your'e on MacOS

**MacOS:**
```
brew install jq git curl docker-compose
brew install --cask docker
```
Once we have Docker installed we need to provide it with privileged access for it to function. Run the following command to open the Docker app and follow the proceeding steps.
```
open /Applications/Docker.app
```

1. Confirm you would like to open the app
2. Select ok when prompted to provide Docker with privileged access
3. Enter your password 
4. Close or minimize the Docker app

**Ubuntu:**  
Please follow the [Docker installation instructions](https://docs.docker.com/engine/install/ubuntu/). Of specific note, you *must* install the `docker-compose-plugin`, which is different than `docker-compose`.
```
apt-get install jq git curl
```
**CentOS/Fedora:**  
Please follow the [Docker installation instructions](https://docs.docker.com/engine/install/centos/). Of specific note, you *must* install the `docker-compose-plugin`, which is different than `docker-compose`.
```
dnf install jq git curl
```

**Other Linux distributions:**  
Please follow the [Docker installation instructions](https://docs.docker.com/engine/install/). Of specific note, you *must* install the `docker-compose-plugin`, which is different than `docker-compose`.

Arch Linux users should install `inetutils` and change the shell script from `hostname -I` to `hostname -i`.

## Usage

This uses default creds of `elastic:changeme` and is intended purely for security research on a local Elastic stack. [Change the password in the `.env` file](https://github.com/peasead/elastic-container/blob/main/README.md#modifying).

This should not be Internet exposed or used in a production environment.

### Enable Pre-Built Detection Rules

If you want to bulk enable Elastic's pre-built detection rules by OS, on startup, you can change the value of the chosen OS in the `.env` file from 0 to 1.

```
# Bulk Enable Detection Rules by OS
LinuxDR=0

WindowsDR=1

MacOSDR=0
```

### Starting

**If you have not [changed the default passwords](https://github.com/peasead/elastic-container/blob/main/README.md#modifying) in the `.env` file, the script will exit.**

Starting will:
- create a network called `elastic`
- download the Elasticsearch, Kibana, and Elastic-Agent Docker images defined in the script
- start Elasticsearch, Kibana, and the Elastic-Agent configured as a Fleet Server w/all settings needed for Fleet and the Detection Engine

```
$ ./elastic-container.sh start

...
 ⠿ Container elasticsearch-security-setup  Healthy 7.3s
 ⠿ Container elasticsearch                 Healthy 39.3s
 ⠿ Container kibana                        Healthy 59.3s
 ⠿ Container elastic-agent                 Started 59.7s

Attempting to enable the Detection Engine and Prebuilt-Detection Rules

Kibana is up. Proceeding

Detection engine enabled. Installing prepackaged rules.

Prepackaged rules installed!

Waiting 40 seconds for Fleet Server setup

Populating Fleet Settings

READY SET GO!

Browse to https://localhost:5601
Username: elastic
Passphrase: not-the-default!
```
After a few minutes, when prompted, browse to https://localhost:5601 and log in with your configured credentials.

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

### Clearing

Clearing will :
- clear all documents in logs and metrics indices 

```
$ ./elastic-container.sh clear

Successfully cleared logs data stream
Successfully cleared metrics data stream
```

### Staging

Staging the container images will:
- download all container images to your local system, but will not start them

```
$ ./elastic-container.sh stage

8.6.0: Pulling from elasticsearch/elasticsearch
e7bd69ff4774: Pull complete
d0a0f12aaf30: Pull complete
...
```

## Modifying

In `.env`, the variables are defined, any can be changed. **You must change the default passwords.**
```
ELASTIC_PASSWORD="changeme"
KIBANA_PASSWORD="changeme"
STACK_VERSION="8.6.2"
```

If you want to change the default values, simply replace whatever is appropriate in the variable declaration.

If you want to use different Elastic Stack versions, you can change those as well. Optional values are on Elastic's Docker hub:

- [Elasticsearch](https://hub.docker.com/r/elastic/elasticsearch/tags?page=1&ordering=last_updated)
- [Kibana](https://hub.docker.com/r/elastic/kibana/tags?page=1&ordering=last_updated)
- [Elastic-Agent](https://hub.docker.com/r/elastic/elastic-agent/tags?page=1&ordering=last_updated)
