---
name: org-chart
description: Display a beautifully formatted ASCII org chart for any person in the organization — showing their manager, peers, and direct reports in a visual tree.
---

# Org Chart

Render a visual ASCII org chart for any person in the organization. Shows the target person in context — their manager above, their peers alongside, and their direct reports below — in a clear tree layout that fits the terminal.

## When to Use

- "Show me the org chart for Sarah"
- "Draw the org tree for the Platform team lead"
- "What does Nadia's org look like?"
- "Show my org chart"
- "Visualize the reporting structure under Alex"

## Instructions

### Step 1: Identify the Current User

```
workiq-ask_work_iq (
  question: "What is my profile information including display name, email, job title, and department?"
)
```

Extract **displayName**, **email**, and **jobTitle**.

### Step 2: Resolve the Target Person

If the user says "my org chart" or "me", the target is the current user from Step 1.

Otherwise, look up the named person:

```
workiq-ask_work_iq (
  question: "Look up the person named <name or email> in the company directory. Return their display name, email, job title, department, and office location."
)
```

If the response indicates multiple matches, present the options and ask the user to pick.

### Step 3: Fetch Org Data

**3a. Get the target's manager and direct reports:**

```
workiq-ask_work_iq (
  question: "Who is <target name>'s manager? Include their display name, email, job title, and department."
)
```

```
workiq-ask_work_iq (
  question: "Who are <target name>'s direct reports? For each person include their display name, email, job title, and department."
)
```

**3b. Walk the full management chain to the root:**

After getting the target's manager, **recursively** ask about each manager's manager until you reach the top of the org:

```
workiq-ask_work_iq (
  question: "Who is <current manager name>'s manager? Include their display name, email, job title, and department."
)
```

Continue until `ask_work_iq` indicates there is no manager (meaning you've reached the **org root**).

Store the entire chain as an ordered list: `[target, manager, manager's manager, …, org root]`.

**Important performance note:** Each iteration depends on the previous result, so these calls must be sequential. However, the first manager call (3a) and the direct reports call can run in parallel.

**Alternative — full chain in one call:** You can attempt to retrieve the entire chain at once:

```
workiq-ask_work_iq (
  question: "What is the full management chain for <target name> all the way up to the CEO? List each person in order from their direct manager to the top, including name, title, and email for each."
)
```

If the response is complete, skip the recursive loop. If it is truncated or incomplete, fall back to the step-by-step approach above.

### Step 4: Clean Up Direct Reports

Filter out non‑primary accounts from the direct reports list:
- Remove entries whose displayName contains "(NON EA SC ALT)", "(SC ALT)", or similar service/alternate account markers.
- Only show real people in the org chart.

### Step 5: Classify Roles for Layout

Categorize each direct report by role type for grouping:

| Pattern in jobTitle | Category | Icon |
|---|---|---|
| Contains "Manager" or "Lead" | 👔 Manager | Shown with count of their reports if known |
| Contains "Principal" or "Senior" or "Staff" | 🔧 Senior IC | |
| Everything else | 💻 IC | |

### Step 6: Render the Org Chart

#### Layout Rules

1. **The target person is always the visual center** — highlighted with a ⭐ marker.
2. **The full management chain appears above** the target, from the org root at the top down to the direct manager, each connected by vertical lines. Use a compact single‑line‑per‑ancestor format for the chain above the direct manager to avoid excessive height.
3. **The direct manager** appears in a full box immediately above the target.
4. **Direct reports appear below** the target, connected by branch lines.
5. **Group direct reports**: managers first, then senior ICs, then ICs — separated by a thin visual gap.
6. **Truncate long names** to fit terminal width. Abbreviate job titles if needed (e.g., "Principal Software Engineer" → "Prin SWE", "Software Engineering Manager" → "SW Eng Mgr").

#### Title Abbreviation Map

Use these abbreviations to keep boxes compact:

| Full Title | Short |
|---|---|
| Principal Software Engineer | Prin SWE |
| Senior Software Engineer | Sr SWE |
| Software Engineer | SWE |
| Software Engineering Manager | SW Eng Mgr |
| Principal Software Engineering Manager | Prin SW Eng Mgr |
| Partner Group Software Engineering Manager | Partner Grp SW Eng Mgr |
| Vice President of Engineering | VP Eng |
| Group Engineering Manager | Grp Eng Mgr |
| Program Manager | PM |
| Senior Program Manager | Sr PM |
| Principal Program Manager | Prin PM |

For titles not in this list, abbreviate by removing common words ("of", "the") and shortening ("Software" → "SW", "Engineering" → "Eng", "Manager" → "Mgr").

## Output Format

### Standard Org Chart (full chain + target + reports)

```
🏛️ ORG CHART
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                👤 Dana Whitfield (CEO)
                │
                👤 Marcus Reyes (EVP, Products)
                │
                👤 Priya Kapoor (CVP, Collaboration)
                │
                ┌──────────────────────────────┐
                │     James Holloway            │
                │     VP Eng                    │
                │     jamesh@contoso.com        │
                └──────────────┬───────────────┘
                               │
                ┌──────────────┴──────────────┐
                │  ⭐ Alex Johnson              │
                │  Engineering Manager         │
                │  alexj@contoso.com           │
                └──────────────┬──────────────┘
                               │
     ┌────────────┬────────────┼────────────┐
     │            │            │            │
┌────┴────┐ ┌────┴────┐ ┌────┴────┐ ┌────┴────┐
│ Sarah K │ │ Pat R   │ │ Jordan  │ │ Morgan  │
│ Sr SWE  │ │ SWE II  │ │ SWE    │ │ QA Eng  │
└─────────┘ └─────────┘ └─────────┘ └─────────┘

     👔 Managers (0)  ·  🔧 Senior ICs (1)  ·  💻 ICs (3)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Alex Johnson has 4 direct reports
   Chain: CEO → Marcus Reyes → Priya Kapoor → James Holloway → ⭐ Alex Johnson
📧 alexj@contoso.com
```

The ancestors above the direct manager use a **compact single‑line format**: `👤 Name (Abbreviated Title)` connected by `│` lines. This keeps the chart readable even with deep hierarchies. Only the **direct manager** and the **target** get full box treatment.

### Wider Org Chart (many reports, full chain)

When there are more than 6 direct reports, switch to a **compact list layout** below the tree:

```
🏛️ ORG CHART
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                👤 Dana Whitfield (CEO)
                │
                👤 Marcus Reyes (EVP)
                │
                ┌─────────────────────────────┐
                │     Lena Petrova            │
                │     VP Eng                  │
                └──────────────┬──────────────┘
                               │
                ┌──────────────┴──────────────┐
                │  ⭐ Nadia Okoye              │
                │  Partner Grp SW Eng Mgr     │
                └──────────────┬──────────────┘
                               │
            ┌──────┬──────┬────┴────┬──────┬──────┬──────┐
            │      │      │        │      │      │      │

👔 MANAGERS (3)
 #  Name                     Title                    Email
 1  Carlos Mendes            Prin SW Eng Mgr          cmendes@contoso.com
 2  Anika Larsen             Prin SW Eng Mgr          alarsen@contoso.com
 3  Raj Malhotra             SW Eng Mgr               rmalhotra@contoso.com

🔧 SENIOR ICs (4)
 #  Name                     Title                    Email
 4  Tomoko Ishida            Prin SWE                 tishida@contoso.com
 5  Felix Brandt             Prin SWE                 fbrandt@contoso.com
 6  Maya Chen                Prin SWE                 mchen@contoso.com
 7  Omar El-Sayed            Prin SW Eng Mgr          oelsayed@contoso.com

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Nadia Okoye has 7 direct reports
   Chain: CEO → Marcus Reyes → Lena Petrova → ⭐ Nadia Okoye
📧 Nadia.Okoye@contoso.com
```

### Summary Line

Always end with a summary that includes the full reporting chain:

```
📊 {Name} reports to {Manager Name} ({Manager Title}) and has {N} direct reports — {M} managers, {K} ICs.
   Chain: {Org Root} → … → {Manager} → ⭐ {Name}
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| Person | No | Current user ("me") | Name, email, or "me" for the target person |
| Depth Down | No | 1 level | How many levels of direct reports to show below the target |

**Note:** The upward chain always walks to the org root — there is no depth limit going up.

## Required MCP Tools

| MCP Server | Tool | Purpose |
|---|---|---|
| workiq (Local WorkIQ CLI) | `ask_work_iq` | User identity, person lookup, manager chain traversal, and direct reports retrieval |

## Tips

- Say "show my org chart" for a quick view of where you sit.
- Say "org chart for {name}" to explore anyone in the company.
- After viewing, you can say "email #3" to contact a specific person, or "schedule a meeting with the managers" to book time.
- Ask follow-up questions like "find all PMs under Sarah's org" for deeper searches.
- Say "go deeper on Carlos" to expand a manager's subtree.

## Examples

### Example 1: View your own org chart

**User:** Show me my org chart

**Result:** Fetches your identity via `ask_work_iq`, walks the full management chain to the CEO, and renders a tree with your manager above and all your direct reports below — grouped by managers, senior ICs, and ICs.

---

### Example 2: Look up a colleague by name

**User:** Draw the org chart for Nadia Okoye

**Result:** Resolves Nadia via `ask_work_iq`, fetches her manager and direct reports in parallel, walks the chain up to the org root, and renders a wide org chart with a compact list layout (since she has 7 direct reports).

---

### Example 3: Ambiguous name requiring disambiguation

**User:** Show the org chart for Alex

**Result:** `ask_work_iq` returns multiple matches (e.g., Alex Johnson, Alex Kim, Alex Patel). Claude prompts:

```
I found multiple people named Alex. Which one did you mean?
 1. Alex Johnson — Engineering Manager, Platform Team
 2. Alex Kim — Senior Software Engineer, Security
 3. Alex Patel — Program Manager, Growth
```

Once the user selects, the full org chart is rendered for the chosen person.

## Error Handling

### Person Not Found

If `ask_work_iq` returns no result for the given name or email:
- Inform the user: *"I couldn't find anyone named '{name}' in the directory."*
- Suggest trying the full name, email address, or alias.
- Offer to search again with a partial name or department hint.

### No Manager Found (Org Root)

When `ask_work_iq` indicates there is no manager for a person, treat that person as the **org root** — this is expected behavior and not an error. Render them at the top of the chain without a manager box.

### No Direct Reports

If `ask_work_iq` indicates the person has no direct reports, render the chart without the branch lines below the target. Include a note:
```
📊 Alex Johnson has 0 direct reports.
```

### Ambiguous Name — Too Many Results

If `ask_work_iq` returns multiple matches for a name, narrow the prompt:
- *"I found too many people matching '{name}'. Could you provide a last name, department, or email?"*

### WorkIQ CLI Unavailable

If `ask_work_iq` is not accessible or returns a connection error:
- Inform the user: *"I'm unable to reach the directory service right now. Please check that the WorkIQ CLI is connected and try again."*
- Do not attempt to guess or fabricate org data.

### Deeply Nested Hierarchies (Performance)

If the management chain exceeds 10 levels, stop recursing and display a truncation indicator at the top:
```
👤 … (chain truncated above 10 levels)
│
👤 {deepest fetched ancestor}
```
This prevents excessive sequential `ask_work_iq` calls for unusually deep org structures.
