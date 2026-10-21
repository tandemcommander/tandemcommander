# Quickstart: validating 281

1. `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
2. PowerShell: `.\build.cmd` → `BUILD SUCCEEDED`.
3. `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → `saltests: <n> checks, 0 failed`
   (the `salmoveback.h` checks among them).
4. The probe (hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\281-moved-aside-leftovers\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\281-moved-aside-leftovers\probe\left281_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: every `*-left` row PASS (an "Error Renaming File" box naming the `salNNN` path, the
   other entry's content intact there), every `*-brief` row PASS (nothing left, no such box),
   registry restored and identical.
5. Regression: 203's `create_clash_probe.ps1` and 201's `short_clash_probe.ps1` keep their
   results.
