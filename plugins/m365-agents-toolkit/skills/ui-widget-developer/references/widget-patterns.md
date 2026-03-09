# Widget Patterns

## Table of Contents
- [Widget Template](#widget-template)
- [Data Access Pattern](#data-access-pattern)
- [Theme Support Pattern](#theme-support-pattern)
- [CSS Variables (Required)](#css-variables-required)
- [Debug Data Pattern](#debug-data-pattern)
- [XSS Prevention](#xss-prevention)
- [Action Buttons](#action-buttons)

HTML widgets for OpenAI Apps SDK with Copilot Chat.

## Widget Template

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Widget Name</title>
  <style>
    /* CSS Variables - Theme definitions at :root level */
    :root {
      --text-color: #1a1a1a;
      --secondary-text: #666;
      --border-color: #e5e5e5;
      --card-bg: #ffffff;
      --hover-bg: #f5f5f5;
      --bg-color: #f9fafb;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --text-color: #f5f5f5;
        --secondary-text: #a3a3a3;
        --border-color: #404040;
        --card-bg: #262626;
        --hover-bg: #333333;
        --bg-color: #1a1a1a;
      }
    }

    /* Theme classes override media query when set by JS */
    body.theme-dark {
      --text-color: #f5f5f5;
      --secondary-text: #a3a3a3;
      --border-color: #404040;
      --card-bg: #262626;
      --hover-bg: #333333;
      --bg-color: #1a1a1a;
    }

    body.theme-light {
      --text-color: #1a1a1a;
      --secondary-text: #666;
      --border-color: #e5e5e5;
      --card-bg: #ffffff;
      --hover-bg: #f5f5f5;
      --bg-color: #f9fafb;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: var(--bg-color);
      padding: 16px;
      color: var(--text-color);
    }

    .container {
      max-width: 800px;
      margin: 0 auto;
    }

    .header {
      margin-bottom: 16px;
      padding-bottom: 12px;
      border-bottom: 1px solid var(--border-color);
    }

    .header h1 {
      font-size: 18px;
      font-weight: 600;
      color: var(--text-color);
    }

    .header .subtitle {
      font-size: 13px;
      color: var(--secondary-text);
      margin-top: 4px;
    }

    .card {
      background: var(--card-bg);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 12px;
      transition: box-shadow 0.2s, transform 0.2s;
    }

    .card:hover {
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
      transform: translateY(-2px);
    }

    .btn {
      padding: 8px 16px;
      border: 1px solid var(--border-color);
      border-radius: 6px;
      background: var(--card-bg);
      color: var(--text-color);
      font-size: 14px;
      cursor: pointer;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }

    .btn:hover {
      background: var(--hover-bg);
    }

    .btn.primary {
      background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
      border-color: transparent;
      color: white;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 id="title">Loading...</h1>
      <div class="subtitle" id="subtitle"></div>
    </div>
    <div id="content">
      <!-- Dynamic content -->
    </div>
  </div>

  <script>
    (function() {
      let rendered = false;

      // Debug mock data for testing outside BizChat
      const DEBUG_DATA = {
        title: "Debug Title",
        items: [
          { name: "Item 1", value: "Value 1" },
          { name: "Item 2", value: "Value 2" }
        ]
      };

      // Apply theme from openai.theme or browser preference
      function applyTheme() {
        if (window.openai && window.openai.theme) {
          const theme = window.openai.theme.toLowerCase();
          console.log('Applying theme:', theme);
          document.body.classList.remove('theme-light', 'theme-dark');
          if (theme === 'dark') {
            document.body.classList.add('theme-dark');
          } else if (theme === 'light') {
            document.body.classList.add('theme-light');
          }
        }
      }
      applyTheme();

      // Debug logging
      console.log('=== WIDGET DEBUG ===');
      console.log('window.openai:', window.openai);
      if (window.openai) {
        console.log('toolOutput:', window.openai.toolOutput);
        console.log('theme:', window.openai.theme);
      }

      function escapeHtml(str) {
        const div = document.createElement('div');
        div.textContent = str || '';
        return div.innerHTML;
      }

      function renderWidget(data) {
        console.log('renderWidget called with:', data);
        if (!data) return;
        rendered = true;

        document.getElementById('title').textContent = data.title || 'Untitled';
        document.getElementById('subtitle').textContent =
          `${data.items?.length || 0} items`;

        const content = document.getElementById('content');
        if (data.items && data.items.length > 0) {
          content.innerHTML = data.items.map(item => `
            <div class="card">
              <strong>${escapeHtml(item.name)}</strong>
              <p style="color: var(--secondary-text); margin-top: 4px;">
                ${escapeHtml(item.value)}
              </p>
            </div>
          `).join('');
        } else {
          content.innerHTML = '<p style="color: var(--secondary-text);">No items</p>';
        }
      }

      function getWidgetData() {
        // Priority: toolOutput > widgetState > structuredContent > data > DEBUG
        if (window.openai) {
          return window.openai.toolOutput ||
                 window.openai.widgetState ||
                 window.openai.structuredContent ||
                 window.openai.data ||
                 null;
        }
        // Fallback for local testing
        console.log('No window.openai - using DEBUG_DATA');
        return DEBUG_DATA;
      }

      function initialize() {
        const data = getWidgetData();
        if (data) {
          renderWidget(data);
        }

        // Listen for state changes
        if (window.openai && typeof window.openai.onStateChange === 'function') {
          window.openai.onStateChange(function(newState) {
            console.log('onStateChange:', newState);
            renderWidget(newState);
          });
        }
      }

      initialize();

      // Poll if not rendered (data might arrive late)
      if (!rendered) {
        let attempts = 0;
        const maxAttempts = 50;
        const poll = setInterval(function() {
          attempts++;
          const data = getWidgetData();
          if (data) {
            renderWidget(data);
            clearInterval(poll);
          } else if (attempts >= maxAttempts) {
            clearInterval(poll);
            document.getElementById('title').textContent = 'Unable to load';
          }
        }, 100);
      }

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initialize);
      }
    })();
  </script>
</body>
</html>
```

## Data Access Pattern

```javascript
// Priority order for data access
const data = window.openai.toolOutput ||      // Primary: MCP tool response
             window.openai.widgetState ||     // Alternative state
             window.openai.structuredContent || // Structured content
             window.openai.data ||            // Generic data
             DEBUG_DATA;                      // Local testing fallback
```

## Theme Support Pattern

```javascript
function applyTheme() {
  if (window.openai && window.openai.theme) {
    const theme = window.openai.theme.toLowerCase();
    document.body.classList.remove('theme-light', 'theme-dark');
    document.body.classList.add(theme === 'dark' ? 'theme-dark' : 'theme-light');
  }
  // Otherwise falls back to prefers-color-scheme media query
}
```

## CSS Variables (Required)

Always define at `:root` level with dark mode override:

```css
:root {
  --text-color: #1a1a1a;
  --secondary-text: #666;
  --border-color: #e5e5e5;
  --card-bg: #ffffff;
  --hover-bg: #f5f5f5;
  --bg-color: #f9fafb;
}

@media (prefers-color-scheme: dark) {
  :root {
    --text-color: #f5f5f5;
    --secondary-text: #a3a3a3;
    --border-color: #404040;
    --card-bg: #262626;
    --hover-bg: #333333;
    --bg-color: #1a1a1a;
  }
}

body.theme-dark { /* Same as dark :root */ }
body.theme-light { /* Same as light :root */ }
```

## Debug Data Pattern

Always include fallback data for local testing:

```javascript
const DEBUG_DATA = {
  // Match your structuredContent shape
  title: "Debug Mode",
  items: [
    { name: "Test Item", value: "Test Value" }
  ]
};

function getWidgetData() {
  if (window.openai) {
    return window.openai.toolOutput || /* ... */;
  }
  return DEBUG_DATA; // Local testing
}
```

## XSS Prevention

Always escape user-provided content:

```javascript
function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str || '';
  return div.innerHTML;
}

// Usage
content.innerHTML = `<span>${escapeHtml(userData)}</span>`;
```

## Action Buttons

```html
<a href="mailto:${escapeHtml(email)}" class="btn primary">Email</a>
<a href="https://teams.microsoft.com/l/chat/0/0?users=${encodeURIComponent(email)}"
   class="btn" target="_blank">Chat</a>
```
