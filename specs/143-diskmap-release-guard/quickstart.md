# Quickstart: verifying feature 143

## Build and unit checks

```batch
build.cmd
build\tandemcommander\Debug_x64\saltests.exe        :: TestLoopClose143 among them, 0 failed
python tools\check_encoding.py                        :: TOTAL: 0
```

## Probe (hidden desktop; no other tandemcommander.exe may run)

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -CommandLine "powershell -File specs\143-diskmap-release-guard\probe\release_guard_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect fixed -OutFile <out>"
```

Expected on this build: every row PASS (E0-E5 clean exit within 25 s, the file of E4/E5 kept; E6 and M3 keep the map;
U1-U4 decline within 1 s). The control `probe/result_pre143.txt` (build before): E1, E4, E5, E6, U1 FAIL
(crash), the rest PASS.

Regression: the 118 probe's Disk Map rows -
`specs/118-plugin-update-close/probe/update_close_probe.ps1 -Expect fixed -Only M1,M2,M3,M4,X1`.

## Owed to a person

- The same rows with a real mouse on the visible desktop: right-click a file in the map, leave
  the menu open, close the program from the taskbar (the menu closes when the map loses
  activation - the crash needs the menu to stay, e.g. sign-out or an update in the background).
- Delete from the map's menu with a real confirmation, then exit the program from its main
  window while the confirmation is open: answer the confirmation, then "force" Yes.
