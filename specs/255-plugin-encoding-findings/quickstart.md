# Quickstart: re-checking 255

From the repository root:

1. `python tools/check_encoding.py --plugins` - TOTAL equals the number of `real defect` rows in
   `verdicts.md`; every listed site is such a row.
2. `python tools/check_encoding.py --plugins --format list` - the same sites, one per line, for a
   diff against the table.
3. `python tools/check_encoding.py --strict` - `TOTAL: 0 finding(s)`, exit 0 (the core).
4. `.\build.cmd` (PowerShell) - `BUILD SUCCEEDED` (the markers are comments).
5. Negative control: add `SetWindowText(h, fileName);` to any scanned plug-in source, run step 1,
   see it reported (+1), remove it.
6. For each `real defect` row: `python tools/backlog/backlog.py show <slug>` - the item exists.
