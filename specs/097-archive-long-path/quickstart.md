# Quickstart: feature 097 - archives at long paths

## Automated (hidden desktop; close an installed Tandem Commander first)

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 7200 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\097-archive-long-path\probe\arcwork_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
... the same with probe\arcpath_probe.ps1 -Stage S2
```

Expected: arcwork 390 PASS / 0 FAIL / 21 n/a (about an hour); arcpath 55 / 0,
twin archive shown 0 times.

## Owed to a person (Release build)

1. A ZIP, a 7z and a TAR archive in a folder with a long accented path (for
   example five nested folders of 40 accented characters): Enter opens it;
   F3, F5 (unpack), F4 + save + leave (update), F8, F5 into the archive.
2. Create next to it a second archive whose path is exactly the first 259
   bytes of the first one's path: Enter on the long one never opens it.
3. With a **mouse**: drag a file out of such an archive to the other panel
   and to Explorer; drag a folder from the panel onto the other panel's
   directory line; copy (Ctrl+C) inside the archive and paste elsewhere -
   each either works or shows "The path specified is too long."; nothing is
   unpacked or deleted by mistake.
4. History (Alt+Left) and a second tab holding the archive location.
5. Start the program with `-L "<long archive path>"`.
6. With WinRAR installed: pack into / open a RAR archive at such a path
   (packing is refused beyond 259 bytes with the message; viewing works).
