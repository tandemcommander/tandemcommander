# Quickstart - validating 374

1. Build: `.\build.cmd full` (Debug x64) -> `BUILD SUCCEEDED`.
2. Unit rules: `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `0 failed`
   (salwsl.h checks).
3. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\374-wsl-drive-item\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\374-wsl-drive-item\probe\wsl374_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Rows: the real distributions listed (SC-001), the option off (SC-002), a fake key with no /
   one / unusable distributions, the drive bar button and tooltip, choosing an item opens
   `\\wsl.localhost\<name>`, the checked item on a WSL path, no distribution started by the
   build (SC-003), the build time with the option on vs off (SC-004), the option saved (SC-005).
4. By hand (owed to a person): the menu shows the penguin icon; the drive bar drop-down opens
   its menu with a real mouse click.
