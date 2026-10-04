# Quickstart: feature 105

Automated (hidden desktop; close an installed Tandem Commander first; Windows PowerShell 5.1):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 2400 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\105-pictview-saveas-loss\probe\saveas_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile result.txt"
```

Expected on this build: every row PASS, "existing files LOST: 0", 4 NOT DRIVEN rows. The build
before this feature (`build\tandemcommander\Debug_x64_pre105`) fails every save and loses the
existing file in every "replace" row (see `probe/saveas_result_pre105.txt`).
`-Only offer,new-png,locked` runs single rows (`new-*`, `tif-*` patterns allowed).

By hand (Release build, a real mouse):
1. F3 on a photo; Ctrl+S (or *File > Save As...*): the type list holds Windows Bitmap, GIF, JPEG,
   PNG and TIFF only. Save as PNG under a new name: the file opens in another viewer.
2. Save As onto an existing file, *Yes*: replaced. Make the file read-only first: the read-only
   question, *Yes* replaces it, *No* leaves it.
3. Open the existing file in another program that locks it (e.g. a Word document's picture is
   not enough - use `powershell -c "$f=[IO.File]::Open('x.png','Open','Read','Read'); pause"`):
   Save As onto it, *Yes*: "Unable to save the image. Error: The process cannot access the
   file ..."; the file is unchanged and no `pv*.tmp` is left in the folder.
4. Save As onto the image the window shows, rotation 90: the window shows the rotated image.
5. JPEG with *Options*: quality 10 vs 95 (file size), a comment with accents (shown by any
   EXIF/metadata tool as UTF-8 text).
6. Not testable without hardware/admin (owed): a disk that fills during the save (a small VHD
   or a USB stick): the target unchanged, the system's "disk is full" text, no `pv*.tmp`.
