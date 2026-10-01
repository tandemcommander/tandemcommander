# Quickstart: verifying feature 089

| What | How | Expected |
|---|---|---|
| unit tests | `saltests.exe` | 0 failed (`TestSplUnicode089`, `TestArcAssoc089`) |
| associations | `probe\assoc_probe.ps1 -Exe <Debug exe>` | the three configurations end identical; a second start changes nothing |
| engine regression | `python specs\087-7zip-2603-rar\probe\run_engine_probe.py <7za.dll>` | 0 failed |
| update regression | `specs\088-plugin-interface-107\probe\viewers_probe.ps1` | 10 / 10 |

## Owed to a person

1. *Archives Associations in Panels* after an update from 0.1.8: `rar;r##` =
   7-Zip plug-in (view) + RAR (WinRAR) (edit).
2. With WinRAR installed: copy a file into an open RAR archive → packed by
   WinRAR.
3. A 7z archive with a lone-surrogate name: list, extract, pack.
4. Add a file into a cleaned-name folder of a 7z archive: overwrite question,
   one item afterwards.
