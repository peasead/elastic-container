"""
Utility functions for Elastic Container
System checks, IP detection, and command execution helpers
"""

import subprocess
import sys
import platform
import click
from typing import Tuple, Optional


def get_host_ip() -> str:
    """
    Detect the host's IP address based on operating system
    
    Returns:
        IP address as string, defaults to "0.0.0.0" if detection fails
    """
    os_name = platform.system()
    
    try:
        if os_name == "Linux":
            # Use hostname -I on Linux
            result = subprocess.run(
                ["hostname", "-I"],
                capture_output=True,
                text=True,
                check=True
            )
            # Get first IP from the output
            ip = result.stdout.strip().split()[0]
            return ip
            
        elif os_name == "Darwin":  # macOS
            # Use ifconfig en0 on macOS
            result = subprocess.run(
                ["ifconfig", "en0"],
                capture_output=True,
                text=True,
                check=True
            )
            # Parse inet line
            for line in result.stdout.split('\n'):
                line = line.strip()
                if line.startswith('inet '):
                    ip = line.split()[1]
                    return ip
        
        # Default fallback
        click.secho("⚠ Warning: Could not detect IP address, using 0.0.0.0", fg="yellow")
        return "0.0.0.0"
        
    except Exception as e:
        click.secho(f"⚠ Warning: Error detecting IP address: {e}", fg="yellow")
        return "0.0.0.0"


def check_python_version() -> bool:
    """
    Check if Python version is 3.10 or higher
    
    Returns:
        True if version is acceptable, False otherwise
    """
    version_info = sys.version_info
    
    if version_info.major < 3 or (version_info.major == 3 and version_info.minor < 10):
        click.secho("\n❌ Error: Python 3.10 or higher is required!", fg="red", bold=True)
        click.echo()
        click.echo(f"Current version: Python {version_info.major}.{version_info.minor}.{version_info.micro}")
        click.echo("Required version: Python 3.10+")
        click.echo()
        click.secho("Please upgrade Python:", fg="yellow")
        click.echo("  • macOS: brew upgrade python3")
        click.echo("  • Linux: Use your package manager")
        click.echo("  • Windows: Download from python.org")
        click.echo()
        click.secho("Check the project documentation at:", fg="cyan")
        click.secho("https://github.com/peasead/elastic-container#README.md#Docker", fg="blue", bold=True)
        click.echo()
        return False
    
    return True


def run_command(
    command: list,
    check: bool = True,
    capture_output: bool = True,
    verbose: bool = False
) -> Tuple[int, str, str]:
    """
    Execute a shell command and return results
    
    Args:
        command: Command as list of strings
        check: Raise exception on non-zero exit code
        capture_output: Capture stdout/stderr
        verbose: Print command and output
        
    Returns:
        Tuple of (exit_code, stdout, stderr)
    """
    if verbose:
        click.secho(f"Running: {' '.join(command)}", fg="cyan", dim=True)
    
    try:
        result = subprocess.run(
            command,
            capture_output=capture_output,
            text=True,
            check=check
        )
        
        if verbose and result.stdout:
            click.echo(result.stdout)
        
        return result.returncode, result.stdout, result.stderr
        
    except subprocess.CalledProcessError as e:
        if verbose:
            click.secho(f"Command failed with exit code {e.returncode}", fg="red")
            if e.stderr:
                click.echo(e.stderr)
        
        return e.returncode, e.stdout if e.stdout else "", e.stderr if e.stderr else ""
    
    except FileNotFoundError:
        error_msg = f"Command not found: {command[0]}"
        if verbose:
            click.secho(error_msg, fg="red")
        return 127, "", error_msg


def check_prerequisites(verbose: bool = False) -> bool:
    """
    Check that all prerequisites are installed and available
    
    Args:
        verbose: Print detailed information
        
    Returns:
        True if all prerequisites met, False otherwise
    """
    if verbose:
        click.secho("Checking prerequisites...", fg="cyan")
    
    # Check Python version
    if not check_python_version():
        return False
    
    if verbose:
        click.secho("✓ Python version OK", fg="green")
    
    return True


def show_docker_error(error_type: str, details: str = "", suggestions: Optional[list] = None):
    """
    Show formatted Docker error message with documentation link
    
    Args:
        error_type: Short error description
        details: Detailed error information
        suggestions: List of suggestions to fix the issue
    """
    click.echo()
    click.secho(f"❌ Error: {error_type}", fg="red", bold=True)
    click.echo()
    
    if details:
        click.echo(details)
        click.echo()
    
    if suggestions:
        click.secho("Troubleshooting:", fg="yellow", bold=True)
        for suggestion in suggestions:
            click.echo(f"  • {suggestion}")
        click.echo()
    
    click.secho("Check the project documentation at:", fg="cyan")
    click.secho("https://github.com/peasead/elastic-container#README.md#Docker", fg="blue", bold=True)
    click.echo()

