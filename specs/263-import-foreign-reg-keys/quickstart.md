# Quickstart - validating 263

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestRegImportRoot263`, contract table in [contracts/import-root-rule.md](contracts/import-root-rule.md)).
3. Probe (hidden desktop; registry backed up, restored, verified):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\263-import-foreign-reg-keys\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\263-import-foreign-reg-keys\probe\import263_probe.ps1 -Label after -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: OURS, OWNDEL, MIXED, NOROOT, DELETE all PASS (before: MIXED, NOROOT, DELETE FAIL -
   `probe/result_before.txt`); MIXED and NOROOT show "Unable to import the specified file. It is not a
   configuration file."
4. Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
