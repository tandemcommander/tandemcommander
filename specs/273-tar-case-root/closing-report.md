# Closing report - 273-tar-case-root
Backlog item: copying-from-a-tar-folder-opened-in-another-case-extracts - Copying from a TAR folder opened in another case extracts nothing
Outcome: closed

## What changed

- `src/common/salarcpathspell.h` (new, header-only): `SalArcPathRespell` - a path inside an
  archive spelled as the listing spells its folders (each component replaced by the first
  sub-folder the listing's own comparison finds, as `CSalamanderDirectory::GetFiles`); NOTFOUND /
  TOOLONG refuse, nothing is cut.
- `src/zip.h`, `src/zip.cpp`: `CSalamanderDirectory::GetPathSpelling` (the rule over the core's
  listing, `SalDirStrCmpEx`).
- `src/fileswn2.cpp` `CFilesWindow::ChangePathToArchive`: after the shortening loop, the path inside
  the archive is re-spelled (heap buffer `CSalMaxPathBuffer`) and stored when it differs; failure
  keeps the typed path. Every route into an archive folder passes here, so every archive plug-in
  receives the archive's own folder names as `archiveRoot`, and the directory line / history show
  them.
- `src/saltests/saltests.cpp` `TestArcPathRespell273`; `src/vcxproj/saltests/saltests.vcxproj`.
- No plug-in, interface, UI string or stored-data change.

## Measurements (before / after, commands)

- Before (main ff3cd942, build up to date): hidden-desktop probe `probe/arccase273_probe.ps1`
  (scratch copy, same rows) -> `probe/result_before.txt` PASS 8 / FAIL 4: TAR-COPY (`t.tar\DOCS`)
  and TAR-DEEP (`t.tar\dOCS\SUB`) target empty, no error; 7Z rows copied but kept `DOCS`.
- After: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\273-tar-case-root\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\273-tar-case-root\probe\arccase273_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
  -> PASS 12 / FAIL 0 (panel `t.tar\Docs`, `t.tar\Docs\Sub`, files with contents; TWINS rows
  unchanged in `\DOCS`). Registry restored, identical.
- Negative control (review): the new block disabled -> the committed probe 8 / 4.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED.
- `saltests.exe` -> saltests: 24859 checks, 0 failed (rule negative control: 7 FAIL).
- Probes: `arccase273_probe.ps1` 12 / 0; 252's `arc252_probe.ps1` 16 / 0.

## Reviews (findings and what was done)

One refute-first review: no MUST, no SHOULD. NOTE 1 (before file from the scratch copy of the
probe) labelled in fix-log; NOTE 2 and NOTE 3 -> Inbox items below; NOTE 4 (accessor without a
unit check) accepted; NOTE 5 (records) done at closing.

## Owed to a person

- (none)

## New Inbox items (slug - title)

- a-path-typed-in-another-case-into-an-archive-with-case-twins - A path typed in another case into an archive with case twins elsewhere opens its root
- copying-into-an-archive-folder-typed-in-another-case-packs - Copying into an archive folder typed in another case packs into a new folder beside it
