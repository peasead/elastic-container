#!/usr/bin/env python3
"""
Elastic Container - Python Edition

A 100% containerized Elastic Stack with Elasticsearch, Kibana, Fleet,
and the Detection Engine all pre-configured and ready to use.

This is a Python port of the elastic-container.sh bash script.
"""

import sys
import time
import click

from lib.config import Config
from lib.docker_manager import DockerManager
from lib.kibana_manager import KibanaManager
from lib.utils import get_host_ip, check_prerequisites


# ASCII art banner
BANNER = """
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║              ELASTIC CONTAINER - Python Edition                   ║
║                                                                   ║
║   Containerized Elastic Stack with Detection Engine & Fleet      ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
"""


@click.group(invoke_without_command=True)
@click.option('-v', '--verbose', is_flag=True, help='Enable verbose output')
@click.pass_context
def cli(ctx, verbose):
    """
    Elastic Container - Manage your containerized Elastic Stack
    
    Commands:
      stage     Download all Docker images to local storage
      start     Start the Elastic Stack containers
      stop      Stop running containers without removing them
      destroy   Stop and remove containers, networks, and volumes
      restart   Restart all stack containers
      status    Check the status of stack containers
      clear     Clear all documents in logs and metrics indexes
      help      Show this help message
    """
    # Store verbose flag in context for subcommands
    ctx.ensure_object(dict)
    ctx.obj['verbose'] = verbose
    
    # If no command provided, show help
    if ctx.invoked_subcommand is None:
        click.echo(ctx.get_help())


@cli.command()
@click.pass_context
def stage(ctx):
    """Download all necessary Docker images to local storage"""
    verbose = ctx.obj['verbose']
    
    try:
        # Initialize components
        config = Config()
        docker_manager = DockerManager(config, verbose=verbose)
        
        # Check Docker availability
        if not docker_manager.check_docker_available():
            sys.exit(1)
        
        # Pull images
        if docker_manager.stage():
            sys.exit(0)
        else:
            sys.exit(1)
            
    except KeyboardInterrupt:
        click.echo("\n\nOperation cancelled by user.")
        sys.exit(130)
    except Exception as e:
        click.secho(f"\n✗ Error: {e}", fg="red", bold=True)
        if verbose:
            import traceback
            click.echo(traceback.format_exc())
        sys.exit(1)


@cli.command()
@click.option('--force-setup', is_flag=True, help='Force full setup even if containers exist')
@click.pass_context
def start(ctx, force_setup):
    """Create container network and start all stack containers"""
    verbose = ctx.obj['verbose']
    
    try:
        if verbose:
            click.echo(BANNER)
        
        # Check prerequisites
        click.secho("Checking prerequisites...", fg="cyan")
        if not check_prerequisites(verbose=verbose):
            sys.exit(1)
        
        # Load configuration
        config = Config()
        
        # Validate passwords have been changed
        config.validate_passwords()
        
        # Initialize managers
        docker_manager = DockerManager(config, verbose=verbose)
        
        # Check Docker availability
        if not docker_manager.check_docker_available():
            sys.exit(1)
        
        # Check if containers already exist
        containers_exist, containers_running = docker_manager.check_containers_exist()
        
        if containers_exist and not force_setup:
            if containers_running:
                click.echo()
                click.secho("✓ Containers are already running!", fg="green", bold=True)
                click.echo()
                click.secho(f"Browse to {config.local_kibana_url}", fg="cyan", bold=True)
                click.echo()
                if verbose:
                    click.echo("Use 'python elastic-container.py status' to check container status")
                    click.echo("Use 'python elastic-container.py --force-setup start' to reconfigure")
                sys.exit(0)
            else:
                click.echo()
                click.secho("🔄 Containers exist but are stopped. Starting them...", fg="cyan", bold=True)
                click.echo()
                
                # Just start existing containers (quick)
                if not docker_manager.start():
                    sys.exit(1)
                
                click.echo()
                click.secho("=" * 70, fg="green", bold=True)
                click.secho("✓ Containers started successfully!", fg="green", bold=True)
                click.secho("=" * 70, fg="green", bold=True)
                click.echo()
                click.secho(f"Browse to {config.local_kibana_url}", fg="cyan", bold=True)
                click.echo()
                
                if verbose:
                    click.secho("Login Credentials:", fg="yellow", bold=True)
                    click.echo(f"  Username:   {config.elastic_username}")
                    click.echo(f"  Password:   {config.elastic_password}")
                    click.echo()
                
                click.secho("Note:", fg="yellow")
                click.echo("  • Existing configuration preserved")
                click.echo("  • Use --force-setup flag to reconfigure if needed")
                click.echo()
                
                sys.exit(0)
        
        # First-time setup or forced setup
        if force_setup:
            click.echo()
            click.secho("🔧 Force setup requested - running full configuration...", fg="yellow")
        
        # Get host IP for Fleet configuration
        host_ip = get_host_ip()
        if verbose:
            click.secho(f"Host IP: {host_ip}", fg="cyan")
        
        # Start containers
        if not docker_manager.start():
            sys.exit(1)
        
        # Initialize Kibana manager
        kibana_manager = KibanaManager(config, docker_manager, host_ip, verbose=verbose)
        
        # Configure Detection Engine and rules
        if not kibana_manager.configure_detection_engine():
            click.secho("\n⚠ Warning: Detection Engine configuration had issues", fg="yellow")
            click.echo("The stack is running but some features may not be configured.")
        
        # Wait for Fleet Server to be ready
        click.echo()
        click.secho("Waiting 40 seconds for Fleet Server setup...", fg="cyan")
        click.echo()
        time.sleep(40)
        
        # Configure Fleet
        click.echo("Populating Fleet Settings...")
        if not kibana_manager.setup_fleet():
            click.secho("\n⚠ Warning: Fleet configuration had issues", fg="yellow")
            click.echo("The stack is running but Fleet may not be fully configured.")
        
        # Success message
        click.echo()
        click.secho("=" * 70, fg="green", bold=True)
        click.secho("✓ Elastic Stack started successfully", fg="green", bold=True)
        click.secho("=" * 70, fg="green", bold=True)
        click.echo()
        click.secho(f"Browse to {config.local_kibana_url}", fg="cyan", bold=True)
        click.echo()
        
        if verbose:
            click.secho("Login Credentials:", fg="yellow", bold=True)
            click.echo(f"  Username:   {config.elastic_username}")
            click.echo(f"  Password:   {config.elastic_password}")
            click.echo()
        
        click.secho("Note:", fg="yellow")
        click.echo("  • You may see a browser warning due to self-signed certificates")
        click.echo("  • Type 'thisisnotsafe' or click proceed to continue to login")
        click.echo()
        
        sys.exit(0)
        
    except KeyboardInterrupt:
        click.echo("\n\nOperation cancelled by user.")
        sys.exit(130)
    except Exception as e:
        click.secho(f"\n✗ Error: {e}", fg="red", bold=True)
        if verbose:
            import traceback
            click.echo(traceback.format_exc())
        sys.exit(1)


@cli.command()
@click.pass_context
def stop(ctx):
    """Stop running containers without removing them"""
    verbose = ctx.obj['verbose']
    
    try:
        config = Config()
        docker_manager = DockerManager(config, verbose=verbose)
        
        if not docker_manager.check_docker_available():
            sys.exit(1)
        
        # Check if containers exist
        containers_exist, containers_running = docker_manager.check_containers_exist()
        
        if not containers_exist:
            click.echo()
            click.secho("✗ No containers found!", fg="red", bold=True)
            click.echo()
            click.echo("Run 'python elastic-container.py start' to create containers first.")
            click.echo()
            sys.exit(1)
        
        if not containers_running:
            click.echo()
            click.secho("✓ Containers are already stopped", fg="green")
            click.echo()
            sys.exit(0)
        
        if docker_manager.stop():
            sys.exit(0)
        else:
            sys.exit(1)
            
    except KeyboardInterrupt:
        click.echo("\n\nOperation cancelled by user.")
        sys.exit(130)
    except Exception as e:
        click.secho(f"\n✗ Error: {e}", fg="red", bold=True)
        if verbose:
            import traceback
            click.echo(traceback.format_exc())
        sys.exit(1)


@cli.command()
@click.pass_context
def destroy(ctx):
    """Stop and remove containers, networks, and volumes"""
    verbose = ctx.obj['verbose']
    
    try:
        config = Config()
        docker_manager = DockerManager(config, verbose=verbose)
        
        if not docker_manager.check_docker_available():
            sys.exit(1)
        
        if docker_manager.destroy():
            sys.exit(0)
        else:
            sys.exit(1)
            
    except KeyboardInterrupt:
        click.echo("\n\nOperation cancelled by user.")
        sys.exit(130)
    except Exception as e:
        click.secho(f"\n✗ Error: {e}", fg="red", bold=True)
        if verbose:
            import traceback
            click.echo(traceback.format_exc())
        sys.exit(1)


@cli.command()
@click.pass_context
def restart(ctx):
    """Restart all Elastic Stack containers"""
    verbose = ctx.obj['verbose']
    
    try:
        config = Config()
        docker_manager = DockerManager(config, verbose=verbose)
        
        if not docker_manager.check_docker_available():
            sys.exit(1)
        
        # Check if containers exist
        containers_exist, containers_running = docker_manager.check_containers_exist()
        
        if not containers_exist:
            click.echo()
            click.secho("✗ No containers found!", fg="red", bold=True)
            click.echo()
            click.echo("Run 'python elastic-container.py start' to create and start containers first.")
            click.echo()
            sys.exit(1)
        
        if not containers_running:
            click.echo()
            click.secho("⚠ Containers exist but are not running", fg="yellow")
            click.echo("Starting them instead of restarting...")
            click.echo()
            
            if docker_manager.start():
                click.secho("✓ Containers started successfully!", fg="green")
                sys.exit(0)
            else:
                sys.exit(1)
        
        # Containers exist and are running - restart them
        if docker_manager.restart():
            sys.exit(0)
        else:
            sys.exit(1)
            
    except KeyboardInterrupt:
        click.echo("\n\nOperation cancelled by user.")
        sys.exit(130)
    except Exception as e:
        click.secho(f"\n✗ Error: {e}", fg="red", bold=True)
        if verbose:
            import traceback
            click.echo(traceback.format_exc())
        sys.exit(1)


@cli.command()
@click.pass_context
def status(ctx):
    """Check the status of all stack containers"""
    verbose = ctx.obj['verbose']
    
    try:
        config = Config()
        docker_manager = DockerManager(config, verbose=verbose)
        
        if not docker_manager.check_docker_available():
            sys.exit(1)
        
        if docker_manager.status():
            sys.exit(0)
        else:
            sys.exit(1)
            
    except KeyboardInterrupt:
        click.echo("\n\nOperation cancelled by user.")
        sys.exit(130)
    except Exception as e:
        click.secho(f"\n✗ Error: {e}", fg="red", bold=True)
        if verbose:
            import traceback
            click.echo(traceback.format_exc())
        sys.exit(1)


@cli.command()
@click.pass_context
def clear(ctx):
    """Clear all documents in logs and metrics data streams"""
    verbose = ctx.obj['verbose']
    
    try:
        config = Config()
        docker_manager = DockerManager(config, verbose=verbose)
        
        if not docker_manager.check_docker_available():
            sys.exit(1)
        
        # Get host IP
        host_ip = get_host_ip()
        
        if docker_manager.clear_documents(host_ip):
            sys.exit(0)
        else:
            sys.exit(1)
            
    except KeyboardInterrupt:
        click.echo("\n\nOperation cancelled by user.")
        sys.exit(130)
    except Exception as e:
        click.secho(f"\n✗ Error: {e}", fg="red", bold=True)
        if verbose:
            import traceback
            click.echo(traceback.format_exc())
        sys.exit(1)


@cli.command('help')
@click.pass_context
def help_command(ctx):
    """Show this help message"""
    # Get the parent context (the group) to show its help
    click.echo(ctx.parent.get_help())


def main():
    """Main entry point"""
    cli(obj={})


if __name__ == '__main__':
    main()

