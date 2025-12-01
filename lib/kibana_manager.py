"""
Kibana and Fleet configuration for Elastic Container
Handles Detection Engine setup and Fleet Server configuration
"""

import time
import json
import click
import requests
from typing import Optional
from urllib3.exceptions import InsecureRequestWarning

from .config import Config
from .docker_manager import DockerManager

# Suppress SSL warnings for self-signed certificates
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)


class KibanaManager:
    """
    Manages Kibana configuration including Detection Engine and Fleet setup
    """
    
    def __init__(self, config: Config, docker_manager: DockerManager, host_ip: str, verbose: bool = False):
        """
        Initialize Kibana Manager
        
        Args:
            config: Configuration object
            docker_manager: Docker manager for operations like getting CA fingerprint
            host_ip: Host IP address for Fleet configuration
            verbose: Enable verbose output
        """
        self.config = config
        self.docker_manager = docker_manager
        self.host_ip = host_ip
        self.verbose = verbose
        
        # Common headers for Kibana API requests
        self.headers = {
            "kbn-version": config.stack_version,
            "kbn-xsrf": "kibana",
            "Content-Type": "application/json"
        }
        
        # Authentication
        self.auth = (config.elastic_username, config.elastic_password)
    
    def _wait_for_kibana(self, max_tries: int = 15, retry_delay: int = 40) -> bool:
        """
        Wait for Kibana to be ready by checking HTTP status
        
        Args:
            max_tries: Maximum number of retry attempts
            retry_delay: Seconds to wait between retries
            
        Returns:
            True if Kibana is ready, False if timeout
        """
        click.echo()
        click.secho("Waiting for Kibana to be ready...", fg="cyan", bold=True)
        
        for attempt in range(max_tries, 0, -1):
            try:
                # Check Kibana status (HEAD request)
                response = requests.head(
                    self.config.local_kibana_url,
                    verify=False,
                    timeout=10,
                    allow_redirects=False
                )
                
                if self.verbose:
                    click.echo(f"Attempt {max_tries - attempt + 1}/{max_tries}: Status {response.status_code}")
                
                # Status 302 indicates Kibana is ready (redirect to login)
                if response.status_code == 302:
                    click.echo()
                    click.secho("✓ Kibana is up. Proceeding.", fg="green")
                    click.echo()
                    return True
                    
            except requests.exceptions.RequestException as e:
                if self.verbose:
                    click.secho(f"Connection attempt failed: {e}", fg="yellow", dim=True)
            
            if attempt > 1:
                click.echo()
                click.echo(f"Kibana still loading. Trying again in {retry_delay} seconds...")
                click.echo(f"Attempts remaining: {attempt - 1}")
                time.sleep(retry_delay)
        
        click.echo()
        click.secho(f"✗ Exceeded maximum tries ({max_tries}) waiting for Kibana", fg="red", bold=True)
        return False
    
    def _enable_detection_engine(self) -> bool:
        """
        Enable the Detection Engine in Kibana
        
        Returns:
            True on success, False on failure
        """
        try:
            response = requests.post(
                f"{self.config.local_kibana_url}/api/detection_engine/index",
                headers=self.headers,
                auth=self.auth,
                verify=False,
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get("acknowledged"):
                    if self.verbose:
                        click.secho("✓ Detection Engine enabled", fg="green")
                    return True
            
            click.echo()
            click.secho("✗ Detection Engine setup failed :-(", fg="red")
            click.echo(f"Status: {response.status_code}")
            click.echo(f"Response: {response.text}")
            return False
            
        except Exception as e:
            click.echo()
            click.secho(f"✗ Detection Engine setup failed: {e}", fg="red")
            return False
    
    def _install_prepackaged_rules(self) -> bool:
        """
        Install prepackaged detection rules
        
        Returns:
            True on success, False on failure
        """
        try:
            response = requests.put(
                f"{self.config.local_kibana_url}/api/detection_engine/rules/prepackaged",
                headers=self.headers,
                auth=self.auth,
                verify=False,
                timeout=180
            )
            
            if response.status_code in [200, 201]:
                if self.verbose:
                    click.secho("✓ Prepackaged rules installed", fg="green")
                return True
            else:
                click.secho(f"⚠ Warning: Prepackaged rules status {response.status_code}", fg="yellow")
                return True  # Continue anyway
                
        except Exception as e:
            click.secho(f"⚠ Warning: Failed to install prepackaged rules: {e}", fg="yellow")
            return True  # Continue anyway
    
    def _enable_detection_rules_by_os(self, os_name: str, query: str) -> bool:
        """
        Enable detection rules for a specific OS
        
        Args:
            os_name: Name of OS (for display)
            query: Lucene query to select rules
            
        Returns:
            True on success, False on failure
        """
        try:
            payload = {
                "query": query,
                "action": "enable"
            }
            
            response = requests.post(
                f"{self.config.local_kibana_url}/api/detection_engine/rules/_bulk_action",
                headers=self.headers,
                auth=self.auth,
                json=payload,
                verify=False,
                timeout=120
            )
            
            if response.status_code in [200, 201]:
                click.echo()
                click.secho(f"✓ Successfully enabled {os_name} detection rules", fg="green")
                return True
            else:
                click.secho(f"⚠ Warning: {os_name} rules status {response.status_code}", fg="yellow")
                return True  # Continue anyway
                
        except Exception as e:
            click.secho(f"⚠ Warning: Failed to enable {os_name} rules: {e}", fg="yellow")
            return True  # Continue anyway
    
    def configure_detection_engine(self) -> bool:
        """
        Configure Detection Engine and install/enable detection rules
        
        Returns:
            True on success, False on failure
        """
        click.echo()
        click.secho("Configuring Detection Engine...", fg="cyan", bold=True)
        
        # Wait for Kibana to be ready
        if not self._wait_for_kibana():
            return False
        
        # Enable Detection Engine
        click.echo("Enabling Detection Engine...")
        if not self._enable_detection_engine():
            return False
        
        # Install prepackaged rules
        click.echo("Installing prepackaged detection rules...")
        if not self._install_prepackaged_rules():
            return False
        
        click.echo()
        click.secho("✓ Prepackaged rules installed!", fg="green", bold=True)
        click.echo()
        
        # Check if any OS-specific rules should be enabled
        any_enabled = (
            self.config.linux_detection_rules or
            self.config.windows_detection_rules or
            self.config.macos_detection_rules
        )
        
        if not any_enabled:
            click.echo("No detection rules enabled in the .env file, skipping detection rules enablement.")
            click.echo()
            return True
        
        # Enable rules by OS
        click.echo("Enabling detection rules by OS...")
        
        if self.config.linux_detection_rules:
            self._enable_detection_rules_by_os(
                "Linux",
                'alert.attributes.tags: ("Linux" OR "OS: Linux")'
            )
        
        if self.config.windows_detection_rules:
            self._enable_detection_rules_by_os(
                "Windows",
                'alert.attributes.tags: ("Windows" OR "OS: Windows")'
            )
        
        if self.config.macos_detection_rules:
            self._enable_detection_rules_by_os(
                "macOS",
                'alert.attributes.tags: ("macOS" OR "OS: macOS")'
            )
        
        click.echo()
        return True
    
    def setup_fleet(self) -> bool:
        """
        Configure Fleet Server settings and create default agent policy
        
        Returns:
            True on success, False on failure
        """
        click.echo()
        click.secho("Configuring Fleet Server...", fg="cyan", bold=True)
        click.echo()
        
        try:
            # Check if Fleet is already initialized
            response = requests.get(
                f"{self.config.local_kibana_url}/api/fleet/agents/setup",
                headers=self.headers,
                auth=self.auth,
                verify=False,
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get("isInitialized"):
                    click.secho("✓ Fleet settings are already configured.", fg="green")
                    return True
            
            click.echo("Fleet is not initialized, setting up Fleet...")
            
            # Get CA fingerprint from Elasticsearch container
            click.echo("Extracting CA certificate fingerprint...")
            fingerprint = self.docker_manager.get_ca_fingerprint()
            
            if not fingerprint:
                click.secho("✗ Failed to get CA fingerprint", fg="red")
                return False
            
            if self.verbose:
                click.secho(f"CA Fingerprint: {fingerprint}", fg="cyan", dim=True)
            
            # Configure Fleet Server host
            click.echo("Configuring Fleet Server host...")
            fleet_host_payload = {
                "host_urls": [f"https://{self.host_ip}:{self.config.fleet_port}"],
                "name": "default",
                "is_default": True
            }
            
            response = requests.post(
                f"{self.config.local_kibana_url}/api/fleet/fleet_server_hosts",
                headers=self.headers,
                auth=self.auth,
                json=fleet_host_payload,
                verify=False,
                timeout=30
            )
            
            if self.verbose and response.status_code in [200, 201]:
                click.secho("✓ Fleet Server host configured", fg="green")
            
            # Configure Elasticsearch output - hosts
            click.echo("Configuring Elasticsearch output...")
            es_output_payload = {
                "hosts": [f"https://{self.host_ip}:9200"]
            }
            
            requests.put(
                f"{self.config.local_kibana_url}/api/fleet/outputs/fleet-default-output",
                headers=self.headers,
                auth=self.auth,
                json=es_output_payload,
                verify=False,
                timeout=30
            )
            
            # Configure CA fingerprint
            ca_payload = {
                "ca_trusted_fingerprint": fingerprint
            }
            
            requests.put(
                f"{self.config.local_kibana_url}/api/fleet/outputs/fleet-default-output",
                headers=self.headers,
                auth=self.auth,
                json=ca_payload,
                verify=False,
                timeout=30
            )
            
            # Configure SSL verification mode
            ssl_payload = {
                "config_yaml": "ssl.verification_mode: certificate"
            }
            
            requests.put(
                f"{self.config.local_kibana_url}/api/fleet/outputs/fleet-default-output",
                headers=self.headers,
                auth=self.auth,
                json=ssl_payload,
                verify=False,
                timeout=30
            )
            
            if self.verbose:
                click.secho("✓ Elasticsearch output configured", fg="green")
            
            # Create agent policy
            click.echo("Creating agent policy...")
            policy_payload = {
                "name": "Endpoint Policy",
                "description": "",
                "namespace": "default",
                "monitoring_enabled": ["logs", "metrics"],
                "inactivity_timeout": 1209600
            }
            
            response = requests.post(
                f"{self.config.local_kibana_url}/api/fleet/agent_policies?sys_monitoring=true",
                headers=self.headers,
                auth=self.auth,
                json=policy_payload,
                verify=False,
                timeout=30
            )
            
            if response.status_code not in [200, 201]:
                click.secho(f"⚠ Warning: Agent policy creation status {response.status_code}", fg="yellow")
                return True  # Continue anyway
            
            policy_id = response.json().get("item", {}).get("id")
            
            if not policy_id:
                click.secho("⚠ Warning: Could not get policy ID", fg="yellow")
                return True
            
            if self.verbose:
                click.secho(f"✓ Agent policy created: {policy_id}", fg="green")
            
            # Get endpoint package version
            click.echo("Installing Elastic Defend package...")
            response = requests.get(
                f"{self.config.local_kibana_url}/api/fleet/epm/packages/endpoint",
                headers=self.headers,
                auth=self.auth,
                verify=False,
                timeout=30
            )
            
            pkg_version = None
            if response.status_code == 200:
                pkg_version = response.json().get("item", {}).get("version")
            
            if not pkg_version:
                click.secho("⚠ Warning: Could not get endpoint package version", fg="yellow")
                return True
            
            # Install Elastic Defend integration
            package_policy_payload = {
                "name": "Elastic Defend",
                "description": "",
                "namespace": "default",
                "policy_id": policy_id,
                "enabled": True,
                "inputs": [
                    {
                        "enabled": True,
                        "streams": [],
                        "type": "ENDPOINT_INTEGRATION_CONFIG",
                        "config": {
                            "_config": {
                                "value": {
                                    "type": "endpoint",
                                    "endpointConfig": {
                                        "preset": "EDRComplete"
                                    }
                                }
                            }
                        }
                    }
                ],
                "package": {
                    "name": "endpoint",
                    "title": "Elastic Defend",
                    "version": pkg_version
                }
            }
            
            response = requests.post(
                f"{self.config.local_kibana_url}/api/fleet/package_policies",
                headers=self.headers,
                auth=self.auth,
                json=package_policy_payload,
                verify=False,
                timeout=30
            )
            
            if response.status_code in [200, 201]:
                if self.verbose:
                    click.secho("✓ Elastic Defend package installed", fg="green")
            else:
                click.secho(f"⚠ Warning: Package policy status {response.status_code}", fg="yellow")
            
            click.echo()
            click.secho("✓ Fleet Server configuration complete!", fg="green", bold=True)
            return True
            
        except Exception as e:
            click.echo()
            click.secho(f"✗ Fleet setup failed: {e}", fg="red")
            if self.verbose:
                import traceback
                click.echo(traceback.format_exc())
            return True  # Don't fail the entire startup

