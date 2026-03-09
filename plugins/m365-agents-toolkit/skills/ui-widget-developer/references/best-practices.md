# Best Practices

> **Language note**: These best practices apply to any MCP server implementation. Code examples
> use TypeScript for illustration, but the patterns (rendering tools, partial data handling,
> tool response format, widget-resource-tool triplet) are language-agnostic concepts.

## Table of Contents
- [1. Rendering Tools Pattern](#1-rendering-tools-pattern)
- [2. Handle Partial Data](#2-handle-partial-data)
- [3. Agent Instructions](#3-agent-instructions)
- [4. Theme Support](#4-theme-support)
- [5. Debug Mode](#5-debug-mode)
- [6. Version Management](#6-version-management)
- [7. Input Schema Descriptions](#7-input-schema-descriptions)
- [8. Consistent Tool Definitions](#8-consistent-tool-definitions)
- [9. CORS Configuration](#9-cors-configuration)
- [10. Widget Security](#10-widget-security)
- [11. DevTunnels](#11-devtunnels)
- [12. Declarative Agent Capabilities](#12-declarative-agent-capabilities)
- [13. Error Handling in Widgets](#13-error-handling-in-widgets)
- [14. Tool Response Format](#14-tool-response-format)
- [15. Conversation Starters](#15-conversation-starters)
- [16. Widget-Resource-Tool Triplet](#16-widget-resource-tool-triplet)

## 1. Rendering Tools Pattern

Design MCP tools as **rendering tools** that accept data from the caller rather than fetching data internally.

**Why**: Copilot can use its capabilities (People, Graph, etc.) to fetch data, then pass it to your MCP tool for rendering. This separation:
- Leverages Copilot's built-in data access
- Makes tools reusable across different data sources
- Simplifies MCP server implementation

**Pattern**:
```typescript
// Good: Accept data as input
inputSchema: {
  type: "object",
  properties: {
    items: { type: "array", items: { /* ... */ } }
  }
}

// Avoid: Fetching data internally
// const data = await fetchFromAPI(); // Don't do this
```

## 2. Handle Partial Data

Always normalize input data to handle missing fields gracefully. Fill in "Unknown" for any missing properties.

**Server Pattern**:
```typescript
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const args = request.params.arguments as { title?: string; items?: Partial<Item>[] };

  // Normalize data - fill in "Unknown" for missing fields
  const title = args.title || "Default Title";
  const items = (args.items || []).map(item => ({
    name: item.name || "Unknown",
    email: item.email || "Unknown",
    location: item.location || "Unknown",
  }));

  const structuredContent = { title, items };
  // ...
});
```

**Widget Pattern** - Hide action buttons when data is "Unknown":
```javascript
function renderItem(item) {
  const hasEmail = item.email && item.email !== 'Unknown';
  const actionsHtml = hasEmail ? `
    <a href="mailto:${escapeHtml(item.email)}" class="btn">Email</a>
    <a href="https://teams.microsoft.com/l/chat/0/0?users=${encodeURIComponent(item.email)}"
       class="btn">Chat</a>
  ` : '';

  return `
    <div class="card">
      <div class="name">${escapeHtml(item.name || 'Unknown')}</div>
      ${actionsHtml}
    </div>
  `;
}
```

**Schema Pattern** - Make properties optional and document defaults:
```json
{
  "properties": {
    "name": {
      "type": "string",
      "description": "Full name. Defaults to 'Unknown' if not provided."
    }
  }
}
```

## 3. Agent Instructions

Tell the agent to use capabilities FIRST, then pass data to MCP tools.

**Pattern** (instruction.txt):
```
IMPORTANT: You MUST ALWAYS use the [Capability] capability FIRST to retrieve data
before calling MCP tools. The MCP tools are RENDERING tools only - they do NOT
fetch data. You must:
1. Query the capability to get the data
2. Pass that retrieved data to the appropriate MCP tool to render it

CRITICAL: Never call the MCP tools without first retrieving data from the capability.
```

## 4. Theme Support

See [widget-patterns.md](widget-patterns.md) for complete theme CSS variable implementation. Key rule: always support dark/light mode via CSS variables at `:root` level, detecting via `window.openai.theme` or `prefers-color-scheme`.

## 5. Debug Mode

Include fallback data for local widget testing without BizChat.

```javascript
const DEBUG_DATA = { /* realistic test data */ };

function getWidgetData() {
  if (window.openai) {
    return window.openai.toolOutput || /* other sources */;
  }
  console.log('Debug mode - using DEBUG_DATA');
  return DEBUG_DATA;
}
```

## 6. Version Management

Bump manifest version for each deployment when changes aren't reflected.

```json
// manifest.json
{ "version": "1.0.5" }  // Increment on each change
```

## 7. Input Schema Descriptions

Provide detailed descriptions with examples and default values in inputSchema.

```json
{
  "properties": {
    "email": {
      "type": "string",
      "description": "Email address (e.g., 'john.doe@microsoft.com'). Defaults to 'Unknown' if not provided."
    },
    "location": {
      "type": "string",
      "description": "Work location (e.g., 'Redmond, WA'). Defaults to 'Unknown' if not provided."
    }
  }
}
```

## 8. Consistent Tool Definitions

Keep inputSchema identical in:
1. MCP server tool definitions
2. mcpPlugin.json tool definitions

Mismatches cause runtime errors.

## 9. CORS Configuration

Always configure CORS for the MCP endpoint. Use origin-checking instead of a wildcard — validate the `Origin` header against an allowlist and reflect it back.

**Required allowed origins**: `m365.cloud.microsoft` and `*.m365.cloud.microsoft`.

```typescript
// Origin checking — allow *.m365.cloud.microsoft and m365.cloud.microsoft
function isAllowedOrigin(origin: string | undefined): boolean {
  if (!origin) return false;
  try {
    const { hostname } = new URL(origin);
    return hostname === "m365.cloud.microsoft" || hostname.endsWith(".m365.cloud.microsoft");
  } catch {
    return false;
  }
}

// Preflight
if (req.method === "OPTIONS" && url.pathname === "/mcp") {
  const origin = req.headers.origin;
  if (isAllowedOrigin(origin)) {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": origin!,
      "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, mcp-session-id, Last-Event-ID, mcp-protocol-version",
      "Access-Control-Expose-Headers": "mcp-session-id, mcp-protocol-version",
    });
  }
}

// All MCP requests — reflect origin if allowed
const origin = req.headers.origin;
if (isAllowedOrigin(origin)) {
  res.setHeader("Access-Control-Allow-Origin", origin!);
  res.setHeader("Access-Control-Expose-Headers", "mcp-session-id, mcp-protocol-version");
}
```

## 10. Widget Security

See the **Security** section in [widget-patterns.md](widget-patterns.md) for the `escapeHtml` implementation and XSS prevention patterns. Key rule: always sanitize user-provided data before inserting into widget HTML.

## 11. DevTunnels

Use **random tunnels** for simplicity - no need to manage named tunnels.

```bash
devtunnel host -p 3001 --allow-anonymous
```

The setup script extracts the URL and updates `.env.local` automatically:
```
MCP_SERVER_URL=https://xxxxx-3001.usw2.devtunnels.ms
MCP_SERVER_DOMAIN=xxxxx-3001.usw2.devtunnels.ms
```

**Important**: Since the URL changes each time, redeploy the agent after starting the tunnel:
```bash
npx -p @microsoft/m365agentstoolkit-cli@latest atk provision --env local
```

## 12. Declarative Agent Capabilities

Only enable capabilities you need.

```json
{
  "capabilities": [
    { "name": "People" }
  ]
}
```

Available:
- `People` - Organizational data, manager/reports
- `GraphConnectors` - Custom Graph connectors
- `OneDriveAndSharePoint` - File access
- `WebSearch` - Web search

## 13. Error Handling in Widgets

Handle data loading failures gracefully.

```javascript
if (!rendered) {
  let attempts = 0;
  const poll = setInterval(() => {
    attempts++;
    const data = getWidgetData();
    if (data) {
      renderWidget(data);
      clearInterval(poll);
    } else if (attempts >= 50) {
      clearInterval(poll);
      showError("Unable to load data");
    }
  }, 100);
}
```

## 14. Tool Response Format

Always include both text content and structuredContent.

```typescript
return {
  content: [{ type: "text", text: "Human-readable summary" }],
  structuredContent: { /* data for widget */ },
  _meta: { "openai/outputTemplate": "ui://widget/name.html" }
};
```

The text content serves as fallback and accessibility.

## 15. Conversation Starters

Add relevant conversation starters to help users discover your agent's capabilities.

```json
{
  "capabilities": {
    "conversation_starters": [
      {
        "title": "Short button label",
        "text": "Full prompt that will be sent when clicked"
      }
    ]
  }
}
```

## 16. Widget-Resource-Tool Triplet

Every widget in a Copilot MCP server requires three coordinated parts:

| Part | What it does | Where it lives |
|------|-------------|----------------|
| **Widget HTML** | The rendered UI | `widgets/<name>.html` (simple) or `assets/<name>.js` + shell HTML (complex) |
| **MCP Resource** | Serves widget HTML to Copilot via `ui://widget/<name>.html` | `resources` array + `ReadResourceRequestSchema` handler |
| **MCP Tool** | Triggers widget rendering via `_meta.openai/outputTemplate` | `tools` array + `CallToolRequestSchema` handler |

If any part is missing:
- No Resource → Copilot can't fetch widget HTML, widget won't render
- No Tool → Widget exists but nothing triggers it
- No Widget HTML → Resource returns 404, tool invocation shows empty widget

**Simple vs Complex widgets:**
- Simple: Self-contained HTML with inline CSS/JS → `ReadResource` returns the full file
- Complex (React, etc.): Minimal HTML shell linking to JS/CSS assets served via `/assets/` route → `ReadResource` returns the shell, assets load from `MCP_SERVER_URL/assets/`

Always create all three parts together. When adding a new tool+widget, start from the resource pattern in [mcp-server-pattern.md](mcp-server-pattern.md).
