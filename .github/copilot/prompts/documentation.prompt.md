---
applyTo: '**/*.md'
---

# Documentation Generation Prompt Template

Use this template when requesting documentation:

### 🔍 DOCUMENTATION REQUEST

**Doc Type**: [API Reference/Tutorial/Guide/README]
**Component**: [Component being documented]
**Target Audience**: [Developers/Researchers/End Users]
**Required Sections**: [List of sections needed]
**Code Examples**: [Yes/No, and what kind if yes]

---

**Additional Context**:
[Background information or special requirements]

## Example Request

### 🔍 DOCUMENTATION REQUEST

**Doc Type**: Tutorial
**Component**: GroupChat Multi-Agent System
**Target Audience**: Python developers new to AutoGen
**Required Sections**: Introduction, Prerequisites, Setup, Agent Configuration, Group Chat Setup, Advanced Patterns, Troubleshooting
**Code Examples**: Yes, with step-by-step explanations and complete working code

---

**Additional Context**:
This tutorial should focus on practical implementation rather than theoretical concepts. It should include a complete working example that users can run with minimal modifications. Target Python developers who have basic understanding of LLMs but are new to multi-agent systems.

## Common Documentation Issues to Address

- `#problems`: Technical inaccuracies or outdated information
- `#todo`: Missing sections or incomplete explanations
- `#fixme`: Unclear explanations or confusing structure
- `#optimize`: Documentation that's too verbose or technical for the target audience
- `#security`: Missing warnings about security considerations

## References
- [AutoGen Documentation Guidelines](https://microsoft.github.io/autogen/docs/contributing)
- [GitHub Repository](https://github.com/DeanLuus22021994/autogen)
