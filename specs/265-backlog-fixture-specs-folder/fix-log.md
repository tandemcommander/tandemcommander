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
