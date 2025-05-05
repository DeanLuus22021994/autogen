---
applyTo: '**/*.py'
---

# AutoGen Project Domain Vocabulary

This document establishes a consistent terminology for AutoGen development to ensure semantic clarity and precision.

| Term | Definition | Usage Context |
|------|------------|---------------|
| **Agent** | An autonomous entity that can interact with other agents, perform tasks, and respond to messages | Core component of the agent architecture |
| **Conversation** | A sequence of messages between agents | Primary interaction model |
| **LLM** | Large Language Model, the foundation model used by agents | Used in reference to external model integration |
| **Orchestration** | The process of coordinating multiple agents to achieve a task | System architecture level |
| **Prompt** | The input text provided to an LLM to generate a response | Agent configuration |
| **Workflow** | A sequence of operations performed by multiple agents | Higher-level automation concept |
| **Function Calling** | The ability of an agent to call and utilize external functions | Agent capability extension |
| **Tool Use** | Agent's capability to leverage external tools/APIs | Implementation pattern |
| **Group Chat** | A conversation involving multiple agents | Multi-agent architecture |
| **RAG** | Retrieval-Augmented Generation | Knowledge integration approach |
| **Context Window** | The maximum amount of text an LLM can process in one interaction | LLM constraint |
| **Observation** | Data or information an agent perceives from its environment | Agent cognitive model |
| **Action** | A task that an agent performs | Agent behavior |
| **Planning** | The process of determining a sequence of actions to achieve a goal | Agent cognitive model |
| **Reasoning** | The process of drawing conclusions from observations | Agent cognitive model |

## IDE Problem References

* Use `#problems` to flag inconsistent terminology usage across the codebase
* Use `#todo` to mark terms that need additional clarification or examples
* Use `#fixme` to identify incorrect or outdated terminology definitions
* Use `#security` to highlight terminology related to security-sensitive components

## Repository Configuration

This vocabulary is specific to the [DeanLuus22021994/autogen](https://github.com/DeanLuus22021994/autogen) fork, which has specific environment variables and configurations for authentication and workflow automation.

## References

* [AutoGen Documentation](https://microsoft.github.io/autogen/docs/)
* [GitHub Repository](https://github.com/DeanLuus22021994/autogen)
