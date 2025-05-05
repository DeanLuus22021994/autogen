# Custom Markdown Linting Rules

This directory contains custom rules for the markdown linting system in the AutoGen project.

## Available Rules

- `sample-rule.js` - A sample rule that demonstrates how to create custom rules for markdown linting.

## Creating Custom Rules

To create a new custom rule:

1. Create a JavaScript file in this directory (e.g., `my-rule.js`)
2. Implement the rule following the markdownlint plugin pattern
3. Export the rule through the module.exports

Example template:

```javascript
"use strict";

module.exports = {
  names: ["custom-rule-name"],
  description: "Description of what the rule checks for",
  tags: ["autogen", "tag"],
  information: new URL("https://github.com/microsoft/autogen"),
  function: function rule(params, onError) {
    // Rule implementation
  }
};