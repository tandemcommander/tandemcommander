# Quickstart - validating 387

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` ->
   `saltests: <n> checks, 0 failed`; `TestRegViewTextToCodePage387` covers 65001 / 932 / 1250,
   the UTF-16 fallback, the empty value, REG_MULTI_SZ and the negative control (old sizing).
3. Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
4. GUI (a person, a machine with the ANSI code page UTF-8 - "Beta: Use Unicode UTF-8 for
   worldwide language support" - or 932): Registry Editor, a REG_SZ value `a€ čččč bar`,
   F3 -> the viewer shows the whole text. On code page 1250 the result is the old one.
