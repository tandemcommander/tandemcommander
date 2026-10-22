# Quickstart - validating 301-subst-target-whole

Prerequisites: a Debug x64 build (`.\build.cmd` from the repository root, PowerShell); no
`tandemcommander.exe` running.

1. Encoding guard (Bash): `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
2. Unit rules (PowerShell): `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` ->
   `saltests: <n> checks, 0 failed` (includes `TestSubstTarget301`).
3. Imports (PowerShell): `dumpbin /imports build\tandemcommander\Debug_x64\tandemcommander.exe |
   Select-String QueryDosDevice` -> only `QueryDosDeviceW`.
4. Probe (PowerShell, hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\301-subst-target-whole\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\301-subst-target-whole\probe\subst_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: `Rows: PASS 9, FAIL 0, NOT DRIVEN 0`, subst left defined 0, fixture removed True,
   registry restored+identical True. Before the fix: 7 / 2 (CJK DEL, CJK INFO).
5. Person step (needs the clipboard): share a folder (or use an existing share), make in it a
   folder of 80 CJK letters, `subst Z: "<that folder>"`, a file in it, *Copy Full Path as UNC* on
   the file -> the clipboard holds the exact `\\machine\share\...` path (or the program says the
   path is too long) - never `?`; `subst Z: /d` afterwards. (A subst to an unshared folder has no
   UNC form: the program says so, before and after.)
