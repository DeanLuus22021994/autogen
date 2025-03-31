"""
Run All Components Sequentially.

This module provides functionality to run all available components in sequence,
making it easy to test or demonstrate the full suite of AutoGen capabilities.
"""

import os
import argparse
import time
from ..utils import debug_args


@debug_args
def run_all(args: argparse.Namespace) -> int:
    """
    Build and run all components in sequence.

    This command runs multiple AutoGen components one after another,
    making it easy to test or demonstrate the full suite of capabilities.

    Key features:
    - Sequential component execution
    - Shared configuration across components
    - Comprehensive testing of all functionality
    - Option to continue despite individual component failures
    """
    # Auto-recompile check - this module will be recompiled on each run if valid
    print(f"[DEBUG] Running module: {__name__}")
    print(f"[DEBUG] Module path: {os.path.abspath(__file__)}")

    # Get a list of all component modules
    from .. import components

    # First, let's collect the components to run
    component_list = []

    # Import all component modules
    for module_name in dir(components):
        # Skip special attributes and non-modules
        if module_name.startswith('__') or module_name == 'register_all_parsers':
            continue

        try:
            module = getattr(components, module_name)

            # Only include modules that have register_parser and a function
            if hasattr(module, 'register_parser'):
                # Get the function from the module
                for attr_name in dir(module):
                    attr = getattr(module, attr_name)
                    if callable(attr) and attr_name != 'register_parser':
                        component_list.append((module_name, attr_name, attr))
                        break
        except (ImportError, AttributeError) as e:
            print(f"[WARNING] Could not load component {module_name}: {e}")

    # Filter out the run_all component itself
    component_list = [c for c in component_list if c[1] != 'run_all']

    # Skip Docker components if requested
    if not args.include_docker:
        component_list = [
            c for c in component_list if 'docker' not in c[0].lower()]

    print(f"[INFO] Found {len(component_list)} components to run")

    # Run each component
    results = []
    for i, (module_name, func_name, func) in enumerate(component_list):
        print(
            f"\n[INFO] Running component {i+1}/{len(component_list)}: {module_name}.{func_name}")

        try:
            # Create a copy of args specifically for this component
            # This is a simple approach - in a real scenario you might
            # need to be more selective about which args to pass
            start_time = time.time()
            result = func(args)
            end_time = time.time()

            success = result == 0
            results.append({
                'component': f"{module_name}.{func_name}",
                'success': success,
                'exit_code': result,
                'time': end_time - start_time
            })

            if not success and not args.continue_on_error:
                print(
                    f"[ERROR] Component {module_name}.{func_name} failed with exit code {result}")
                print(
                    "[INFO] Stopping execution because --continue_on_error is False")
                break
        except ImportError as imp_err:
            print(
                f"[ERROR] Import error in component {module_name}.{func_name}: {str(imp_err)}")
            results.append({
                'component': f"{module_name}.{func_name}",
                'success': False,
                'error': str(imp_err)
            })
            if not args.continue_on_error:
                break
        except AttributeError as attr_err:
            print(
                f"[ERROR] Attribute error in component {module_name}.{func_name}: {str(attr_err)}")
            results.append({
                'component': f"{module_name}.{func_name}",
                'success': False,
                'error': str(attr_err)
            })
            if not args.continue_on_error:
                break
        except ValueError as val_err:
            print(
                f"[ERROR] Value error in component {module_name}.{func_name}: {str(val_err)}")
            results.append({
                'component': f"{module_name}.{func_name}",
                'success': False,
                'error': str(val_err)
            })
            if not args.continue_on_error:
                break
        except TypeError as type_err:
            print(
                f"[ERROR] Type error in component {module_name}.{func_name}: {str(type_err)}")
            results.append({
                'component': f"{module_name}.{func_name}",
                'success': False,
                'error': str(type_err)
            })
            if not args.continue_on_error:
                break
        except KeyError as key_err:
            print(
                f"[ERROR] Key error in component {module_name}.{func_name}: {str(key_err)}")
            results.append({
                'component': f"{module_name}.{func_name}",
                'success': False,
                'error': str(key_err)
            })
            if not args.continue_on_error:
                break
        except FileNotFoundError as file_err:
            print(
                f"[ERROR] File not found in component {module_name}.{func_name}: {str(file_err)}")
            results.append({
                'component': f"{module_name}.{func_name}",
                'success': False,
                'error': str(file_err)
            })
            if not args.continue_on_error:
                break
        except PermissionError as perm_err:
            print(
                f"[ERROR] Permission error in component {module_name}.{func_name}: {str(perm_err)}")
            results.append({
                'component': f"{module_name}.{func_name}",
                'success': False,
                'error': str(perm_err)
            })
            if not args.continue_on_error:
                break

    # Print summary
    print("\n" + "="*50)
    print("EXECUTION SUMMARY")
    print("="*50)

    successful = sum(1 for r in results if r.get('success', False))
    print(f"Total components: {len(results)}")
    print(f"Successful: {successful}")
    print(f"Failed: {len(results) - successful}")

    if len(results) - successful > 0:
        print("\nFailed components:")
        for r in results:
            if not r.get('success', False):
                if 'error' in r:
                    print(f"  - {r['component']}: {r['error']}")
                else:
                    print(f"  - {r['component']}: Exit code {r['exit_code']}")

    # Return 0 if all successful or if continuing on error
    if successful == len(results):
        print("\n[SUCCESS] All components executed successfully")
        return 0
    else:
        print(f"\n[WARNING] {len(results) - successful} component(s) failed")
        return 1


def register_parser(subparsers):
    """Register the run all parser"""
    parser = subparsers.add_parser(
        "all", help="Build and run all components")

    # Add universal arguments that should apply to all components
    parser.add_argument(
        "--model", default="gpt-4-turbo", help="Model to use")
    parser.add_argument(
        "--temperature", type=float, default=0.2, help="Temperature for generation")
    parser.add_argument(
        "--max_tokens", type=int, default=1000, help="Max tokens to generate")
    parser.add_argument(
        "--cache_seed", type=int, default=42, help="Cache seed for reproducibility")
    parser.add_argument(
        "--cache_dir", default=".cache", help="Directory for caching")
    parser.add_argument(
        "--verbose", type=bool, default=True, help="Enable verbose output")

    # Run all specific arguments
    parser.add_argument(
        "--include_docker", type=bool, default=False, help="Include Docker components")
    parser.add_argument(
        "--continue_on_error", type=bool, default=False, help="Continue on component errors")

    # Studio settings
    parser.add_argument(
        "--port", type=int, default=8081, help="Port to listen on")
    parser.add_argument(
        "--host", default="0.0.0.0", help="Host to bind to")

    # Common component settings that several might use
    parser.add_argument(
        "--timeout", type=int, default=600, help="Timeout for operations")
    parser.add_argument(
        "--work_dir", default="./temp_workdir", help="Working directory")

    # Set the function to execute
    parser.set_defaults(func=run_all)

    return parser
