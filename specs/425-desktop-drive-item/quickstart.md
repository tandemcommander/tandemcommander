# Quickstart - validating 425-desktop-drive-item

Prerequisites: `build.cmd full` (Debug x64), no running `tandemcommander.exe`.

1. Unit rules: `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `saltests: <n> checks, 0 failed`
   (`TestDesktopDrive425`).
2. Probe (hidden desktop, PowerShell, from the repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\425-desktop-drive-item\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\425-desktop-drive-item\probe\desktop_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (FLD-ZIP NOT DRIVEN when the desktop holds no zip archive); the registry
   restored and identical.
3. By hand (a person, owed to the release checklist): Alt+F1 -> Desktop opens the Desktop folder;
   the drive bar's Desktop button; Alt+F1 -> Shell Folders -> Enter on Documents gives the disk path;
   the Change Drive page's Desktop check box hides the item; Fluent 2 and Classic icons, light and dark.
