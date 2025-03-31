"""
Basic Agent Chat Component.

This module provides the functionality to run a simple conversation
between a user and an AI assistant with minimal setup.
"""

import argparse
import os
from menu.utils import run_command, debug_args


@debug_args
def python_basic_agent_chat(args: argparse.Namespace) -> int:
    """
    Run the basic agent chat example.

    This sample demonstrates a simple conversation between a user and an AI assistant.
    It's the simplest entry point to AutoGen and requires minimal setup.

    Key features:
    - Single agent conversation
    - Basic prompt/response pattern
    - Minimal dependencies (just requires the OpenAI API)
    """
    # Auto-recompile check - this module will recompile itself on each run if valid
    print(f"[DEBUG] Running module: {__name__}")
    module_path = os.path.abspath(__file__)
    print(f"[DEBUG] Module path: {module_path}")

    # Run the actual command
    cmd = [
        "python", "-m", "python.samples.agentchat.simple",
        "--model", args.model,
        "--temperature", str(args.temperature),
        "--max_tokens", str(args.max_tokens),
        "--cache_seed", str(args.cache_seed),
        "--cache_dir", args.cache_dir,
        "--verbose", str(args.verbose).lower()
    ]

    return run_command(cmd)


def register_parser(subparsers):
    """Register the basic agent chat parser."""
    parser = subparsers.add_parser(
        "basic-agent", help="Run basic agent chat example")

    # Add arguments
    parser.add_argument(
        "--model", default="gpt-4-turbo", help="Model to use")
    parser.add_argument(
        "--temperature", type=float, default=0.1, help="Temperature for generation")
    parser.add_argument(
        "--max_tokens", type=int, default=1000, help="Max tokens to generate")
    parser.add_argument(
        "--cache_seed", type=int, default=42, help="Cache seed for reproducibility")
    parser.add_argument(
        "--cache_dir", default=".cache", help="Directory for caching")
    parser.add_argument(
        "--verbose", type=bool, default=True, help="Enable verbose output")

    # Set the function to execute
    parser.set_defaults(func=python_basic_agent_chat)

    return parser
