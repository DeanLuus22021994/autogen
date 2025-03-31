"""Command-line argument parsing module for AutoGen menu utility."""

import argparse
from .components import register_all_parsers


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line argument parser."""
    parser = argparse.ArgumentParser(description="AutoGen Build & Run Utility")
    subparsers = parser.add_subparsers(
        dest="component", help="Component to build/run")

    # Register all component parsers
    success = register_all_parsers(subparsers)

    if not success:
        print(
            "[WARNING] No valid components were registered. Some commands may not be available.")

    return parser
