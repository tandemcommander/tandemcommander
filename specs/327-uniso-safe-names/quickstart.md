# Quickstart - validating 327-uniso-safe-names

Prerequisites: Debug x64 build (`.\build.cmd`), Python on Windows, WSL Ubuntu (xorriso is fetched
into `~/tc-xorriso` by the script once), IMAPI2 (Windows).

1. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestArcItemName327`, see [contracts/item-name.md](contracts/item-name.md)).
2. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\327-uniso-safe-names\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\327-uniso-safe-names\probe\iso327_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every NAME, OUTSIDE and STREAMS row PASS for JOLIET, UDF, XBOX, PLAIN, HFS, VOL
   (before: 39 FAIL).
3. Regressions: `specs\326-uniso-rrip-without-rr\probe\iso326_probe.ps1` (28 / 0) and
   `specs\322-uniso-hfs-btree-joliet\probe\iso322_probe.ps1` (18 / 0) the same way.
