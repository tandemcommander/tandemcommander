# Quickstart - 359-uniso-udf-vat-cut

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoUdfVat_359`).
3. Probe (needs WSL Ubuntu for mkudffs):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\359-uniso-udf-vat-cut\probe\run_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\359-uniso-udf-vat-cut\probe\iso359_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\359-uniso-udf-vat-cut\probe\result_after.txt"
   ```

   Expected: every row PASS (L-RAWCUT / R-RAWCUT answer with the read-error box, L-CUT0 the read error,
   L-CUT3 / R-CUT3 the missing-VAT box, L-RAWFULL the read error, L-MKCDR no window); registry restored,
   identical.
4. Regression: `specs\358-uniso-udf-vat-missing\probe\iso358_probe.ps1` the same way -> 40 / 0.
