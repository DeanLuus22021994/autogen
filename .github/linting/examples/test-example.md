# Example Markdown for Rule Testing

This file contains various examples for testing markdown linting rules.

## Links with HTTP URLs

Here are some links that use insecure HTTP:
- [Example 1](http://example.com)
- [Example 2](http://microsoft.com)
- [Example 3](http://github.com)

These links use HTTPS and should pass:
- [Secure Example 1](https://example.com)
- [Secure Example 2](https://microsoft.com/autogen)
- [Secure Example 3](https://github.com/microsoft/autogen)

## Tables for Format Testing

| Name | Type | Description |
|------|------|-------------|
| id | string | Unique identifier |
| name | string | Display name |
| enabled | boolean | Whether the feature is enabled |

## Code Blocks for Syntax Testing

```python
def hello_world():
    print("Hello, World!")
    return True
```

```javascript
function testFunction() {
  console.log("Testing JavaScript");
  return true;
}
```

## Headers with Spacing Issues

#Incorrect Header 1
##  Too Many Spaces

## Proper Header

### Lists with Format Issues

* Item 1
* Item 2
  * Nested item
* Item 3
  *Incorrect nesting
* Item 4

## Line Length Testing

This is a short line.

This is a very long line that exceeds the recommended line length limit and should trigger warnings if line length rules are enabled in the linting configuration.

## HTML Tags

<div>This contains HTML tags which might be flagged depending on your rules.</div>

<custom-tag>Custom HTML tags might also be flagged.</custom-tag>

## Inline Code

Use the `console.log()` function to print to the console.

## Emphasis

**Bold text** and *italic text* are common in markdown.

## Line Break Issues

This line ends with two spaces
This line continues after a line break.

This paragraph
has a line break
without trailing spaces.
