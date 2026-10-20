# Research - 265 backlog fixture specs folder

## R1 - Does a file inside `specs/243-example/` change what `check` reports?

- Decision: a `README.md` inside the folder is safe.
- Rationale: the `feature-missing` rule in `tools/backlog/backlog.py` only asks whether a
  directory named `<feature>-*` exists under `specs/`; nothing else in `check` reads
  `specs/`. Measured on a temporary copy of the fixture with the folder and a one-line
  `README.md` added: `check` -> `TOTAL: 0`.
- Alternatives considered: `.gitkeep` (empty, says nothing about why the folder exists - the
  item asks for a README as its example); changing the tests to create the folder (the item
  asks for the folder in git, and the fixture README already promises it).

## R2 - Does the `feature-missing` seed still produce its finding?

- Decision: yes, unchanged.
- Rationale: the seed is `shutil.rmtree(r / "specs" / "243-example")` on the test's copy,
  which removes the folder with its contents.

## R3 - Other consumers of the fixture

- `tools/backlog/test_backlog.py` copies `fixtures/valid` (`shutil.copytree`) per test.
- `tools/backlog/test_loop.py` copies it into a temporary git repository and then created
  `specs/243-example/README.md` itself (`mkdir(exist_ok=True)`, `write_text`) - harmless, but
  its comment would become false; removed (spec Clarifications).
- `specs/247-backlog-run-loop/probe/e2e_real_claude.py` `make_repo()` did the same with
  `mkdir(parents=True)` and no `exist_ok` - with the folder in the fixture it raises
  `FileExistsError` (found by review 1, missed in the first enumeration, which searched only
  `tools/`); removed.
- `specs/242-backlog-system/probe/mutate.py` copies the tool folder for mutation testing;
  the fixture gains one file, which it copies along.
- No test lists the files of `specs/`; the `iterdir` calls in the tests read
  `backlog/items/` only.
