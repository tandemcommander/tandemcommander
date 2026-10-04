# Quickstart: feature 107

Automated (hidden desktop; close an installed Tandem Commander first; Python 3 and the WebClient
service running for the WebDAV rows - without them those rows are NOT DRIVEN):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\107-folder-alias-move\probe\folderalias_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect107 -OutFile result.txt"
```

Expected: 0 FAIL (see `probe/folderalias_result.txt`). The build before this feature
(`Debug_x64_pre107`, without `-Expect107`) fails the moves through an alias (empty folders deleted,
content moved one level down). The probe creates and removes a SUBST letter (first free of T, U, V,
Q, R) and a `net use` drive (first free of W, Y, X) mapped to `\\localhost\C$`. The paste rows are
NOT DRIVEN on the hidden desktop (the clipboard cannot be opened there).

By hand (Release build, a real mouse and keyboard):
1. Make `C:\t\parentlong\F` with a file, a subfolder with a file, and an empty subfolder.
2. Left panel `C:\t\parentlong`, right panel `\\localhost\C$\t\parentlong`. F6 of `F` to the right
   panel: "Cannot move a directory to itself."; `F` unchanged (the empty folder still there).
3. The same with the right panel in `\\localhost\C$\t\parentlong\F` and in `...\F\<subfolder>`: the
   same message, nothing changed.
4. F5 of `F` to `\\localhost\C$\t\parentlong\`: "Cannot copy a file to itself.", nothing changed.
5. Drag `F` with the mouse (Shift = move) onto the right panel in step 2's state, and Ctrl+X / Ctrl+V:
   the same message (these routes are not driven by the probe).
6. Make `a.txt` and its hard link `b.txt` (`mklink /H b.txt a.txt`) in `C:\t\hl`; F5 of `a.txt` to
   `\\localhost\C$\t\hl\`: "Cannot copy a file to itself."; F5 of `a.txt` onto `C:\t\hl\b.txt`:
   "Confirm File Overwrite" as before, then `b.txt` is an independent copy.
7. An ordinary F6 of a folder to another folder (also to `\\localhost\C$\...` of another folder)
   moves it as before.
