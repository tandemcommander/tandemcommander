# Quickstart - validate 265

From the repository root (Git Bash).

1. Fixture check: `python tools/backlog/backlog.py --root tools/backlog/fixtures/valid check`
   -> last line `TOTAL: 0`.
2. Test suites: `python -m unittest tools/backlog/test_backlog.py` -> `OK` (68 tests);
   `python -m unittest tools/backlog/test_loop.py` -> `OK`.
3. Fresh checkout: `git clone --quiet --branch 265-backlog-fixture-specs-folder . <tmp>/c`,
   then in `<tmp>/c` repeat steps 1-2 -> same results (the folder comes from git, not from a
   working tree created by hand).
4. Negative control: in that clone delete `tools/backlog/fixtures/valid/specs/243-example`
   and run `test_backlog.py` -> failures return (at `6085500d`: 28 failures, 2 errors).
5. Seed still bites: the test `feature-missing` of `SEEDED` passes (it expects exactly that
   finding after deleting the folder) - part of step 2.
