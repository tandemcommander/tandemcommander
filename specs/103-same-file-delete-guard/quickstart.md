# Quickstart: feature 103

Automated (hidden desktop; close an installed Tandem Commander first; needs Python 3 and the
WebClient service running - without it the dav-* cases are NOT DRIVEN):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 3000 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\103-same-file-delete-guard\probe\samefile_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect103"
```

Expected: 62 PASS / 0 FAIL (31 cases x RUN + END). The build before this feature
(`Debug_x64_pre103`, without `-Expect103`) deletes the file in dav-qren, dav-mov, dav-msil,
dav-xmov, sl-qren and sl-mov (55 / 7; slt-cpy differs without a loss).

By hand (Release build, a real mouse):
1. `python specs\103-same-file-delete-guard\probe\davnorm.py C:\t\dav 18103`; put a file named
   `cafe` + U+0301 + `.txt` into `C:\t\dav` (NFD, e.g. from PowerShell with `[char]0x301`).
2. Open `\\localhost@18103\dav` in a panel; Quick Rename the file to `Café.txt` typed on the
   keyboard: renamed, no question; the file in `C:\t\dav` is `Café.txt` with its content.
3. Open `\\127.0.0.1@18103\dav` in the other panel; F6 and F5 a file from one panel to the
   other: "Cannot move a file to itself." / "Cannot copy a file to itself."; the file is intact.
4. `subst T: C:\t\x`; F5/F6 from `C:\t\x` to `T:\`: the same messages, no overwrite question.
5. An ordinary overwrite (F6 onto another existing file) still asks and overwrites.
6. Not testable here (owed to a person with the hardware): a macOS or Samba SMB share where an
   NFC/NFD rename is answered "already exists" - expected: renamed through `salXXX`, never deleted.
