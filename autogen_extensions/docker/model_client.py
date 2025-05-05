"""
Docker Model Runner client for interacting with Docker's Model Runner API.

This module provides a client for sending requests to Docker Model Runner,
which allows running AI models locally using Docker Desktop 4.40+.
"""
import os
import requests
import json
import logging
from typing import List, Optional

# Set up logging
logger = logging.getLogger(__name__)

class ModelClient:
    """Client for interacting with Docker Model Runner API.

    This client provides methods to send prompts to AI models running locally
    through Docker Model Runner, reducing dependency on external APIs.

    Attributes:
        model_name (str): The name of the model to use
        endpoint (str): The endpoint URL for the Docker Model Runner API
    """

    def __init__(self, model_name: str = "ai/mistral"):
        """Initialize the model client.

        Args:
            model_name: The name of the model to use (default: "ai/mistral")
        """
        self.model_name = model_name
        # Get endpoint from environment or use default
        self.endpoint = os.environ.get(
            "MODEL_RUNNER_ENDPOINT",
            "http://model-runner.docker.internal/engines/v1/chat/completions"
        )
        logger.debug(f"Initialized ModelClient with model '{model_name}' at endpoint '{self.endpoint}'")

    def complete(self,
                prompt: str,
                system_message: Optional[str] = None,
                temperature: float = 0.7,
                max_tokens: int = 1000) -> str:
        """Get a completion from the model.

        Args:
            prompt: The user prompt to send to the model
            system_message: Optional system message to set context
            temperature: Sampling temperature (0-1)
            max_tokens: Maximum tokens to generate

        Returns:
            The model's response text

        Raises:
            ConnectionError: If the model cannot be reached
            ValueError: If the model returns an error
        """
        messages = []

        if system_message:
            messages.append({"role": "system", "content": system_message})

        messages.append({"role": "user", "content": prompt})

        logger.debug(f"Sending request to {self.endpoint} for model {self.model_name}")

        try:
            response = requests.post(
                self.endpoint,
                headers={"Content-Type": "application/json"},
                json={
                    "model": self.model_name,
                    "messages": messages,
                    "temperature": temperature,
                    "max_tokens": max_tokens
                }
            )

            if response.status_code != 200:
                logger.error(f"Model API error: {response.status_code} - {response.text}")
                raise ValueError(f"Model API error: {response.text}")

            result = response.json()
            content = result["choices"][0]["message"]["content"]
            logger.debug(f"Received response from model (length: {len(content)})")
            return content

        except requests.exceptions.ConnectionError as e:
            logger.error(f"Connection error to Docker Model Runner: {e}")
            raise ConnectionError(
                "Could not connect to Docker Model Runner. "
                "Make sure Docker Desktop is running with Model Runner enabled."
            )
        except Exception as e:
            logger.error(f"Unexpected error in model client: {e}")
            raise

    def list_available_models(self) -> List[str]:
        """List models available in Docker Model Runner.

        Returns:
            List of available model names
        """
        try:
            # Replace the completions endpoint with the models endpoint
            models_endpoint = self.endpoint.replace("/chat/completions", "/models")
            logger.debug(f"Fetching available models from {models_endpoint}")

            response = requests.get(models_endpoint)

            if response.status_code != 200:
                logger.warning(f"Failed to list models: {response.status_code} - {response.text}")
                return []

            result = response.json()
            models = [model["id"] for model in result["data"]]
            logger.debug(f"Found {len(models)} available models")
            return models

        except Exception as e:
            logger.error(f"Error listing available models: {e}")
            return []

    def is_model_available(self, model_name: Optional[str] = None) -> bool:
        """Check if a specific model is available.

        Args:
            model_name: The name of the model to check (default: current model)

        Returns:
            True if the model is available, False otherwise
        """
        if model_name is None:
            model_name = self.model_name

        available_models = self.list_available_models()
        return model_name in available_models
