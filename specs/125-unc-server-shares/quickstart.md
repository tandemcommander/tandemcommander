# Quickstart: validating feature 125

Prerequisites: no `tandemcommander.exe` running; Debug tree from `build.cmd full`.

```powershell
# 1. pure rules
build\tandemcommander\Debug_x64\saltests\saltests.exe        # all checks pass (TestUncServer125 among them)

# 2. the probe on the fixed build (hidden desktop)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_on_hidden_desktop.ps1 -Log $env:TEMP\tc125.log -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\tandemcommander\specs\125-unc-server-shares\probe\unc_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Expect fixed -OutFile E:\Projects\tandemcommander\specs\125-unc-server-shares\probe\unc_result.txt"

# 3. controls: the same probe with -Expect measure on Debug_x64_v019 (error boxes) and on a
#    build with nethood=on (the plug-in keeps priority)
```

Expected in step 2: `FAIL 0`. By hand (a person, a real network): Shift+F7, `\\<file server>\`,
Enter - a menu with the server's shares under the path line; Enter on one opens it; Esc returns
to the dialog. A wrong server name: after a few seconds a message with the Windows reason; Esc
during the wait cancels.
