# Quickstart: validating 256

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`; `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (checks of `SalMenuCharAnswer`, `SalDlgHotKeyW`, `SalDlgHotKeyVkMatch`, `SalDlgHotKeyCharMatch`).
3. Probe (no other tandemcommander.exe running), from the repository root:
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\256-popup-wide-mnemonics\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\256-popup-wide-mnemonics\probe\pm256_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
   Expected: ZH, CC, AS rows PASS (ZH before: the "&?" item ran), END rows PASS, registry identical.
4. Person (real keyboard): a User Menu item "&Ж..." with a Russian layout; on a Japanese (DBCS) and a
   UTF-8 (beta) system a full-width hot key typed through the IME; TortoiseSVN's context menu
   (right-click in a working copy, type a submenu item's hot key); the Find window with the Russian
   language and Options collapsed, Alt + a hidden control's Cyrillic hot key.
