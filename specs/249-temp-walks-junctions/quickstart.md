# Quickstart: validating 249

Prerequisites: 7-Zip installed (`C:\Program Files\7-Zip\7z.exe`), no `tandemcommander.exe` running,
the Debug x64 build of the branch.

1. `.\build.cmd` -> `BUILD SUCCEEDED`; `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`;
   `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `0 failed`.
2. Probe (PowerShell, hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\249-temp-walks-junctions\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\249-temp-walks-junctions\probe\tempjunction249_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: SWEEP PASS, PLAIN PASS, UNPACK PASS (before: UNPACK FAIL, `probe/result_before.txt`);
   the UNPACK row's windows show the "System error" message naming `top`; registry restored and
   identical.
3. Self-extractor: `cl /Zs` on `src/plugins/zip/selfextr/selfextr.cpp` (compile-only) - no error
   in the changed function.
