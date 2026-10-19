# Quickstart - validating 248-folders-column-names

Prerequisites: a Windows whose shell column names hold non-ASCII letters (here cs-CZ, ACP 1250);
no other `tandemcommander.exe` running (the probe shares `HKCU\Software\Tandem Commander`).

1. Build: `.\build.cmd` (PowerShell, repository root) → `BUILD SUCCEEDED`.
2. Encoding guard: `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
3. Probe on the hidden desktop (PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\248-folders-column-names\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\248-folders-column-names\probe\folders248_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: rows PATH, NAME, CELLS, COL2 ("Typ položky"), COL3 ("Datum změny"), END PASS; COL1
   ("Velikost") INFO; `registry restored+identical: True`. Before the fix (`-Expect before` with
   the old build) COL2 and COL3 FAIL - the negative control.
4. By hand: open `fld:` in the Detailed view and look at the header line.
