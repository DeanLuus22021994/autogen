---
applyTo: '**/*.py'
---

# Core AutoGen Concepts

This document outlines the fundamental concepts in the AutoGen framework to ensure consistent implementation.

## Agent System Architecture

AutoGen is designed around a multi-agent architecture with these primary components:

1. **Agent Types**:
   * **Conversable Agents**: Base agents that can engage in conversations
   * **Assistant Agents**: LLM-powered agents that can generate responses
   * **User Proxy Agents**: Represent human users or external systems
   * **Group Chat Managers**: Coordinate conversations between multiple agents

2. **Conversation Management**:
   * Messages are passed between agents in structured conversations
   * Conversations maintain history and context
   * Agents can have memory and access to past interactions

3. **Tool Integration**:
   * Agents can use functions and external tools
   * Function calling allows agents to execute code
   * Tools extend agent capabilities beyond language generation

4. **Configuration System**:
   * Agents have configurable parameters
   * LLM settings control generation behavior
   * System messages define agent personality and capabilities

## Core Design Principles

1. **Modularity**: Components should be loosely coupled and highly cohesive
2. **Extensibility**: Design for extension rather than modification
3. **Observability**: Enable monitoring and debugging of agent interactions
4. **Reliability**: Handle errors and edge cases gracefully
5. **Scalability**: Support multiple concurrent conversations and agents

## Implementation Guidelines

When implementing core AutoGen concepts:

* Follow the established agent hierarchy
* Maintain backward compatibility with existing APIs
* Document all public interfaces thoroughly
* Handle exceptions at appropriate abstraction levels
* Provide examples for new features

## IDE Problem References

* Use `#problems` to mark inconsistencies with the architectural design
* Use `#todo` to highlight areas needing implementation or documentation
* Use `#optimize` to indicate components that could benefit from performance improvements
* Use `#refactor` to mark code that doesn't align with core design principles

## References

* [AutoGen Architecture Documentation](https://microsoft.github.io/autogen/docs/concepts)
* [GitHub Repository](https://github.com/DeanLuus22021994/autogen)
