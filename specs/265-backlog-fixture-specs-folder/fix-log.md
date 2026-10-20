# Fix log - 265 backlog fixture specs folder

Backlog item `backlog-fixture-empty-specs-folder-missing`.

## Before (main `6085500d`, 2026-10-20)

- `python tools/backlog/backlog.py --root tools/backlog/fixtures/valid check` ->
  `backlog/items/archive-pack-refuses-a-long-folder-silently/desc.md:13: feature-missing: no folder specs/243-* for the in-progress feature`,
  `TOTAL: 1`.
- `python -m unittest tools/backlog/test_backlog.py` -> `Ran 68 tests in 5.585s`,
  `FAILED (failures=28, errors=2)`.
- `ls tools/backlog/fixtures/valid/specs/` -> no such folder; `git ls-tree -r HEAD
  tools/backlog/fixtures` lists nothing under `valid/specs/`.
- Cause: the folder was created empty in feature 242 (T010); git stores no empty folders.
- Consumers enumerated (research R3): `test_backlog.py` (copytree per test; the
  `feature-missing` seed `shutil.rmtree`s the folder), `test_loop.py` (copytree, then creates
  `specs/243-example/README.md` itself - workaround of 247; first kept, removed after review 1),
  `specs/242-backlog-system/probe/mutate.py` (copies the tool folder). Only the
  `feature-missing` rule of `backlog.py` reads `specs/`. (This first enumeration searched
  `tools/` only; review 1 found `specs/247-backlog-run-loop/probe/e2e_real_claude.py`, review 2
  `specs/247-backlog-run-loop/probe/mutate_loop.py` - see *Review*.)
- Probe on a temporary copy with the folder plus a one-line README: `check` -> `TOTAL: 0`.

## Change

- New `tools/backlog/fixtures/valid/specs/243-example/README.md` (why the folder exists; keeps
  it in git).
- `tools/backlog/fixtures/README.md`: says the folder is kept by that README.
- No change to `tools/backlog/backlog.py` or the product (`git diff main...HEAD --stat`: only
  `backlog/`, `.specify/feature.json`, `specs/265-*`, the two fixture files; after review 1
  also the removal of the workaround in `tools/backlog/test_loop.py` and
  `specs/247-backlog-run-loop/probe/e2e_real_claude.py`).

## After (branch `265-backlog-fixture-specs-folder`, 2026-10-20)

- Working tree: fixture `check` -> `TOTAL: 0`; `python -m unittest tools/backlog/test_backlog.py`
  -> `Ran 68 tests`, `OK` (includes `test_every_rule_is_detected`, whose `feature-missing`
  seed deletes the folder and expects the finding); `python -m unittest tools/backlog/test_loop.py`
  -> `Ran 57 tests`, `OK`.
- Fresh clone (`git clone --branch 265-backlog-fixture-specs-folder . %TEMP%\tc265_clone`):
  `git ls-tree` lists `tools/backlog/fixtures/valid/specs/243-example/README.md`; fixture
  `check` -> `TOTAL: 0`; `test_backlog.py` -> 68 tests `OK`; in a second fresh clone
  `test_loop.py` -> 57 tests `OK`. Clones deleted.
- Negative control (in the first clone, folder deleted): `check` -> `TOTAL: 1`;
  `test_backlog.py` -> `FAILED (failures=29, errors=1)` - the failures return. (At `6085500d`
  the split was 28/2; the total of 30 failing tests is the same, the split between failure and
  error differs. Explained by review 2: `test_backlog.py:339` makes `specs/244-ftp` without
  `parents=True`; with `valid/specs/` missing entirely it raises an error, with only
  `243-example` deleted the leftover `specs/` turns that error into a failure. Deleting
  `valid/specs/` gives 28/2, exactly as at `6085500d`.)
- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Build / saltests: not run - no file of the product, `src/` or the build changed.

## Review

### Review 1 (independent agent, refute-first)

- MUST 1: `specs/247-backlog-run-loop/probe/e2e_real_claude.py` `make_repo()` created
  `specs/243-example` with `mkdir(parents=True)` (no `exist_ok`); with the folder now in the
  fixture it raises `FileExistsError` and the probe aborts before E1-E4. Missed by the first
  consumer enumeration (it searched `tools/` only). Fixed: the workaround is removed; the
  folder comes from the fixture.
- SHOULD 2: the comment in `tools/backlog/test_loop.py` `setUp` ("the fixture's empty folder is
  not in git ...") becomes false. Fixed: the workaround and its comment are removed (spec
  Clarification revised, FR-007).
- NOTE 3: duplicated "at 6085500d" in the item's *Log* (wording of the `verify` note) -
  cosmetic; the item is deleted at closing.
- NOTE 4-6: create-new-feature.sh scans only top-level `specs/*`; `loop.py` never reads
  `specs/`; the 242 mutation probe reports 31/32 caught (as recorded in 242) and is meaningful
  on a fresh checkout again; no data-safety or standing-rule concern.

After the fix (commit `[265] review 1: ...`):

- Fresh clone of the branch: `make_repo()` of the 247 probe -> `make_repo OK`, the folder's
  README present (from the fixture); control, fresh clone of `main`: `make_repo OK` (it still
  creates the folder itself there).
- Fresh clone of the branch: `test_backlog.py` -> 68 tests `OK`; `test_loop.py` -> 57 tests
  `OK`.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.

### Review 2 (fresh independent agent, refute-first, with the findings of review 1)

- No MUST, no SHOULD. Re-ran in a fresh clone at `42700908`: fixture `check` `TOTAL: 0`,
  `test_backlog.py` 68 OK, `test_loop.py` 57 OK, the 247 probe's `make_repo()` OK (the folder
  tracked from the fixture), `backlog.py check` on the repository `TOTAL: 0`, encoding guard
  `TOTAL: 0 finding(s)`.
- Negative control with `valid/specs/` deleted: `check` `TOTAL: 1`, `test_backlog.py` 28
  failures / 2 errors; `test_loop.py` fails (`test_wrappers`, `test_nothing_eligible`,
  `test_ready`) and its process tests stall - the suite now depends on the committed folder.
- Consumers searched across the whole repository: `test_backlog.py`, `test_loop.py`,
  `e2e_real_claude.py`, `mutate.py`, `mutate_loop.py` - no other.
- NOTE 1 (stale "kept" in *Before*), NOTE 2 (the 29/1 vs 28/2 split explained), NOTE 3
  (`mutate_loop.py` missing from research R3): fixed in this fix-log and `research.md`.
- NOTE 4 (duplicated "at 6085500d" in the item's *Log*): cosmetic; the item is deleted at
  closing.
- NOTE 5: `tools/backlog/test_loop.py` `tearDown` (`shutil.rmtree(..., ignore_errors=True)`)
  leaves every test's temporary git repository in `%TEMP%\loop247-*` (read-only git objects;
  324 folders counted) - not caused by 265 → Inbox item
  `loop-tool-tests-leave-a-temporary-git-folder-behind-on-every` (`measure:265`).
