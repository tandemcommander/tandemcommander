# Quickstart - validating 285

1. Build Debug: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestUncShareListSignIn285`).
3. Probe on the hidden desktop (PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\285-share-list-sign-in\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\285-share-list-sign-in\probe\signin_probe.ps1 -Expect fixed -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: rows A1, A2, C1, F1, W1, K1, N1, R1 PASS, every END row PASS, registry restored and
   identical. Before the change (`result_before.txt`, `-Expect measure`) A1..K1 show the error box
   "(5)" and no sign-in.
4. Release has no seam: a string search of the Release `tandemcommander.exe` for
   `TC_PROBE_UNC_SIGNIN` finds nothing.
5. A person (real file server that refuses the list to an anonymous / current user): open
   `\\server\` -> Windows' sign-in dialog -> sign in -> the share list; Esc / Cancel in the dialog;
   a wrong password; *Remember my credentials* stored by Windows only when ticked.
