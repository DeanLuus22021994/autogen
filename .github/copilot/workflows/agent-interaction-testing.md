---
applyTo: '**/*_test.py'
---

# Workflow: Agent Interaction Testing

**Purpose**: Validate that agents can correctly interact with each other in a conversation

**Steps**:

1. Define test agents with controlled behaviors
2. Set up a conversation between agents
3. Inject test messages and prompts
4. Verify message handling and responses
5. Assert on conversation outcomes

**Inputs required**:

* Agent definitions
* Test conversation scenarios
* Expected message patterns
* Success criteria

**Implementation template**:

```python
import unittest
from autogen import Agent, Conversation

class TestAgentInteraction(unittest.TestCase):
    def setUp(self):
        # Create test agents
        self.agent1 = Agent(name="agent1", ...)
        self.agent2 = Agent(name="agent2", ...)

        # Set up conversation
        self.conversation = Conversation(agents=[self.agent1, self.agent2])

    def test_basic_interaction(self):
        # Initialize conversation with a message
        initial_message = "Hello, can you help me with a task?"
        response = self.conversation.initiate(
            sender=self.agent1,
            recipient=self.agent2,
            message=initial_message
        )

        # Verify the interaction
        self.assertIn("I can help", response)
        self.assertEqual(len(self.conversation.messages), 2)

    def test_complex_workflow(self):
        # Test a multi-step interaction with expected outcomes
        # ...

    def tearDown(self):
        # Clean up resources
        pass
