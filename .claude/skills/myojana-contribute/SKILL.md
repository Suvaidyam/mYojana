---
name: myojana-contribute
description: >
  Onboard a new contributor to mYojana — explain the project architecture,
  set up the Frappe dev environment, list open GitHub issues, and guide
  through the full vibe-coding contribution workflow (pick issue → branch →
  fix → lint → commit → push → open PR). Trigger on: "help me contribute",
  "understand this project", "how do I start", "what is mYojana",
  "explain the codebase", "I want to fix a bug", or /myojana-contribute.
---

# mYojana Contributor Onboarding Skill

You are helping a developer get oriented in the **mYojana** codebase and contribute their first (or next) fix using Claude Code. Follow every step below in order. Make a todo list at the start and tick items off as you go.

---

## Step 1 — Project Orientation

Read these files and build a mental model of the project:

```
README.md
pyproject.toml
myojana/hooks.py
myojana/api.py          (lines 1-30 for imports + entry points)
```

Then **explain to the developer**:

- **What mYojana is**: A Social Protection Management System (SPMS) built on the Frappe framework. It helps NGOs register beneficiaries, match them to eligible government schemes via a rule engine, track applications, and generate reports.
- **Tech stack**: Python 3.10 + Frappe framework, MariaDB, Vanilla JS, Frappe Desk UI. Built and deployed via Frappe Bench CLI.
- **4 modules**:
  - `myojana` — core (beneficiary management, APIs, services)
  - `master` — reference data (geography, demographics, 31 doctypes)
  - `rule_engine` — visual eligibility rule builder
  - `sva_report` — flexible reporting
- **Auto-naming**: Beneficiaries are named `{state}-{####}` e.g. `MH-0001`
- **Key business flow**: Beneficiary registered → Rule Engine matches them to eligible Schemes → Scheme Child records track application status → Reports + WhatsApp notifications

---

## Step 2 — Codebase Deep Dive

Read and explain these critical files so the developer understands the core patterns:

### Core Services
```
myojana/services/beneficiary_scheme.py   # eligibility matching engine
myojana/services/family.py               # family grouping via phone number
myojana/utils/misc.py                    # rule → SQL converter
myojana/utils/report_filter.py           # permission-aware report filtering
myojana/utils/cache.py                   # user permission cache
```

### Explain these patterns:
1. **Rule Engine flow**: Admin defines rules (field + operator + value, AND/OR groups) on a Scheme → `Misc.create_condition()` converts them to SQL WHERE fragments → `BeneficaryScheme.get_schemes()` evaluates them per beneficiary and returns a match percentage
2. **Geographic permissions**: Users are assigned to a level (State → District → Block → Centre/Sub-Centre). `Cache.get_user_permission()` builds SQL WHERE clauses that filter all list views and reports to the user's assigned scope.
3. **Family management**: A `Primary Member` record is the family anchor, identified by a unique contact number. `family.create()` / `family.update()` manage the linkage.
4. **API pattern**: All Frappe endpoints use `@frappe.whitelist()`. Sensitive endpoints must NOT have `allow_guest=True`.

### Coding conventions to follow:
- **Indentation**: tabs (not spaces)
- **Quotes**: double quotes for strings
- **SQL**: always use `frappe.db.escape()` or parameterised `frappe.db.sql(query, (value,))` — never f-string user input directly into SQL
- **Linter**: `ruff` (line length 110, target Python 3.10)
- **No print()**: use `frappe.log_error()` for errors, `frappe.logger().info()` for info

---

## Step 3 — Environment Setup

Check if the developer's environment is ready:

```bash
# Check Frappe bench
bench --version

# Check ruff linter
ruff --version

# Check Python version
python3 --version
```

If `bench` is not found, explain the setup:
```bash
pip install frappe-bench
bench init frappe-bench --frappe-branch version-15
cd frappe-bench
bench new-site your-site.local
bench get-app https://github.com/Suvaidyam/mYojana.git --branch development
bench --site your-site.local install-app myojana
bench --site your-site.local migrate
bench start
```

If ruff is not found:
```bash
pip install ruff
```

Validate linting on a sample file:
```bash
ruff check myojana/api.py
```

Explain how to run tests:
```bash
bench run-tests --app myojana
# Or a single test:
bench run-tests --app myojana --module myojana.tests.test_beneficiary_scheme
```

---

## Step 4 — Pick an Issue (Vibe Coding Workflow)

List open GitHub issues from `suvaidyam/myojana` using the GitHub MCP tool.

Show the developer the open issues grouped by priority:

**Critical (security — fix first):**
- Any issues labelled `bug` with `[Security]` in title

**Good first issues (well-scoped, low risk):**
- Code quality / documentation issues
- Single-file fixes

Ask the developer: **"Which issue would you like to work on?"**

Once they pick one, read the full issue body and confirm you understand the problem.

---

## Step 5 — Branch, Fix, Commit, Push, PR

### 5.1 Create a branch
```bash
git fetch origin development
git checkout -b fix/issue-<N>-<short-slug> origin/development
```
Where `<N>` is the issue number and `<short-slug>` is 2–4 words from the title, e.g. `fix/issue-7-div-by-zero`.

### 5.2 Explore affected files
Use the Explore subagent or read files directly. Understand the code before changing it.

### 5.3 Apply the fix
Follow mYojana conventions:
- Use tabs for indentation
- Use `frappe.db.escape()` for any SQL values
- Use Frappe ORM (`frappe.get_doc`, `frappe.get_list`) where possible
- Never add `allow_guest=True` to endpoints that access beneficiary data
- Raise `frappe.ValidationError` not bare strings

### 5.4 Lint
```bash
ruff check <changed-file.py> --fix
```

### 5.5 Commit
```bash
git add <changed files>
git commit -m "fix(<scope>): <short description>

<optional longer explanation>

Closes #<N>"
```

**Scope examples**: `security`, `api`, `services`, `utils`, `middleware`, `perf`, `docs`

### 5.6 Push
```bash
git push -u origin fix/issue-<N>-<short-slug>
```

### 5.7 Open PR
Use `mcp__github__create_pull_request` with:
- `base`: `development`
- `head`: your branch name
- `title`: same as commit title
- `body`:
  ```
  ## Summary
  - <bullet points of what changed and why>

  ## Files Changed
  - `path/to/file.py`

  Closes #<N>
  ```

---

## Step 6 — Wrap Up

Tell the developer:
1. The PR URL
2. What the PR does in plain English
3. Suggest the next easiest open issue they could pick up

If this is their first contribution, also mention:
- PRs merge into `development` branch
- The project is seeking NGO/government grant funding — quality contributions directly support that goal
- Open issues #13 (report pagination), #18 (unit tests), #19 (audit trail), #20 (Hindi i18n) are all high-value for grant reviewers

---

## Open Issues Reference

Key open issues as of project revival (check GitHub for current state):

| # | Title | Effort |
|---|-------|--------|
| 13 | Report pagination — all 39 reports need LIMIT | Medium |
| 14 | N+1 query in top_schemes / most_eligible_ben | Medium |
| 18 | Unit tests for core business logic | Large |
| 19 | Audit trail for beneficiary data changes | Large |
| 20 | Hindi (hi) language translation support | Medium |
| 21 | Complete CI/CD pipeline | Small |

---

## Project Structure Quick Reference

```
mYojana/
├── myojana/                    # Core Frappe app
│   ├── api.py                  # Main API endpoints
│   ├── hooks.py                # Frappe app config & event hooks
│   ├── services/
│   │   ├── beneficiary_scheme.py   # Eligibility matching (KEY FILE)
│   │   └── family.py               # Family management
│   ├── utils/
│   │   ├── misc.py             # Rule → SQL converter (KEY FILE)
│   │   ├── cache.py            # User permission cache
│   │   └── report_filter.py    # Permission-aware report filtering
│   ├── middlewares/
│   │   └── user.py             # List-view permission conditions
│   ├── apis/
│   │   ├── whatsapp.py         # MSG91 WhatsApp integration
│   │   ├── html_to_image.py    # ID card image generation
│   │   └── load_test.py        # Test data (dev mode only)
│   ├── myojana/doctype/        # 23 core DocTypes
│   └── report/                 # 39 custom reports
├── master/                     # Reference data (31 DocTypes)
│   └── doctype/
│       ├── scheme/             # Welfare scheme definition
│       ├── state/ district/ block/ village/   # Geography
│       └── ...
├── rule_engine/                # Eligibility rule builder
└── sva_report/                 # Flexible reporting module
```
