# Quickstart - validating 262

## Automated

```powershell
python tools/check_encoding.py --strict          # TOTAL: 0 finding(s)
.\build.cmd                                       # BUILD SUCCEEDED
& "build\tandemcommander\Debug_x64\saltests\saltests.exe"   # saltests: <n> checks, 0 failed (TestCodeTable262)
src\plugins\codeview\test\run_tests.cmd           # RESULT: all codeview checks passed (web side unchanged)
```

## By a person (real desktop, CP1250 system code page)

1. F3 on `src/plugins/codeview/test/corpus/encodings/cp852.bat` -> wrong letters, status `ANSI`.
2. *View > Encoding*: the five entries, a separator, the tables as in the built-in viewer's
   *Convert* menu (same order and separators).
3. Choose *CP852 - CP1250* -> "Příliš žluťoučký kůň úpěl ďábelské ódy", status `CP852 - CP1250`,
   the item checked.
4. F8 / Shift+F8 step through the list and wrap.
5. Close, F3 on `cp852.bat` again -> decoded with CP852 - CP1250 at once; restart the program ->
   still so. F3 on `utf8-nobom.cpp`, `utf16le-bom.reg` -> unchanged.
6. Choose *System code page* -> today's letters; F3 on `cp1250.ini` -> correct as today.
