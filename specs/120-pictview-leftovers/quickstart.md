# Quickstart: feature 120

## Without the GUI (done, repeatable)

```
specs\120-pictview-leftovers\probe\pixharness\build_and_run.cmd
```

Builds the harness from the plug-in's engine and reader twice (working tree / git HEAD - pass a
revision of the build before once this feature is committed, e.g. `build_and_run.cmd 7d6ffeb6`)
and compares with Pillow. Expected: `NEW: 0 mismatching checks`, the OLD control > 0.

## GUI runs (owed; hidden desktop; no tandemcommander.exe running; Python with Pillow)

Registry baseline before the runs: `HKCU\Software\Tandem Commander` SHA-256 `9BD42518403B7EDF...`
(each probe exports, restores and verifies the key itself).

1. This build:

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out120.txt -WaitSeconds 2400 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\120-pictview-leftovers\probe\pv120_probe.ps1 -Exe build\tandemcommander\Debug_x64_120\tandemcommander.exe -OutFile specs\120-pictview-leftovers\probe\pv120_result.txt"
```

Expected: `tgt-shown`, `tgt-shown-no`, `tgt-shown-hl`, `hist-png`, `hist-gif`, `hist-alpha`,
`bk-rot`, `cmt-gif-ascii`, `cmt-gif-u8` PASS (each with its END row); `tgt-shown-print` PASS or NOT
DRIVEN (no printer); `hist-*` NOT DRIVEN only if the hidden desktop renders nothing (the capture
shows no tone band); `pip-plain`, `pip-mirror` NOT DRIVEN (hidden desktop).

2. The build before (control):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log outpre120.txt -WaitSeconds 2400 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\120-pictview-leftovers\probe\pv120_probe.ps1 -Exe build\tandemcommander\Debug_x64_pre120\tandemcommander.exe -OutFile specs\120-pictview-leftovers\probe\pv120_result_pre120.txt"
```

Expected FAIL: `tgt-shown`, `tgt-shown-hl` (error 32), `hist-*` (extra levels), `bk-rot` (40x30);
PASS: `tgt-shown-no`, `tgt-shown-print`, `cmt-gif-*`.

3. Regressions on this build (111 and 105 probes, unchanged):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out111.txt -WaitSeconds 2400 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\111-pictview-shown-image\probe\shown_probe.ps1 -Exe build\tandemcommander\Debug_x64_120\tandemcommander.exe -OutFile specs\120-pictview-leftovers\probe\regress_shown111_120.txt"
powershell -File tools\run_on_hidden_desktop.ps1 -Log out105.txt -WaitSeconds 2400 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\105-pictview-saveas-loss\probe\saveas_probe.ps1 -Exe build\tandemcommander\Debug_x64_120\tandemcommander.exe -OutFile specs\120-pictview-leftovers\probe\regress_saveas105_120.txt"
```

Expected: 111 85 / 0 / 2 (as `specs/111-.../probe/shown_result.txt`), 105 56 / 0 / 4 with 0 files
lost.

4. The pipette - ONLY on the visible desktop, ONLY when the maintainer agrees to one run (it moves
the mouse cursor over the viewer for about 10 s per row and puts it back):

```
set TC_PROBE_ALLOW_VISIBLE_DESKTOP=1
powershell -NoProfile -ExecutionPolicy Bypass -File specs\120-pictview-leftovers\probe\pv120_probe.ps1 -Exe build\tandemcommander\Debug_x64_120\tandemcommander.exe -VisiblePipette -OutFile specs\120-pictview-leftovers\probe\pv120_pipette.txt
```

(and the same with `Debug_x64_pre120` and `pv120_pipette_pre120.txt` as the control: FAIL
expected). Do not touch the mouse during the run.

## By hand (Release build, a real mouse) - owed

1. F3 on a photo; *Tools > Pipette* (or the status bar's color panel): the color shown matches the
   pixel under the cursor (compare with a paint program's color picker); mirror the image
   (*Image > Mirror horizontally*): still the pixel under the cursor.
2. *File > Histogram* of a photo: a plausible curve; of a one-color image: one bar per channel.
3. Two windows: A shows `x.png`, B shows `z.png`; in A *File > Rename* to `z.png`, Yes: B now
   shows A's picture under `z.png`.
4. Configuration: a different full-screen background color; rotate an image, full screen on and
   off: still rotated, not squeezed.
