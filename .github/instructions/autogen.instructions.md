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
- 🔹 **Configuration Consistency**: Follow established patterns for DIR.TAG files and XML configurations

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

```markdown
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
```

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
```

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

## 📁 Configuration Files Structure

Maintain these configuration patterns for consistency:

### DIR.TAG Files

Use standardized DIR.TAG format for tracking development status and debt:

```plaintext
#INDEX: [directory-path]
#TODO:
  - [Task description] [STATUS]
  - [Task description] [STATUS]
  - ...
status: [OVERALL_STATUS]
updated: [YYYY-MM-DDThh:mm:ssZ]
description: |
  [Detailed description of the directory purpose]
  [Additional context and information]
```

Status values: `NOT_STARTED`, `PARTIALLY_COMPLETE`, `DONE`, `OUTSTANDING`

### XML Configuration Files

Use standardized XML for configuration:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<root_element>
  <section>
    <property>value</property>
    <nested_section>
      <nested_property>value</nested_property>
    </nested_section>
  </section>
</root_element>
```

### Docker Model Runner Integration

Configure Docker Model Runner according to this pattern:

```markdown
# Docker Model Integration

The following Docker images are used via Docker Model Runner:
- ai/mistral-nemo
- ai/mxbai-embed-large
- ai/smollm2
- ai/mistral

## Usage
1. Ensure Docker Desktop 4.40+ is installed
2. Enable Docker Model Runner in Docker Desktop settings
3. Use the CLI: `docker model pull/run ai/model-name`
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
- **Docker Model Runner**: Integration with local AI models
- **XML Validation**: Schema validation for configuration files

---

## 📋 Project-Specific Components

### 1. DIR.TAG Structure

```plaintext
# filepath: [path/to/directory]/DIR.TAG
#INDEX: [directory-path]
#TODO:
  - [Task description] [STATUS]
  - [Task description] [STATUS]
status: [OVERALL_STATUS]
updated: [YYYY-MM-DDThh:mm:ssZ]
description: |
  [Detailed description]
```

### 2. DevContainer Integration

```yaml
# Docker Model Runner configuration
version: '3.8'

services:
  # Development tooling services
  autogen-dev:
    image: mcr.microsoft.com/devcontainers/python:3.10
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - MODEL_RUNNER_ENDPOINT=http://model-runner.docker.internal/engines/v1/chat/completions
```

### 3. XML Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<model_settings>
  <docker_model_runner>
    <enabled>true</enabled>
    <version>beta</version>
  </docker_model_runner>
  <models>
    <model>
      <name>ai/model-name</name>
      <description>Model description</description>
    </model>
  </models>
</model_settings>
```

### 4. Key Domain Vocabulary

| Term | Definition | Usage Context |
|------|------------|---------------|
| **DIR.TAG** | Special file used to track development status and debt in directories | Used for maintaining development traceability |
| **Docker Model Runner** | Docker feature for running AI models locally | Used for local development with minimal API usage |
| **XML Configuration** | Standardized XML format for configuration files | Used in `.config/host/*.xml` for system configuration |
