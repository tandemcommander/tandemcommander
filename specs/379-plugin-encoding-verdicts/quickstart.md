# Quickstart: re-check feature 379

From the repository root (Bash):

1. `python tools/check_encoding.py --plugins | tail -1` → `TOTAL: 17 finding(s)` (the number of
   *real defect* rows in `verdicts.md`).
2. `python tools/check_encoding.py --plugins --format list` → exactly the *real defect* sites of
   `verdicts.md` (compare the sorted lists).
3. `python tools/check_encoding.py --strict | tail -1` → `TOTAL: 0 finding(s)`.
4. `git diff main -U0 -- src | grep '^[+-]' | grep -v '^+++\|^---' | grep -v 'encoding-check: allow'`
   → nothing (comments only).
5. Negative control: append `SetWindowText(h, fileName);` to a marked plug-in file → the scan
   reports one more; restore the file.
6. Markers stripped in a copy of `tools/` + `src/plugins` → the scan gives back the 81 of
   `baseline_3e0da39c.txt`.
7. PowerShell: `.\build.cmd` → `BUILD SUCCEEDED`.
