# Quickstart - 278-regedt-find-regexp-cp

1. Build: PowerShell `.\build.cmd` → `BUILD SUCCEEDED`.
2. Rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → `0 failed`; the checks
   `TestRegFindTextToCodePage278` cover 65001 (`čččč bar` = 12 bytes ending `bar`; an 8-byte
   space refused; the old unit sizing loses `bar` - negative control), 932, 1250.
3. Regression on code page 1250: re-run feature 257's probe on the hidden desktop
   (`specs/257-regedt-find-words-hex/probe/find_words_hex_probe.ps1`, rows unchanged: 9 / 0).
4. GUI under a multi-byte code page (person): Windows *Region* → *Administrative* → *Change system
   locale* → *Beta: Use Unicode UTF-8*, restart; create `HKCU\Software\tc278` with REG_SZ `v` =
   `čččč bar`; Registry Editor Find in that key, Regular expression `bar`, Look at data → `v`
   found; with Whole words → found.
