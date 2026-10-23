# Quickstart - 320-zip-failed-replace

1. Build: `.\build.cmd` (PowerShell) -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks,
   0 failed` (TestSafeReplace320 included).
3. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\320-zip-failed-replace\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\320-zip-failed-replace\probe\zipreplace_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: add-locked and del-locked PASS (the replace message, nothing new, nothing changed);
   add-ctl, add-sharedel, del-ctl, del-sharedel PASS; registry restored and identical.
4. Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
