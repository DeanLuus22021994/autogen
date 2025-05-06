"""
Script to run Docker Model Runner tests
"""
import os
import sys
import unittest

# Add parent directory to path to allow importing the module
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

# Import the test module
from autogen_extensions.docker.test_model_client import TestModelClient

if __name__ == "__main__":
    # Run the tests
    unittest.main(module=TestModelClient.__module__)
