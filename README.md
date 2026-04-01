<div align="center">
  <img src="https://github.com/dhwani-ris/mYojana/assets/128586957/5fd6a7c2-98bc-4b79-a94b-33858b6bcfc2" alt="mYojana Logo" width="300px">
  <br/>
  <strong>Social Protection Management System (SPMS)</strong>
  <br/>
  A Frappe application to help NGOs manage beneficiary entitlements and government social welfare schemes.
</div>

---

## Table of Contents
- [What is mYojana?](#what-is-myojana)
- [Architecture](#architecture)
- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [API Reference](#api-reference)
- [User Roles](#user-roles)
- [Contributing](#contributing)
- [License](#license)

---

## What is mYojana?

mYojana is an open-source **Social Protection Management System (SPMS)** that empowers NGOs and field teams to:
- Register and profile beneficiaries with comprehensive demographic, disability, and location data
- Automatically match beneficiaries to eligible government and social schemes using a configurable rule engine
- Track scheme applications, follow-ups, and outcomes
- Generate 39+ analytical reports with role-based data access
- Deliver beneficiary ID cards via WhatsApp

**Target users:** NGO administrators, field workers, MIS executives, CSC members

---

## Architecture

mYojana is built on the **Frappe** framework (Python + Jinja + MariaDB) and structured into four modules:

| Module | Purpose |
|--------|---------|
| `myojana` | Core — beneficiary management, APIs, services |
| `master` | Reference data — geography, demographics, disability |
| `rule_engine` | Eligibility rule builder |
| `sva_report` | Flexible reporting |

**Key services:**
- `myojana/services/beneficiary_scheme.py` — scheme eligibility matching
- `myojana/services/family.py` — family group management
- `myojana/utils/misc.py` — rule-to-SQL conversion
- `myojana/utils/report_filter.py` — permission-aware report filtering

---

## Features

- **Beneficiary Registration** — 40+ field profiling form with dynamic field visibility; auto-naming (`{state}-{####}`)
- **Rule Engine** — define eligibility rules (field + operator + value, AND/OR groups); auto-matches beneficiaries to schemes
- **Geographic Permission Hierarchy** — State → District → Block → Centre/Sub-Centre; users only see their assigned data
- **39+ Reports** — age-wise, gender, education, house type, milestone, camp, district-wise; CSV/Excel export
- **WhatsApp Integration** — send beneficiary ID cards via MSG91/Gupshup APIs
- **Family Management** — group beneficiaries by household (unique phone number)
- **Audit Trail** (planned) — track all data changes with user and timestamp

---

## Installation

### Prerequisites
- Python 3.10+
- Node.js 18+
- MariaDB 10.6+
- [Frappe Bench](https://github.com/frappe/bench)
- `wkhtmltopdf` (for ID card image generation)

### On Self-Hosted Bench

```bash
# 1. Get into your bench directory
cd /path/to/bench

# 2. Download the app
bench get-app https://github.com/suvaidyam/mYojana.git --branch development

# 3. Install on your site
bench --site your-site.local install-app myojana

# 4. Run migrations
bench --site your-site.local migrate

# 5. Restart services
bench restart
```

### On Frappe Cloud

1. Log in to your Frappe Cloud account.
2. Navigate to your site → Apps → Install App.
3. Search for **mYojana** and click Install.

---

## Configuration

After installation, open **mYojana Settings** from the Frappe desk:

| Setting | Description |
|---------|-------------|
| `id_card_template` | App Template doctype used for ID card generation |
| `auth_key` | MSG91 auth key for WhatsApp notifications |
| `integrated_number` | WhatsApp integrated number for outbound messages |
| `doctype_mapping` | Maps Frappe doctypes to geographic permission fields |

Configure **User Permissions** for each user at the appropriate geographic level (State / District / Block / Centre / Sub-Centre). Users will only see data within their assigned scope.

---

## API Reference

All endpoints require authentication unless noted. Base path: `/api/method/myojana.api.<function>`.

| Endpoint | Auth | Description |
|----------|------|-------------|
| `execute(name)` | Required | Get all schemes with eligibility matching for a beneficiary |
| `eligible_beneficiaries(scheme, columns, filters, start, page_imit, is_limit)` | Required | Paginated list of beneficiaries eligible for a scheme |
| `most_eligible_ben()` | Required | Top 5 schemes by eligible beneficiary count |
| `top_schemes()` | Required | Top schemes per milestone category |
| `get_user_permission(user)` | Required | User's geographic permission assignments |
| `get_mYojana_settings()` | Guest | Public app configuration |
| `get_image(ben_id)` | Required | Generate and return beneficiary ID card image |

---

## User Roles

| Role | Access |
|------|--------|
| Administrator / Admin | Full access |
| System Manager | Site-level management |
| MIS Executive | Reporting and analytics |
| CSC Member | Beneficiary data entry and follow-up |
| Sub-Centre | Field-level data entry, restricted to assigned sub-centre |

---

## Contributing

We welcome contributions! Please:

1. Fork the repository and create a feature branch from `development`
2. Follow the coding style: Python uses tabs, Ruff linting (line length 110)
3. Add tests for new business logic under `myojana/tests/`
4. Submit a Pull Request against the `development` branch

For bugs or feature requests, [open an issue](https://github.com/suvaidyam/myojana/issues).

---

## License

MIT — see [LICENSE](LICENSE)

Originally developed by [DhwaniRIS](https://www.dhwaniris.com). Currently maintained by [Suvaidyam](https://github.com/suvaidyam).

---

## Main Screens

![mYojana](https://github.com/dhwani-ris/mYojana/assets/128586957/fa12e187-481a-4cb9-bfbc-ddc08b84fc9b)

