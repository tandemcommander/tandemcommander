# Quickstart - validating 358-uniso-udf-vat-missing

Prerequisites: WSL Ubuntu (mkudffs is fetched by `specs/356-uniso-udf-rest/probe/mkudf356.sh`), Python, the
Debug x64 build (`build.cmd`). No other `tandemcommander.exe` running.

1. Unit rules (PowerShell): `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> last line
   `saltests: <n> checks, 0 failed` (group `TestIsoUdfVat_358`).
2. Probe (PowerShell, from the repository root):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\358-uniso-udf-vat-missing\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\358-uniso-udf-vat-missing\probe\iso358_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\358-uniso-udf-vat-missing\probe\rows_after.txt"`
   -> every row PASS (before the fix: 8 FAIL rows - R-VCDR100, R-VCLAIM16, R-VCLAIM100Z, L-VCDR100, END + RUN).
3. Regression: probe 356 (`specs\356-uniso-udf-rest\probe\iso356_probe.ps1`) -> 56 / 0.
4. Negative control: the rule `SalIsoUdfVatTranslates` mutated to `<=` -> saltests fails.
