---
applyTo: '**/*.py'
---

# Pattern: Agent Definition

**Purpose**: Define a new agent with specific capabilities and behaviors

**When to use**: When creating a new agent type or specialization

**Implementation template**:

```python
from autogen import Agent

class CustomAgent(Agent):
    """
    A specialized agent that handles [specific domain] tasks.

    This agent implements [specific capabilities] and is designed
    to interact with [specific other agents or systems].
    """

    def __init__(self, name, **kwargs):
        """
        Initialize the CustomAgent.

        Args:
            name (str): The name of the agent
            **kwargs: Additional configuration parameters
        """
        super().__init__(name=name, **kwargs)
        self.capabilities = []
        # Additional initialization

    def handle_message(self, message, sender):
        """
        Process incoming messages and generate responses.

        Args:
            message (str): The received message
            sender (Agent): The agent that sent the message

        Returns:
            str: The response message
        """
        # Message handling logic
        response = self._process_message(message)
        return response

    def _process_message(self, message):
        """
        Internal method to process message content.

        Args:
            message (str): The message to process

        Returns:
            str: Processed response
        """
        # Implementation details
        pass
