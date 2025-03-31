"""
.NET Group Chat Component.

This module provides functionality to build and run the .NET Group Chat sample,
demonstrating AutoGen's language-agnostic capabilities.
"""

import os
import argparse
from utils import run_command, debug_args, ROOT_DIR


@debug_args
def dotnet_group_chat(args: argparse.Namespace) -> int:
    """
    Build and run the .NET Group Chat sample.

    This sample demonstrates a multi-agent conversation system in .NET.
    It shows how to create and orchestrate multiple agents in a C# environment.

    Key features:
    - Multiple agent orchestration in .NET
    - Turn-based conversation management
    - Integration with LLM APIs from C#
    - Optimized .NET build configuration
    """
    # Auto-recompile check - this module will be recompiled on each run if valid
    print(f"[DEBUG] Running module: {__name__}")
    print(f"[DEBUG] Module path: {os.path.abspath(__file__)}")

    # Navigate to the .NET sample directory
    sample_dir = os.path.join(
        ROOT_DIR, "dotnet/samples/AgentChat/AutoGen.GroupChat.Sample")
    build_dir = os.path.join(sample_dir, "bin/Release")

    # Build the .NET sample
    build_cmd = [
        "dotnet", "build",
        "-c", "Release",
        "-o", "./bin/Release",
        "--no-restore",
        "--nologo",
        "/p:DebugType=None",
        "/p:DebugSymbols=false"
    ]

    if run_command(build_cmd, cwd=sample_dir) != 0:
        print("[ERROR] .NET build failed")
        return 1

    # Run the .NET sample
    run_cmd = [
        "./AutoGen.GroupChat.Sample",
        "--model", args.model,
        "--temperature", str(args.temperature),
        "--max-tokens", str(args.max_tokens),
        "--cache-seed", str(args.cache_seed),
        "--cache-dir", args.cache_dir,
        "--timeout", str(args.timeout),
        "--verbose", str(args.verbose).lower()
    ]

    return run_command(run_cmd, cwd=build_dir)


def register_parser(subparsers):
    """Register the .NET Group Chat parser."""
    parser = subparsers.add_parser(
        "dotnet-group", help="Build and run .NET Group Chat")

    # Add arguments
    parser.add_argument(
        "--model", default="gpt-4-turbo", help="Model to use")
    parser.add_argument(
        "--temperature", type=float, default=0.1, help="Temperature for generation")
    parser.add_argument(
        "--max-tokens", type=int, default=4000, help="Max tokens to generate")
    parser.add_argument(
        "--cache-seed", type=int, default=42, help="Cache seed for reproducibility")
    parser.add_argument(
        "--cache-dir", default=".cache", help="Directory for caching")
    parser.add_argument(
        "--timeout", type=int, default=600, help="Execution timeout in seconds")
    parser.add_argument(
        "--verbose", type=bool, default=True, help="Enable verbose output")

    # Set the function to execute
    parser.set_defaults(func=dotnet_group_chat)

    return parser
