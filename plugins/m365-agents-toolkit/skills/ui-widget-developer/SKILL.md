---
name: ui-widget-developer
description: |
  Build MCP (Model Context Protocol) servers for Copilot Chat using the OpenAI Apps SDK or MCP Apps SDK widget rendering support (any language). Use this skill when:
  - Creating MCP servers that integrate with M365 Copilot declarative agents
  - Building rich interactive widgets (HTML) that render in Copilot Chat
  - Implementing tools that return structuredContent for widget rendering
  - Adapting an existing MCP server to support Copilot widget rendering
  - Setting up devtunnels for localhost MCP server exposure
  - Configuring mcpPlugin.json manifests with RemoteMCPServer runtime
  Do NOT use this skill for general agent development (scaffolding, manifests, deployment) — use m365-agent-developer instead. This skill is ONLY for MCP server + widget development.
  Triggers: "MCP server for Copilot", "OpenAI Apps SDK", "Copilot widget", "structuredContent", "MCP plugin", "devtunnels MCP", "bizchat MCP", "OAI app", "widget rendering", "text/html+skybridge", "UI widget"
---

# Copilot MCP Server Development

## 📛 PROJECT DETECTION 📛

This skill triggers when building MCP servers with OAI app or widget rendering for Microsoft 365 Copilot Chat. The MCP server can be written in any language that supports the MCP protocol (TypeScript, Python, C#, etc.). The agent project and MCP server may live in the same repo, separate folders, or entirely different projects.

## Scenario Routing

| Starting Point | What You Need | Path |
|---------------|---------------|------|
| **From scratch** (no agent, no MCP server) | Full setup | Delegate agent scaffolding to `m365-agent-developer` first, then return here for MCP server + widgets |
| **Existing M365 agent, new MCP server** | MCP server + widgets + mcpPlugin.json | Start at [Implementation](#implementation) |
| **Existing MCP server, add Copilot widgets** | Widget support added to existing server | Start at [Copilot Widget Protocol](references/copilot-widget-protocol.md#adaptation-checklist-existing-mcp-server) |
| **Language choice** (non-TypeScript) | Protocol requirements | See [Copilot Widget Protocol](references/copilot-widget-protocol.md) for what to implement, [MCP Server Pattern (TypeScript)](references/mcp-server-pattern.md) as a reference |

---

## 🚨 CRITICAL EXECUTION RULES 🚨

**BACKGROUND PROCESSES:** MCP server start commands (e.g., `npm run dev`, `python server.py`, `dotnet run`) and devtunnel hosting commands MUST ALWAYS be run in the background using `isBackground: true`. These are long-running processes that never terminate. Running them in foreground will block the agent.

**AGENT PROVISIONING:** Re-provisioning is only required when the **agent manifest** changes (e.g., mcpPlugin.json tool definitions, MCP server URL, declarativeAgent.json, instruction.txt). MCP server code changes (tool implementations, widget HTML, server logic) do **NOT** require re-provisioning the agent — running or deploying the server picks up changes automatically.

When provisioning is needed:
1. **Bump the version** in `manifest.json` (increment the patch version, e.g., `1.0.0` → `1.0.1`)
2. **Deploy the agent:**
   ```bash
   npx -p @microsoft/m365agentstoolkit-cli@latest atk provision --env local
   ```

**WIDGET TESTING LINKS:** Every time you return to the user with a result while the MCP server is running, you MUST include links to ALL widgets so they can test them locally. Format:
```
🧪 Test widgets locally:
- http://localhost:3001/widgets/widget-name.html
- http://localhost:3001/widgets/another-widget.html
```
List every `.html` file in the `mcp-server/widgets/` directory (or equivalent widget folder). This helps users verify widget rendering before testing in Copilot.

**AGENT PROJECT DELEGATION:** This skill builds MCP servers and widgets, NOT declarative agent projects. If the user's request involves creating or configuring the declarative agent itself (scaffolding, `m365agents.yml`, `m365agents.local.yml`, `declarativeAgent.json`, manifest lifecycle), delegate to the `m365-agent-developer` skill.

**MCP RESOURCE REGISTRATION:** Every widget MUST have a matching MCP resource. Without resources, Copilot cannot fetch widget HTML through the MCP protocol and widgets will not render.

For each new widget, complete this checklist:
1. ☐ Create widget HTML file in `widgets/` directory (see widget-patterns.md)
2. ☐ Define a `ui://widget/<name>.html` URI constant
3. ☐ Add a `Resource` entry to the `resources` array with:
   - `uri`: the `ui://widget/<name>.html` URI
   - `mimeType`: `"text/html+skybridge"`
   - `_meta`: CSP config with `openai/widgetDomain` and `openai/widgetCSP` (from environment)
4. ☐ Add a handler for `resources/read` that returns the widget HTML for this URI
5. ☐ Add the tool with `_meta.openai/outputTemplate` pointing to the same `ui://widget/<name>.html` URI
6. ☐ Verify the server capabilities include `resources: {}` in the initialize response

**Widget HTML size considerations:**
- **Simple widgets**: The `resources/read` handler can return the full self-contained HTML (inline CSS/JS)
- **Complex widgets** (React, large UIs): The resource HTML should be a minimal shell that links to JS/CSS assets served from the MCP server's `/assets/` route:
  ```html
  <!doctype html><html><head>
    <script type="module" src="${serverUrl}/assets/my-widget.js"></script>
    <link rel="stylesheet" href="${serverUrl}/assets/my-widget.css">
  </head><body>
    <div id="widget-root"></div>
  </body></html>
  ```
  Use the `WIDGET_BASE_URL` or `MCP_SERVER_URL` environment variable for the asset URL base (see mcp-server-pattern.md "Configurable Widget Base URL" section).

See [mcp-server-pattern.md](references/mcp-server-pattern.md) for the complete resource and asset serving patterns.

---

## ⚠️ MCP TOOL CONFIGURATION RULE ⚠️

**NEVER manually write tool definitions in `mcpPlugin.json`.** Always use MCP Inspector to get the complete tool definitions from the running MCP server.

**TOOL NAMING CONVENTION:** Tool names MUST match the pattern `^[A-Za-z0-9_]+$` (letters, numbers, and underscores only). **NEVER use hyphens (-) in tool names.** Use underscores instead (e.g., `render_profile` not `render-profile`).

**MANDATORY WORKFLOW:**
1. **Start the MCP server** (in background)
2. **Use MCP Inspector** to get the latest tool definitions:
   ```bash
   npx @modelcontextprotocol/inspector --cli https://my-mcp-server.example.com --transport http --method tools/list
   ```
3. **Copy the COMPLETE tool definition** from the inspector (including `name`, `description`, `inputSchema`, `_meta`, `annotations`, `title`)
4. **Paste into `mcpPlugin.json`** under `runtimes[].spec.mcp_tool_description.tools` (inside the `RemoteMCPServer` runtime's `spec` object)

The MCP Inspector shows the exact tool schema from your server. Copy it completely - do not manually write or modify these definitions. This ensures `mcpPlugin.json` stays in sync with the MCP server.

---

Build MCP servers that integrate with Microsoft 365 Copilot Chat and render rich interactive widgets.

## Architecture

```
M365 Copilot ──▶ mcpPlugin.json ──▶ MCP Server ──▶ structuredContent ──▶ HTML Widget
     │              (RemoteMCPServer)    (Streamable HTTP)                  (window.openai.toolOutput)
     │
     └── Capabilities (People, etc.) provide data to pass to MCP tools
```

## Project Structure

Example project structure, not a hard requirement but a common pattern for organizing MCP server + widget development:

```
project/
├── appPackage/
│   ├── manifest.json           # Teams manifest (bump version on deploy)
│   ├── declarativeAgent.json   # Agent config + capabilities
│   ├── mcpPlugin.json          # Tool definitions with _meta
│   └── instruction.txt         # Agent behavior instructions
├── mcp-server/
│   ├── src/index.ts            # Server with Streamable HTTP
│   ├── widgets/*.html          # OpenAI Apps SDK widgets
│   └── package.json
├── scripts/
│   ├── setup-devtunnel.sh      # Linux/Mac devtunnel setup
│   └── setup-devtunnel.ps1     # Windows devtunnel setup
└── env/.env.local              # MCP_SERVER_URL, MCP_SERVER_DOMAIN
```

**Language note**: This shows a TypeScript project layout. For Python, replace `mcp-server/src/index.ts` with your Python entry point (e.g., `server.py`). For C#, use a standard .NET project structure. The `appPackage/`, `widgets/`, `scripts/`, and `env/` directories are language-agnostic.

## Copilot Widget Protocol

Your MCP server must implement these protocol requirements to render widgets in Copilot Chat. This applies regardless of language:

1. **Streamable HTTP transport** — `/mcp` endpoint handling POST, GET, DELETE with session management
2. **CORS headers** — Origin-checking on `/mcp` allowing `m365.cloud.microsoft` and `*.m365.cloud.microsoft`, with required MCP headers
3. **Server capabilities** — `initialize` response must declare `resources: {}` and `tools: {}`
4. **MCP resources** — Register widgets with `ui://widget/<name>.html` URIs, `text/html+skybridge` mime type, and CSP `_meta`
5. **Tool response format** — Return `content` (text) + `structuredContent` (widget data) + `_meta` with `openai/outputTemplate`
6. **Widget serving** — HTTP route at `/widgets/*.html` with origin-checking CORS

For full protocol details, JSON shapes, and an adaptation checklist for existing MCP servers, see [references/copilot-widget-protocol.md](references/copilot-widget-protocol.md).

## Implementation

### MCP Server Pattern (TypeScript Reference)

See [references/mcp-server-pattern.md](references/mcp-server-pattern.md) for complete implementation.

> For other languages, implement the requirements described in [Copilot Widget Protocol](references/copilot-widget-protocol.md) using your language's MCP SDK. See the [Language SDK References](references/copilot-widget-protocol.md#language-sdk-references) table for SDK packages.

Core requirements:
- Expose Streamable HTTP transport on `/mcp`
- Return `structuredContent` + `_meta` with `openai/outputTemplate`
- Serve widgets via HTTP endpoint
- Handle CORS for cross-origin requests
- Handle partial data gracefully (fill in "Unknown" for missing fields)

Tool response format:
```typescript
return {
  content: [{ type: "text", text: "Summary" }],
  structuredContent: { /* widget data */ },
  _meta: { "openai/outputTemplate": "ui://widget/name.html", "openai/widgetAccessible": true }
};
```

### Handling Partial Data

Always normalize input data to handle missing fields:

```typescript
server.setRequestHandler(CallToolRequestSchema, async (request: CallToolRequest) => {
  const args = request.params.arguments as { title?: string; items?: Partial<Item>[] };

  // Normalize data - fill in "Unknown" for missing fields
  const title = args.title || "Default Title";
  const items = (args.items || []).map(item => ({
    name: item.name || "Unknown",
    value: item.value || "Unknown",
  }));

  // Build structuredContent for widget
  const structuredContent = { title, items };
  // ...
});
```

### Widget Pattern

See [references/widget-patterns.md](references/widget-patterns.md) for complete examples.

Core requirements:
- Access data: `window.openai.toolOutput` (primary source)
- Theme support: `window.openai.theme` or `prefers-color-scheme`
- Debug fallback: Embedded mock data when `window.openai` unavailable
- CSS variables for theming at `:root` level
- Handle "Unknown" values gracefully (e.g., hide action buttons)

### Plugin Schema

See [references/plugin-schema.md](references/plugin-schema.md) for mcpPlugin.json format.

Core requirements:
- Schema `v2.4` with `RemoteMCPServer` runtime
- `run_for_functions` array matching tool names
- `_meta` in tool definitions for widget binding
- `inputSchema` - make properties optional for flexibility, describe defaults in descriptions

## DevTunnels Setup

> **Local testing only.** DevTunnels are for development and testing on your machine. Before sharing the agent more broadly, deploy both the MCP server and widget assets to a hosted environment (e.g., Azure App Service, Azure Static Web Apps, or another hosting provider) and update the agent manifest URLs accordingly.

See [references/devtunnels.md](references/devtunnels.md) for automated setup scripts.

DevTunnels expose your localhost MCP server to M365 Copilot using **random tunnels** for simplicity:

```bash
devtunnel host -p 3001 --allow-anonymous
```

The setup script:
1. Starts a random devtunnel on the configured port
2. Extracts the tunnel URL from the output
3. **Automatically updates `env/.env.local`** with `MCP_SERVER_URL` and `MCP_SERVER_DOMAIN`
4. Continues hosting the tunnel

### Quick Start

**Terminal 1 - Start MCP Server:**
```bash
cd mcp-server
npm install
npm run dev
```

**Terminal 2 - Start DevTunnel:**
```bash
npm run tunnel
# Or on Windows:
npm run tunnel:win
```

**After tunnel starts, redeploy the agent** (URL changes each time):
```bash
npx -p @microsoft/m365agentstoolkit-cli@latest atk provision --env local
```

## Development Workflow

1. **Start the MCP server** (dev mode with hot reload):
   - TypeScript: `cd mcp-server && npm install && npm run dev`
   - Python: `cd mcp-server && pip install -r requirements.txt && python server.py`
   - C#: `cd mcp-server && dotnet run`

2. **Start the devtunnel** (auto-configures `.env.local`):
   ```bash
   npm run tunnel
   ```

3. **Deploy the agent** (required after each tunnel restart):
   ```bash
   npx -p @microsoft/m365agentstoolkit-cli@latest atk provision --env local
   ```

4. **Test in Copilot Chat** - Bump `version` in manifest.json if changes aren't reflected

## Best Practices

See [references/best-practices.md](references/best-practices.md) for detailed guidance.

Key points:
1. **Rendering tools**: Accept data as input, don't fetch internally
2. **Instructions**: Tell agent to use capabilities FIRST, then pass data to MCP tools
3. **Themes**: Always support dark/light via CSS variables
4. **Debug mode**: Include fallback data for local widget testing
5. **Partial data**: Handle missing fields with "Unknown" defaults
6. **Action buttons**: Hide email/chat buttons when data is "Unknown"
7. **Version bumping**: Bump manifest version when changes aren't reflected in Copilot
