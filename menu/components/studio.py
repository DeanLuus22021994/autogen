import os
import argparse
from utils import run_command, debug_args, ROOT_DIR


@debug_args
def autogen_studio_build(args: argparse.Namespace) -> int:
    """
    Build and run AutoGen Studio with all optimization flags.

    AutoGen Studio is a web-based UI for creating and running multi-agent workflows
    without writing code. This build process includes optimizing the frontend
    and configuring the backend for maximum performance.

    Key features:
    - Visual workflow design
    - Drag-and-drop agent configuration
    - Persistent storage of workflows
    - Real-time execution monitoring
    - Library of sample workflows
    """
    # Auto-recompile check - this module will be recompiled on each run if valid
    print(f"[DEBUG] Running module: {__name__}")
    print(f"[DEBUG] Module path: {os.path.abspath(__file__)}")

    # Install Python package
    install_cmd = [
        "pip", "install", "-e", "python/samples/apps/autogen-studio[dev]"
    ]
    if run_command(install_cmd) != 0:
        return 1

    # Build frontend
    frontend_dir = os.path.join(
        ROOT_DIR, "python/samples/apps/autogen-studio/autogenstudio/web")
    build_cmd = [
        "npm", "install"
    ]
    if run_command(build_cmd, cwd=frontend_dir) != 0:
        return 1

    build_cmd = [
        "npm", "run", "build", "--",
        "--production",
        "--optimize-minimize",
        "--no-source-maps"
    ]
    if run_command(build_cmd, cwd=frontend_dir) != 0:
        return 1

    # Run the application
    run_cmd = [
        "python", "-m", "autogenstudio",
        "--host", args.host,
        "--port", str(args.port),
        "--database_uri", args.database_uri,
        "--log_level", args.log_level,
        "--storage_path", args.storage_path,
        "--enable_cache", str(args.enable_cache).lower(),
        "--cache_dir", args.cache_dir,
        "--cache_seed", str(args.cache_seed),
        "--num_workers", str(args.num_workers),
        "--request_timeout", str(args.request_timeout),
        "--model_cache_size", str(args.model_cache_size),
        "--database_pool_size", str(args.database_pool_size),
        "--database_pool_recycle", str(args.database_pool_recycle),
        "--max_file_size", str(args.max_file_size),
        "--max_nodes", str(args.max_nodes),
        "--max_edges", str(args.max_edges)
    ]

    if args.static_root_path:
        run_cmd.extend(["--static_root_path", args.static_root_path])

    if args.file_logging:
        run_cmd.extend(["--file_logging", str(args.file_logging).lower()])
        run_cmd.extend(["--log_file", args.log_file])
        run_cmd.extend(["--file_log_level", args.file_log_level])

    return run_command(run_cmd)


def register_parser(subparsers):
    """Register the AutoGen Studio parser"""
    parser = subparsers.add_parser(
        "studio", help="Build and run AutoGen Studio")

    # Add arguments
    parser.add_argument(
        "--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument(
        "--port", type=int, default=8081, help="Port to listen on")
    parser.add_argument(
        "--database_uri", default="sqlite:///./autogenstudio.db", help="Database URI")
    parser.add_argument(
        "--log_level", default="INFO", help="Logging level")
    parser.add_argument(
        "--storage_path", default="./autogenstudio_storage", help="Storage path")
    parser.add_argument(
        "--enable_cache", type=bool, default=True, help="Enable caching")
    parser.add_argument(
        "--cache_dir", default=".autogenstudio_cache", help="Cache directory")
    parser.add_argument(
        "--cache_seed", type=int, default=42, help="Cache seed")
    parser.add_argument(
        "--num_workers", type=int, default=4, help="Number of workers")
    parser.add_argument(
        "--request_timeout", type=int, default=300, help="Request timeout")
    parser.add_argument(
        "--model_cache_size", type=int, default=5, help="Model cache size")
    parser.add_argument(
        "--database_pool_size", type=int, default=20, help="Database pool size")
    parser.add_argument(
        "--database_pool_recycle", type=int, default=3600, help="Database pool recycle")
    parser.add_argument(
        "--max_file_size", type=int, default=10485760, help="Max file size")
    parser.add_argument(
        "--max_nodes", type=int, default=50, help="Max nodes")
    parser.add_argument(
        "--max_edges", type=int, default=200, help="Max edges")
    parser.add_argument(
        "--static_root_path", default="./static", help="Static root path")
    parser.add_argument(
        "--file_logging", type=bool, default=True, help="Enable file logging")
    parser.add_argument(
        "--log_file", default="autogenstudio.log", help="Log file")
    parser.add_argument(
        "--file_log_level", default="DEBUG", help="File log level")

    # Set the function to execute
    parser.set_defaults(func=autogen_studio_build)

    return parser
