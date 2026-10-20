# Quickstart: validate 253

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed`
   (`TestAttrsLink253`).
3. Probe on the hidden desktop (PowerShell, from the repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\253-attrs-link-own-entry\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\253-attrs-link-own-entry\probe\attrs_link253_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: COMP, UNCOMP, TIME, SUBC, PLAIN PASS (before: the first four FAIL); ENC NOT DRIVEN;
   registry restored + identical.
4. Regression: 213's `specs\213-attrs-case-links\probe\attrs_case_link_probe.ps1` -> 8 / 0.
5. Person (a machine with an EFS certificate): Change Attributes -> Encrypted on a junction shows
   "Error encrypting" for the junction; the target folder stays unencrypted.
