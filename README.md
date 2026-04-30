# The Elastic Container Project

Stand up a 100% containerized Elastic stack, TLS secured, with Elasticsearch, Kibana, Fleet, and the Detection Engine all pre-configured, enabled and ready to use, within minutes.

If you're interested in more details regarding this project and what to do once you have it running, check out our [blog post](https://www.elastic.co/security-labs/the-elastic-container-project) on the Elastic Security Labs site.

:warning: This is not an Elastic created, sponsored, or maintained project. Elastic is not responsible for this projects design or implementation.

[![elastic-container.png](https://i.postimg.cc/J7TpsqKJ/elastic-container.png)](https://postimg.cc/NLH6VR3f)

## Steps

1. `Git clone` this repo
2. Install prerequisites (see below)
3. Change into the `elastic-container/` folder
4. **Set a current stack image tag** — pinned versions in `.env` can disappear from registries over time. Either run `bash ./elastic-container.sh update-version` (or `bash ./elastic-container.sh -u`) to set `STACK_VERSION` to the newest stable `x.y.z` tag listed for [elastic/elasticsearch on Docker Hub](https://hub.docker.com/r/elastic/elasticsearch/tags), or open that page and set `STACK_VERSION` in `.env` manually to a tag that exists for Elasticsearch, Kibana, and Elastic Agent. After `chmod +x`, you can use `./elastic-container.sh` instead of `bash ./elastic-container.sh`.
5. Change the default password of `changeme` in the `.env` file (don't change the `elastic` username, it's a [required built-in user](https://www.elastic.co/guide/en/elasticsearch/reference/current/built-in-users.html))  
6. Bulk enable pre-built detection rules by OS in the `.env` file (not required, see usage below)
7. Make the `elastic-container.sh` shell script executable by running `chmod +x elastic-container.sh`
8. Execute the `elastic-container.sh` shell script with the start argument `./elastic-container.sh start`
9. Wait for the prompt to tell you to browse to https://localhost:5601 \
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
**RPM distributions (CentOS/Fedora/Rocky/RHEL):**  
Please follow the [Docker installation instructions](https://docs.docker.com/engine/install/centos/). Of specific note, you *must* install the `docker-compose-plugin`, which is different than `docker-compose`.
```
dnf install jq git curl
```

**Other Linux distributions:**  
Please follow the [Docker installation instructions](https://docs.docker.com/engine/install/). Of specific note, you *must* install the `docker-compose-plugin`, which is different than `docker-compose`.

Arch Linux users should install `inetutils` and change the shell script from `hostname -I` to `hostname -i`.

**Windows 10/11 with WSL 2 (Ubuntu 20.04):**  
Make sure you are using WSL version 2. You can check the version using `wsl -l -v` in PowerShell. If the version is wrong you can change it with `wsl --set-version Ubuntu-20.04 2`

```
apt-get update
apt-get install jq git curl
```
Please follow the [Docker installation instructions](https://docs.docker.com/engine/install/ubuntu/). Of specific note, you *must* install the `docker-compose-plugin`, which is different than `docker-compose`.

Once the Docker suite is installed run `sudo service docker start` to start it.

See the following [WSL 2 networking](#wsl-2-networking) section for how Windows and the containerized stack reach each other (ports, `localhost`, TLS, and Fleet), otherwise continue to [Usage](#usage).  

### WSL 2 networking

When you run this project inside **WSL 2**, Docker publishes Elasticsearch, Kibana, and Fleet on the ports defined in `.env` (`ES_PORT`, `KIBANA_PORT`, `FLEET_PORT`). Those listeners are inside the WSL virtual machine. **Windows** and **WSL** are not the same network namespace, so URLs and hostnames depend on which direction traffic flows.

#### Reaching the Elastic stack from the Windows host

Use these endpoints from browsers, scripts, or other apps **on Windows**:

1. **Try `localhost` first** — e.g. `https://localhost:5601` (Kibana), `https://localhost:9200` (Elasticsearch), `https://localhost:8220` (Fleet). WSL 2 often forwards published container ports to Windows `localhost`.
2. **If `localhost` fails** — use the WSL instance’s IP. From PowerShell: `(wsl hostname -I).Trim().Split()[0]`, or from WSL: `hostname -I` (first address). Then use `https://<that-ip>:5601` (and the same pattern for other ports).

**TLS:** Stack certificates are issued for `localhost` and related names, not arbitrary IPs. Connecting with **`https://localhost:...`** from Windows usually matches the certificate. Connecting by **WSL IP** can trigger certificate hostname warnings unless you adjust verification or regenerate certs.

**Optional WSL settings:** You do not have to change WSL for this to work. On Windows 11, [mirrored networking](https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking) in `%UserProfile%\.wslconfig` can make `localhost` behavior more predictable:

```ini
[wsl2]
networkingMode=mirrored
```

After editing, run `wsl --shutdown` and open WSL again.

**Fleet and Elastic Agent:** On start, `elastic-container.sh` discovers a host IP (via `hostname -I` on Linux) and uses it in Fleet output and Fleet Server URLs so agents can reach the stack. That value is typically the **WSL NIC IP**, not `127.0.0.1`. Agents running **on Windows** may need a URL that resolves from Windows (`localhost` or the WSL IP); align that with TLS expectations (fingerprint / verification settings as documented for your agent version).

The `LOCAL_KBN_URL` and `LOCAL_ES_URL` entries in `.env` (`127.0.0.1`) are for **curl inside WSL** during setup, not a requirement for how Windows clients connect.

#### Reaching a Windows-hosted service from the Elastic stack

If a service listens on the **Windows** host (for example port `1234`) and something in the stack (a connector, webhook, or other outbound HTTP client) must call it:

1. **Bind the Windows app on all interfaces** — If it listens only on `127.0.0.1`, WSL and Docker cannot reach it. Bind to `0.0.0.0` or the appropriate non-loopback interface.
2. **Docker Desktop on Windows (WSL 2 backend)** — From containers, the Windows machine is usually reachable as **`host.docker.internal`**, e.g. `http://host.docker.internal:1234`. If name resolution fails, add `extra_hosts` for your service in `docker-compose.yml` (see [Docker extra_hosts](https://docs.docker.com/compose/compose-file/compose-file-v3/#extra_hosts)).
3. **Docker Engine only inside WSL** (no Docker Desktop) — `host.docker.internal` / `host-gateway` typically refers to the **Linux WSL instance**, not Windows. Use the **Windows host IP** as seen from WSL — often the `nameserver` address in `/etc/resolv.conf` inside the distro (e.g. `172.x.x.x`). Use `http://<that-ip>:1234` in stack configuration, and allow the port in **Windows Defender Firewall** for the WSL / Hyper-V network if needed.

## Usage

This uses default creds of `elastic:changeme` and is intended purely for security research on a local Elastic stack. [Change the password in the `.env` file](https://github.com/peasead/elastic-container/blob/main/README.md#modifying). Don't change the `elastic` username, it's a [required built-in user](https://www.elastic.co/guide/en/elasticsearch/reference/current/built-in-users.html) 

This should not be Internet exposed or used in a production environment.

### Enable Pre-Built Detection Rules

If you want to bulk enable Elastic's pre-built detection rules by OS, on startup, you can change the value of the chosen OS in the `.env` file from 0 to 1.

```
# Bulk Enable Detection Rules by OS
LinuxDR=0

WindowsDR=1

MacOSDR=0
```

### Updating `STACK_VERSION`

If pulls fail because the tag in `.env` was removed or is outdated, refresh the pinned version before `stage` or `start`:

```
$ ./elastic-container.sh update-version
```

This queries the [elastic/elasticsearch](https://hub.docker.com/r/elastic/elasticsearch/tags) repository on Docker Hub, finds the highest stable tag matching `x.y.z` (SNAPSHOT and other non-semver tags are ignored), and rewrites the active `STACK_VERSION=` line in `.env`. The same behavior is available as a short flag: `./elastic-container.sh -u`. Docker does not need to be running for this action. For snapshot or pre-release builds, set `STACK_VERSION` in `.env` by hand to match a published tag.

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

In `.env`, the variables are defined, below are the variables that can be changed. **You must change the default passwords.**
```
ELASTIC_PASSWORD="changeme"
KIBANA_PASSWORD="changeme"
STACK_VERSION="8.14.0"
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
Invoke-WebRequest -Uri https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.12.2-windows-x86_64.zip -OutFile elastic-agent-8.12.2-windows-x86_64.zip
Expand-Archive .\elastic-agent-8.12.2-windows-x86_64.zip -DestinationPath .
cd elastic-agent-8.12.2-windows-x86_64
.\elastic-agent.exe install --url=https://<FLEETHOST>:8220 --insecure -f --enrollment-token=<api_key>
```
