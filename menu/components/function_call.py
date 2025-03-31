"""
Function Calling Component.

This module provides functionality to run examples showcasing OpenAI's
function calling capabilities integrated with AutoGen agents.
"""

import os
import argparse
from ..utils import run_command, debug_args


@debug_args
def python_function_calling(args: argparse.Namespace) -> int:
    """
    Run the function calling example.

    This sample demonstrates how to use function calling capabilities with agents.
    It allows agents to execute predefined functions with structured inputs/outputs.

    Key features:
    - Native OpenAI function calling API integration
    - Structured function definitions
    - Parameter validation
    - Type-safe function execution
    - Automatic tool selection by the model
    """
    # Auto-recompile check - this module will be recompiled on each run if valid
    print(f"[DEBUG] Running module: {__name__}")
    print(f"[DEBUG] Module path: {os.path.abspath(__file__)}")

    cmd = [
        "python", "-m", "python.samples.agentchat.agent_with_function_call",
        "--model", args.model,
        "--temperature", str(args.temperature),
        "--max_tokens", str(args.max_tokens),
        "--cache_seed", str(args.cache_seed),
        "--cache_dir", args.cache_dir,
        "--verbose", str(args.verbose).lower(),
        "--stream", str(args.stream).lower()
    ]

    # Add optional function params if provided
    if hasattr(args, 'function_config') and args.function_config:
        cmd.extend(["--function_config", args.function_config])

    if hasattr(args, 'allow_parallel') and args.allow_parallel:
        cmd.extend(["--allow_parallel", str(args.allow_parallel).lower()])

    return run_command(cmd)


def register_parser(subparsers):
    """Register the function calling parser."""
    parser = subparsers.add_parser(
        "function-call", help="Run function calling example")

    # Add arguments
    parser.add_argument(
        "--model", default="gpt-4-turbo", help="Model to use")
    parser.add_argument(
        "--temperature", type=float, default=0.1, help="Temperature for generation")
    parser.add_argument(
        "--max_tokens", type=int, default=2000, help="Max tokens to generate")
    parser.add_argument(
        "--cache_seed", type=int, default=42, help="Cache seed for reproducibility")
    parser.add_argument(
        "--cache_dir", default=".cache", help="Directory for caching")
    parser.add_argument(
        "--verbose", type=bool, default=True, help="Enable verbose output")
    parser.add_argument(
        "--stream", type=bool, default=False, help="Enable streaming of responses")
    parser.add_argument(
        "--function_config", default=None,
        help="Path to function configuration JSON file (optional)")
    parser.add_argument(
        "--allow_parallel", type=bool, default=False,
        help="Allow parallel function execution")

    # Set the function to execute
    parser.set_defaults(func=python_function_calling)

    return parser
