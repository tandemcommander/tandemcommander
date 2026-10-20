# Closing report - 271-zip-case-twins
Backlog item: a-zip-made-on-windows-that-holds-names-differing-only-in - A ZIP made on Windows that holds names differing only in case is not case-sensitive
Outcome: closed

## What changed

- The ZIP plug-in builds its listing case-sensitively and keeps `SALDIRFLAG_CASESENSITIVE` when an
  entry was made on Unix (as before) or when a folder holds names that differ only in case (252's
  `SalDirTreeHasCaseTwins`); otherwise it clears the flag - ordinary ZIPs are listed as before
  (`src/plugins/zip/list.cpp`, `list.h`).
- The listing's decision is kept in its own `CPluginDataInterface` (`zipdll.h`); copy out, Paste,
  view / edit one file and Delete start the plug-in's name comparison from it (`main.cpp`;
  `extract.cpp` no longer overwrites it). A folder without an entry of its own is now matched with
  the listing's case sensitivity - this also ends a data loss in Unix-made ZIPs (deleting folder
  "d" deleted the files of "D").
- No plug-in interface change, no UI strings, no core change.

## Measurements (before / after, commands)

Probe `probe/zip271_probe.ps1` on the hidden desktop
(`powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\271-zip-case-twins\probe\zip271_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`):
- before (671ae06b, `probe/result_before.txt`): 6 FAIL / 10 PASS - ZIP-HIDE, ZIP-GLOBAL, ZIP-ONE,
  ZIP-DEL, UNIX-ONE, UNIX-DEL (UNIX-DEL: deleting folder "d" also deleted D/x.txt);
- after (`probe/result_after.txt`, with review 1's tightened ZIP-TREE row): 16 / 0;
- negative control (listing switch forced off, `probe/result_negctl_no_listing_switch.txt`):
  4 FAIL (ZIP-ONE, ZIP-DEL, UNIX-ONE, UNIX-DEL);
- regressions: 110's `zipname_probe.ps1` 42 / 0, 164's `zip_delete_cost_probe.ps1` 6 / 0.
Registry restored and identical in every run.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- `.\build.cmd` -> `BUILD SUCCEEDED` (zip.spl rebuilt)
- `saltests.exe` -> `saltests: 24816 checks, 0 failed`
- probes as above: 16 / 0 (0 NOT DRIVEN), 42 / 0, 6 / 0

## Reviews (findings and what was done)

One refute-first review, no MUST (re-ran the probe 16 / 0, own rows SUB-DEL / SUB-ONE PASS, own
negative control failed SUB-DEL as expected).
- SHOULD 1 (adding into a twin ZIP replaces the other twin; measured ADD-DIR / ADD-FILE): outside
  the item -> the Inbox item recorded during the run, rewritten with the measurements.
- NOTE 1 (ZIP-TREE did not prove the folders are apart): fixed - the row requires "Copy 2
  directories"; re-run 16 / 0.
- NOTE 2-6: recorded in `fix-log.md` *Review* (no change needed).

## Owed to a person (with the new person-step items)

- Clipboard Paste of a twin from a Windows-made twin ZIP: a log line added to the existing person
  step `paste-of-a-case-twin-from-an-archive-and-sftp-twins-by-hand`.

## New Inbox items (slug - title)

- adding-a-file-into-a-zip-that-holds-names-differing-only-in - Adding a file into a ZIP that holds
  names differing only in case can replace the other twin
