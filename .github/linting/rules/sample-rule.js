// Sample custom rule for markdown linting

"use strict";

module.exports = {
  names: ["custom-rule-sample"],
  description: "Sample custom rule for AutoGen markdown documents",
  tags: ["autogen", "sample"],
  information: new URL("https://github.com/microsoft/autogen"),
  function: function rule(params, onError) {
    // Simple example: detect potentially problematic patterns in markdown
    params.tokens.filter(token => token.type === "inline").forEach(token => {
      const text = token.content;

      // Example: Detect URLs that might be problematic
      const urlPattern = /http:\/\/[^\s)]+/g;
      let match;
      while ((match = urlPattern.exec(text)) !== null) {
        // Suggest using https instead of http
        onError({
          lineNumber: token.lineNumber,
          detail: "Consider using https:// instead of http:// for security",
          context: match[0],
          range: [match.index + 1, match[0].length]
        });
      }
    });
  }
};