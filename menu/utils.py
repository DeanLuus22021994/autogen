"""Utility functions for the AutoGen menu system."""

import os
import importlib
import inspect
import subprocess
import traceback
import pickle
import hashlib
from typing import List, Optional, Dict

# Ensure we're in the root directory
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.cache')

# Create cache directory if it doesn't exist
os.makedirs(CACHE_DIR, exist_ok=True)


def run_command(cmd: List[str], cwd: Optional[str] = None,
                env: Optional[Dict[str, str]] = None) -> int:
    """Run a shell command and return the exit code."""
    print(f"Running command: {' '.join(cmd)}")
    process_env = os.environ.copy()
    if env:
        process_env.update(env)
    return subprocess.call(cmd, cwd=cwd or ROOT_DIR, env=process_env)


def debug_args(func):
    """Decorator to debug function arguments before execution."""
    def wrapper(args, **kwargs):
        print(f"\n[DEBUG] Running {func.__name__} with arguments:")
        for arg_name, arg_value in vars(args).items():
            print(f"  - {arg_name}: {arg_value}")
        print(f"[DEBUG] Working directory: {os.getcwd()}")
        print(f"[DEBUG] Root directory: {ROOT_DIR}")
        return func(args, **kwargs)
    return wrapper


def get_module_hash(module_path):
    """Generate a hash for the module content to detect changes."""
    with open(module_path, 'rb') as f:
        content = f.read()
    return hashlib.md5(content).hexdigest()


def validate_component_module(module_name):
    """
    Validate a component module by importing it and checking for required attributes.

    Returns:
        tuple: (is_valid, module_object or error message)
    """
    try:
        # Try importing the module
        module = importlib.import_module(module_name)

        # Check for required attributes
        required_attrs = ['register_parser']
        missing_attrs = [
            attr for attr in required_attrs if not hasattr(module, attr)]

        if missing_attrs:
            err_msg = f"Module {module_name} is missing required attributes: "
            err_msg += f"{', '.join(missing_attrs)}"
            return False, err_msg

        # Validate register_parser function
        if not callable(getattr(module, 'register_parser')):
            return False, f"Module {module_name}: register_parser is not callable"

        # Ensure the function has the right signature
        sig = inspect.signature(module.register_parser)
        if len(sig.parameters) != 1:
            err_msg = f"Module {module_name}: register_parser must take exactly "
            err_msg += "one argument (subparsers)"
            return False, err_msg

        # Module is valid
        return True, module

    except ImportError as e:
        error_traceback = traceback.format_exc()
        return False, f"Error importing module {module_name}: {str(e)}\n{error_traceback}"
    except AttributeError as e:
        error_traceback = traceback.format_exc()
        return False, f"Error validating module {module_name}: {str(e)}\n{error_traceback}"
    except (TypeError, ValueError) as e:
        error_traceback = traceback.format_exc()
        return False, f"Invalid module signature {module_name}: {str(e)}\n{error_traceback}"


def get_cached_component(module_name, module_path):
    """
    Get a cached component if it exists and is valid.

    Returns:
        tuple: (found_in_cache, component_or_error)
    """
    # Generate cache file path
    module_hash = get_module_hash(module_path)
    cache_file = os.path.join(
        CACHE_DIR, f"{module_name.replace('.', '_')}_{module_hash}.pkl")

    # Check if cache exists
    if os.path.exists(cache_file):
        try:
            with open(cache_file, 'rb') as f:
                cached_component = pickle.load(f)
            return True, cached_component
        except (pickle.PickleError, IOError) as e:
            return False, f"Error loading cache for {module_name}: {str(e)}"

    return False, None


def cache_component(module_name, component, module_path):
    """Cache a validated component."""
    try:
        module_hash = get_module_hash(module_path)
        cache_file = os.path.join(
            CACHE_DIR, f"{module_name.replace('.', '_')}_{module_hash}.pkl")

        with open(cache_file, 'wb') as f:
            pickle.dump(component, f)

        print(f"[INFO] Component {module_name} cached successfully")
        return True
    except (pickle.PickleError, IOError) as e:
        print(f"[WARNING] Failed to cache component {module_name}: {str(e)}")
        return False
