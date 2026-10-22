# Quickstart - validating 299-unpack-dialog-text-fits

Prerequisites: a Debug x64 build (`.\build.cmd`), no other `tandemcommander.exe` running.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Probe (PowerShell, hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\299-unpack-dialog-text-fits\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\299-unpack-dialog-text-fits\probe\unpack299_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: `path-cjk`, `path-ascii`, `mask-cjk` PASS (refused, field whole, nothing under tgt);
   `ctl`, `ctl-path` PASS; every END row PASS; registry restored identical. Before the fix: 3 FAIL
   (`probe/result_before.txt`).
3. Regression: 204's probe, row `f9-zip` (Alt+F9 of a ZIP, target typed) -> PASS
   (`-Only f9-zip`, log `probe/regress_204.txt`).
4. `saltests.exe` -> `0 failed`; `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.

Manual (a person, optional): Alt+F9 on a ZIP, paste a path longer than 260 characters into the
target field, OK -> "The path specified is too long.", the dialog stays.
