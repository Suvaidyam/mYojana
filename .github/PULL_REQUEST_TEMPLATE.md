## Summary

<!-- What does this PR do and why? 2-4 bullet points. -->

- 
- 

## Linked issue

Closes #<!-- issue number -->

## Type of change

- [ ] Bug fix
- [ ] Enhancement / new feature
- [ ] Refactor (no functional change)
- [ ] Documentation
- [ ] Infrastructure / CI

## Files changed

<!-- List the key files modified and what changed in each. -->

| File | Change |
|------|--------|
|  |  |

## Testing

<!-- How was this tested? Describe steps or paste test output. -->

- [ ] Manually tested on local bench
- [ ] Unit tests added / updated (`bench run-tests --app myojana`)
- [ ] No new tests needed (explain why):

## Checklist

- [ ] `ruff check` passes with no errors on changed files
- [ ] No `print()` statements added (use `frappe.log_error()` / `frappe.logger()`)
- [ ] No `allow_guest=True` added to endpoints that access beneficiary data
- [ ] SQL queries use `frappe.db.escape()` or parameterised `frappe.db.sql(query, (value,))` — no f-string SQL
- [ ] Indentation is **tabs**, not spaces
- [ ] If a DocType JSON was changed, `bench migrate` has been run locally
- [ ] PR targets the `development` branch (not `main`)
