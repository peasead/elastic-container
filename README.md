# The Elastic Container Project

Stand up a 100% containerized Elastic stack, TLS secured, with Elasticsearch, Kibana, Fleet, and the Detection Engine all pre-configured, enabled and ready to use, within minutes.

If you're interested in more details regarding this project and what to do once you have it running, check out our [blog post](https://www.elastic.co/security-labs/the-elastic-container-project) on the Elastic Security Labs site.

:warning: This is not an Elastic created, sponsored, or maintained project. Elastic is not responsible for this projects design or implementation.

<p align="center">
<img width="256" height="256" alt="ecp-logo" src="https://github.com/user-attachments/assets/639b56e0-1429-49fe-b3ad-275666412a92">
</p>

## Steps

1. `Git clone` this repo
2. Install prerequisites (see below)
3. Change into the `elastic-container/` folder
4. Change the default password of `changeme` in the `.env` file (don't change the `elastic` username, it's a [required built-in user](https://www.elastic.co/guide/en/elasticsearch/reference/current/built-in-users.html))  
5. Bulk enable pre-built detection rules by OS in the `.env` file (not required, see usage below)
6. Create a Python virtual environment: `python -m venv venv`
7. Activate the virtual environment and install dependencies: `source venv/bin/activate && pip install -r requirements.txt`
8. Execute the Python script with the start command: `python elastic-container.py start`
9. Wait for the prompt to tell you to browse to https://localhost:5601

## Requirements

### Operating System: 

- Linux (Ubuntu, Debian, Rocky, Fedora, RHEL, CentOS)
- MacOS 
- Windows (via WSL2)

### Prerequisites: 

- **Python 3.10 or higher** (required)
- [Docker suite](https://docs.docker.com/get-docker/) with [docker compose plugin](https://docs.docker.com/compose/install/)
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

**MacOS:**
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install prerequisites
brew install python@3.11 git
brew install --cask docker
```
Once we have Docker installed we need to provide it with privileged access for it to function. Run the following command to open the Docker app and follow the proceeding steps.
```bash
open /Applications/Docker.app
```

1. Confirm you would like to open the app
2. Select ok when prompted to provide Docker with privileged access
3. Enter your password 
4. Close or minimize the Docker app

**Ubuntu/Debian:**  
Please follow the [Docker installation instructions](https://docs.docker.com/engine/install/ubuntu/). Of specific note, you *must* install the `docker-compose-plugin`, which is different than `docker-compose`.

```bash
# Install software-properties-common for PPA support
sudo apt-get update
sudo apt-get install -y software-properties-common

# Add Python 3.11 repository (deadsnakes PPA)
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt-get update

# Install Python 3.11 and tools
sudo apt-get install -y python3.11 python3.11-venv python3.11-distutils python3-pip git

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt-get install -y docker-compose-plugin

# Add user to docker group and start Docker
sudo usermod -aG docker $USER
newgrp docker
sudo systemctl start docker
sudo systemctl enable docker
```

**RPM distributions (Rocky/RHEL/CentOS/Fedora):**  
Please follow the [Docker installation instructions](https://docs.docker.com/engine/install/centos/). Of specific note, you *must* install the `docker-compose-plugin`, which is different than `docker-compose`.

```bash
# Install Python and tools
sudo dnf install -y python3.11 python3-pip git dnf-plugins-core

# Add Docker's official repository
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker Engine and Compose plugin
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group and start Docker
sudo usermod -aG docker $USER
newgrp docker
sudo systemctl start docker
sudo systemctl enable docker
```

**Windows 10/11 with WSL 2 (Ubuntu 20.04):**  
Make sure you are using WSL version 2. You can check the version using `wsl -l -v` in PowerShell. If the version is wrong you can change it with `wsl --set-version Ubuntu-20.04 2`

```bash
sudo apt-get update

# Follow Ubuntu installation instructions above
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt-get update
sudo apt-get install -y python3.11 python3.11-venv python3.11-distutils python3-pip git
```
Please follow the [Docker installation instructions](https://docs.docker.com/engine/install/ubuntu/). Of specific note, you *must* install the `docker-compose-plugin`, which is different than `docker-compose`.

Once the Docker suite is installed run `sudo service docker start` to start it.

## Usage

This uses default creds of `elastic:changeme` and is intended purely for security research on a local Elastic stack. [Change the password in the `.env` file](https://github.com/peasead/elastic-container/blob/main/README.md#modifying). Don't change the `elastic` username, it's a [required built-in user](https://www.elastic.co/guide/en/elasticsearch/reference/current/built-in-users.html) 

This should not be Internet exposed or used in a production environment.

```bash
Usage: elastic-container.py [OPTIONS] COMMAND [ARGS]...

Elastic Container - Manage your containerized Elastic Stack

Options:
  -v, --verbose  Enable verbose output
  --help         Show this message and exit.

Commands:
  clear    Clear all documents in logs and metrics data streams
  destroy  Stop and remove containers, networks, and volumes
  help     Show this help message
  restart  Restart all Elastic Stack containers
  stage    Download all necessary Docker images to local storage
  start    Create container network and start all stack containers
  status   Check the status of all stack containers
  stop     Stop running containers without removing them
```

### Enable Pre-Built Detection Rules

If you want to bulk enable Elastic's pre-built detection rules by OS, on startup, you can change the value of the chosen OS in the `.env` file from 0 to 1.

```
# Bulk Enable Detection Rules by OS
LinuxDR=0

WindowsDR=1

MacOSDR=0
```

### Starting

Starting will:
- create a network called `elastic`
- download the Elasticsearch, Kibana, and Elastic-Agent Docker images defined in the script
- start Elasticsearch, Kibana, and the Elastic-Agent configured as a Fleet Server w/all settings needed for Fleet and the Detection Engine

```
Activate virtual environment (if not already active)  
$ source venv/bin/activate

Start the stack  
$ python elastic-container.py start

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

Browse to https://localhost:5601
```

After a few minutes, when prompted, browse to https://localhost:5601 and log in with your configured credentials.

**Subsequent starts are much faster** - if containers already exist and are running, the script will detect this and complete instantly. If containers exist but are stopped, it will start them quickly (~30 seconds) without reconfiguring.

### Destroying

Destroying will:
- stop the Elasticsearch and Kibana containers
- delete the Elasticsearch and Kibana containers
- delete the `elastic` container network
- delete the created volumes

```
$ python elastic-container.py destroy

fleet-server
kibana
elasticsearch
elastic
```

### Stopping

Stopping will:
- stop the Elasticsearch and Kibana containers without deleting them

```
$ python elastic-container.py stop

fleet-server
kibana
elasticsearch
elastic
```

### Restarting

Restarting will:
- restart all the containers

```
$ python elastic-container.py restart

elasticsearch
kibana
fleet-server
```

### Status

Requesting the status will:
- return the current status of the running containers

```
$ python elastic-container.py status

NAMES: STATUS
fleet-server: Up 6 minutes
kibana: Up 6 minutes
elasticsearch: Up 6 minutes
```

### Clearing

Clearing will :
- clear all documents in logs and metrics indices 

```
$ python elastic-container.py clear

Successfully cleared logs data stream
Successfully cleared metrics data stream
```

### Staging

Staging the container images will:
- download all container images to your local system, but will not start them

```
$ python elastic-container.py stage

8.6.0: Pulling from elasticsearch/elasticsearch
e7bd69ff4774: Pull complete
d0a0f12aaf30: Pull complete
...
```

### Verbose Output

All commands support a verbose flag (`-v`) for detailed output:

```
$ python elastic-container.py -v start
```

### Force Reconfiguration

If you need to reconfigure Detection Engine or Fleet settings after they've already been set up:

```
$ python elastic-container.py --force-setup start
```

## Modifying

In `.env`, the variables are defined, below are the variables that can be changed. **You must change the default passwords.**
```
ELASTIC_PASSWORD="changeme"
KIBANA_PASSWORD="changeme"
STACK_VERSION="9.2.1"
```

If you want to change the default values, simply replace whatever is appropriate in the variable declaration.

If you want to use different Elastic Stack versions, you can change those as well. Optional values are on Elastic's Docker hub:

- [Elasticsearch](https://hub.docker.com/r/elastic/elasticsearch/tags?page=1&ordering=last_updated)
- [Kibana](https://hub.docker.com/r/elastic/kibana/tags?page=1&ordering=last_updated)
- [Elastic-Agent](https://hub.docker.com/r/elastic/elastic-agent/tags?page=1&ordering=last_updated)

### Increase JVM Heap Size

The default heap size is 512M which may be insufficent in some cases. In that case we can change the heap size by editing `docker-compose.yml` and passing `ES_JAVA_OPTS` environment variable to elasticsearch container. 

```yml
  elasticsearch:
   ...
    environment:
+     - ES_JAVA_OPTS=-Xmx1g -Xms1g
```

## Automating

To enroll an Agent you will need the enrollment token.
You can get the token either under `https://<KIBANAHOST>:5601/app/fleet/enrollment-tokens` or via the API
[https://www.elastic.co/guide/en/fleet/current/fleet-api-docs.html#get-enrollment-token-api](https://www.elastic.co/guide/en/fleet/current/fleet-api-docs.html#get-enrollment-token-api)

```bash
curl -k --request GET \
   --url 'https://<KIBANAHOST>:5601/api/fleet/enrollment_api_keys' \
   -u <USER>:<PASSWORD> \
   --header 'Content-Type: application/json' \
   --header 'kbn-xsrf: xx'
```
This will return the tokens in JSON:
```json
{
  "list": [
    {
      "id": "461cc77f-e9dd-46f0-b5c8-7babf644b08f",
      "active": true,
      "api_key_id": "ZS7TYI4B02xLEiUBWuqK",
      "api_key": "WlM3VFlJNEIwMnhMRWlVQld1cUs6b3JmRGRyTnBUSmVOc05DeU1NelJIZw==",
      "name": "Default (461cc77f-e9dd-46f0-b5c8-7babf644b08f)",
      "policy_id": "09528aeb-70c7-4448-91cf-0be1e6a1838a",
      "created_at": "2024-03-21T11:44:08.721Z"
    },
[...]
```

With that information it is possible to enroll an Agent, e.g. via WinRM or Ansible:

```powershell
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-[version]-windows-x86_64.zip -OutFile elastic-agent-[version]-windows-x86_64.zip
Expand-Archive .\elastic-agent-[version]-windows-x86_64.zip -DestinationPath .
cd elastic-agent-[version]-windows-x86_64
.\elastic-agent.exe install --url=https://<FLEETHOST>:8220 --insecure -f --enrollment-token=<api_key>
```
