# Quickstart: verifying feature 086

## Automated (run by the implementation session, results in `fix-log.md`)

| What | How | Expected |
|---|---|---|
| generator | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `0 failed` (group `TestRandom086`) |
| imports | `python -c "import sys; sys.path.insert(0,'tools'); import check_runtime_deps as c; print('bcrypt.dll' in c.pe_imports(r'build\tandemcommander\Debug_x64\plugins\zip\zip.spl'))"` | `True` (same for `tandemcommander.exe`) |
| salt reader | `python specs\086-zip-aes-salt\probe\zip_salts.py --selftest` | `selftest: PASS` (reads archives 7-Zip makes with AES-256 and ZipCrypto) |

## Owed to a person (needs the Pack dialog)

Prerequisite: 7-Zip (`C:\Program Files\7-Zip\7z.exe`). Use the Debug or
Release build; any test folder; password `Zz086test`.

1. **AES-256, two archives, one run.** Select one file, Alt+F5 (Pack), ZIP,
   *Encrypt* with AES-256, password `Zz086test` → `a1.zip`; repeat → `a2.zip`.
2. **Restart** the program, repeat → `a3.zip`, `a4.zip`.
3. **AES-128** once → `b1.zip`; **ZIP 2.0** twice → `z1.zip`, `z2.zip`.
4. `python specs\086-zip-aes-salt\probe\zip_salts.py a1.zip a2.zip a3.zip a4.zip b1.zip z1.zip z2.zip`
   → every salt / header listed, `repeats: 0` (SC-001).
5. `"C:\Program Files\7-Zip\7z.exe" t -pZz086test <each archive>` →
   `Everything is Ok` (SC-002, other tool).
6. Open each archive in Tandem Commander and extract with the password → the
   original file, byte-identical (`fc /b`).
7. An encrypted archive made by 0.1.8 (keep one from before the update) opens
   and extracts as before.
