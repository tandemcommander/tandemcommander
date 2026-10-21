# Quickstart - validating 293-infoline-realloc-pair

1. Encoding guard (Bash, repository root): `python tools/check_encoding.py --strict` → last line
   `TOTAL: 0 finding(s)`.
2. Build (PowerShell): `.\build.cmd` → `BUILD SUCCEEDED`.
3. Unit rules (PowerShell): `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → last line
   `saltests: <n> checks, 0 failed`; the checks of `TestGrowBufferPair293` cover the four outcomes of
   [data-model.md](data-model.md) and the fresh-line case.
4. Negative control: build `saltests` with the old rule (results stored only when both succeed)
   substituted in `salgrowpair.h` → the moved-block checks fail; restore the rule.
5. Reading proof: `CStatusWindow::SetText` grows only through `SalGrowBufferPair`; no other code
   writes `Text`, `AlpDX` or `Allocated` except the constructor and destructor (grep in fix-log).
