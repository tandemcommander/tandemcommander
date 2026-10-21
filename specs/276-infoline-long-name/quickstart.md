# Quickstart - validating 276

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestInfoLineBuf276`).
3. Probe on the hidden desktop:

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\276-infoline-long-name\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\276-infoline-long-name\probe\infoline276_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (PIXCTL, ARCCAP, ARCMAX, ARCDEEP, DISK, ARCSHORT - FOCUS, LINE, END);
   before the fix ARCCAP and ARCDEEP FAIL (one box, line unchanged).
4. Regressions: 260's `cache260_probe.ps1` (16 / 0) and 275's `arcmember275_probe.ps1` (17 / 0).
5. By hand (a person): open a ZIP with a member of 200 CJK letters + ".txt", move the cursor onto
   it - no box, the information line shows the name, its size, date, time and attributes, and
   the name a second time where the short name stands.
