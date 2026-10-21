# Quickstart - validating 283

Prerequisites: Debug x64 build (`build.cmd`), Python, the hidden-desktop runner.

1. Build: PowerShell `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed` (the 283 checks: classification table, ASCII differential, old-fold defects under an emulated CP1250 table, continuation bytes never fold to ASCII in any ANSI code page).
3. Probe (hidden desktop):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\283-mask-code-page-fold\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\283-mask-code-page-fold\probe\mask283_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
   Expected: `Rows: PASS 20, FAIL 0, NOT DRIVEN 0`, registry restored+identical True (before: 14 / 6 / 0).
4. Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.

Owed to a person (optional, the probe covers it): Select (Num +) with `*.čtx` in a folder holding `A.ČTX` selects it.
