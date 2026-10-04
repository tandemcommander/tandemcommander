# Quickstart: feature 108

Automated (hidden desktop; close an installed Tandem Commander first; Python 3 and 7-Zip
(`C:\Program Files\7-Zip\7z.exe`) needed - `probe/arcfix.py` makes and reads the archives):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\108-archive-edit-name-collision\probe\namecoll_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile result.txt"
```

Expected (see `probe/namecoll_result.txt`): every row PASS except `hL1_zip` and `hL2_zip` - an edit of
ONE member of a pair whose names fold together still makes the ZIP plug-in delete the other member
(its own name matching, queued in NEXT-WORK item 5). The build before this feature
(`Debug_x64_pre108`) fails every pair row and both `typed` rows. The collision pairs are those of a
CP1250 system (the probe prints the ACP); on another code page other pairs collide and some rows
pass on both builds.

By hand (Release build, real keyboard; a real editor such as Notepad):
1. Make a ZIP with `ĥ.txt` and `Ĺ.txt` (or `Ítem.txt` and `Ýtem.txt`) with different content, e.g.
   with 7-Zip.
2. Enter it, F4 on the first, add a line, save, close Notepad; the same for the second.
3. Leave the archive (Backspace), OK, *Update All*, answer the overwrite questions with *Yes*.
4. Extract the archive elsewhere: both files present, each with its own content and its own line.
5. A 7z archive with a folder `Dir` holding `x.txt`: Change Directory (Shift+F7) to
   `<archive>\DIR`, F4 on `x.txt`, add a line, close; Backspace, Enter on `Dir`, F4 on `x.txt`:
   Notepad shows the first added line; add another, close; leave and update: `Dir/x.txt` holds both
   lines, no `DIR` folder in the archive.
