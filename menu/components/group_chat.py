"""
Group Chat with Code Execution Component.

This module provides functionality to run examples showcasing
multi-agent conversations with code generation and execution.
"""

import os
import argparse
from ..utils import run_command, debug_args


@debug_args
def python_group_chat_with_code(args: argparse.Namespace) -> int:
    """
    Run the group chat with code execution example.

    This sample demonstrates a multi-agent conversation with code generation and execution.
    It shows how multiple agents can collaborate to solve programming tasks.

    Key features:
    - Multiple specialized agents (assistant, user proxy, code executor)
    - Code generation and execution in a sandbox
    - Turn-based conversation flow
    - Automatic error correction and debugging
    """
    # Auto-recompile check - this module will be recompiled on each run if valid
    print(f"[DEBUG] Running module: {__name__}")
    print(f"[DEBUG] Module path: {os.path.abspath(__file__)}")

    cmd = [
        "python", "-m", "python.samples.agentchat.group_chat_with_code",
        "--model", args.model,
        "--temperature", str(args.temperature),
        "--max_tokens", str(args.max_tokens),
        "--cache_seed", str(args.cache_seed),
        "--cache_dir", args.cache_dir,
        "--timeout", str(args.timeout),
        "--work_dir", args.work_dir,
        "--verbose", str(args.verbose).lower()
    ]

    # Add optional streaming parameter if provided
    if hasattr(args, 'stream') and args.stream:
        cmd.extend(["--stream", str(args.stream).lower()])

    return run_command(cmd)


def register_parser(subparsers):
    """Register the group chat with code parser."""
    parser = subparsers.add_parser(
        "group-chat", help="Run group chat with code execution")

    # Add arguments
    parser.add_argument(
        "--model", default="gpt-4-turbo", help="Model to use")
    parser.add_argument(
        "--temperature", type=float, default=0.1, help="Temperature for generation")
    parser.add_argument(
        "--max_tokens", type=int, default=4000, help="Max tokens to generate")
    parser.add_argument(
        "--cache_seed", type=int, default=42, help="Cache seed for reproducibility")
    parser.add_argument(
        "--cache_dir", default=".cache", help="Directory for caching")
    parser.add_argument(
        "--timeout", type=int, default=600, help="Timeout for code execution in seconds")
    parser.add_argument(
        "--work_dir", default="./coding", help="Working directory for code execution")
    parser.add_argument(
        "--verbose", type=bool, default=True, help="Enable verbose output")
    parser.add_argument(
        "--stream", type=bool, default=False, help="Enable streaming of responses")

    # Set the function to execute
    parser.set_defaults(func=python_group_chat_with_code)

    return parser
