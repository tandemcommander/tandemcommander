# Closing report - 265-backlog-fixture-specs-folder
Backlog item: backlog-fixture-empty-specs-folder-missing - Backlog tool tests fail on a fresh checkout: the fixture folder specs/243-example is not in git
Outcome: closed

## What changed

- New `tools/backlog/fixtures/valid/specs/243-example/README.md`: says why the folder exists
  (target of the `feature-missing` rule for the fixture's in-progress item) and keeps it in git.
- `tools/backlog/fixtures/README.md`: says the folder is kept by that README.
- After review 1: the now redundant workaround that created the folder itself was removed from
  `tools/backlog/test_loop.py` (`setUp`) and `specs/247-backlog-run-loop/probe/e2e_real_claude.py`
  (`make_repo`, which raised `FileExistsError` once the folder was in the fixture).
- `tools/backlog/backlog.py` and the product are unchanged. No user-visible change, so no
  `CHANGELOG.md` entry.

## Measurements (before / after, commands)

| Measurement | Before (`main` `6085500d`) | After (fresh clone of the branch) |
|---|---|---|
| `python tools/backlog/backlog.py --root tools/backlog/fixtures/valid check` | `feature-missing`, `TOTAL: 1` | `TOTAL: 0` |
| `python -m unittest tools/backlog/test_backlog.py` | 68 tests, 28 failures, 2 errors | 68 tests, OK |
| `python -m unittest tools/backlog/test_loop.py` | (passed only through its workaround) | 57 tests, OK |
| 247 probe `make_repo()` | OK | OK (folder from the fixture) |
| Negative control: folder deleted in the clone | - | `check` `TOTAL: 1`; `test_backlog.py` failures return (29/1; 28/2 with all of `valid/specs/` deleted) |

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `python tools/backlog/backlog.py check` -> `TOTAL: 0`.
- Build and `saltests`: not run - no file of `src/`, the product or the build changed.
- GUI probes: none (no GUI involved).

## Reviews (findings and what was done)

- Review 1: MUST - the 247 e2e probe's `make_repo()` crashed with `FileExistsError` (fixed: the
  workaround removed); SHOULD - false comment in `test_loop.py` (fixed: removed with the
  workaround); NOTE - duplicated text in the item's *Log* (cosmetic, item deleted).
- Review 2 (fresh agent, with review 1's findings): no MUST, no SHOULD. NOTEs: stale "kept" in
  the fix-log, the 29/1 vs 28/2 split explained, `mutate_loop.py` missing from research R3 -
  fixed in the documents; the temporary-folder leak of `test_loop.py` -> new Inbox item.
- Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

Nothing.

## New Inbox items (slug - title)

- loop-tool-tests-leave-a-temporary-git-folder-behind-on-every - Loop tool tests leave a temporary git folder behind on every test
