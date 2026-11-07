# Quickstart - validating 417

## Build and unit checks

```text
.\build.cmd full                                             -> BUILD SUCCEEDED
build\tandemcommander\Debug_x64\saltests\saltests.exe        -> saltests: <n> checks, 0 failed (TestPluginIcons417 included)
python tools\brand\fluent-icons\check_iconset.py             -> 0 problems
python tools\check_encoding.py --strict                      -> TOTAL: 0 finding(s)
```

## Regenerating the plug-in icons

```text
python -I tools\brand\fluent-icons\gen_fluent_plugins.py %TEMP%\fluent-1.1.344     (the package of the README)
git diff --stat src\res\iconsets\fluent\plugins                                   -> no change with the pinned package
```

## Hidden-desktop probe

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\417-fluent-plugin-icons\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\417-fluent-plugin-icons\probe\plugin417_probe.ps1 -Exe <build>\tandemcommander\Debug_x64\tandemcommander.exe -Before <build of main>\tandemcommander\Debug_x64\tandemcommander.exe"
```

Expected rows: CLASSIC-EQ (0 px vs the build of main), FLUENT (every Plugins bar icon differs from Classic and is
drawn; the drive bar's plug-in buttons differ), DIRLINE (RegEdit's directory line is its set icon; Folders' equals
Classic), SWITCH / SWITCHBACK (no restart), CACHE (the stored plug-in icons equal after Fluent 2 and Classic
sessions), OVR (an empty or missing set file = today's icon), MANAGER, FIT.

## By hand (release checklist)

- Open the Plugins menu, a plug-in submenu, View With and Alt+F1 in Fluent 2 Light and Dark: every plug-in icon is
  its set icon, legible on the highlight; at 150 % sharp.
- Configuration > Appearance: the group reads "Icon style"; Alt+I moves to it.
