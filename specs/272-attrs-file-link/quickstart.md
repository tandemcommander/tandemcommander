# Quickstart: validate 272

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed`
   (`TestAttrsLink253`, `TestAttrsFileLink272`).
3. Probe on the hidden desktop (PowerShell, from the repository root; file links need Developer
   Mode or the privilege):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\272-attrs-file-link\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\272-attrs-file-link\probe\attrs_flink272_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: COMP, UNCOMP, TIME, SUBC, PLAIN, NONLINK PASS (before: the first four FAIL); ENC NOT
   DRIVEN; registry restored + identical.
4. Regressions: 253's `specs\253-attrs-link-own-entry\probe\attrs_link253_probe.ps1` -> 10 / 0
   (1 NOT DRIVEN); 213's `specs\213-attrs-case-links\probe\attrs_case_link_probe.ps1` -> 8 / 0.
5. Person (a machine with an EFS certificate): Change Attributes -> Encrypted on a file symbolic
   link shows "Error Changing Encryption" for the link; the target file stays unencrypted.
