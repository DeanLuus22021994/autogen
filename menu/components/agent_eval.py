"""
Agent Evaluation Component for AutoGen.

This module provides the functionality to evaluate agent performance
using standardized metrics and test scenarios.
"""

import os
import argparse
from menu.utils import run_command, debug_args


@debug_args
def agent_evaluation(args: argparse.Namespace) -> int:
    """
    Run the Agent Evaluation framework.

    This tool evaluates agent performance across a standardized set of tasks,
    providing metrics for comparison between different agent configurations.

    Key features:
    - Standardized evaluation protocols
    - Performance metrics calculation
    - Comparative analysis between agent configurations
    - Integration with various agent types
    - Support for custom evaluation criteria
    """
    # Auto-recompile check - this module will be recompiled on each run if valid
    print(f"[DEBUG] Running module: {__name__}")
    print(f"[DEBUG] Module path: {os.path.abspath(__file__)}")

    # Create logs directory if it doesn't exist
    log_dir = os.path.dirname(args.log_file)
    if log_dir and not os.path.exists(log_dir):
        os.makedirs(log_dir, exist_ok=True)

    cmd = [
        "python", "-m", "python.samples.agenteval.eval_with_agenteval",
        "--model", args.model,
        "--eval-model", args.eval_model,
        "--temperature", str(args.temperature),
        "--cache-seed", str(args.cache_seed),
        "--cache-dir", args.cache_dir,
        "--num-evals", str(args.num_evals),
        "--parallel-evals", str(args.parallel_evals),
        "--log-file", args.log_file,
        "--verbose", str(args.verbose).lower()
    ]

    # Add optional evaluation criteria if provided
    if hasattr(args, 'eval_criteria') and args.eval_criteria:
        cmd.extend(["--eval-criteria", args.eval_criteria])

    # Add optional task set if provided
    if hasattr(args, 'task_set') and args.task_set:
        cmd.extend(["--task-set", args.task_set])

    return run_command(cmd)


def register_parser(subparsers):
    """Register the Agent Evaluation parser."""
    parser = subparsers.add_parser(
        "eval", help="Run Agent Evaluation framework")

    # Add arguments
    parser.add_argument(
        "--model", default="gpt-4-turbo", help="Model to use for agent")
    parser.add_argument(
        "--eval-model", default="gpt-4-turbo", help="Model to use for evaluation")
    parser.add_argument(
        "--temperature", type=float, default=0.1, help="Temperature for generation")
    parser.add_argument(
        "--cache-seed", type=int, default=42, help="Cache seed for reproducibility")
    parser.add_argument(
        "--cache-dir", default=".cache_eval", help="Directory for caching")
    parser.add_argument(
        "--num-evals", type=int, default=5, help="Number of evaluations to run")
    parser.add_argument(
        "--parallel-evals", type=int, default=2, help="Number of parallel evaluations")
    parser.add_argument(
        "--log-file", default="eval_results.jsonl", help="Log file for evaluation results")
    parser.add_argument(
        "--eval-criteria", default=None,
        help="Comma-separated list of evaluation criteria (correctness,relevance,coherence)")
    parser.add_argument(
        "--task-set", default=None, help="Path to custom task set JSON file")
    parser.add_argument(
        "--verbose", type=bool, default=True, help="Enable verbose output")

    # Set the function to execute
    parser.set_defaults(func=agent_evaluation)

    return parser
