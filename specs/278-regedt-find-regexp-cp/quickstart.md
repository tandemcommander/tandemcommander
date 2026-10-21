# Quickstart - 278-regedt-find-regexp-cp

1. Build: PowerShell `.\build.cmd` → `BUILD SUCCEEDED`.
2. Rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → `0 failed`; the checks
   `TestRegFindTextToCodePage278` cover 65001 (`čččč bar` = 12 bytes ending `bar`; an 8-byte
   space refused; the old unit sizing loses `bar` - negative control), 932, 1250.
3. Regression on code page 1250: re-run feature 257's probe on the hidden desktop
   (`specs/257-regedt-find-words-hex/probe/find_words_hex_probe.ps1`, rows unchanged: 9 / 0).
4. GUI under a multi-byte code page (person): Windows *Region* → *Administrative* → *Change system
   locale* → *Beta: Use Unicode UTF-8*, restart; create `HKCU\Software\tc278` with REG_SZ `v` =
   `čččč bar`, a REG_SZ named `čččč bar` with the data `x`, and a subkey `čččč bar`; Registry
   Editor Find in `tc278`, Regular expression `bar`, only Look at data → `v` found; only Look at
   values → the value `čččč bar` found; only Look at keys → the key `čččč bar` found; each also
   with Whole words → found. Afterwards delete `tc278` and restore the system locale setting.
