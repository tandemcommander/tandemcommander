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
- `tools/backlog/test_loop.py` copies it into a temporary git repository and then creates
  `specs/243-example/README.md` itself (`mkdir(exist_ok=True)`, `write_text`): with the folder
  present it just overwrites the copy's README - harmless; kept (spec Clarifications).
- `specs/242-backlog-system/probe/mutate.py` copies the tool folder for mutation testing;
  the fixture gains one file, which it copies along.
- No test lists the files of `specs/`; the `iterdir` calls in the tests read
  `backlog/items/` only.
