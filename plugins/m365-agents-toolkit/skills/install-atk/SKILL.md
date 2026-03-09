---
name: install-atk
description: >
  Install or update the M365 Agents Toolkit (ATK) CLI and VS Code extension.
  Triggers: "install atk", "update atk", "install agents toolkit", "update agents toolkit",
  "install the toolkit", "setup atk", "get atk", "install atk cli", "install atk extension",
  "install atk vsix", "update the vs code extension", "install latest atk", "upgrade atk"
---

# Install ATK

Install or update the M365 Agents Toolkit (ATK) CLI and/or VS Code extension.

## Triggers

This skill activates when the user asks to:
- Install or update ATK / Agents Toolkit / the toolkit
- Install or update the ATK CLI
- Install or update the ATK VS Code extension / VSIX
- Set up ATK / get started with ATK

## Behavior

**IMPORTANT: Always check if ATK is already installed before running `npm install`.** Running `npm install -g` concurrently from multiple agents/evals will cause corruption. Only install when ATK is missing or the user explicitly asks to update.

When triggered, determine what the user wants:

| User intent | Action |
|-------------|--------|
| Install/update **everything** or just "ATK" | Check + install both CLI and VSIX |
| Install/update **CLI** only | Check + install CLI only |
| Install/update **extension** / **VSIX** only | Install VSIX only |
| Ambiguous | Check + install both CLI and VSIX |

## Commands

### Step 1: Check if ATK CLI is already installed

```bash
atk --version 2>/dev/null
```

- **If this succeeds** (prints a version): ATK is already installed. **Skip the npm install step** unless the user explicitly asked to update/upgrade.
- **If this fails** (command not found): Proceed to install.

### Step 2: Install ATK CLI (only if missing or user asked to update)

```bash
npm install -g @microsoft/m365agentstoolkit-cli@rc
```

### Step 3: ATK VS Code Extension (if requested)

```bash
code --install-extension TeamsDevApp.ms-teams-vscode-extension
```

## Execution

1. **Check** if ATK CLI is already available with `atk --version`
2. **Skip install** if already present (unless user explicitly wants an update)
3. Run the appropriate install command(s) only if needed
4. Report the result (already installed / newly installed / failure)
5. Verify with `atk --version`

## Safety Rules

- **MUST** run the CLI install before the VSIX install when installing both
- **MUST NOT** skip errors — report failures clearly to the user
- **MUST** use the exact package names and extension IDs above — do not substitute with other names or links
