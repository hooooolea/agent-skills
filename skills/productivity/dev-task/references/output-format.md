# Phase 3 Review Output Format

The Phase 3 sub-agent must follow this format **exactly**. The main agent
parses it programmatically to extract PASS / WARN / FAIL counts and the
verdict line.

---

## Per-finding format

Every finding is one bullet, prefixed with one of three tags:

- `[PASS]` — area is clean, no action needed
- `[WARN]` — minor issue, should be fixed but not blocking
- `[FAIL]` — blocking issue, Phase 2 must fix before commit

```
[FAIL] file.py:42 — SQL injection: user_id concatenated into query string
       Fix: use parameterised query (`cursor.execute("... WHERE id=?", (uid,))`)
[WARN] tests/test_x.py — no test for the new error branch
       Fix: add test covering the ValueError path
[PASS] README.md — "Public API" section updated to include new endpoint
```

**Rules**:

1. One finding per line (multi-line is OK: tag on first line, fix on
   indented continuation lines).
2. Include `file:line` when pointing at specific code. Section name only
   for doc/config findings.
3. `[FAIL]` items MUST include a concrete fix hint, not just a complaint.
4. Empty sections are fine — emit `[PASS] <section> — no issues` instead
   of skipping the section.

---

## Five review sections (in order)

```
[Section 1] Convention Compliance
[PASS|WARN|FAIL] findings...

[Section 2] Completeness
[PASS|WARN|FAIL] findings...

[Section 3] Security
[PASS|WARN|FAIL] findings...

[Section 4] Maintainability
[PASS|WARN|FAIL] findings...

[Section 5] Doc Sync
[PASS|WARN|FAIL] findings...
```

---

## Mandatory verdict line

The very last line of Phase 3 output MUST be one of:

```
VERDICT: 通过          (zero FAIL, zero or any WARN)
VERDICT: 有条件通过    (zero FAIL, but ≥1 WARN that the user should know about)
VERDICT: 不通过        (≥1 FAIL)
```

Use **Chinese characters exactly** (通过 / 有条件通过 / 不通过) — the main
agent's regex depends on these literal strings.

---

## Format failure handling

If the sub-agent's output is missing the verdict line or has no `[PASS]/
[WARN]/[FAIL]` tags at all, the main agent emits `[FORMAT_FAIL]` and
re-invokes Phase 3 once with a stronger format reminder. A second failure
escalates to the main agent doing the review by hand.

---

## Minimal example (good output)

```
[Section 1] Convention Compliance
[PASS] repo uses snake_case throughout — new helpers match
[PASS] imports follow stdlib / third-party / local grouping

[Section 2] Completeness
[PASS] TASK acceptance criterion 1 (add POST /api/v1/foo) — implemented
[WARN] error response uses 500 instead of 400 for bad input — consider 400

[Section 3] Security
[FAIL] api/foo.py:88 — user_id from query string flows into raw SQL
       Fix: use parameter binding, see Phase 1 § existing pattern in db.py:23

[Section 4] Maintainability
[PASS] no dead code introduced
[WARN] function `bar()` is 47 lines — consider splitting validation from I/O

[Section 5] Doc Sync
[PASS] README "Public API" section updated

VERDICT: 不通过
```
