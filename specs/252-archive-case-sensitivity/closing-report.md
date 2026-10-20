# Closing report - 252-archive-case-sensitivity
Backlog item: archive-plugins-declare-case-sensitivity - 7-Zip, TAR and SFTP do not declare case-sensitive listings
Outcome: closed

## What changed

- `src/common/salcasetwins.h` (new, header-only): `SalNamesHaveCaseTwins` and
  `SalDirTreeHasCaseTwins<TDir>` - does any folder of a listing hold two byte-different names that
  the core's case-insensitive rules (`SalNameOrderCompareCI` = `SalNameCompareOrdinalCI`, or the
  legacy fold = `StrICmp`) take for one? Low memory -> "yes" (the exact listing is kept).
- 7-Zip (`C7zClient::ListArchive`) and TAR (`CPluginInterfaceForArchiver::ListArchive`): the listing
  is built with `SALDIRFLAG_CASESENSITIVE`; afterwards the flag is cleared unless the listing holds
  case twins. Archives without twins: exactly the old listing and behaviour. Archives with twins:
  Paste, Reselect, Store / Restore Selection, Hide Selected Names act on the exact twin; folders D
  and d stay two folders (TAR used to extract only one of them).
- SFTP (`fs.cpp`): listings always declare `SALDIRFLAG_CASESENSITIVE` (as FTP).
- No plug-in interface change, no UI strings, no settings.

## Measurements (before / after, commands)

Probe `probe/arc252_probe.ps1` on the hidden desktop
(`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\252-archive-case-sensitivity\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\252-archive-case-sensitivity\probe\arc252_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`):

| Row | Before (HEAD 1cc16d0e build) | After |
|---|---|---|
| TAR-HIDE / 7Z-HIDE | FAIL - both twins hidden, only z.txt copied | PASS - A.txt (UPPER) + z.txt |
| TAR-GLOBAL / 7Z-GLOBAL | FAIL - both twins restored and copied | PASS - only a.txt (lower) |
| TAR-TREE | FAIL - merged folder, only d/y.txt extracted (D/x.txt lost) | PASS - D/x.txt, d/y.txt |
| 7Z-TREE | FAIL - merged into d/ (x.txt in the wrong folder) | PASS - D/x.txt, d/y.txt |
| TAR-CONTROL / 7Z-CONTROL | PASS | PASS (no twins: unchanged) |

Totals: before 6 FAIL / 10 PASS, after 16 PASS / 0 FAIL / 0 NOT DRIVEN; registry restored and
identical in every run. Negative controls: the TAR flag kept without twins -> TAR-CONTROL FAIL
(`probe/result_negctl_tar_always_cs.txt`); the legacy half of the rule removed -> saltests 1 failed.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED, 0 compiler warnings / errors.
- `saltests.exe`: 24375 checks, 0 failed.
- Probe: 16 / 0 (above).

## Reviews (findings and what was done)

One independent refute-first review: no MUST. SHOULD 1 (the design rationale wrongly said
Windows archives with one folder spelled in two cases are not split) - spec and research corrected,
named as a known change. SHOULD 2 (a TAR folder entered in another case extracts nothing,
pre-existing) - Inbox item. NOTE 1 (probe did not check contents) - content check added, re-run
16 / 0. NOTE 3 (cost) - the reviewer's benchmark recorded in fix-log.md (1,000,000 names in one
folder 0.96 s ASCII / 4.46 s non-ASCII). NOTE 4 (ZIP leftover) - Inbox item. Details:
fix-log.md *Review*.

## Owed to a person (with the new person-step items)

- `paste-of-a-case-twin-from-an-archive-and-sftp-twins-by-hand` - the clipboard Paste of one twin
  from a TAR / 7z archive (the item's own *Expected*) and the SFTP twin rows (the test container was
  not running).

## New Inbox items (slug - title)

- `copying-from-a-tar-folder-opened-in-another-case-extracts` - Copying from a TAR folder opened in
  another case extracts nothing (review:252)
- `a-zip-made-on-windows-that-holds-names-differing-only-in` - A ZIP made on Windows that holds names
  differing only in case is not case-sensitive (leftover:252)
- `paste-of-a-case-twin-from-an-archive-and-sftp-twins-by-hand` - Paste of a case twin from an
  archive and SFTP twins by hand (252) (leftover:252, person step)
