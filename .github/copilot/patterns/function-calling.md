---
applyTo: '**/*.py'
---

# Pattern: Function Calling Integration

**Purpose**: Enable agents to call external functions and use tools

**When to use**: When implementing agents that need to perform actions beyond text generation

**Implementation template**:

```python
from autogen import ConversableAgent, AssistantAgent, UserProxyAgent, config_list_from_json

# Define functions the agent can call
def search_database(query: str) -> str:
    """
    Search the database for information.

    Args:
        query: The search query

    Returns:
        str: The search results as text
    """
    # Implementation
    return f"Results for: {query}"

def perform_calculation(x: float, y: float, operation: str) -> float:
    """
    Perform a mathematical calculation.

    Args:
        x: First operand
        y: Second operand
        operation: One of "add", "subtract", "multiply", "divide"

    Returns:
        float: The calculation result
    """
    if operation == "add":
        return x + y
    elif operation == "subtract":
        return x - y
    elif operation == "multiply":
        return x * y
    elif operation == "divide":
        return x / y
    else:
        raise ValueError(f"Unknown operation: {operation}")

# Configure the function calling
llm_config = {
    "config_list": config_list_from_json("path/to/config.json"),
    "functions": [
        {
            "name": "search_database",
            "description": "Search the database for information",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "The search query"
                    }
                },
                "required": ["query"]
            }
        },
        {
            "name": "perform_calculation",
            "description": "Perform a mathematical calculation",
            "parameters": {
                "type": "object",
                "properties": {
                    "x": {
                        "type": "number",
                        "description": "First operand"
                    },
                    "y": {
                        "type": "number",
                        "description": "Second operand"
                    },
                    "operation": {
                        "type": "string",
                        "description": "The operation to perform",
                        "enum": ["add", "subtract", "multiply", "divide"]
                    }
                },
                "required": ["x", "y", "operation"]
            }
        }
    ]
}

# Create an agent with function calling capabilities
assistant = AssistantAgent(
    name="function_calling_assistant",
    system_message="You are an assistant that can search a database and perform calculations.",
    llm_config=llm_config
)

# Create a user proxy that can execute functions
user_proxy = UserProxyAgent(
    name="user_proxy",
    human_input_mode="ALWAYS",
    function_map={
        "search_database": search_database,
        "perform_calculation": perform_calculation
    }
)

# Initiate a conversation
user_proxy.initiate_chat(
    assistant,
    message="Can you help me find information about machine learning and calculate 15 * 24?"
)
```

**Key considerations**:
- Define clear function signatures with proper type hints
- Provide thorough documentation for each function
- Handle errors gracefully within functions
- Ensure functions return serializable results
- Monitor function call frequency to avoid excessive API usage
- Test functions independently before integrating with agents

## Common Issues to Watch For

- `#problems`: Functions with side effects that aren't properly documented
- `#security`: Functions that don't validate inputs or handle sensitive data
- `#optimize`: Inefficient functions that could cause performance bottlenecks
- `#fixme`: Functions that don't handle edge cases properly
- `#testneeded`: Missing test coverage for function behavior

## References
- [AutoGen Function Calling Documentation](https://microsoft.github.io/autogen/docs/reference/agentchat/function_calling)
- [GitHub Repository](https://github.com/DeanLuus22021994/autogen)
