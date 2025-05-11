#!/bin/bash
set -e

# Create a timer to track startup performance
start_time=$(date +%s)
echo "Starting container setup..."

# Run dotnet and python setup in parallel
setup_dotnet() {
  echo "Setting up .NET environment..."
  # Use restore instead of update for faster startup
  dotnet workload restore
  dotnet dev-certs https --trust
  echo ".NET environment setup complete."
}

setup_python() {
  echo "Setting up Python environment..."
  # shellcheck disable=SC2164
  pushd python
  # Use uv for faster package installation
  if [ ! -f .venv/bin/activate ]; then
    echo "Creating Python virtual environment..."
    python -m pip install --upgrade pip
    pip install uv
    uv venv
  fi
  
  # Only run sync if packages have changed (check timestamp of pyproject.toml)
  if [ ! -f .venv/.last_sync ] || [ pyproject.toml -nt .venv/.last_sync ]; then
    echo "Syncing Python packages..."
    uv pip sync
    touch .venv/.last_sync
  else
    echo "Python packages already up to date."
  fi
  
  # shellcheck disable=SC1091
  source .venv/bin/activate
  
  # Only update PATH if not already done
  if ! grep -q "$(pwd)/.venv/bin" ~/.bashrc; then
    echo "export PATH=$PATH:$(pwd)/.venv/bin" >> ~/.bashrc
  fi
  
  # shellcheck disable=SC2164
  popd
  echo "Python environment setup complete."
}

# Run setup functions in parallel
setup_dotnet &
setup_python &

# Wait for all background jobs to complete
wait

# Display total setup time
end_time=$(date +%s)
elapsed=$((end_time - start_time))
echo "Container setup completed in ${elapsed} seconds."
