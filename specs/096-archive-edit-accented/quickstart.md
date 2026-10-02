# Quickstart: feature 096

Automated (close an installed Tandem Commander first):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\096-archive-edit-accented\probe\archedit_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Expected: 17 cases, all `UPDATED`.

By hand (Release build): open a ZIP archive, F4 on `článek.txt`, change and
save it in your editor, leave the archive: the Archive Update question
appears; Yes; open the archive again and view the file. The same with a 7z
archive, and with WinRAR installed a RAR archive.
