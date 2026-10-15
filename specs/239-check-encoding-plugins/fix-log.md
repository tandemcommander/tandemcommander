# Fix log: 239 - the encoding guard can list the plug-ins

Backlog (124): `tools/check_encoding.py` does not scan `plugins/` - excluded by policy (feature 042:
the guard must not change plug-in behaviour, and the build fails on any finding).

## Work

`tools/check_encoding.py --plugins`: scans `src/plugins` instead of the core - a **report only**
(never exits 1, also with `--strict`; `build.cmd` does not use it). Third-party code is skipped
(`7zip/7za`, `checksum/tomcrypt`, `codeview/test`, `automation/help`). `--draft` works with it.

## The list (`plugins_findings.txt`, the build at 238)

78 findings of the build's rules (424 with `--draft`): `lossy-lenient-at-intake` 38 (automation 6,
uniso 5, regedt 5, mmviewer 4, mdview 3, ...), `utf8-to-legacy-sink` 18 (ZIP 11, filecomp 3,
dbviewer 2, ...), `strict-probe-rejects-wtf8` 12, `mixed-composition` 6, `dead-dispinfow` 2,
`ansi-template-number` 2. A work list - each finding needs reading (a plug-in's own rules may make
it harmless); recorded in NEXT-WORK.

The core: `check_encoding.py` TOTAL 0 as before; `build.cmd` unchanged.

Not reviewed by an agent: a report-only option of a tool, no product code.
