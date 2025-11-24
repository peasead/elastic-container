"""
Docker management for Elastic Container
Handles all Docker Compose operations
"""

import subprocess
import click
import requests
from typing import Optional
from urllib3.exceptions import InsecureRequestWarning

from .config import Config
from .utils import run_command, show_docker_error

# Suppress SSL warnings for self-signed certificates
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)


class DockerManager:
    """
    Manages Docker Compose operations for Elastic Container
    """
    
    def __init__(self, config: Config, verbose: bool = False):
        """
        Initialize Docker Manager
        
        Args:
            config: Configuration object
            verbose: Enable verbose output
        """
        self.config = config
        self.verbose = verbose
        self.compose_command = self._detect_compose_command()
    
    def _detect_compose_command(self) -> Optional[list]:
        """
        Detect available docker compose command
        
        Returns:
            Command as list (e.g., ["docker", "compose"]) or None if not found
        """
        # Try docker compose (plugin) first
        try:
            result = subprocess.run(
                ["docker", "compose", "version"],
                capture_output=True,
                check=True
            )
            if self.verbose:
                click.secho("✓ Found: docker compose (plugin)", fg="green")
            return ["docker", "compose"]
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass
        
        # Try docker-compose (standalone)
        try:
            result = subprocess.run(
                ["docker-compose", "version"],
                capture_output=True,
                check=True
            )
            if self.verbose:
                click.secho("✓ Found: docker-compose (standalone)", fg="green")
            return ["docker-compose"]
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass
        
        return None
    
    def check_docker_available(self) -> bool:
        """
        Check if Docker is installed and running
        
        Returns:
            True if Docker is ready, False otherwise
        """
        # Check if docker command exists
        try:
            subprocess.run(
                ["docker", "--version"],
                capture_output=True,
                check=True
            )
        except FileNotFoundError:
            show_docker_error(
                "Docker is not installed!",
                "Docker is required to run Elastic Container.",
                [
                    "macOS: https://docs.docker.com/desktop/install/mac-install/",
                    "Linux: https://docs.docker.com/engine/install/",
                    "Windows: https://docs.docker.com/desktop/install/windows-install/"
                ]
            )
            return False
        
        # Check if Docker daemon is running
        try:
            subprocess.run(
                ["docker", "ps"],
                capture_output=True,
                check=True
            )
        except subprocess.CalledProcessError:
            show_docker_error(
                "Docker is installed but not running!",
                "Please start Docker:",
                [
                    "macOS/Windows: Open Docker Desktop application",
                    "Linux: Run 'sudo systemctl start docker' or 'sudo service docker start'"
                ]
            )
            return False
        
        # Check if compose is available
        if self.compose_command is None:
            show_docker_error(
                "Docker Compose is not available!",
                "Elastic Container requires 'docker compose' (plugin) or 'docker-compose' (standalone).",
                [
                    "Plugin (recommended): Included with Docker Desktop or install docker-compose-plugin",
                    "Standalone: https://docs.docker.com/compose/install/"
                ]
            )
            return False
        
        if self.verbose:
            click.secho("✓ Docker is available and running", fg="green")
        
        return True
    
    def _run_compose(self, args: list, check: bool = True) -> tuple[int, str, str]:
        """
        Execute a docker compose command
        
        Args:
            args: Additional arguments for docker compose
            check: Raise exception on error
            
        Returns:
            Tuple of (exit_code, stdout, stderr)
        """
        command = self.compose_command + args
        return run_command(command, check=check, verbose=self.verbose)
    
    def stage(self) -> bool:
        """
        Pull all required Docker images
        
        Returns:
            True on success, False on failure
        """
        click.echo()
        click.secho("Pulling Docker images...", fg="cyan", bold=True)
        click.echo()
        
        images = [
            f"docker.elastic.co/elasticsearch/elasticsearch:{self.config.stack_version}",
            f"docker.elastic.co/kibana/kibana:{self.config.stack_version}",
            f"docker.elastic.co/elastic-agent/elastic-agent:{self.config.stack_version}"
        ]
        
        for image in images:
            click.echo(f"Pulling {image}...")
            exit_code, stdout, stderr = run_command(
                ["docker", "pull", image],
                check=False,
                verbose=self.verbose
            )
            
            if exit_code != 0:
                click.secho(f"✗ Failed to pull {image}", fg="red")
                click.echo(stderr)
                return False
            
            click.secho(f"✓ Pulled {image}", fg="green")
        
        click.echo()
        click.secho("All images pulled successfully!", fg="green", bold=True)
        return True
    
    def start(self) -> bool:
        """
        Start the Elastic Stack containers
        
        Returns:
            True on success, False on failure
        """
        click.echo()
        click.secho("Starting Elastic Stack network and containers...", fg="cyan", bold=True)
        click.echo()
        
        exit_code, stdout, stderr = self._run_compose(
            ["up", "-d", "--no-deps"],
            check=False
        )
        
        if exit_code != 0:
            show_docker_error(
                "Failed to start containers!",
                f"Command: {' '.join(self.compose_command)} up -d\nExit code: {exit_code}\n\nError output:\n{stderr}",
                [
                    "Check if ports 5601, 9200, 8220 are already in use",
                    "Ensure you have enough disk space",
                    "Try 'docker compose down -v' to clean up first",
                    "Run with -v flag for verbose output"
                ]
            )
            return False
        
        # Show output (docker compose shows container status)
        if stdout:
            click.echo(stdout)
        
        return True
    
    def stop(self) -> bool:
        """
        Stop running containers without removing them
        
        Returns:
            True on success, False on failure
        """
        click.echo()
        click.secho("Stopping running containers...", fg="cyan", bold=True)
        click.echo()
        
        exit_code, stdout, stderr = self._run_compose(["stop"], check=False)
        
        if exit_code != 0:
            click.secho(f"✗ Failed to stop containers", fg="red")
            click.echo(stderr)
            return False
        
        if stdout:
            click.echo(stdout)
        
        click.secho("✓ Containers stopped", fg="green")
        return True
    
    def destroy(self) -> bool:
        """
        Stop and remove containers, networks, and volumes
        
        Returns:
            True on success, False on failure
        """
        click.echo()
        click.secho("#####", fg="yellow")
        click.secho("Stopping and removing the containers, network, and volumes created.", fg="yellow")
        click.secho("#####", fg="yellow")
        click.echo()
        
        exit_code, stdout, stderr = self._run_compose(["down", "-v"], check=False)
        
        if exit_code != 0:
            click.secho(f"✗ Failed to destroy stack", fg="red")
            click.echo(stderr)
            return False
        
        if stdout:
            click.echo(stdout)
        
        click.secho("✓ Stack destroyed", fg="green")
        return True
    
    def restart(self) -> bool:
        """
        Restart Elastic Stack containers
        
        Returns:
            True on success, False on failure
        """
        click.echo()
        click.secho("#####", fg="cyan")
        click.secho("Restarting all Elastic Stack components.", fg="cyan")
        click.secho("#####", fg="cyan")
        click.echo()
        
        exit_code, stdout, stderr = self._run_compose(
            ["restart", "elasticsearch", "kibana", "fleet-server"],
            check=False
        )
        
        if exit_code != 0:
            click.secho(f"✗ Failed to restart containers", fg="red")
            click.echo(stderr)
            return False
        
        if stdout:
            click.echo(stdout)
        
        click.secho("✓ Containers restarted", fg="green")
        return True
    
    def status(self) -> bool:
        """
        Show status of running containers
        
        Returns:
            True on success, False on failure
        """
        exit_code, stdout, stderr = self._run_compose(["ps"], check=False)
        
        if exit_code != 0:
            click.secho(f"✗ Failed to get status", fg="red")
            click.echo(stderr)
            return False
        
        # Filter out setup container
        lines = stdout.split('\n')
        filtered_lines = [line for line in lines if 'setup' not in line.lower() or line.startswith('NAME')]
        
        click.echo('\n'.join(filtered_lines))
        return True
    
    def check_containers_exist(self) -> tuple[bool, bool]:
        """
        Check if containers exist and whether they're running
        
        Returns:
            Tuple of (containers_exist, containers_running)
        """
        # Check all containers including stopped ones
        exit_code, stdout, stderr = self._run_compose(["ps", "-a"], check=False)
        
        if exit_code != 0:
            return False, False
        
        # Check for main containers (elasticsearch, kibana, fleet-server)
        main_containers = ["elasticsearch", "kibana", "fleet-server"]
        found_containers = []
        running_containers = []
        
        for line in stdout.split('\n'):
            line_lower = line.lower()
            for container in main_containers:
                if container in line_lower:
                    found_containers.append(container)
                    # Check if running (has "Up" in status or "running")
                    if 'up' in line_lower or 'running' in line_lower:
                        running_containers.append(container)
        
        # Containers exist if we found at least 2 of the 3 main ones
        containers_exist = len(found_containers) >= 2
        # All running if we found all 3 running
        all_running = len(running_containers) >= 3
        
        return containers_exist, all_running
    
    def get_ca_fingerprint(self) -> Optional[str]:
        """
        Extract CA certificate fingerprint from Elasticsearch container
        
        Returns:
            Fingerprint string or None on failure
        """
        try:
            # Get the CA cert from the container
            cat_command = self.compose_command + [
                "exec", "-w", "/usr/share/elasticsearch/config/certs/ca",
                "elasticsearch", "cat", "ca.crt"
            ]
            
            cat_result = subprocess.run(
                cat_command,
                capture_output=True,
                text=True,
                check=True
            )
            
            # Get fingerprint using openssl
            openssl_result = subprocess.run(
                ["openssl", "x509", "-noout", "-fingerprint", "-sha256"],
                input=cat_result.stdout,
                capture_output=True,
                text=True,
                check=True
            )
            
            # Parse fingerprint (format: "SHA256 Fingerprint=XX:XX:XX...")
            fingerprint_line = openssl_result.stdout.strip()
            if "=" in fingerprint_line:
                fingerprint = fingerprint_line.split("=")[1].replace(":", "")
                return fingerprint
            
            return None
            
        except subprocess.CalledProcessError as e:
            if self.verbose:
                click.secho(f"Failed to get CA fingerprint: {e}", fg="red")
            return None
    
    def clear_documents(self, host_ip: str) -> bool:
        """
        Clear all documents in logs and metrics data streams
        
        Args:
            host_ip: Elasticsearch host IP
            
        Returns:
            True on success, False on failure
        """
        click.echo()
        click.secho("Clearing data streams...", fg="cyan", bold=True)
        click.echo()
        
        es_url = f"https://{host_ip}:{self.config.es_port}"
        auth = (self.config.elastic_username, self.config.elastic_password)
        
        success = True
        
        # Clear logs data stream
        try:
            response = requests.delete(
                f"{es_url}/_data_stream/logs-*",
                auth=auth,
                verify=False,
                timeout=30
            )
            
            if response.status_code == 200 and "true" in response.text:
                click.secho("✓ Successfully cleared logs data stream", fg="green")
            else:
                click.secho("✗ Failed to clear logs data stream", fg="red")
                success = False
                
        except Exception as e:
            click.secho(f"✗ Failed to clear logs data stream: {e}", fg="red")
            success = False
        
        # Clear metrics data stream
        try:
            response = requests.delete(
                f"{es_url}/_data_stream/metrics-*",
                auth=auth,
                verify=False,
                timeout=30
            )
            
            if response.status_code == 200 and "true" in response.text:
                click.secho("✓ Successfully cleared metrics data stream", fg="green")
            else:
                click.secho("✗ Failed to clear metrics data stream", fg="red")
                success = False
                
        except Exception as e:
            click.secho(f"✗ Failed to clear metrics data stream: {e}", fg="red")
            success = False
        
        click.echo()
        return success

