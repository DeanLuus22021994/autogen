// Sample custom rule for markdown linting
module.exports = {
  names: ["custom-sample-rule"],
  description: "Sample custom rule",
  tags: ["customization"],
  function: function rule(params, onError) {
    // This is just a placeholder rule
    // Actual implementation would check for specific patterns
    return true;
  }
};