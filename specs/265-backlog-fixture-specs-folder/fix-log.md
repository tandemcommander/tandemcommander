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
  `specs/243-example/README.md` itself - workaround of 247, kept), `specs/242-backlog-system/probe/mutate.py`
  (copies the tool folder). Only the `feature-missing` rule of `backlog.py` reads `specs/`.
- Probe on a temporary copy with the folder plus a one-line README: `check` -> `TOTAL: 0`.

## Change

- New `tools/backlog/fixtures/valid/specs/243-example/README.md` (why the folder exists; keeps
  it in git).
- `tools/backlog/fixtures/README.md`: says the folder is kept by that README.
- No change to `tools/backlog/*.py` or the product (`git diff main...HEAD --stat`: only
  `backlog/`, `.specify/feature.json`, `specs/265-*`, the two fixture files).

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
  error differs - not investigated further, SC-003 asks only that the failures return.)
- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Build / saltests: not run - no file of the product, `src/` or the build changed.
