"""
Docker AutoGen Studio Component.

This module provides functionality to build and run AutoGen Studio in Docker,
making it easy to get started with the full-featured UI for AutoGen.
"""

import os
import argparse
from menu.utils import run_command, debug_args, ROOT_DIR


@debug_args
def docker_studio(args: argparse.Namespace) -> int:
    """
    Build and run AutoGen Studio in Docker.

    This tool builds and runs AutoGen Studio, a visual interface for creating, testing,
    and deploying agent workflows. Running in Docker ensures consistent environments
    across different systems.

    Key features:
    - One-click setup of AutoGen Studio
    - Persistent storage for workflows and data
    - Configurable container resources
    - Production-ready deployment options
    """
    # Auto-recompile check - this module will be recompiled on each run if valid
    print(f"[DEBUG] Running module: {__name__}")
    print(f"[DEBUG] Module path: {os.path.abspath(__file__)}")

    # Build the Docker image
    build_cmd = [
        "docker", "build",
        "-t", "autogen-studio",
        "--build-arg", f"NODE_ENV={args.node_env}",
        "--build-arg", f"BUILD_OPTIMIZE={str(args.build_optimize).lower()}",
        "--build-arg", f"ENABLE_SOURCE_MAPS={str(args.enable_source_maps).lower()}",
        "--build-arg", f"CACHE_DIR={args.cache_dir}",
        "--build-arg", f"NUM_WORKERS={args.num_workers}",
        "-f", "python/samples/apps/autogen-studio/Dockerfile",
        "."
    ]

    if run_command(build_cmd) != 0:
        print("[ERROR] Docker build failed")
        return 1

    # Create volume directories if they don't exist
    data_dir = os.path.abspath(os.path.join(ROOT_DIR, args.data_volume))
    storage_dir = os.path.abspath(os.path.join(ROOT_DIR, args.storage_volume))

    os.makedirs(data_dir, exist_ok=True)
    os.makedirs(storage_dir, exist_ok=True)

    # Run the Docker container
    run_cmd = [
        "docker", "run",
        "-p", f"{args.port}:8081",
        "-v", f"{data_dir}:/app/data",
        "-v", f"{storage_dir}:/app/storage",
        "-e", "AUTOGENSTUDIO_DATABASE_URI=sqlite:///data/autogenstudio.db",
        "-e", "AUTOGENSTUDIO_STORAGE_PATH=/app/storage",
        "-e", f"AUTOGENSTUDIO_ENABLE_CACHE={str(args.enable_cache).lower()}",
        "-e", f"AUTOGENSTUDIO_CACHE_DIR=/app/.cache",
        "-e", f"AUTOGENSTUDIO_NUM_WORKERS={args.num_workers}",
        "-e", "AUTOGENSTUDIO_LOG_LEVEL={args.log_level}",
        "-e", f"AUTOGENSTUDIO_REQUEST_TIMEOUT={args.request_timeout}",
        "-e", f"AUTOGENSTUDIO_MAX_FILE_SIZE={args.max_file_size}",
        "--memory", args.container_memory,
        "--cpus", args.container_cpus,
    ]

    # Add container name if specified
    if hasattr(args, 'container_name') and args.container_name:
        run_cmd.extend(["--name", args.container_name])

    # Add container removal flag if specified
    if hasattr(args, 'rm_container') and args.rm_container:
        run_cmd.append("--rm")

    # Add detached mode if specified
    if hasattr(args, 'detached') and args.detached:
        run_cmd.append("-d")

    # Add image name
    run_cmd.append("autogen-studio")

    return run_command(run_cmd)


def register_parser(subparsers):
    """Register the Docker Studio parser."""
    parser = subparsers.add_parser(
        "docker-studio", help="Build and run AutoGen Studio in Docker")

    # Add arguments
    parser.add_argument(
        "--port", type=int, default=8081, help="Port to listen on")
    parser.add_argument(
        "--node_env", default="production", help="Node environment")
    parser.add_argument(
        "--build_optimize", type=bool, default=True, help="Enable build optimization")
    parser.add_argument(
        "--enable_source_maps", type=bool, default=False, help="Enable source maps")
    parser.add_argument(
        "--cache_dir", default=".cache", help="Cache directory")
    parser.add_argument(
        "--num_workers", type=int, default=4, help="Number of workers")
    parser.add_argument(
        "--data_volume", default="./autogenstudio_data", help="Data volume path")
    parser.add_argument(
        "--storage_volume", default="./autogenstudio_storage", help="Storage volume path")
    parser.add_argument(
        "--enable_cache", type=bool, default=True, help="Enable caching")
    parser.add_argument(
        "--log_level", default="INFO", help="Logging level")
    parser.add_argument(
        "--request_timeout", type=int, default=300, help="Request timeout")
    parser.add_argument(
        "--max_file_size", type=int, default=10485760, help="Max file size")
    parser.add_argument(
        "--container_memory", default="4g", help="Container memory limit")
    parser.add_argument(
        "--container_cpus", default="2", help="Container CPU limit")
    parser.add_argument(
        "--container_name", default=None, help="Container name (optional)")
    parser.add_argument(
        "--rm_container", type=bool, default=False,
        help="Remove container when it exits")
    parser.add_argument(
        "--detached", type=bool, default=False,
        help="Run container in background")

    # Set the function to execute
    parser.set_defaults(func=docker_studio)

    return parser
