# Complete `.github/copilot/workflows/prompt-optimization.md` File

Here's the fully amended file with all markdown and formatting issues resolved:

```markdown
---
applyTo: '**/*.py'
---

# Workflow: Prompt Optimization

**Purpose**: Systematically improve LLM prompts for better agent performance

**Steps**:

1. Define baseline prompt requirements and metrics
2. Create prompt variations with different approaches
3. Test each variation against standardized inputs
4. Analyze response quality metrics
5. Refine top-performing prompts iteratively

**Inputs required**:

* Initial prompt templates
* Evaluation criteria
* Test cases
* Performance metrics

**Implementation template**:

```python
import json
import os
from typing import List, Dict, Any
from autogen import AssistantAgent, UserProxyAgent

class PromptOptimizer:
    def __init__(self, base_prompt: str, test_cases: List[str]):
        """
        Initialize the prompt optimizer.

        Args:
            base_prompt: The starting system message
            test_cases: A list of user messages to test against
        """
        self.base_prompt = base_prompt
        self.test_cases = test_cases
        self.results = []

    def evaluate_prompt(self, prompt: str, criteria: Dict[str, float]) -> Dict[str, float]:
        """
        Evaluate a prompt against the test cases.

        Args:
            prompt: The system message to test
            criteria: The evaluation criteria with weights

        Returns:
            Dict of scores for each criterion
        """
        # Create an agent with the prompt
        agent = AssistantAgent(
            name="test_agent",
            system_message=prompt,
            llm_config={
                "model": os.environ.get("PREFERRED_MODEL", "gpt-4"),
                "temperature": 0
            }
        )

        user = UserProxyAgent(
            name="user_proxy",
            human_input_mode="NEVER"
        )

        scores = {}
        for criterion in criteria:
            scores[criterion] = 0.0

        # Run test cases
        for test_case in self.test_cases:
            # Get response
            user.initiate_chat(agent, message=test_case, cache=False)
            response = agent.chat_messages[user.name][-1]["content"]

            # Score response (this would use more sophisticated evaluation in practice)
            for criterion, weight in criteria.items():
                criterion_score = self._score_criterion(response, criterion, test_case)
                scores[criterion] += criterion_score * weight

        # Average scores
        for criterion in scores:
            scores[criterion] /= len(self.test_cases)

        # Record results
        self.results.append({
            "prompt": prompt,
            "scores": scores,
            "overall_score": sum(scores.values()) / len(scores)
        })

        return scores

    def _score_criterion(self, response: str, criterion: str, test_case: str) -> float:
        """
        Score a response on a specific criterion.

        Args:
            response: The agent's response
            criterion: The criterion to evaluate
            test_case: The test case that generated the response

        Returns:
            A score between 0.0 and 1.0
        """
        # This would implement actual scoring logic
        # For example, using another LLM to evaluate, or using heuristics
        return 0.5  # Placeholder

    def get_best_prompt(self) -> str:
        """
        Get the best performing prompt.

        Returns:
            The prompt with the highest overall score
        """
        if not self.results:
            return self.base_prompt

        return max(self.results, key=lambda x: x["overall_score"])["prompt"]

    def save_results(self, filename: str):
        """
        Save optimization results to a file.

        Args:
            filename: The file to save to
        """
        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)

# Example usage
if __name__ == "__main__":
    base_prompt = "You are a helpful assistant."
    test_cases = [
        "What is machine learning?",
        "How do I implement a neural network?",
        "Explain the concept of reinforcement learning."
    ]

    optimizer = PromptOptimizer(base_prompt, test_cases)

    # Test variations
    variations = [
        "You are a helpful assistant specialized in explaining technical concepts clearly.",
        "You are a machine learning expert who explains concepts in simple terms.",
        "You are an AI teacher who breaks down complex topics into easy-to-understand explanations."
    ]

    criteria = {
        "clarity": 0.4,
        "accuracy": 0.4,
        "conciseness": 0.2
    }

    for prompt in variations:
        scores = optimizer.evaluate_prompt(prompt, criteria)
        print(f"Prompt: {prompt}\nScores: {scores}\n")

    best_prompt = optimizer.get_best_prompt()
    print(f"Best prompt: {best_prompt}")

    # Save results
    optimizer.save_results("prompt_optimization_results.json")
```

**Expected outcomes**:

* Quantitative scores for different prompt variations
* Identification of the best-performing prompts
* Documentation of prompt evolution
* Insights into effective prompt patterns

## Common Issues to Watch For

* `#problems`: Optimization techniques that favor one criterion excessively
* `#optimize`: Evaluation processes that are too slow for rapid iteration
* `#fixme`: Scoring methods that don't align with actual user requirements
* `#todo`: Missing evaluation criteria for important aspects of responses
* `#security`: Prompt variations that might lead to unwanted agent behaviors

## Integration with Fork Environment

When using this workflow with your fork, ensure that:

* The LLM configuration is compatible with your authentication setup
* Replace hardcoded model names with environment variables where appropriate
* Add proper error handling for API rate limits and authentication issues

```python
# Example of environment variable integration
llm_config = {
    "model": os.environ.get("PREFERRED_MODEL", "gpt-4"),
    "api_key": os.environ.get("FORK_HUGGINGFACE_ACCESS_TOKEN"),
    "timeout": int(os.environ.get("API_TIMEOUT", "300")),
    "max_retries": int(os.environ.get("API_MAX_RETRIES", "3"))
}
```

## References

* [Prompt Engineering Guidelines](https://www.promptingguide.ai/)
* [GitHub Repository](https://github.com/DeanLuus22021994/autogen)
* [AutoGen Documentation](https://microsoft.github.io/autogen/docs/)
