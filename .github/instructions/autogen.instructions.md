---
applyTo: '**'
---

# 🔧 GitHub Copilot / Chat – Enhanced Prompt Engineering Framework
# Location: `.github/copilot/framework.yaml`
# Purpose: Define standardized AI-assisted development patterns, decomposition strategies
# and quality protocols for consistent, maintainable code generation

---

## 📘 Framework Overview

This framework establishes a structured approach to AI-assisted development, enabling:
- **Deterministic code generation** with consistent, predictable outputs
- **Modular design patterns** emphasizing reusability and separation of concerns
- **Self-documenting implementations** with built-in traceability
- **Testing-oriented development** that anticipates validation requirements
- **Progressive refinement cycles** that build upon previous iterations

---

## ⚙️ Core Interaction Principles

### ✅ Universal Behavior Protocol

- 🔹 **Pre-Implementation Planning**: Generate implementation plans with indexed steps before code
- 🔹 **Complete Solutions**: Provide full file replacements with all necessary imports and dependencies
- 🔹 **Architectural Integrity**: Every generated file or method adheres to SOLID principles
- 🔹 **Iterability First**: Design data structures with iteration patterns appropriate to language
- 🔹 **Runtime Consideration**: Explicitly account for error handling, edge cases and performance characteristics

---

## 📝 Request/Response Protocol

When requesting implementations, follow this pattern:

```markdown
### 🔍 IMPLEMENTATION REQUEST

**Context**: [Brief description of where this code fits]
**Purpose**: [What this code should accomplish]
**Constraints**: [Any limitations to respect]
**Pattern Preferences**: [Design patterns to follow]
**Language/Framework**: [Tech stack details]

---

**Details**: [Fuller explanation if needed]
```

Expected response format:

```markdownmarkdown
### 🧩 Implementation Plan

1. **Task Decomposition**:
   - Component 1: [Purpose]
   - Component 2: [Purpose]
   - ...

2. **Architecture Approach**:
   - [Key architectural decisions explained]
   - [Dependencies and interactions]

3. **Implementation Files**:
   - `[filepath1]`: [Purpose]
   - `[filepath2]`: [Purpose]
   - ...

### 📄 Implementation: [filepath]

```[language]
// Generated code with:
// - Complete imports
// - Well-structured components
// - Clear documentation
// - Error handling
// - Performance considerations
```

### 🧪 Validation Strategy

- Unit tests for [specific behaviors]
- Integration tests for [specific integrations]
- Potential edge cases: [list]
```markdown

---

## 📁 Copilot Integration Structure

Maintain these files for optimal Copilot assistance:

### `./.github/copilot/domain/vocabulary.md`

Define domain-specific terminology, patterns, and conventions:

```markdown
## Domain Vocabulary

| Term | Definition | Example Usage |
|------|------------|---------------|
| Term1 | Meaning | Context where used |
...
```

### `./.github/copilot/patterns/[pattern-name].md`

Document reusable patterns for the assistant to reference:

```markdown
## Pattern: [Name]

**Purpose**: [What this pattern solves]
**When to use**: [Appropriate scenarios]
**Implementation template**:

```[language]
// Template code
```

**Key considerations**:
- [Important note 1]
- [Important note 2]
```markdown

### `./.github/copilot/workflows/[workflow-name].md`

Define repeatable processes:

```markdown
## Workflow: [Name]

**Steps**:
1. [Step 1]
2. [Step 2]
...

**Inputs required**:
- [Input 1]
- [Input 2]

**Expected outputs**:
- [Output 1]
- [Output 2]
```

---

## 🧠 Quality Assurance Protocol

All generated code must meet these standards:

1. **Correctness**: Functionally accurate implementation
2. **Completeness**: All edge cases and error conditions handled
3. **Clarity**: Self-documenting with appropriate comments
4. **Consistency**: Follows project conventions and patterns
5. **Conciseness**: No redundant or unnecessary code
6. **Compatibility**: Works with specified dependencies and environment
7. **Testability**: Designed for automated testing

---

## 🔄 Refinement Cycle

Each implementation includes a refinement protocol:

1. **Initial Implementation**: First complete solution
2. **Evaluation**: Assessment against quality criteria
3. **Refinement Request**: Specific improvements needed
4. **Iteration**: Updated implementation with changes highlighted
5. **Documentation**: Update documentation to reflect changes

When requesting refinements:

```markdown
### 🔄 Refinement Request

**Target**: [File or component to refine]
**Issues**:
1. [Issue 1]
2. [Issue 2]
...
**Desired Outcome**: [What success looks like]
```

---

## 📊 Implementation Metrics

For complex implementations, provide these metrics:

- **Complexity score**: Estimate of cognitive complexity
- **Dependency count**: Number of external dependencies
- **Test coverage potential**: Estimate of testable surface area
- **Maintenance forecast**: Anticipated maintenance needs

---

## 🧪 Testing Guidelines

Every implementation should suggest appropriate tests:

- **Unit tests**: For isolated functionality
- **Integration tests**: For component interactions
- **Property-based tests**: For behavior verification across input ranges
- **Performance tests**: For runtime characteristics

Test naming convention: `[ComponentName]_[Scenario]_[ExpectedResult]`

---

## 🛠️ Tool Integration

Enable these integrations where applicable:

- **Linters**: Compatibility with project linting rules
- **Type checkers**: Strong typing where supported
- **Package managers**: Proper dependency specification
- **Build systems**: Integration with build pipeline
- **CI/CD**: Considerations for automated testing

---
```markdown

## Modular Components for Enhanced Implementation

Additionally, here are the first key modular component files you should create to maximize the effectiveness of this framework:

### 1. `.github/copilot/domain/vocabulary.md`

```markdown
# AutoGen Project Domain Vocabulary

| Term | Definition | Usage Context |
|------|------------|---------------|
| **Agent** | An autonomous entity that can interact with other agents, perform tasks, and respond to messages | Core component of the agent architecture |
| **Conversation** | A sequence of messages between agents | Primary interaction model |
| **LLM** | Large Language Model, the foundation model used by agents | Used in reference to external model integration |
| **Orchestration** | The process of coordinating multiple agents to achieve a task | System architecture level |
| **Prompt** | The input text provided to an LLM to generate a response | Agent configuration |
| **Workflow** | A sequence of operations performed by multiple agents | Higher-level automation concept |
| **Function Calling** | The ability of an agent to call and utilize external functions | Agent capability extension |
```

### 2. `.github/copilot/patterns/agent-definition.md`

```markdown
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
```

**Key considerations**:
- Agents should have a single clear responsibility
- Implement proper error handling and logging
- Consider message format compatibility with other agents
- Design for extensibility through composition rather than inheritance where possible
```markdown

### 3. `.github/copilot/workflows/agent-interaction-testing.md`

```markdown
# Workflow: Agent Interaction Testing

**Purpose**: Validate that agents can correctly interact with each other in a conversation

**Steps**:
1. Define test agents with controlled behaviors
2. Set up a conversation between agents
3. Inject test messages and prompts
4. Verify message handling and responses
5. Assert on conversation outcomes

**Inputs required**:
- Agent definitions
- Test conversation scenarios
- Expected message patterns
- Success criteria

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
```

**Expected outcomes**:
- Verified agent responses match expectations
- Conversation flow proceeds as designed
- Error conditions are properly handled
- Performance metrics are within acceptable ranges
