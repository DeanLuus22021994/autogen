---
applyTo: '**/tests/*.py'
---

# Test Generation Prompt Template

Use this template when requesting test implementations:

## 🔍 TEST IMPLEMENTATION REQUEST

**Component to Test**: [Component name]
**Test Scope**: [Unit/Integration/System]
**Test Scenarios**: [List of scenarios to test]
**Dependencies**: [Any dependencies required]
**Mocking Requirements**: [What should be mocked]

---

**Success Criteria**:
[What determines if the tests are successful]

## Example Request

### 🔍 TEST IMPLEMENTATION REQUEST

**Component to Test**: CodeWriterAgent
**Test Scope**: Unit and Integration
**Test Scenarios**:
- Code generation from natural language description
- Error handling for unclear instructions
- Integration with UserProxyAgent
- Function calling capabilities
**Dependencies**: unittest, pytest, mock
**Mocking Requirements**: LLM API calls should be mocked to return deterministic responses

---

**Success Criteria**:
- All test cases pass consistently
- Code coverage is at least 85%
- Edge cases are properly handled
- Test execution time is reasonable
- Mocks accurately simulate actual API behavior

## Common Testing Issues to Address

- `#problems`: Tests that are not deterministic or depend on external services
- `#fixme`: Insufficient test coverage for edge cases
- `#optimize`: Tests that are unnecessarily slow or resource-intensive
- `#refactor`: Duplicated test code that could be extracted into fixtures or helpers
- `#security`: Tests that expose sensitive information in logs or outputs

## References
- [AutoGen Testing Guide](https://microsoft.github.io/autogen/docs/testing)
- [GitHub Repository](https://github.com/DeanLuus22021994/autogen)
