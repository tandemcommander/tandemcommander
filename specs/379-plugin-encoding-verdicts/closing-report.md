# Closing report - 379-plugin-encoding-verdicts
Backlog item: check-encoding-plugin-findings - Read the 78 findings of check_encoding.py --plugins one by one
Outcome: closed

## What changed

- Every site of `python tools/check_encoding.py --plugins` has a verdict in `verdicts.md` (82 rows:
  feature 239's 78 + 4 new at HEAD): **64 false positives**, **17 real defects**, **1 fixed** (the FTP
  listing probe, by feature 269).
- 64 `// encoding-check: allow <rule> - <reason>` comment lines in 31 plug-in sources (63 carried
  over from the stopped feature 255, re-checked at HEAD; 4 new in Code Viewer `config.cpp`; 255's
  markers on rows 3, 32-34, 41, 67, 68, 75 not kept). No code changed.
- Rows re-judged against 255: CheckVer row 3, TAR / UnCAB / UnMIME rows 67 / 68 / 75 (the vendored
  7-Zip converter writes an unpaired surrogate as 3-byte WTF-8 on Windows), Automation rows 32-34
  (review 1: `OLE2T` = `OLE2A` feeds `CreateWindowExA` and registry value names).
- No CHANGELOG entry: nothing user-visible changes (comments and a developer report).

## Measurements (before / after, commands)

- Before (3e0da39c): `python tools/check_encoding.py --plugins` → `TOTAL: 81`, none annotated
  (`baseline_3e0da39c.txt`); 77 of 239's 78 unchanged, the FTP row gone (269), 4 new Code Viewer rows.
- After: `TOTAL: 17`; the `--format list` sites (file + rule) equal the 17 real-defect rows (sorted
  `diff`: none); every real-defect slug exists.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`, exit 0.
- `git diff main -- src`: 31 files, 64 insertions, 0 deletions, every line a marker.
- Negative control 1: a planted `SetWindowText(h, fileName)` in `dbviewer/dialogs.cpp` → one more finding
  (14 → 15, run before review 1), restored. Negative control 2: markers stripped in a copy → 81 = the baseline.
- `.\build.cmd` (Debug x64) → `BUILD SUCCEEDED` (the marked plug-ins rebuilt). `saltests` not run:
  no core or `src/common/` change. No probe: no behaviour change. No UI strings: no `.slt` refresh.
- `verdicts.md` generated and checked by a session script: every false-positive reason equals its
  marker; every row matched by file, rule and text between the two baselines.

## Reviews (findings and what was done)

- Review 1: MUST Automation `strconv.cpp` rows 32-34 wrongly marked → markers removed, real defect,
  item. SHOULD core registry facade A APIs → Inbox item. SHOULD UnCAB item understated → corrected
  (whole cabinet fails, severity 5). NOTEs: fix-log count and Code Viewer marker wording fixed; the
  Markdown Viewer URI decoder and the ZIP 64 KiB header bound recorded.
- Review 2: no MUST. SHOULD `_bstr_t` narrowing → added to the Automation item. SHOULD Registry Editor
  cut full key path → Inbox item. NOTEs recorded in `fix-log.md`.

## Owed to a person (with the new person-step items)

- The maintainer: add `tar-wtf8-names-read-in-code-page` and `uncab-wtf8-flagged-name-refused` to the
  `depends-on` of `plugin-encoding-scan-strict-in-build` (an agent may not change another item's
  fields; the request is a log line on that item). No person-step item.

## New Inbox items (slug - title)

- `tar-wtf8-names-read-in-code-page` - TAR: a name with an unpaired surrogate stored as WTF-8 is read as another name
- `uncab-wtf8-flagged-name-refused` - UnCAB: one UTF-8 cabinet name with an unpaired surrogate makes the whole cabinet fail
- `unmime-wtf8-name-read-in-code-page` - UnMIME: an attachment name with an unpaired surrogate is read in the code page
- `checkver-filter-names-code-page` - CheckVer: a non-ASCII module name in the filter list is shown garbled
- `automation-ole2t-captions-and-value-names` - Automation: non-ASCII texts and captions garbled, persistent value names may collide
- `registry-wide-deletevalue-and-key-names` - Registry facade: deleting a value and opening keys use the ANSI API with UTF-8 names
- `regedt-full-path-cut-reported-as-success` - Registry Editor: a too long full key path is cut and reported as success
