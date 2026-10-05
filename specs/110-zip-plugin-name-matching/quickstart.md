# Quickstart: feature 110

Automated (hidden desktop; close an installed Tandem Commander first; Windows PowerShell 5.1;
Python 3 on PATH):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\110-zip-plugin-name-matching\probe\zipname_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile result.txt"
```

Expected on this build: every row PASS (`probe/zipname_result.txt`). The build before
(`build\tandemcommander\Debug_x64_pre110`) fails the rows that show the defect
(`probe/zipname_result_pre110.txt`). `-Only c_hL,f_` runs single rows (name prefixes); `-Scratch <folder>` moves the fixtures (default
`%TEMP%\tc110`). The `r_*` rows (several members of one name, mixed answers) are the review's SF1.
`python specs\110-zip-plugin-name-matching\probe\zip_collision_set.py` prints the pairs the old
comparison merged on this machine's code page and locale.

By hand (Release build, a real mouse and keyboard; CP1250 for the first two):
1. Make a ZIP holding `Ĺ.txt` (7-Zip or Windows Explorer). In a folder on disk create `ĥ.txt`.
   Open the archive in one panel, F5 `ĥ.txt` into it: no overwrite question; the archive holds
   both files afterwards.
2. An archive holding `ĥ.txt` and `Ĺ.txt`: F4 on `ĥ.txt` only, change it, leave the archive,
   Update: one overwrite question; `Ĺ.txt` is still in the archive, unchanged.
3. An archive holding `Č.txt`: F5 `č.txt` into it: an overwrite question (as for `A.txt` /
   `a.txt`); Yes leaves only `č.txt` with the new content.
4. An archive holding `ax.txt`, `Ax.txt`, `AX.txt` and a second file to add: F5 `ax.txt` and the other
   file, answer *Yes*, *Skip*, *Skip*: `ax.txt` holds the new content, `Ax.txt` and `AX.txt` are kept.
5. Unchanged: F5 `a.txt` into an archive holding `A.txt` asks to overwrite as before; an old
   archive made by Windows XP's compressed folders (OEM names) behaves as before for a file of
   the same name.
