# Quickstart: validating 259

1. Build: `.\build.cmd` (PowerShell, repository root) - `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` - `0 failed`;
   `TestCopyName259` covers the rule (contract: [contracts/copy-name-rule.md](contracts/copy-name-rule.md)).
3. Edit New File probe (hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\259-long-name-refusals\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\259-long-name-refusals\probe\editnew259_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: SHORT, REL, ABS, CJK, OVER all PASS (before: REL, ABS, CJK FAIL); registry restored
   identical.
4. Encoding guard: `python tools/check_encoding.py --strict` - `TOTAL: 0 finding(s)`.
5. Owed to a person (clipboard): in a folder holding "84 CJK letters.txt" Ctrl+C, Ctrl+V - a
   "- Copy" file appears; with "250 ASCII letters.txt" - the "too long" question, no file, never
   "to itself"; both files selected together, Skip - the short one is copied, the long one not.
