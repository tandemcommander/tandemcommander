# Quickstart: validating 252

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (the checks of `salcasetwins.h`: ASCII twins, identical duplicates, legacy-only and Unicode-only
   twins, nested tree, empty tree).
3. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\252-archive-case-sensitivity\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\252-archive-case-sensitivity\probe\arc252_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\252-archive-case-sensitivity\probe\result_after.txt"
   ```

   Rows for TAR and 7z: HIDE (Hide Selected Names on one twin, Select All, F5 into a case-sensitive
   folder: the other twin + z.txt arrive), GLOBAL (Store / Restore Selection of one twin, F5: only it
   arrives), TREE (D/x.txt + d/y.txt: Select All, F5: both arrive in two folders), CONTROL (an
   archive without twins: `<archive>\DOCS` enters `Docs`). Before the fix: HIDE / GLOBAL / TREE fail,
   CONTROL passes; after: all pass.
4. Person: the clipboard Paste of a.txt from such an archive; SFTP Hide Selected Names on a.txt /
   A.txt on the test server.
