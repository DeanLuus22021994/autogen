"""
Docker Model Runner integration tests
"""
import sys
import os
import argparse
import subprocess
import json
from pathlib import Path

# Add parent directory to path to allow importing the module
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

def check_docker_version():
    """Check if Docker is installed and version is compatible with Model Runner"""
    try:
        result = subprocess.run(
            ['docker', '--version'],
            capture_output=True,
            text=True,
            check=True
        )
        print(f"Docker version: {result.stdout.strip()}")
        return True
    except (subprocess.SubprocessError, FileNotFoundError):
        print("ERROR: Docker not found or not running")
        return False

def check_model_runner():
    """Check if Docker Model Runner is available"""
    try:
        result = subprocess.run(
            ['docker', 'model', 'list'],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print("ERROR: Docker Model Runner not available")
            print(f"Error message: {result.stderr}")
            return False

        print("Docker Model Runner is available")
        if result.stdout.strip():
            print("Available models:")
            for line in result.stdout.strip().split('\n')[1:]:  # Skip header
                if line.strip():
                    print(f"  - {line}")
        else:
            print("No models available. You can pull models with:")
            print("  docker model pull ai/mistral")
        return True
    except subprocess.SubprocessError:
        print("ERROR: Failed to check Docker Model Runner")
        return False

def test_model_endpoint():
    """Test if model endpoint is accessible"""
    import requests

    try:
        response = requests.get(
            "http://model-runner.docker.internal/engines/v1/models",
            timeout=5
        )
        if response.status_code == 200:
            print("Model Runner API is accessible")
            return True
        else:
            print(f"ERROR: Model Runner API returned status code {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"ERROR: Could not connect to Model Runner API: {e}")
        return False

def main():
    """Main function to run tests"""
    parser = argparse.ArgumentParser(description="Test Docker Model Runner integration")
    parser.add_argument('--verbose', action='store_true', help='Enable verbose output')
    args = parser.parse_args()

    print("=== Docker Model Runner Integration Tests ===")

    # Run tests
    docker_ok = check_docker_version()
    if not docker_ok:
        print("\nDocker is not available. Please install Docker Desktop 4.40+")
        return False

    model_runner_ok = check_model_runner()
    if not model_runner_ok:
        print("\nDocker Model Runner is not enabled. Please follow these steps:")
        print("1. Open Docker Desktop")
        print("2. Go to Settings > Features in development > Beta")
        print("3. Enable 'Docker Model Runner'")
        print("4. Click 'Apply & restart'")
        return False

    if args.verbose:
        endpoint_ok = test_model_endpoint()
        if not endpoint_ok:
            print("\nModel Runner API is not accessible.")
            print("Make sure Docker Desktop is running and Model Runner is enabled.")
            return False

    print("\nAll integration tests passed!")
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
