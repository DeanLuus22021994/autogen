#!/bin/bash
set -e

start_time=$(date +%s)
MARKER_FILE="/tmp/container-initialized"
[ -f "$MARKER_FILE" ] && {
    echo "Container already initialized."
    echo "Container is ready!" > /tmp/container-ready
    echo "Container ready in 0 seconds (cached)."
    exit 0
}

configure_gpu() {
    if [ -c /dev/nvidia0 ] || [ -d /proc/driver/nvidia ]; then
        export NVIDIA_VISIBLE_DEVICES=all
        export CUDA_VISIBLE_DEVICES=0
        python3 -c 'import ctypes; ctypes.CDLL("libcuda.so.1")' || true
    fi
}

setup_dotnet() {
    [ -d "/root/.nuget/packages" ] && [ "$(ls -A /root/.nuget/packages)" ] || dotnet workload restore
    dotnet dev-certs https --trust
}

setup_python() {
    local py_dir="/workspaces/autogen/python"
    [ -d ../python ] && py_dir="../python" || [ -d ./python ] && py_dir="./python"
    [ -d "$py_dir" ] || return
    cd "$py_dir"
    [ -f .venv/bin/activate ] || {
        python3 -m pip install --upgrade pip
        command -v uv &>/dev/null || pip install uv
        uv venv --system-site-packages .venv
    }
    if [ ! -f .venv/.last_sync ] || [ pyproject.toml -nt .venv/.last_sync ] || [ uv.lock -nt .venv/.last_sync ]; then
        uv pip sync --no-cache-dir --jobs "$(nproc)"
        touch .venv/.last_sync
    fi
    source .venv/bin/activate
    grep -q "$(pwd)/.venv/bin" ~/.bashrc || echo "export PATH=\$PATH:$(pwd)/.venv/bin" >> ~/.bashrc
    cd - >/dev/null
}

configure_gpu
setup_dotnet &
setup_python &
wait
touch "$MARKER_FILE"
echo "Container is ready!" > /tmp/container-ready
echo "Container setup completed in $(( $(date +%s) - start_time )) seconds."

