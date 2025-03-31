#!/usr/bin/env python3
"""
AutoGen Build & Run Utility

This script provides a unified interface for building and running all AutoGen components
with optimized configurations. It serves as a one-stop solution for developers working
with the AutoGen ecosystem.

Usage:
    python menu.py <component> [options]
    python menu.py all [options]

Examples:
    python menu.py studio --port 8888
    python menu.py basic-agent --model gpt-4o
    python menu.py all
"""

import sys
import importlib
from .parser import create_parser
from .components import load_all_components


def main():
    """Main entry point for the script."""
    # Force component reload on each run to pick up any changes
    load_all_components()

    parser = create_parser()
    args = parser.parse_args()

    if not hasattr(args, 'func'):
        parser.print_help()
        return 1

    try:
        # Force reload the module of the function that will be executed
        if hasattr(args.func, '__module__'):
            module_name = args.func.__module__
            if module_name.startswith('menu.components.'):
                print(
                    f"[INFO] Reloading module {module_name} before execution")
                importlib.reload(sys.modules[module_name])

        return args.func(args)
    except KeyboardInterrupt:
        print("\nOperation interrupted by user.")
        return 130
    except ImportError as e:
        print(f"Error importing module: {str(e)}")
        return 1
    except AttributeError as e:
        print(f"Attribute error: {str(e)}")
        return 1
    except ValueError as e:
        print(f"Value error: {str(e)}")
        return 1
    except TypeError as e:
        print(f"Type error: {str(e)}")
        return 1
    except FileNotFoundError as e:
        print(f"File not found: {str(e)}")
        return 1
    except PermissionError as e:
        print(f"Permission error: {str(e)}")
        return 1
    except OSError as e:
        print(f"OS error: {str(e)}")
        return 1
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
