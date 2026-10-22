# Quickstart - 309-tar-link-members

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestTarLink309`).
3. Probe (hidden desktop; registry backed up and restored by the probe):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\309-tar-link-members\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\309-tar-link-members\probe\link309_probe.ps1 -Label after -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: every row PASS - UNP-HARD-DEL, UNP-HARD-PAX-DEL, UNP-HARD-GNU-DEL (all files, archive
   deleted, nothing asked), UNP-HARD-MISSING-DEL and UNP-SYM-DEL (a box naming the member, archive
   kept), UNP-HARD-TWIN-DEL (a.txt intact), COPY-HARD (4 files).
4. Regressions: `specs\308-pax-deep-unpack\probe\unp308_probe.ps1` -> 12 / 0;
   `specs\306-tar-pax-headers\probe\pax306_probe.ps1` -> 28 / 0.
5. By hand (a person, optional): a real GNU tar backup with hard links, Unpack with "Delete archive
   after unpacking" - every name present; a Linux package tarball with symbolic links - one box, archive kept.
