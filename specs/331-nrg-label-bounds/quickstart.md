# Quickstart - 331-nrg-label-bounds

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (the `TestNrgCdText331` group: chunk fit, gathered text bounds, label split, DAOX range, names).
3. Regression of the fitting-label path: feature 329's probe, row A-OPEN, on the hidden desktop:
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\331-nrg-label-bounds\probe\result_329_A.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\329-uniso-other-readers-refused\probe\iso329_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Only A-OPEN"`
   -> A-OPEN PASS (the 256-byte name reported, the short one listed).
4. Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
