"""
Tests for Docker Model Runner client
"""
import unittest
from unittest.mock import patch, MagicMock
import requests
from autogen_extensions.docker.model_client import ModelClient

class TestModelClient(unittest.TestCase):
    """Test suite for the Docker Model Runner client"""

    def setUp(self):
        """Set up test environment"""
        self.client = ModelClient(model_name="ai/mistral")

    @patch('requests.post')
    def test_complete_success(self, mock_post):
        """Test successful completion request"""
        # Setup mock response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "choices": [
                {
                    "message": {
                        "content": "This is a test response"
                    }
                }
            ]
        }
        mock_post.return_value = mock_response

        # Call the method
        result = self.client.complete("Test prompt", system_message="You are a test assistant")

        # Verify the result
        self.assertEqual(result, "This is a test response")

        # Verify the request
        mock_post.assert_called_once()
        args, kwargs = mock_post.call_args
        self.assertEqual(args[0], "http://model-runner.docker.internal/engines/v1/chat/completions")
        self.assertEqual(kwargs["headers"], {"Content-Type": "application/json"})

        # Check payload
        payload = kwargs["json"]
        self.assertEqual(payload["model"], "ai/mistral")
        self.assertEqual(payload["temperature"], 0.7)
        self.assertEqual(payload["max_tokens"], 1000)
        self.assertEqual(len(payload["messages"]), 2)
        self.assertEqual(payload["messages"][0]["role"], "system")
        self.assertEqual(payload["messages"][1]["role"], "user")
        self.assertEqual(payload["messages"][1]["content"], "Test prompt")

    @patch('requests.post')
    def test_complete_connection_error(self, mock_post):
        """Test connection error handling"""
        # Setup mock to raise connection error
        mock_post.side_effect = requests.exceptions.ConnectionError("Connection refused")

        # Call the method and check if it raises ConnectionError
        with self.assertRaises(ConnectionError) as context:
            self.client.complete("Test prompt")

        # Verify the error message
        self.assertIn("Could not connect to Docker Model Runner", str(context.exception))

    @patch('requests.post')
    def test_complete_api_error(self, mock_post):
        """Test API error handling"""
        # Setup mock response for API error
        mock_response = MagicMock()
        mock_response.status_code = 400
        mock_response.text = "Invalid model specified"
        mock_post.return_value = mock_response

        # Call the method and check if it raises ValueError
        with self.assertRaises(ValueError) as context:
            self.client.complete("Test prompt")

        # Verify the error message
        self.assertIn("Model API error", str(context.exception))

    @patch('requests.get')
    def test_list_available_models(self, mock_get):
        """Test listing available models"""
        # Setup mock response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "data": [
                {"id": "ai/mistral"},
                {"id": "ai/smollm2"},
                {"id": "ai/mistral-nemo"}
            ]
        }
        mock_get.return_value = mock_response

        # Call the method
        models = self.client.list_available_models()

        # Verify the result
        self.assertEqual(len(models), 3)
        self.assertIn("ai/mistral", models)
        self.assertIn("ai/smollm2", models)
        self.assertIn("ai/mistral-nemo", models)

    @patch('autogen_extensions.docker.model_client.ModelClient.list_available_models')
    def test_is_model_available(self, mock_list_models):
        """Test checking if a model is available"""
        # Setup mock
        mock_list_models.return_value = ["ai/mistral", "ai/smollm2"]

        # Test with available model
        result1 = self.client.is_model_available("ai/mistral")
        self.assertTrue(result1)

        # Test with unavailable model
        result2 = self.client.is_model_available("ai/nonexistent-model")
        self.assertFalse(result2)

if __name__ == "__main__":
    unittest.main()
