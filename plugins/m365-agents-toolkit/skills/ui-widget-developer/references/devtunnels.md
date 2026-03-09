# DevTunnels Setup for MCP Servers

## Table of Contents
- [Prerequisites](#prerequisites)
- [Environment Configuration](#environment-configuration)
  - [`.env.local` File Structure](#envlocal-file-structure)
- [Automated Setup Script (Random Tunnel)](#automated-setup-script-random-tunnel)
  - [`scripts/setup-devtunnel.sh`](#scriptssetup-devtunnelsh)
  - [`scripts/setup-devtunnel.ps1` (Windows)](#scriptssetup-devtunnelps1-windows)
- [package.json Scripts](#packagejson-scripts)
  - [Root package.json](#root-packagejson)
  - [mcp-server/package.json](#mcp-serverpackagejson)
- [MCP Server Environment Integration](#mcp-server-environment-integration)
  - [Load Environment Variables](#load-environment-variables)
  - [Use Environment for CSP](#use-environment-for-csp)
  - [Add dotenv Dependency](#add-dotenv-dependency)
- [Development Workflow](#development-workflow)
  - [Terminal 1: Start MCP Server](#terminal-1-start-mcp-server)
  - [Terminal 2: Start DevTunnel](#terminal-2-start-devtunnel)
  - [After Starting the Tunnel](#after-starting-the-tunnel)
- [Troubleshooting](#troubleshooting)

Automated setup for exposing localhost MCP servers via Azure DevTunnels using random tunnels.

## Prerequisites

- [Azure DevTunnels CLI](https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/get-started) installed
- Node.js installed
- MCP server running on localhost (default port: 3001)
- **First-time setup**: `devtunnel user login -g -d` (GitHub auth with device code). Azure AD device code auth (`devtunnel user login -d`) is blocked by tenant Conditional Access policy on managed devices — use GitHub auth as the default.

## Environment Configuration

### `.env.local` File Structure

Add these variables to `env/.env.local`:

```bash
# DevTunnel port
DEVTUNNEL_PORT=3001

# Auto-populated by devtunnel setup script (run npm run tunnel):
MCP_SERVER_URL=
MCP_SERVER_DOMAIN=
```

## Automated Setup Script (Random Tunnel)

Uses random tunnels for simplicity - no need to manage named tunnels.

### `scripts/setup-devtunnel.sh`

```bash
#!/bin/bash
set -e

ENV_FILE="env/.env.local"
PORT="${DEVTUNNEL_PORT:-3001}"

# Auto-login check: ensure devtunnel is authenticated
if ! devtunnel user show &>/dev/null; then
  echo "DevTunnel not logged in. Authenticating via GitHub..."
  devtunnel user login -g -d
fi

echo "Starting DevTunnel on port $PORT..."
echo ""

# Host a random tunnel and capture output
devtunnel host -p "$PORT" --allow-anonymous 2>&1 | while IFS= read -r line; do
  echo "$line"

  # Extract URL when it appears
  if [[ "$line" =~ (https://[a-zA-Z0-9.-]+\.devtunnels\.ms[^ ]*) ]]; then
    TUNNEL_URL="${BASH_REMATCH[1]}"
    TUNNEL_DOMAIN=$(echo "$TUNNEL_URL" | sed -E 's|https?://||' | sed 's|/.*||')

    echo ""
    echo "Updating $ENV_FILE..."

    # Update MCP_SERVER_URL
    if grep -q "^MCP_SERVER_URL=" "$ENV_FILE"; then
      sed -i "s|^MCP_SERVER_URL=.*|MCP_SERVER_URL=$TUNNEL_URL|" "$ENV_FILE"
    else
      echo "MCP_SERVER_URL=$TUNNEL_URL" >> "$ENV_FILE"
    fi

    # Update MCP_SERVER_DOMAIN
    if grep -q "^MCP_SERVER_DOMAIN=" "$ENV_FILE"; then
      sed -i "s|^MCP_SERVER_DOMAIN=.*|MCP_SERVER_DOMAIN=$TUNNEL_DOMAIN|" "$ENV_FILE"
    else
      echo "MCP_SERVER_DOMAIN=$TUNNEL_DOMAIN" >> "$ENV_FILE"
    fi

    echo ""
    echo "Environment configured:"
    echo "   MCP_SERVER_URL=$TUNNEL_URL"
    echo "   MCP_SERVER_DOMAIN=$TUNNEL_DOMAIN"
    echo ""
  fi
done
```

### `scripts/setup-devtunnel.ps1` (Windows)

```powershell
$envFile = "env\.env.local"
$port = if ($env:DEVTUNNEL_PORT) { $env:DEVTUNNEL_PORT } else { "3001" }

# Auto-login check: ensure devtunnel is authenticated
try {
    devtunnel user show 2>&1 | Out-Null
} catch {
    Write-Host "DevTunnel not logged in. Authenticating via GitHub..."
    devtunnel user login -g -d
}

Write-Host "Starting DevTunnel on port $port..."
Write-Host ""

# Start devtunnel and process output
devtunnel host -p $port --allow-anonymous 2>&1 | ForEach-Object {
    Write-Host $_

    # Extract URL when it appears
    if ($_ -match "(https://[a-zA-Z0-9.-]+\.devtunnels\.ms[^ ]*)") {
        $tunnelUrl = $Matches[1]
        $tunnelDomain = $tunnelUrl -replace "https?://", "" -replace "/.*", ""

        Write-Host ""
        Write-Host "Updating $envFile..."

        $content = Get-Content $envFile
        $content = $content -replace "^MCP_SERVER_URL=.*", "MCP_SERVER_URL=$tunnelUrl"
        $content = $content -replace "^MCP_SERVER_DOMAIN=.*", "MCP_SERVER_DOMAIN=$tunnelDomain"
        $content | Out-File -FilePath $envFile -Encoding UTF8

        Write-Host ""
        Write-Host "Environment configured:"
        Write-Host "   MCP_SERVER_URL=$tunnelUrl"
        Write-Host "   MCP_SERVER_DOMAIN=$tunnelDomain"
        Write-Host ""
    }
}
```

## package.json Scripts

### Root package.json

```json
{
  "scripts": {
    "tunnel": "bash scripts/setup-devtunnel.sh",
    "tunnel:win": "powershell scripts/setup-devtunnel.ps1",
    "dev:server": "cd mcp-server && npm run dev",
    "install:server": "cd mcp-server && npm install"
  }
}
```

### mcp-server/package.json

```json
{
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "tunnel": "bash ../scripts/setup-devtunnel.sh",
    "tunnel:win": "powershell ../scripts/setup-devtunnel.ps1"
  }
}
```

## MCP Server Environment Integration

### Load Environment Variables

```typescript
import { config } from "dotenv";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Load .env.local from project root
config({ path: path.resolve(__dirname, "../../env/.env.local") });

const port = Number(process.env.DEVTUNNEL_PORT ?? process.env.PORT ?? 3001);
const serverUrl = process.env.MCP_SERVER_URL ?? `http://localhost:${port}`;
const serverDomain = process.env.MCP_SERVER_DOMAIN ?? "localhost";

console.log(`Server URL: ${serverUrl}`);
console.log(`Server Domain: ${serverDomain}`);
```

### Use Environment for CSP

```typescript
// Resource metadata with dynamic CSP from environment
function resourceMeta() {
  const domain = process.env.MCP_SERVER_DOMAIN ?? "localhost";
  const url = process.env.MCP_SERVER_URL ?? `http://localhost:${port}`;

  return {
    "openai/widgetDomain": url,
    "openai/widgetCSP": {
      connect_domains: [url, `https://${domain}`],
      resource_domains: [url, `https://${domain}`],
    },
  };
}

// Tool metadata with dynamic widget URL
function toolMeta(widgetPath: string) {
  return {
    "openai/outputTemplate": `ui://widget/${widgetPath}`,
    "openai/widgetAccessible": true,
  };
}
```

### Add dotenv Dependency

```bash
npm install dotenv
```

## Development Workflow

### Terminal 1: Start MCP Server

```bash
cd mcp-server
npm install
npm run dev
```

### Terminal 2: Start DevTunnel

```bash
# From project root
npm run tunnel
# Or on Windows:
npm run tunnel:win
```

The script will:
1. Start a random devtunnel on the configured port
2. Extract the tunnel URL from the output
3. Update `env/.env.local` with `MCP_SERVER_URL` and `MCP_SERVER_DOMAIN`
4. Continue hosting the tunnel

### After Starting the Tunnel

Since the URL changes each time, redeploy the agent after starting the tunnel:

```bash
npx -p @microsoft/m365agentstoolkit-cli@latest atk provision --env local
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `devtunnel: command not found` | Install Azure DevTunnels CLI |
| URL not extracted | Check the devtunnel output for the URL manually |
| CSP errors in Copilot | Verify `MCP_SERVER_DOMAIN` matches tunnel domain |
| Server not accessible | Ensure MCP server is running before starting tunnel |
| Permission denied on script | Run `chmod +x scripts/setup-devtunnel.sh` |
| Agent not updated | Bump version in manifest.json and redeploy |
| `EADDRINUSE` port conflict | Previous server instance still running. Windows: `taskkill //PID <pid> //F`. Linux/Mac: `lsof -ti:<port> \| xargs kill -9` |
| DevTunnel login fails with CA policy error | Tenant Conditional Access blocks device code auth on managed devices. Use GitHub auth: `devtunnel user login -g -d` |
| Tunnel URL changed but agent uses old URL | Tunnel URLs are ephemeral. After each tunnel restart: update `MCP_SERVER_URL` in `.env.local`, bump `version` in manifest.json, redeploy with `atk provision` |
