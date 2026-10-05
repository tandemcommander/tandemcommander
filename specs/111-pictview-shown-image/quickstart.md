# Quickstart: feature 111

Automated (hidden desktop; close an installed Tandem Commander first; Windows PowerShell 5.1; Python
with Pillow; the WebClient service running for the two WebDAV rows):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 2400 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\111-pictview-shown-image\probe\shown_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile result.txt"
```

Expected on this build: every row PASS, 2 NOT DRIVEN rows (the recycle bin, the real wallpaper
call), `wp-real PASS` (the real wallpaper registry values and `SPI_GETDESKWALLPAPER` unchanged).
The build before (`build\tandemcommander\Debug_x64_pre111`) MUST be run with `-NoWallpaper` (its
wallpaper commands would change the desktop of the session): see `probe/shown_result_pre111.txt`.
`-Only ren-*,two-save` runs single rows.

The wallpaper rows run only with the dry-run seam: the probe sets `TC_PICTVIEW_WALLPAPER_DRYRUN`
to a log file and refuses to send a wallpaper command when the seam's name is not in
`pictview.spl`. With the seam the program writes the picture file but no registry value and calls
no `SystemParametersInfo`.

By hand (Release build, a real mouse) - owed:
1. F3 on a photo; *File > Rename* to a name with accents: renamed, the window keeps the image and
   its zoom. Same with *Delete* (Recycle Bin): the file is in the Recycle Bin, the window title is
   `<Deleted>`; *Save As* still saves the image.
2. Open the same photo twice (F3 twice); in one window *Save As* over it with rotation 90: both
   windows show the rotated image.
3. A 1-bit PNG or a fax TIFF: *Save As* offers "2 colors" and, for TIFF, CCITT G3/G4; an opaque
   PNG saved from a screenshot tool does not ask about the alpha channel; a PNG with transparency
   does.
4. *File > Set as Wallpaper > Stretch* on a photo: the desktop shows it; `%LOCALAPPDATA%\Tandem
   Commander\PictView_Wallpaper.bmp` exists; *Restore Previous* brings back the previous
   background; *None* removes it. **This changes your desktop** - note your background first.
5. TIFF with a comment in Czech: Explorer's Properties > Details show it as Title/Subject; JPEG with
   a comment: an EXIF tool shows it without a trailing NUL.
