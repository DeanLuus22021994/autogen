// .github/linting/rules/example-rule.js
// Basic example rule to ensure the rules directory has valid content

"use strict";

module.exports = {
  names: ["example-rule"],
  description: "Example custom rule",
  tags: ["autogen", "example"],
  function: function rule(params, onError) {
    params.tokens.filter(function filterToken(token) {
      return token.type === "heading_open";
    }).forEach(function forToken(token) {
      if (token.line.trim().length > 80) {
        onError({
          lineNumber: token.lineNumber,
          detail: "Heading line is too long",
          context: token.line.trim()
        });
      }
    });
  }
};