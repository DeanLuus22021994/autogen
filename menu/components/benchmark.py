"""
Benchmark Component for AutoGen.

This module provides functionality to run performance benchmarks
for measuring and comparing agent capabilities.
"""

import os
import argparse
from menu.utils import run_command, debug_args


@debug_args
def benchmark(args: argparse.Namespace) -> int:
    """
    Run the benchmarking framework.

    This tool evaluates agent performance across a standardized set of tasks,
    providing metrics for comparison between different agent configurations.

    Key features:
    - Standardized task suite (mini/full options)
    - Performance metrics calculation
    - Results visualization
    - Comparative analysis tools
    - Detailed performance reports
    """
    # Auto-recompile check - this module will be recompiled on each run if valid
    print(f"[DEBUG] Running module: {__name__}")
    print(f"[DEBUG] Module path: {os.path.abspath(__file__)}")

    # Create results directory if it doesn't exist
    if not os.path.exists(args.results_dir):
        os.makedirs(args.results_dir, exist_ok=True)

    cmd = [
        "python", "-m", "python.samples.agenteval.benchmark",
        "--benchmark-set", args.benchmark_set,
        "--model", args.model,
        "--eval-model", args.eval_model,
        "--temperature", str(args.temperature),
        "--max-tokens", str(args.max_tokens),
        "--cache-seed", str(args.cache_seed),
        "--cache-dir", args.cache_dir,
        "--results-dir", args.results_dir,
        "--parallel-runs", str(args.parallel_runs),
        "--timeout", str(args.timeout),
        "--verbose", str(args.verbose).lower()
    ]

    # Add optional custom benchmark path if provided
    if hasattr(args, 'custom_benchmark') and args.custom_benchmark:
        cmd.extend(["--custom-benchmark", args.custom_benchmark])

    # Add optional report format if provided
    if hasattr(args, 'report_format') and args.report_format:
        cmd.extend(["--report-format", args.report_format])

    return run_command(cmd)


def register_parser(subparsers):
    """Register the benchmark framework parser."""
    parser = subparsers.add_parser(
        "benchmark", help="Run benchmark framework")

    # Add arguments
    parser.add_argument(
        "--model", default="gpt-4-turbo", help="Model to use")
    parser.add_argument(
        "--benchmark-set", default="full", help="Benchmark set (mini/full)")
    parser.add_argument(
        "--eval-model", default="gpt-4-turbo", help="Model to use for evaluation")
    parser.add_argument(
        "--temperature", type=float, default=0.1, help="Temperature for generation")
    parser.add_argument(
        "--max-tokens", type=int, default=4000, help="Max tokens to generate")
    parser.add_argument(
        "--results-dir", default="./benchmark_results", help="Results directory")
    parser.add_argument(
        "--parallel-runs", type=int, default=2, help="Number of parallel runs")
    parser.add_argument(
        "--timeout", type=int, default=1800, help="Timeout in seconds")
    parser.add_argument(
        "--cache-seed", type=int, default=42, help="Cache seed for reproducibility")
    parser.add_argument(
        "--cache-dir", default=".cache_benchmark", help="Directory for caching")
    parser.add_argument(
        "--custom-benchmark", default=None, help="Path to custom benchmark definition file")
    parser.add_argument(
        "--report-format", default="json", help="Report format (json/csv/html)")
    parser.add_argument(
        "--verbose", type=bool, default=True, help="Enable verbose output")

    # Set the function to execute
    parser.set_defaults(func=benchmark)

    return parser
