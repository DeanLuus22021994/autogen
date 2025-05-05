---
applyTo: '**/*.md'
---

# Custom Dictionary for AutoGen Project

This document defines custom terminology and technical words specific to the AutoGen project that might not be recognized by standard spellcheckers.

## Technical Terms

* **CODEOWNERS**: GitHub's file format for specifying code ownership
* **Iterability**: The quality of being able to be iterated over
* **testneeded**: Tag to mark code requiring test coverage
* **autogen**: Short for Autonomous Agent Generation framework
* **mcp**: Management Control Panel
* **pwsh**: PowerShell Core command-line interface
* **vscode**: Visual Studio Code IDE

## Integration with VS Code

To add these terms to your VS Code spell checking, add the following to your `.vscode/settings.json`:

```json
{
  "cSpell.words": [
    "autogen",
    "CODEOWNERS",
    "Iterability",
    "mcp",
    "pwsh",
    "testneeded",
    "vscode"
  ]
}
```

## References

* [VS Code Code Spell Checker Extension](https://marketplace.visualstudio.com/items?itemName=streetsidesoftware.code-spell-checker)
* [GitHub CODEOWNERS Documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
