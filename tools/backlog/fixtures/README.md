# Fixtures of `test_backlog.py`

- `valid/` — a complete, consistent backlog (`check` → `TOTAL: 0`) with an
  item in every section, every type, a `github#5` item with `issue.md` and
  `reply.md`, an `evidence/` folder, `related` and `depends-on` links, a
  title with `|` and brackets, one journal row, and `specs/243-example/` for
  the in-progress item. It was generated with the tool itself
  (`new`, `move`, `block`, `start`, `run-log` with
  `TANDEM_BACKLOG_NOW=2026-10-17T10:00:00`), so it is also a sample of the
  formats.
- Seeded defects (SC-004): one per check rule, each a single change applied
  to a copy of `valid/` — the table `SEEDED` in `test_backlog.py` lists
  them. Keeping them as mutations rather than 18 copied folders means a
  format change is made once, here, and every defect stays exactly one
  change away from a valid backlog.

- Sub-rule seeds (`SEEDED_MORE` in `test_backlog.py`): further single
  changes for rules with several parts (duplicate `github#N`, `updated`
  before `created`, `verified` format, control characters, log order, title
  line, *Steps* checklist, self-reference, rejected dependency, a file that
  is not UTF-8, a hand-written row) — added after the review showed the
  first set left them untested.

Negative controls: `python specs/242-backlog-system/probe/mutate.py` applies
one mutation per copy of `backlog.py` and runs the tests; on 2026-10-17 31
of 32 mutants were caught (the survivor is equivalent — see the script's
docstring).
