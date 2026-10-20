# Quickstart: validating 271

1. `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
2. PowerShell: `.\build.cmd` -> `BUILD SUCCEEDED` (zip.spl rebuilt).
3. `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed` (no core change; the
   twin rule's checks are 252's).
4. Probe on the hidden desktop:

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\271-zip-case-twins\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\271-zip-case-twins\probe\zip271_probe.ps1 -Label after -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: 16 PASS, 0 FAIL (before: 6 FAIL - ZIP-HIDE, ZIP-GLOBAL, ZIP-ONE, ZIP-DEL, UNIX-ONE,
   UNIX-DEL); ZIP-CONTROL passes before and after; registry restored and identical.
5. Negative control: the operations' switch not taken from the listing (step 3 of the contract
   removed) -> ZIP-ONE / ZIP-DEL / UNIX-* fail again while ZIP-HIDE / ZIP-GLOBAL pass.
