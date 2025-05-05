---
applyTo: '**/agents/*.py'
---

# Agent Creation Prompt Template

Use this template when requesting a new agent implementation:

## 🔍 AGENT IMPLEMENTATION REQUEST

**Agent Name**: [Name of the agent]
**Purpose**: [What this agent should accomplish]
**Capabilities**: [What the agent should be able to do]
**Interaction Patterns**: [How this agent interacts with other agents]
**LLM Requirements**: [Any specific LLM configuration needed]

---

**Detailed Behavior Description**:
[Describe in detail how the agent should behave]

**System Message**:
[The system message to be used for this agent]

## Example Request

### 🔍 AGENT IMPLEMENTATION EXAMPLE

**Agent Name**: ResearchAgent
**Purpose**: Conduct research on specific topics and provide comprehensive summaries
**Capabilities**: Web searching, information retrieval, summarization, citation
**Interaction Patterns**: Takes research requests from UserProxy, reports findings to AssistantAgent
**LLM Requirements**: GPT-4 with high temperature for creative research approaches

---

**Detailed Behavior Description**:
The ResearchAgent should be able to take a research topic, break it down into searchable queries, conduct searches using available tools, compile information from various sources, and create a comprehensive summary with proper citations. It should be able to identify credible sources and prioritize recent information when appropriate.

**System Message**:
"You are a research specialist who can find and summarize information on any topic. When given a research request, break it down into manageable parts, search for relevant information, and compile a comprehensive response with proper citations. Prioritize credible sources and recent information when relevant. Always cite your sources."

## Common Implementation Issues to Address

- `#problems`: Agent design that doesn't clearly define interaction boundaries
- `#security`: Missing input validation or unsafe function execution
- `#optimize`: Inefficient message handling patterns
- `#testneeded`: Lack of test cases for agent behavior verification
- `#todo`: Incomplete implementation of specified capabilities

## References
- [AutoGen Agent Documentation](https://microsoft.github.io/autogen/docs/reference/agentchat/agent)
- [GitHub Repository](https://github.com/DeanLuus22021994/autogen)
