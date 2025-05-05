---
applyTo: '**/*.py'
---

# Pattern: Conversation Flow

**Purpose**: Design robust conversation patterns between agents

**When to use**: When implementing agent-to-agent communication or multi-agent workflows

**Implementation template**:

```python
from autogen import ConversableAgent, AssistantAgent, UserProxyAgent, GroupChat, GroupChatManager

# Define the agents
assistant = AssistantAgent(
    name="assistant",
    system_message="You are a helpful AI assistant.",
    llm_config={"model": "gpt-4", "temperature": 0.7}
)

user_proxy = UserProxyAgent(
    name="user_proxy",
    human_input_mode="ALWAYS"
)

# Create a specialized task agent
research_agent = AssistantAgent(
    name="researcher",
    system_message="You are a research specialist who finds and summarizes information.",
    llm_config={"model": "gpt-4", "temperature": 0.2}
)

# Option 1: Direct conversation
user_proxy.initiate_chat(
    assistant,
    message="I need help with a research task."
)

# Option 2: Group chat with multiple agents
agents = [user_proxy, assistant, research_agent]
group_chat = GroupChat(agents=agents, messages=[], max_round=10)
manager = GroupChatManager(groupchat=group_chat, llm_config={"model": "gpt-4"})

# Start the group conversation
user_proxy.initiate_chat(
    manager,
    message="Let's research the latest developments in AI."
)
```

**Key considerations**:
- Design conversations with clear entry and exit points
- Consider timeouts and maximum rounds to prevent infinite loops
- Implement proper error handling for failed responses
- Monitor conversation state for debugging
- Use appropriate prompting techniques for effective agent communication

## Common Issues to Watch For

- `#problems`: Circular conversations that don't terminate properly
- `#security`: Inadequate message validation between agents
- `#optimize`: Redundant message passing patterns
- `#fixme`: Missing error handling for network or API failures
- `#refactor`: Tightly coupled agent interactions that limit reusability

## References
- [AutoGen GroupChat Documentation](https://microsoft.github.io/autogen/docs/reference/agentchat/groupchat)
- [GitHub Repository](https://github.com/DeanLuus22021994/autogen)
