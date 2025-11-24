# The Elastic Container Project

Stand up a 100% containerized Elastic stack, TLS secured, with Elasticsearch, Kibana, Fleet, and the Detection Engine all pre-configured, enabled and ready to use, within minutes.

If you're interested in more details regarding this project and what to do once you have it running, check out our [blog post](https://www.elastic.co/security-labs/the-elastic-container-project) on the Elastic Security Labs site.

:warning: This is not an Elastic created, sponsored, or maintained project. Elastic is not responsible for this projects design or implementation.

[![elastic-container.png](https://i.postimg.cc/J7TpsqKJ/elastic-container.png)](https://postimg.cc/NLH6VR3f)

## Quick Start

1. `git clone` this repo
2. Install prerequisites (see below)
3. Change into the `elastic-container/` folder
4. Change the default password of `changeme` in the `.env` file (don't change the `elastic` username, it's a [required built-in user](https://www.elastic.co/guide/en/elasticsearch/reference/current/built-in-users.html))
5. (Optional) Bulk enable pre-built detection rules by OS in the `.env` file
6. Create a Python virtual environment and install dependencies
7. Run `python elastic-container.py start`
8. Browse to https://localhost:5601 and log in with your credentials

(You may be presented a browser warning due to the self-signed certificates. You can type `thisisnotsafe` or click to proceed after which you will be directed to the Elastic log in screen)

## Requirements

### Operating System

- Linux (Ubuntu, Debian, Fedora, RHEL, Rocky, Arch)
- macOS
- Windows 10/11 (via WSL2 or native)

### Prerequisites

- **Python 3.10 or higher** (required)
- [Docker](https://docs.docker.com/get-docker/) with [docker compose plugin](https://docs.docker.com/compose/install/)
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

---

## Installation by Platform

### macOS

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install prerequisites
brew install python@3.11 git
brew install --cask docker

# Start Docker Desktop
open /Applications/Docker.app
# Wait for Docker to start, then close/minimize

# Clone repository
git clone https://github.com/peasead/elastic-container.git
cd elastic-container

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install -r requirements.txt
```

### Ubuntu / Debian

```bash
# Update system
sudo apt-get update

# Install prerequisites
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

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Clone repository
git clone https://github.com/peasead/elastic-container.git
cd elastic-container

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install -r requirements.txt
```

### Fedora / RHEL / Rocky / CentOS

```bash
# Install prerequisites
sudo dnf install -y python3.11 python3-pip git

# Install Docker
sudo dnf install -y docker docker-compose-plugin

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Clone repository
git clone https://github.com/peasead/elastic-container.git
cd elastic-container

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install -r requirements.txt
```

### Windows 10/11 with WSL2

Make sure you are using WSL version 2. Check with `wsl -l -v` in PowerShell. If needed, change it with `wsl --set-version Ubuntu-22.04 2`

**Inside WSL2 Ubuntu:**

```bash
# Update system
sudo apt-get update

# Install prerequisites (follow Ubuntu instructions above)
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt-get update
sudo apt-get install -y python3.11 python3.11-venv python3.11-distutils python3-pip git

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt-get install -y docker-compose-plugin

# Start Docker
sudo service docker start

# Clone repository
git clone https://github.com/peasead/elastic-container.git
cd elastic-container

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install -r requirements.txt
```

---

## Configuration

This project uses default credentials of `elastic:changeme` and is intended purely for security research on a local Elastic stack.

**⚠️ You MUST change the default passwords in the `.env` file before starting.**

Don't change the `elastic` username - it's a [required built-in user](https://www.elastic.co/guide/en/elasticsearch/reference/current/built-in-users.html).

This should **not** be Internet exposed or used in a production environment.

### Required `.env` Changes

Edit the `.env` file and change these values:

```bash
ELASTIC_PASSWORD="YourSecurePassword123!"
KIBANA_PASSWORD="YourSecurePassword123!"
STACK_VERSION="8.14.0"
```

### Enable Pre-Built Detection Rules (Optional)

To bulk enable Elastic's pre-built detection rules by OS on startup, change the value from `0` to `1` in the `.env` file:

```bash
# Bulk Enable Detection Rules by OS
LinuxDR=0
WindowsDR=1
MacOSDR=0
```

---

## Usage

### Starting the Stack

**If you have not changed the default passwords in the `.env` file, the script will exit with an error.**

Starting will:
- Create a network called `elastic`
- Download the Elasticsearch, Kibana, and Elastic-Agent Docker images
- Start Elasticsearch, Kibana, and Fleet Server with all settings configured
- Enable the Detection Engine and install prebuilt detection rules (if configured)

```bash
# Activate virtual environment (if not already active)
source venv/bin/activate

# Start the stack
python elastic-container.py start

# For verbose output
python elastic-container.py -v start
```

**First run output:**
```
Checking prerequisites...
✓ Passphrase has been changed. Proceeding.
✓ Docker is available and running

Starting Elastic Stack network and containers...
 ⠿ Container elasticsearch-security-setup  Healthy 7.3s
 ⠿ Container elasticsearch                 Healthy 39.3s
 ⠿ Container kibana                        Healthy 59.3s
 ⠿ Container elastic-agent                 Started 59.7s

Configuring Detection Engine...
✓ Kibana is up. Proceeding.
✓ Detection Engine enabled
✓ Prepackaged rules installed!

Waiting 40 seconds for Fleet Server setup...

Populating Fleet Settings...
✓ Fleet Server configuration complete!

======================================================================
🚀 READY SET GO!
======================================================================

Browse to https://localhost:5601
```

After a few minutes, browse to https://localhost:5601 and log in with your configured credentials.

**Subsequent runs are much faster:**
```bash
python elastic-container.py start
# Output: ✓ Containers are already running! (instant)
```

### Stopping the Stack

Stopping will stop the containers without removing them:

```bash
python elastic-container.py stop
```

### Restarting the Stack

Restarting will restart all containers:

```bash
python elastic-container.py restart
```

### Checking Status

Check the status of running containers:

```bash
python elastic-container.py status
```

Output:
```
NAME            STATUS          PORTS
elasticsearch   Up 10 minutes   0.0.0.0:9200->9200/tcp
kibana          Up 10 minutes   0.0.0.0:5601->5601/tcp
fleet-server    Up 10 minutes   0.0.0.0:8220->8220/tcp
```

### Clearing Data

Clear all documents in logs and metrics data streams:

```bash
python elastic-container.py clear
```

Output:
```
✓ Successfully cleared logs data stream
✓ Successfully cleared metrics data stream
```

### Staging Images

Download all container images without starting them:

```bash
python elastic-container.py stage
```

This is useful to pre-download images on a fast connection before going offline.

### Destroying the Stack

**⚠️ This will delete all data!**

Destroying will:
- Stop all containers
- Remove all containers
- Delete the `elastic` network
- Delete all created volumes

```bash
python elastic-container.py destroy
```

### Force Reconfiguration

If you need to reconfigure Detection Engine or Fleet settings:

```bash
python elastic-container.py --force-setup start
```

This forces full setup even if containers already exist.

---

## Command Reference

| Command | Description | Notes |
|---------|-------------|-------|
| `start` | Start the stack | Intelligent - skips setup if already configured |
| `start --force-setup` | Force full reconfiguration | Useful after `.env` changes |
| `start -v` | Start with verbose output | Shows detailed progress |
| `stop` | Stop containers | Preserves data |
| `restart` | Restart containers | Quick bounce |
| `status` | Show container status | Check if running |
| `destroy` | Remove everything | **Deletes all data** |
| `clear` | Clear log/metrics data | Keep containers running |
| `stage` | Download images only | Pre-fetch for offline use |

---

## Modifying Configuration

### Changing Passwords and Versions

Edit the `.env` file to change these values:

```bash
ELASTIC_PASSWORD="YourPassword"
KIBANA_PASSWORD="YourPassword"
STACK_VERSION="8.14.0"
```

To use different Elastic Stack versions, check available tags on Elastic's Docker Hub:

- [Elasticsearch tags](https://hub.docker.com/r/elastic/elasticsearch/tags?page=1&ordering=last_updated)
- [Kibana tags](https://hub.docker.com/r/elastic/kibana/tags?page=1&ordering=last_updated)
- [Elastic-Agent tags](https://hub.docker.com/r/elastic/elastic-agent/tags?page=1&ordering=last_updated)

### Increase JVM Heap Size

The default heap size is 512M which may be insufficient in some cases. Edit `docker-compose.yml` and add the `ES_JAVA_OPTS` environment variable:

```yml
elasticsearch:
  ...
  environment:
    - ES_JAVA_OPTS=-Xmx1g -Xms1g
```

---

## Advanced Usage

### Agent Enrollment

To enroll additional Elastic Agents, you'll need an enrollment token.

Get the token from Kibana UI:
- Navigate to `https://localhost:5601/app/fleet/enrollment-tokens`

Or via the Fleet API:

```bash
curl -k --request GET \
  --url 'https://localhost:5601/api/fleet/enrollment_api_keys' \
  -u elastic:YourPassword \
  --header 'Content-Type: application/json' \
  --header 'kbn-xsrf: xx'
```

Response example:
```json
{
  "list": [
    {
      "id": "461cc77f-e9dd-46f0-b5c8-7babf644b08f",
      "active": true,
      "api_key_id": "ZS7TYI4B02xLEiUBWuqK",
      "api_key": "WlM3VFlJNEIwMnhMRWlVQld1cUs6b3JmRGRyTnBUSmVOc05DeU1NelJIZw==",
      "name": "Default",
      "policy_id": "09528aeb-70c7-4448-91cf-0be1e6a1838a",
      "created_at": "2024-03-21T11:44:08.721Z"
    }
  ]
}
```

### Installing Agents on Remote Systems

**Windows (PowerShell):**
```powershell
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.14.0-windows-x86_64.zip -OutFile elastic-agent.zip
Expand-Archive .\elastic-agent.zip -DestinationPath .
cd elastic-agent-8.14.0-windows-x86_64
.\elastic-agent.exe install --url=https://<FLEET_HOST>:8220 --insecure -f --enrollment-token=<TOKEN>
```

**Linux:**
```bash
curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.14.0-linux-x86_64.tar.gz
tar xzvf elastic-agent-8.14.0-linux-x86_64.tar.gz
cd elastic-agent-8.14.0-linux-x86_64
sudo ./elastic-agent install --url=https://<FLEET_HOST>:8220 --insecure -f --enrollment-token=<TOKEN>
```

**macOS:**
```bash
curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.14.0-darwin-x86_64.tar.gz
tar xzvf elastic-agent-8.14.0-darwin-x86_64.tar.gz
cd elastic-agent-8.14.0-darwin-x86_64
sudo ./elastic-agent install --url=https://<FLEET_HOST>:8220 --insecure -f --enrollment-token=<TOKEN>
```

---

## Troubleshooting

### Python Version Issues

```bash
# Check Python version (must be 3.10+)
python --version

# If wrong version, make sure you're using Python 3.11
python3.11 --version

# Recreate virtual environment with correct Python
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Docker Not Running

**macOS:**
```bash
open /Applications/Docker.app
```

**Linux:**
```bash
sudo systemctl start docker
# or
sudo service docker start
```

### Port Already in Use

Check if ports are available:
```bash
# Check Kibana port
lsof -i :5601

# Check Elasticsearch port
lsof -i :9200

# Check Fleet port
lsof -i :8220
```

Stop conflicting services or change ports in `.env` file.

### Containers Won't Start

```bash
# Check Docker logs
docker logs elasticsearch
docker logs kibana
docker logs fleet-server

# Ensure enough resources
# Docker Desktop: Settings → Resources → Memory (recommend 4GB+)

# Clean start
python elastic-container.py destroy
python elastic-container.py start
```

### Module Not Found Errors

```bash
# Make sure virtual environment is activated
source venv/bin/activate

# Reinstall dependencies
pip install -r requirements.txt
```

---

## Project Structure

```
elastic-container/
├── elastic-container.py      # Main CLI script
├── lib/
│   ├── __init__.py           # Package initialization
│   ├── config.py             # Configuration management
│   ├── docker_manager.py     # Docker operations
│   ├── kibana_manager.py     # Kibana/Fleet setup
│   └── utils.py              # Utility functions
├── requirements.txt          # Python dependencies
├── docker-compose.yml        # Docker Compose configuration
├── .env                      # Environment variables (you create this)
└── README.md                 # This file
```

---

## Contributing

Contributions are welcome! Please open an issue or pull request on GitHub.

## License

See [LICENSE.md](LICENSE.md) for details.

## Disclaimer

This is not an official Elastic project. It is maintained by the community for security research and testing purposes only.
