# Localization Workflow

This document provides step-by-step instructions for localizing an M365 Copilot declarative agent into multiple languages.

Localization spans two layers: the **app manifest** (`manifest.json`) and the **declarative agent manifest** (`declarativeAgent.json`). Both use the same set of language files, but reference strings differently.

> **Important:** If an agent supports more than one language, you must provide a separate language file for **every** supported language, including the default language. Single-language agents do not require language files.

---

## How Localization Works

| Layer | Key style | Example |
|-------|-----------|---------|
| App manifest (`manifest.json`) | JSONPath expressions | `name.short`, `description.full` |
| Agent / plugin manifests | Double-bracket tokens resolved via `localizationKeys` | `[[agent_name]]`, `[[plugin_description]]` |

Both types of localized strings live in the **same** language file per locale.

---

## Prerequisites

- Project must be scaffolded and contain `appPackage/declarativeAgent.json`
- The agent should already have user-facing strings (name, description, starters, etc.) that need translation
- Decide on the set of languages to support before starting (you need at least two to benefit from localization)

---

## Step 1: Tokenize Agent Manifests

Replace user-facing strings in `declarativeAgent.json` (and `plugin.json`, if applicable) with tokenized keys wrapped in double brackets (`[[key_name]]`).

**Token key rules:**
- Must match the pattern: `^[a-zA-Z_][a-zA-Z0-9_]*$`
- Use descriptive, snake_case names (e.g., `starter_vpn_title` not `key1`)
- Keep names consistent across agent and plugin manifests

### Declarative Agent Manifest

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/declarative-agent/v1.6/schema.json",
  "version": "v1.6",
  "name": "[[agent_name]]",
  "description": "[[agent_description]]",
  "instructions": "$[file]('instructions.txt')",
  "conversation_starters": [
    {
      "title": "[[starter_vpn_title]]",
      "text": "[[starter_vpn_text]]"
    },
    {
      "title": "[[starter_password_title]]",
      "text": "[[starter_password_text]]"
    }
  ],
  "disclaimer": {
    "text": "[[disclaimer_text]]"
  }
}
```

### API Plugin Manifest (if applicable)

Tokenize user-facing strings in `plugin.json` the same way:

```json
{
  "schema_version": "v2.4",
  "name_for_human": "[[plugin_name]]",
  "description_for_human": "[[plugin_description]]",
  "description_for_model": "[[plugin_model_description]]"
}
```

> **Note:** The `instructions` property is **not** localizable. Use an external `instructions.txt` file referenced via `$[file]('instructions.txt')` to keep instructions separate. Instructions are consumed by the LLM directly and should be written in a single language (typically English).

### Localizable Fields Reference

**Declarative agent manifest:**

| Field | Description | Max length | Required |
|---|---|---|---|
| `name` | Display name of the agent | 100 chars | ✔️ |
| `description` | Description shown to users | 1,000 chars | ✔️ |
| `conversation_starters[].title` | Short title for a conversation starter | — | |
| `conversation_starters[].text` | Full prompt text for a conversation starter | — | |
| `disclaimer.text` | Disclaimer shown at conversation start | — | |

**API plugin manifest:**

| Field | Description | Max length | Required |
|---|---|---|---|
| `name_for_human` | Short, human-readable plugin name | 20 chars | ✔️ |
| `description_for_human` | Human-readable description | 100 chars | ✔️ |
| `description_for_model` | Description provided to the model | 2,048 chars | |
| `conversation_starters[].title` | Title for plugin conversation starters | — | |
| `conversation_starters[].text` | Text for plugin conversation starters | — | |

---

## Step 2: Add `localizationInfo` to the App Manifest

Add the `localizationInfo` section to `manifest.json`. Specify the default language tag, a default language file, and an entry for each additional language.

```json
{
  "localizationInfo": {
    "defaultLanguageTag": "en",
    "defaultLanguageFile": "en.json",
    "additionalLanguages": [
      {
        "languageTag": "fr",
        "file": "fr.json"
      },
      {
        "languageTag": "es",
        "file": "es.json"
      }
    ]
  }
}
```

**Rules:**
- The manifest schema version must be the same for both `manifest.json` and the localization files
- Language files live in the `appPackage/` directory alongside the manifests
- Use language-only tags (e.g., `en` rather than `en-us`) for top-level translations; add region-specific overrides only when needed

---

## Step 3: Create Language Files

Create one JSON file per language in `appPackage/`, using the file names referenced in `localizationInfo`. Each file contains:

1. **App manifest strings** — using JSONPath keys (e.g., `name.short`, `description.full`)
2. **Agent and plugin strings** — under a `localizationKeys` object, using the token names (without brackets)

### Default Language File (`en.json`)

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/teams/vDevPreview/MicrosoftTeams.Localization.schema.json",
  "name.short": "IT Help Desk",
  "name.full": "IT Help Desk Agent",
  "description.short": "Resolve common IT issues",
  "description.full": "Helps employees resolve common IT issues using internal knowledge bases and ticketing systems.",
  "localizationKeys": {
    "agent_name": "IT Help Desk Agent",
    "agent_description": "Helps employees resolve common IT issues using internal knowledge bases and ticketing systems.",
    "starter_vpn_title": "VPN issues",
    "starter_vpn_text": "I can't connect to the corporate VPN. What should I try?",
    "starter_password_title": "Password reset",
    "starter_password_text": "How do I reset my password?",
    "disclaimer_text": "This agent provides general IT guidance. For urgent issues, contact the helpdesk directly.",
    "plugin_name": "IT Tickets",
    "plugin_description": "Create and manage IT support tickets.",
    "plugin_model_description": "Use this plugin to create, update, and query IT support tickets in the ticketing system."
  }
}
```

### Additional Language File (`fr.json`)

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/teams/vDevPreview/MicrosoftTeams.Localization.schema.json",
  "name.short": "Support informatique",
  "name.full": "Agent de support informatique",
  "description.short": "Résoudre les problèmes informatiques courants",
  "description.full": "Aide les employés à résoudre les problèmes informatiques courants à l'aide des bases de connaissances internes.",
  "localizationKeys": {
    "agent_name": "Agent de support informatique",
    "agent_description": "Aide les employés à résoudre les problèmes informatiques courants à l'aide des bases de connaissances internes.",
    "starter_vpn_title": "Problèmes de VPN",
    "starter_vpn_text": "Je n'arrive pas à me connecter au VPN de l'entreprise. Que dois-je essayer ?",
    "starter_password_title": "Réinitialisation du mot de passe",
    "starter_password_text": "Comment réinitialiser mon mot de passe ?",
    "disclaimer_text": "Cet agent fournit des conseils informatiques généraux. Pour les problèmes urgents, contactez le service d'assistance directement.",
    "plugin_name": "Tickets informatiques",
    "plugin_description": "Créer et gérer les tickets de support informatique.",
    "plugin_model_description": "Utilisez ce plugin pour créer, mettre à jour et interroger les tickets de support informatique."
  }
}
```

### Required App Manifest Keys

Every language file **must** include these four JSONPath keys:

| Key | Description | Max length | Required |
|---|---|---|---|
| `name.short` | Short app name | 30 chars | ✔️ |
| `name.full` | Full app name | 100 chars | ✔️ |
| `description.short` | Short app description | 80 chars | ✔️ |
| `description.full` | Full app description | 4,000 chars | ✔️ |

---

## Language Resolution Order

The Microsoft 365 host resolves strings in the following order:

1. Start with the **default language** strings
2. Overwrite with the user's **language-only** file (e.g., `en`)
3. Overwrite with the user's **language + region** file (e.g., `en-gb`), if available

For example, if the default language is `fr`, and you provide `en` and `en-gb` files, a user with locale `en-gb` sees: `fr` → overwritten by `en` → overwritten by `en-gb`.

> **Tip:** Provide top-level, language-only translations (e.g., `en` rather than `en-us`). Add region-specific overrides only for the few strings that need them.

---

## Project Structure

A localized app package includes the language files alongside the manifests:

```text
my-agent/
├── appPackage/
│   ├── manifest.json
│   ├── declarativeAgent.json
│   ├── plugin.json              # optional
│   ├── en.json                  # default language file
│   ├── fr.json                  # French language file
│   ├── es.json                  # Spanish language file
│   ├── color.png
│   └── outline.png
├── env/
│   └── .env.dev
└── m365agents.yml
```

---

## Critical Rules

### 1. Every Token Must Have a Matching Key

Every `[[token]]` in `declarativeAgent.json` or `plugin.json` must have a corresponding entry in the `localizationKeys` object of **every** language file. Missing keys cause runtime resolution failures.

### 2. Keep Token Names Descriptive

Use descriptive key names that indicate the content (e.g., `starter_vpn_title` rather than `key1`). This makes localization files easier to maintain.

### 3. Do NOT Localize Instructions

The `instructions` property is consumed by the LLM directly and is not part of the localization system. Keep instructions in a single language (typically English) via `instructions.txt`.

### 4. Schema Version Consistency

The `$schema` version in language files must match the manifest schema version in `manifest.json`.

### 5. Always Deploy After Adding Localization

After making any localization changes (tokenizing manifests, adding `localizationInfo`, or creating/updating language files), deploy the agent as usual:

```bash
npx -y --package @microsoft/m365agentstoolkit-cli atk provision --env local --interactive false
```

### 6. Do NOT Invent Translations

When adding a new language, **ask the user** for the translated strings. Do NOT machine-translate or invent content. If the user provides translations, use them exactly. If they ask you to translate, confirm the translations before writing them.

---

## Error Handling

| Error | Action |
|-------|--------|
| Token in manifest has no matching `localizationKeys` entry | **Stop.** List the missing keys and the language files that need them. Ask the user to provide the translations. |
| Language file referenced in `localizationInfo` doesn't exist | **Stop.** List the missing files. Ask the user to provide them or remove the language from `additionalLanguages`. |
| `localizationInfo.defaultLanguageFile` is missing | **Stop.** Inform the user that a default language file is required when `localizationInfo` is present. |
| Agent has only one language | Inform the user that language files are not required for single-language agents. Ask if they want to add more languages. |

---

## Learn More

- [Localize your agent](https://learn.microsoft.com/en-us/microsoft-365-copilot/extensibility/localize-agents) — Official Microsoft localization guide for agents
- [Localize your app (Microsoft Teams)](https://learn.microsoft.com/en-us/microsoftteams/platform/concepts/build-and-test/apps-localization) — General Teams app localization reference
- [Localization schema reference](https://learn.microsoft.com/en-us/microsoftteams/platform/resources/schema/localization-schema) — JSON schema for localization files
