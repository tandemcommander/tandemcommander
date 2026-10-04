# Quickstart: feature 106

Automated (hidden desktop; close an installed Tandem Commander first; Windows PowerShell 5.1;
7-Zip 22+ at `C:\Program Files\7-Zip\7z.exe` reads the results):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 2400 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\106-zip-overwrite-source\probe\packself_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile result.txt"
```

Expected on this build: every RUN/END row PASS (70; "loss 0" in every row), 4 NOT DRIVEN rows. The
build before (`build\tandemcommander\Debug_x64_pre106`) loses a source in every A, C, D row and
the declined file in E-decline-vol2 (`probe/packself_result_pre106.txt`). `-Only A-,C-same`
runs single rows (prefixes).

By hand (Release build, a real mouse and keyboard):
1. A folder with `a.z01` (any file) and `b.txt`; select both, Alt+F5, ZIP, name `a.zip`, OK; in
   *Extended Pack Options* check *Create multi-volume archive*, size 1 KB, OK: the message "This
   file is one of the files being packed ..." names `a.z01`; no overwrite question; both files
   unchanged.
2. The same with the archive name typed as `\\localhost\C$\...\a.zip` (an administrative share
   of the same disk): the same refusal.
3. Select `src.zip` and `b.txt`, Alt+F5, name `src.zip`, OK, *Overwrite*: "Cannot copy a file
   to itself." and the Pack dialog again; `src.zip` unchanged. With *Add* the old behaviour
   (the ZIP plug-in reports a sharing violation for `src.zip` - *Skip*).
4. A folder `out` with an unrelated `a.z02`; pack a 20 KB file from elsewhere as multi-volume
   `out\a.zip`, 4 KB volumes; at "Overwrite file a.z02?" press *Cancel*: `a.z02` is still there.
5. Not testable here (owed): multi-volume onto removable media with disk changes; a
   self-extracting archive (needs an SFX package, not shipped); the RAR packer (WinRAR).
