"""
Human Feedback Component.

This module provides functionality to run examples showcasing
agent responses that can be refined through human feedback.
"""

import os
import argparse
from utils import run_command, debug_args


@debug_args
def human_feedback(args: argparse.Namespace) -> int:
    """
    Run the human feedback example.

    This sample demonstrates an agent that can refine its outputs based on
    human feedback, allowing for iterative improvement.

    Key features:
    - Interactive feedback mechanism
    - Response refinement based on feedback
    - Multi-turn conversations with corrections
    - Learning from human preferences
    """
    # Auto-recompile check - this module will be recompiled on each run if valid
    print(f"[DEBUG] Running module: {__name__}")
    print(f"[DEBUG] Module path: {os.path.abspath(__file__)}")

    # Create log directory if needed
    log_dir = os.path.dirname(args.log_file)
    if log_dir and not os.path.exists(log_dir):
        os.makedirs(log_dir, exist_ok=True)

    cmd = [
        "python", "-m", "python.samples.agentchat.human_feedback",
        "--model", args.model,
        "--temperature", str(args.temperature),
        "--max-tokens", str(args.max_tokens),
        "--feedback-model", args.feedback_model,
        "--max-iterations", str(args.max_iterations),
        "--cache-seed", str(args.cache_seed),
        "--cache-dir", args.cache_dir,
        "--log-file", args.log_file,
        "--verbose", str(args.verbose).lower()
    ]

    # Add optional feedback source if provided
    if hasattr(args, 'feedback_source') and args.feedback_source:
        cmd.extend(["--feedback-source", args.feedback_source])

    return run_command(cmd)


def register_parser(subparsers):
    """Register the human feedback parser"""
    parser = subparsers.add_parser(
        "human-feedback", help="Run human feedback example")

    # Add arguments
    parser.add_argument(
        "--model", default="gpt-4-turbo", help="Model to use")
    parser.add_argument(
        "--temperature", type=float, default=0.2, help="Temperature for generation")
    parser.add_argument(
        "--max-tokens", type=int, default=2000, help="Max tokens to generate")
    parser.add_argument(
        "--feedback-model", default="gpt-4-turbo", help="Model to use for feedback")
    parser.add_argument(
        "--max-iterations", type=int, default=5, help="Maximum feedback iterations")
    parser.add_argument(
        "--feedback-source", default=None,
        help="Feedback source (interactive, file:/path/to/feedback.json)")
    parser.add_argument(
        "--cache-seed", type=int, default=42, help="Cache seed for reproducibility")
    parser.add_argument(
        "--cache-dir", default=".cache", help="Directory for caching")
    parser.add_argument(
        "--log-file", default="feedback_log.jsonl", help="Log file for feedback results")
    parser.add_argument(
        "--verbose", type=bool, default=True, help="Enable verbose output")

    # Set the function to execute
    parser.set_defaults(func=human_feedback)

    return parser
