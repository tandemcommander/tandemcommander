# Quickstart - validating 416

1. Build: `.\build.cmd full` (new strings, resources) -> `BUILD SUCCEEDED`.
2. Pure rules and offline rasterization: `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `0 failed`
   (`TestIconSet416`: set id, paths, name tables, preview list, override choice, every Fluent file at 16/20/24/32 px
   in light and dark: shapes, coverage, contrast against the toolbar backgrounds and the menu highlight).
3. Data check: `python tools/brand/fluent-icons/check_iconset.py` -> every name the code uses exists in both
   folders, no mask-key colour, tokenizer emulation 0 problems.
4. GUI probe on the hidden desktop (registry backed up and restored):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\416-fluent-icon-set\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\416-fluent-icon-set\probe\iconset416_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`
   Rows: default = Fluent (no value), Classic equals the `before` captures, the switch through the Appearance page's
   OK applies without restart, the value persists, empty dark override falls back, Appearance page captured, label
   fit in 8 languages.
5. Before captures: the same probe with `-Label before` on the build of `main` (Classic only exists).
