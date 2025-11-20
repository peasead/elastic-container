"""
Configuration management for Elastic Container
Loads and validates .env file settings
"""

import os
import sys
from pathlib import Path
from typing import Optional
from dotenv import load_dotenv
import click


class Config:
    """
    Manages configuration from .env file
    Validates required settings and provides easy access to all config values
    """
    
    def __init__(self, env_file: str = ".env"):
        """
        Initialize configuration by loading .env file
        
        Args:
            env_file: Path to .env file (default: .env)
        """
        self.env_file = Path(env_file)
        
        # Check if .env file exists
        if not self.env_file.exists():
            click.secho(f"Error: {env_file} file not found!", fg="red", bold=True)
            click.secho(f"Please create a {env_file} file with required configuration.", fg="yellow")
            click.secho("\nRequired variables:", fg="yellow")
            click.secho("  - ELASTIC_PASSWORD", fg="yellow")
            click.secho("  - KIBANA_PASSWORD", fg="yellow")
            click.secho("  - STACK_VERSION", fg="yellow")
            sys.exit(1)
        
        # Load environment variables from .env file
        load_dotenv(self.env_file)
        
        # Validate required variables exist
        self._validate_required_variables()
    
    def _validate_required_variables(self):
        """Ensure all required environment variables are set"""
        required_vars = [
            "ELASTIC_PASSWORD",
            "KIBANA_PASSWORD",
            "STACK_VERSION"
        ]
        
        missing_vars = [var for var in required_vars if not os.getenv(var)]
        
        if missing_vars:
            click.secho("Error: Missing required environment variables in .env file:", fg="red", bold=True)
            for var in missing_vars:
                click.secho(f"  - {var}", fg="red")
            sys.exit(1)
    
    def validate_passwords(self):
        """
        Validate that default passwords have been changed
        Exits with error if passwords are still set to 'changeme'
        """
        if "changeme" in [self.elastic_password.lower(), self.kibana_password.lower()]:
            click.secho("\n" + "=" * 70, fg="red")
            click.secho("ERROR: Default passwords detected!", fg="red", bold=True)
            click.secho("=" * 70, fg="red")
            click.echo()
            click.secho("Sorry, looks like you haven't updated the passphrase from the default.", fg="yellow")
            click.secho("Please update the 'changeme' passphrases in the .env file.", fg="yellow")
            click.echo()
            click.secho("Security Note:", fg="cyan", bold=True)
            click.secho("  This project is intended for local security research only.", fg="cyan")
            click.secho("  You must change default passwords before starting.", fg="cyan")
            click.echo()
            sys.exit(1)
        
        click.secho("✓ Passphrase has been changed. Proceeding.", fg="green")
    
    def get(self, key: str, default: Optional[str] = None) -> Optional[str]:
        """
        Get environment variable value
        
        Args:
            key: Environment variable name
            default: Default value if not found
            
        Returns:
            Variable value or default
        """
        return os.getenv(key, default)
    
    # Elastic credentials
    @property
    def elastic_username(self) -> str:
        """Elasticsearch username (default: elastic)"""
        return self.get("ELASTIC_USERNAME", "elastic")
    
    @property
    def elastic_password(self) -> str:
        """Elasticsearch password"""
        return self.get("ELASTIC_PASSWORD", "")
    
    @property
    def kibana_password(self) -> str:
        """Kibana system user password"""
        return self.get("KIBANA_PASSWORD", "")
    
    # Stack configuration
    @property
    def stack_version(self) -> str:
        """Elastic Stack version"""
        return self.get("STACK_VERSION", "8.14.0")
    
    @property
    def cluster_name(self) -> str:
        """Elasticsearch cluster name"""
        return self.get("CLUSTER_NAME", "docker-cluster")
    
    @property
    def license(self) -> str:
        """Elasticsearch license type"""
        return self.get("LICENSE", "basic")
    
    # Ports
    @property
    def es_port(self) -> int:
        """Elasticsearch port"""
        return int(self.get("ES_PORT", "9200"))
    
    @property
    def kibana_port(self) -> int:
        """Kibana port"""
        return int(self.get("KIBANA_PORT", "5601"))
    
    @property
    def fleet_port(self) -> int:
        """Fleet Server port"""
        return int(self.get("FLEET_PORT", "8220"))
    
    # Resource limits
    @property
    def mem_limit(self) -> str:
        """Memory limit for containers"""
        return self.get("MEM_LIMIT", "1073741824")  # 1GB default
    
    # Detection Rules
    @property
    def linux_detection_rules(self) -> bool:
        """Enable Linux detection rules"""
        return self.get("LinuxDR", "0") == "1"
    
    @property
    def windows_detection_rules(self) -> bool:
        """Enable Windows detection rules"""
        return self.get("WindowsDR", "0") == "1"
    
    @property
    def macos_detection_rules(self) -> bool:
        """Enable macOS detection rules"""
        return self.get("MacOSDR", "0") == "1"
    
    # Constructed URLs
    @property
    def local_kibana_url(self) -> str:
        """Local Kibana URL"""
        return f"https://localhost:{self.kibana_port}"
    
    @property
    def local_elasticsearch_url(self) -> str:
        """Local Elasticsearch URL"""
        return f"https://localhost:{self.es_port}"
    
    def __repr__(self) -> str:
        """String representation of config (hides passwords)"""
        return (
            f"Config(stack_version={self.stack_version}, "
            f"kibana_port={self.kibana_port}, "
            f"es_port={self.es_port}, "
            f"fleet_port={self.fleet_port})"
        )

