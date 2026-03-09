# Workspace Detection & Gate Rules

This document contains detailed rules for workspace detection, gate scenarios, and error handling behavior.

---

## Gate Definitions

### Gate 1: Wrong Project Type — STOP

The workspace contains a non-agent project (Express, React, Django, plain Node.js, Python, Go, etc.) with NO `appPackage/` folder and NO `m365agents.yml`.

**Your entire response must be text-only. No edits, no commands, no files.**

**Example rejection:**
```
This workspace contains an Express.js application (I can see package.json with
express as a dependency, src/index.js, etc.) but it is NOT an M365 declarative
agent project — there is no `appPackage/` folder and no `m365agents.yml`.

I cannot create agent files inside an existing non-agent project. To create a
declarative agent:
1. Navigate to a separate, empty directory
2. Ask me to create a new agent from scratch
```

### Gate 2: No Manifest, User Wants to Edit/Deploy — STOP

No `appPackage/declarativeAgent.json` exists but user implies an existing agent ("add X to this agent", "deploy this", "update instructions").

**Your entire response must be text-only. No edits, no commands, no files.**

**Example rejection:**
```
This workspace does not appear to be an M365 declarative agent project —
I could not find `appPackage/declarativeAgent.json`.

To get started with a new agent, please:
1. Navigate to an empty directory
2. Ask me to create a new agent from scratch

I cannot add capabilities or plugins to a project that doesn't have an agent manifest.
```

### Gate 3: No Manifest, User Wants New Project — Scaffold

User explicitly says "create a new agent", "scaffold", "start from scratch". The workspace should be empty — if it has a different project, go to Gate 1 instead.

→ Proceed to [Scaffolding Workflow](scaffolding-workflow.md)

### Gate 4: Manifest Exists with Errors — Fix First

`declarativeAgent.json` exists but has validation errors.

**Rules:**
- Run `atk validate --env local` to get the full error report
- Report ALL errors to the user with specific details
- ASK the user before making changes
- **Do NOT** run `atk provision` — fix errors first, no exceptions
- **Do NOT** silently rewrite the entire file — surgical fixes only
- **Do NOT** invent placeholder values for missing required fields

**Special case — mostly empty manifest** (has `$schema` and `version` but no `name`, `description`, or `instructions`): This is Gate 4. Run `atk validate --env local`, report missing fields, ASK the user. Do NOT invent values.

**Malformed JSON handling:**
1. TELL the user the file has malformed JSON
2. IDENTIFY the specific syntax issues (missing commas, unclosed brackets, etc.)
3. ASK the user if you should fix the syntax
4. Fix with surgical edits (not a rewrite — if you're changing >20% of lines, stop and reconsider)
5. Re-validate with `atk validate --env local` after fixing

### Gate 5: Valid Agent Project — Edit

→ Proceed to [Editing Workflow](editing-workflow.md)

---

## STOP Scenarios Quick Reference

| Scenario | What you see | What you MUST do | What you MUST NOT do |
|----------|-------------|-----------------|---------------------|
| Express/React/Node app | `package.json` + `src/index.js` but NO `appPackage/` | Text-only: tell user this is NOT an agent project | ❌ Create `appPackage/` ❌ Run `atk new` ❌ Create ANY files |
| No manifest, edit request | No `declarativeAgent.json`, user says "add capability" | Text-only: explain manifest is missing | ❌ Create files ❌ Scaffold ❌ "Help" by creating missing files |
| Manifest missing fields | `declarativeAgent.json` missing `name`/`description`/`instructions` | Run `atk validate --env local`, list ALL missing fields, ASK user | ❌ Invent placeholders ❌ Auto-fill ❌ Run `atk provision` |
| Manifest has errors | `atk validate --env local` reports errors | Report ALL errors, suggest fixes, ask user | ❌ Silently fix ❌ Deploy ❌ Auto-correct |

---

## Anti-Patterns (Gate 4)

These will cause eval failure:
- ❌ Scaffolding a new project to "fix" an incomplete manifest
- ❌ Inventing placeholder values (generic names, boilerplate instructions)
- ❌ Running `atk provision` "to see what happens"
- ❌ Auto-completing missing fields without asking
- ❌ Running `atk provision` when validation found errors — not even "to test"
- ❌ Deploying "for educational purposes" to show error output
- ❌ Using any manual JSON parsing instead of `atk validate --env local`

**"EVEN IF..." — No exceptions to the deploy block:**
- EVEN IF deploying would "demonstrate the error" — just report errors
- EVEN IF the user says "deploy this" — validation errors override. Explain why.
- EVEN IF the user says "validate and deploy" — deploy ONLY IF validation passes
- EVEN IF you fixed errors yourself — re-validate FIRST, deploy only if clean
