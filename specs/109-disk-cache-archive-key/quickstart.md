# Quickstart: feature 109

Automated (hidden desktop; close an installed Tandem Commander first; Python 3 and 7-Zip
(`C:\Program Files\7-Zip\7z.exe`) needed - `specs/108-archive-edit-name-collision/probe/arcfix.py`
makes and reads the archives; the probe makes and removes a SUBST letter of T, U, V, Q, R and uses
`\\localhost\C$`):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 2400 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\109-disk-cache-archive-key\probe\diskcache_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile result.txt"
```

Expected (see `probe/diskcache_result.txt`): every row PASS. The build before this feature
(`Debug_x64_pre109`, `probe/diskcache_result_pre109.txt`) fails the five twoarc rows, `alias-subst`,
`alias-unc`, `prefix` and `stale-same`. The colliding archive names (`ĥ` / `Ĺ`) are those of a CP1250 system; on
another code page the twoarc rows pass on both builds (other pairs collide there). Rows `resubst` / `renet` (a SUBST /
`net use` letter re-pointed to another folder) pass on both builds; they failed on the first version of
109 (independent review) and guard the rule that an equal key is never trusted by itself. The probe
makes and removes its own SUBST letter (T, U, V, Q, R) and `net use` drive (W, Y, X).

By hand (Release build, real keyboard, a real editor such as Notepad):
1. Make `ĥ.zip` and `Ĺ.zip` in one folder, each with an `x.txt` of different content.
2. Left panel: enter `ĥ.zip`, F3 on `x.txt` - the viewer shows `ĥ.zip`'s text. Right panel: enter
   `Ĺ.zip`, F3 on `x.txt` - the viewer shows `Ĺ.zip`'s text (before 109: `ĥ.zip`'s).
3. F4 on `x.txt` in both panels, add a line in each, save, close. Leave both archives, *Update All*.
   Extract both elsewhere: each `x.txt` has its own text and only its own line.
4. Make `p.zip` and `p.zip.zip`. Left: enter `p.zip.zip`, F4 on a file, add a line, save, close.
   Right: enter `p.zip`, Backspace. Left: F4 on the same file again - Notepad shows the added line
   (before 109: the original text; the line was gone).
5. `subst T: <folder>`; left: `<folder>\arc.zip`, right: `T:\arc.zip`; F4 on the same file in both -
   the second Notepad shows the first line; leave both, update: both lines in the archive.
   `subst T: /d`.
6. Both panels on one archive, F3 on a file; update the archive with another program (e.g. 7-Zip's
   `7z u`); F3 again in either panel: the new content (before 109: the old one until both panels
   had left the archive).
