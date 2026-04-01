#!/usr/bin/env bash
# =============================================================================
# mYojana GitHub Issues Creator
# =============================================================================
# Usage:
#   export GITHUB_TOKEN=ghp_your_token_here
#   bash create_github_issues.sh
#
# Requirements: curl, python3
# Repo: suvaidyam/myojana
# =============================================================================

set -e

if [ -z "$GITHUB_TOKEN" ]; then
  echo "ERROR: Set GITHUB_TOKEN before running."
  echo "  export GITHUB_TOKEN=ghp_your_personal_access_token"
  exit 1
fi

OWNER="suvaidyam"
REPO="myojana"
API="https://api.github.com"
HEADERS=(-H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" -H "Content-Type: application/json")

create_label() {
  local name=$1 color=$2 desc=$3
  curl -s -X POST "$API/repos/$OWNER/$REPO/labels" "${HEADERS[@]}" \
    -d "{\"name\":\"$name\",\"color\":\"$color\",\"description\":\"$desc\"}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"Label: {d.get('name','already exists or error')}\")" 2>/dev/null || true
}

create_issue() {
  local title=$1 body=$2 labels=$3
  curl -s -X POST "$API/repos/$OWNER/$REPO/issues" "${HEADERS[@]}" \
    -d "$(python3 -c "import json,sys; print(json.dumps({'title':sys.argv[1],'body':sys.argv[2],'labels':json.loads(sys.argv[3])}))" "$title" "$body" "$labels")" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"Issue #{d.get('number')} created: {d.get('html_url','error: '+str(d.get('errors',d.get('message',''))))}\")"
}

echo "=== Creating Labels ==="
create_label "security"     "d93f0b" "Security vulnerability"
create_label "code-quality" "e4e669" "Code quality improvement"
create_label "performance"  "0075ca" "Performance improvement"
create_label "testing"      "7057ff" "Test coverage"

echo ""
echo "=== Creating Issues ==="

# ---- SECURITY ----

create_issue \
  "[Security] SQL injection vulnerabilities across multiple files" \
  "## Problem
Multiple f-string SQL queries pass unsanitized user input directly into SQL, creating SQL injection vulnerabilities.

## Affected Files & Lines
- \`myojana/api.py\` — lines 47, 62–70, 105, 120–131, 196–207, 275
- \`myojana/utils/misc.py\` — lines 12–15, 32–34
- \`myojana/utils/cache.py\` — lines 19–29
- \`myojana/utils/report_filter.py\` — lines 17, 23, 28, 36–38
- \`myojana/services/beneficiary_scheme.py\` — lines 49–61
- \`myojana/services/family.py\` — lines 53–54

## Example
\`\`\`python
# VULNERABLE (api.py line 62)
filter_condition += f\" AND LOWER({filter_key}) LIKE LOWER('{filter_value}%')\"
\`\`\`

## Fix
Replace all f-string SQL with parameterized queries:
\`\`\`python
frappe.db.sql(\"SELECT ... WHERE field = %s\", (value,))
\`\`\`" \
  '["bug","security"]'

create_issue \
  "[Security] Broken authorization logic in user middleware" \
  "## Problem
\`myojana/middlewares/user.py\` line 5 has a logic error — the condition is always \`True\`:

\`\`\`python
# BROKEN — always evaluates to True
if \"Administrator\" and \"Admin\" not in frappe.get_roles(user):
\`\`\`

This means the permission filter is always applied, potentially hiding or exposing data incorrectly for all users including Administrators.

## Fix
\`\`\`python
if \"Administrator\" not in frappe.get_roles(user) and \"Admin\" not in frappe.get_roles(user):
\`\`\`" \
  '["bug","security"]'

create_issue \
  "[Security] Sensitive API endpoints exposed with allow_guest=True" \
  "## Problem
Several API endpoints in \`myojana/api.py\` are accessible without authentication (\`allow_guest=True\`), exposing sensitive beneficiary and scheme data:

- \`get_image()\` — allows anonymous access to beneficiary ID card images
- \`eligible_beneficiaries()\` — exposes sensitive beneficiary PII
- \`most_eligible_ben()\` — exposes scheme/beneficiary counts
- \`top_schemes()\` — exposes scheme data
- \`get_installed_apps()\` — information disclosure

## Fix
Remove \`allow_guest=True\` from all sensitive endpoints. Only \`get_mYojana_settings()\` may remain public if needed." \
  '["bug","security"]'

# ---- BUG ----

create_issue \
  "[Bug] Invalid Python syntax — raise \"No rules\" in api.py" \
  "## Problem
\`myojana/api.py\` line 25 contains invalid Python syntax:

\`\`\`python
raise \"No rules\"  # Invalid — cannot raise a string
\`\`\`

This causes a \`TypeError\` at runtime when triggered.

## Fix
\`\`\`python
raise frappe.ValidationError(\"No rules defined for this scheme\")
\`\`\`" \
  '["bug"]'

create_issue \
  "[Bug] Method name typo — delate_family in family.py" \
  "## Problem
\`myojana/services/family.py\` has a method named \`delate_family\` (typo — should be \`delete_family\`).

This could cause \`AttributeError\` if callers use the correct spelling.

## Fix
Rename \`delate_family\` → \`delete_family\` and update all call sites." \
  '["bug"]'

create_issue \
  "[Bug] Class name typo — BeneficaryScheme (missing 'i')" \
  "## Problem
\`myojana/services/beneficiary_scheme.py\` defines the class as \`BeneficaryScheme\` (missing letter 'i'), while the correct spelling is \`BeneficiaryScheme\`.

This makes the codebase inconsistent and confusing.

## Fix
Rename class to \`BeneficiaryScheme\` and update all import/usage sites." \
  '["bug"]'

create_issue \
  "[Bug] Division by zero risk in BeneficiaryScheme eligibility calculation" \
  "## Problem
\`myojana/services/beneficiary_scheme.py\` lines 30, 46, and 93 perform division without guarding against division by zero:

\`\`\`python
matching_rules_per = matched / total * 100  # ZeroDivisionError if total == 0
\`\`\`

A scheme with no rules would crash the eligibility check.

## Fix
\`\`\`python
matching_rules_per = (matched / total * 100) if total > 0 else 0
\`\`\`" \
  '["bug"]'

create_issue \
  "[Bug] Bare except clauses swallow all errors in html_to_image.py" \
  "## Problem
\`myojana/apis/html_to_image.py\` lines 30–33 and 77–80 use bare \`except:\` clauses that catch everything including \`KeyboardInterrupt\` and \`SystemExit\`:

\`\`\`python
try:
    options = json.loads(options)
except:
    options = None  # Silently swallows ALL exceptions
\`\`\`

This makes debugging impossible and can mask serious errors.

## Fix
\`\`\`python
except (json.JSONDecodeError, TypeError):
    options = None
\`\`\`" \
  '["bug"]'

# ---- CODE QUALITY ----

create_issue \
  "[Code Quality] Remove debug print() statements from production code" \
  "## Problem
Production code contains \`print()\` statements that should never be in a deployed application:

- \`myojana/apis/whatsapp.py\` line 41: \`print(\"template_name\", auth_key)\` — **logs the auth key!**
- \`myojana/apis/html_to_image.py\` lines 46, 73: \`print(\"Exception::\", e)\`

## Fix
- Remove all \`print()\` statements
- Replace error logging with \`frappe.log_error(message, title)\`" \
  '["code-quality"]'

create_issue \
  "[Code Quality] Move load_test.py out of production codebase" \
  "## Problem
\`myojana/apis/load_test.py\` is a test data generator that should never ship in production. It:
- Creates fake beneficiary records at scale
- Only checks \`if frappe.session.user == \"Administrator\"\` (easily bypassed)
- Has no limit on the \`count\` parameter (DoS risk)

## Fix
Move to \`scripts/load_test.py\` and add a developer mode guard:
\`\`\`python
if not frappe.conf.developer_mode:
    frappe.throw(\"Only available in developer mode\")
\`\`\`" \
  '["code-quality","bug"]'

create_issue \
  "[Code Quality] Incomplete/commented-out code in report_filter.py" \
  "## Problem
\`myojana/utils/report_filter.py\` lines 44–50 contain incomplete commented-out code that was never finished or removed:

\`\`\`python
# if filter_key == \"district\":
#     ...
\`\`\`

This is dead code that adds confusion.

## Fix
Either implement the missing logic or remove the dead comment block." \
  '["code-quality"]'

# ---- PERFORMANCE ----

create_issue \
  "[Performance] Missing database indexes on frequently queried fields" \
  "## Problem
\`myojana/myojana/doctype/beneficiary_profiling/beneficiary_profiling.json\` has no \`search_index\` set on heavily queried fields. All 39 reports and most API calls filter/join on these columns, causing full table scans as data grows.

## Fields Missing Indexes
- \`date_of_visit\`
- \`district\`
- \`state\`
- \`ward\`
- \`date_of_birth\`
- \`status\`
- \`select_primary_member\`

## Fix
Add \`\"search_index\": 1\` to these field definitions in the JSON." \
  '["performance"]'

create_issue \
  "[Performance] All 39 reports return unbounded result sets (no pagination)" \
  "## Problem
Every report in \`myojana/myojana/report/\` returns the full result set with no \`LIMIT\` clause. With thousands of beneficiaries this causes memory exhaustion and timeouts.

## Fix
Add pagination to all report \`get_data()\` methods:
\`\`\`python
def get_data(filters, start=0, page_length=100):
    # ...
    query += \" LIMIT %(page_length)s OFFSET %(start)s\"
    return frappe.db.sql(query, {\"start\": start, \"page_length\": page_length}, as_dict=True)
\`\`\`" \
  '["performance"]'

create_issue \
  "[Performance] N+1 query patterns in api.py — top_schemes and most_eligible_ben" \
  "## Problem
Two functions in \`myojana/api.py\` execute N separate SQL queries inside a loop:

- \`top_schemes()\` (lines 216–247): calls \`get_beneficiary_scheme_query()\` for every scheme
- \`most_eligible_ben()\` (lines 190–214): same pattern

With 100 schemes, this produces 100 individual queries per API call.

## Fix
Refactor to use a single \`GROUP BY\` query that returns counts for all schemes at once." \
  '["performance"]'

create_issue \
  "[Performance] Duplicate CASE logic and missing logging in scheduler task" \
  "## Problem
\`myojana/scheduler_events/ben_dob_update.py\` has two identical CASE blocks (lines 9–11 and 16–20). The duplicate logic runs on the entire \`Beneficiary Profiling\` table daily with no logging of success or failure.

## Fix
- Deduplicate the CASE statements
- Add \`frappe.log_error()\` for failure and a logger call for success" \
  '["performance","code-quality"]'

# ---- DOCUMENTATION ----

create_issue \
  "[Documentation] README is minimal — project needs proper documentation" \
  "## Problem
The current README is only ~48 lines covering basic install steps. For a project seeking grant funding or new contributors, this is insufficient.

## Missing Sections
- Architecture overview
- Feature list (with screenshots)
- Deployment guide (full Bench setup)
- Configuration guide (mYojana Settings walkthrough)
- API reference (endpoints, params, responses)
- Contributing guide
- License and acknowledgements" \
  '["documentation"]'

create_issue \
  "[Documentation] No docstrings in core service modules" \
  "## Problem
Core business logic files have no docstrings, making the codebase hard to understand and contribute to:

- \`myojana/services/beneficiary_scheme.py\`
- \`myojana/services/family.py\`
- \`myojana/utils/misc.py\`
- \`myojana/utils/report_filter.py\`

## Fix
Add class-level and method-level docstrings explaining purpose, parameters, and return values." \
  '["documentation"]'

# ---- TESTING ----

create_issue \
  "[Testing] No unit tests for core business logic" \
  "## Problem
Critical business logic has zero test coverage:

- \`myojana/services/beneficiary_scheme.py\` — eligibility matching (core feature)
- \`myojana/services/family.py\` — family creation/deletion
- \`myojana/utils/report_filter.py\` — permission-based filtering
- \`myojana/middlewares/user.py\` — authorization logic

## Fix
Create test files:
- \`myojana/tests/test_beneficiary_scheme.py\`
- \`myojana/tests/test_family.py\`
- \`myojana/tests/test_report_filter.py\`
- \`myojana/tests/test_middlewares.py\`" \
  '["testing"]'

# ---- ENHANCEMENT ----

create_issue \
  "[Enhancement] Implement audit trail for beneficiary data changes" \
  "## Problem
There is no audit logging of who created, modified, or deleted beneficiary records or scheme applications. This is required for NGO compliance, donor accountability, and data governance.

## Fix
Hook into Frappe document events for \`Beneficiary Profiling\` and \`Scheme Child\`:

\`\`\`python
# In beneficiary_profiling.py
def on_update(self):
    log_audit_trail(self, event=\"update\")

def on_trash(self):
    log_audit_trail(self, event=\"delete\")
\`\`\`

Create a new \`Audit Log\` doctype storing: doctype, document name, user, timestamp, field changed, old value, new value." \
  '["enhancement"]'

create_issue \
  "[Enhancement] Add Hindi (hi) language translation support" \
  "## Problem
All UI strings are hardcoded in English. For a system targeting Indian NGOs and government programmes, Hindi support is essential and is often a grant requirement.

## Fix
1. Wrap all user-facing strings with Frappe's \`__()\` function
2. Create \`myojana/translations/hi.csv\` with translations
3. Test with Frappe's language switching mechanism" \
  '["enhancement"]'

create_issue \
  "[Enhancement] Complete CI/CD pipeline" \
  "## Problem
The existing \`.github/workflows/test.yaml\` is incomplete:
- Missing SonarCloud token configuration
- No test coverage reporting
- No status badges in README
- CI only runs on \`develop\` branch

## Fix
1. Add \`coverage.py\` reporting to CI
2. Configure SonarCloud properly or replace with Codecov
3. Add status badges to README
4. Run CI on all branches and PRs" \
  '["enhancement"]'

echo ""
echo "=== Done! All issues created. ==="
