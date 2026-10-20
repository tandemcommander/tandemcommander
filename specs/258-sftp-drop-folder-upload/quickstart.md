# Quickstart - validating feature 258

Prerequisites: Debug x64 build (`build.cmd`), Python with paramiko (`python -c "import paramiko"`),
Docker container `tandem-sftp` on localhost:2222 for the regression.

1. Pure rules: `src\plugins\sftp\test\build_and_run.cmd` -> `... passed, 0 failed`.
2. Feature probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\258-sftp-drop-folder-upload\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\258-sftp-drop-folder-upload\probe\sftp258_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: rows DROPNEW, DROPEXIST, DROPMOVE, DROPDIR, REPL, CUT PASS; END rows PASS;
   registry restored + identical.
3. Regression: 133's probe (`specs\133-sftp-server-verify\probe\sftp133_probe.ps1`) on the
   container - all rows PASS as before.
