---
name: workiq
description: Query Microsoft 365 Copilot for workplace intelligence — search emails, meetings, documents, Teams messages, and people expertise using natural language.
---

# Work IQ

Query your Microsoft 365 data with natural language using the `ask_work_iq` MCP tool.

## When to Use

Use this skill when the user asks about:

- **Emails** — "What did John say about the proposal?"
- **Meetings** — "What's on my calendar tomorrow?"
- **Documents** — "Find my recent PowerPoint presentations"
- **Teams messages** — "Summarize today's messages in the Engineering channel"
- **People** — "Who is working on Project Alpha?"

## MCP Tool

### `ask_work_iq`

Ask a question to Microsoft 365 Copilot for information about emails, meetings, files, and other M365 data.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `question` | string | Yes | The question to ask |
| `fileUrls` | string[] | No | Optional list of OneDrive or SharePoint file URLs to use as context |

**Example:**

```json
{
  "question": "What meetings do I have this week about the budget?",
  "fileUrls": []
}
```

## Prerequisites

- Access to a Microsoft 365 tenant
- Admin consent for the WorkIQ application (see [User and Admin Consent Overview](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/user-admin-consent-overview))
- EULA acceptance (`workiq accept-eula`)
