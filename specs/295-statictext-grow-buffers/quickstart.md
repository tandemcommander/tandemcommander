# Quickstart - validating 295-statictext-grow-buffers

1. Encoding guard (Bash, repository root): `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
2. Build (PowerShell): `.\build.cmd` → `BUILD SUCCEEDED`.
3. Unit rules (PowerShell): `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` →
   `saltests: <n> checks, 0 failed`; `TestGrowBuffers295` (five buffers, every single failure and
   chosen combinations) and feature 293's `TestGrowBufferPair293` both pass.
4. Negative control: temporarily change `SalGrowBuffers` to store results only when all grew (the
   old pair rule) or to release earlier results on a failure (the old `SetText`), rebuild saltests →
   failures in `TestGrowBuffers295`; restore, rebuild (touch the header) → 0 failed.
5. Reading proof (fix-log): `CStaticText::SetText` calls the rule with the same sizes and order as
   before; `SetSize` writes only after the check; every reader of `Size` checks NULL.

No GUI probe: memory exhaustion between the calls cannot be produced on the running program.
