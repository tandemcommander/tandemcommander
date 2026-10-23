# Quickstart - validating feature 329

Prerequisites: WSL Ubuntu (genisoimage / xorriso are fetched without root by `probe/mkimg329.sh`),
Python 3, the Debug x64 build (`build.cmd`).

1. Unit rules: `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `saltests: <n> checks, 0 failed`
   (includes the `CSalLeftOutIds` checks).
2. Probe (hidden desktop, from the repository root, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\tc329_log_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\329-uniso-other-readers-refused\probe\iso329_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\329-uniso-other-readers-refused\probe\result_after.txt"
   ```

   Expected: RUN rows U-COPY, X-COPY, H-COPY, U-UNP-DEL, X-UNP-DEL, H-UNP-DEL, A-OPEN all PASS (before
   the fix: 0 / 7); registry restored and identical.
3. Regression: `specs\328-uniso-refused-entry\probe\iso328_probe.ps1`,
   `specs\327-uniso-safe-names\probe\iso327_probe.ps1`, `specs\322-uniso-hfs-btree-joliet\probe\iso322_probe.ps1`
   stay all PASS.
