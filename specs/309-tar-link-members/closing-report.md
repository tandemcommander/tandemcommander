# Closing report - 309-tar-link-members
Backlog item: tar-unpack-drops-hard-links-and-deletes-archive - Unpacking a tar leaves hard-linked files out silently and Delete archive after unpacking then deletes the archive
Outcome: closed

## What changed

- A hard-link member of a tar that an extraction (whole Unpack, Copy of a folder) was asked for is
  extracted as a copy of the file it names, when that file was written by the same operation - through
  the plug-in's usual `SafeFileCreate` (overwrite question / Skip / Cancel), with the member's time and
  attributes; the source is opened read / share-read only and an existing destination that is the
  source by file identity (`salsamefile.h`) is not written.
- Every other link member asked for - a symbolic link, a hard link whose target was not written (not in
  the archive, outside the mask or selection, skipped, a folder) or whose target name has a `..`
  component - is named once per operation (system text "(2)" / "(50)" + `name -> link name`), and the
  operation returns FALSE after extracting the rest, so the core keeps the archive with "Delete archive
  after unpacking". `UnpackOneFile` reports a link member it is asked for (unreachable from the listing).
- Link names: PAX `linkpath` (new in `src/common/salpaxheader.h`) > GNU 'K' long link name (was read and
  discarded) > ustar `linkname`, decoded and normalized like member names; the normalization loop moved
  unchanged into the new header `src/common/saltarlink.h` (`SalTarNormalizeNameU8`, `SalTarLinkDecide`,
  `SalTarPathHasDotDotU8`).
- Unchanged: the panel listing (link members still not shown), files, folders, devices, 306 / 308
  behaviour, cpio. No UI string added, plug-in ABI untouched.
- Known behaviour change (CHANGELOG): a whole Unpack of an archive holding symbolic links now ends as
  failed with one message (the files are extracted the same).

## Measurements (before / after, commands)

- Before (f0187403, main): `link309_probe.ps1` on the hidden desktop -> `probe/result_before.txt`
  PASS 8 / FAIL 6 - hard links missing (UNP-HARD-DEL 2 of 4, PAX 1 of 2, GNU 1 of 2, COPY-HARD 2 of 4),
  symbolic link and missing-target link silent, t.tar deleted in every Delete row.
- After: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\309-tar-link-members\probe\result_after.txt
  -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\309-tar-link-members\probe\link309_probe.ps1
  -Label after-review1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"` -> PASS 16 / FAIL 0
  (UNP-HARD-DOTDOT-DEL added by review 1: before its fix `probe/result_dotdot_before_fix.txt` FAIL -
  b.txt made from the wrong file, t.tar deleted).
- Negative controls: refusal ignored + copy disabled -> `probe/result_negctl.txt` 7 / 7 (every RUN row
  fails); identity check removed -> `probe/result_negctl_identity.txt` FAIL with an overwrite question and
  a "(32)" box, a.txt intact (the share-read guard); restored build `probe/result_after_restored.txt` 14 / 0.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED (C4267 only on unchanged lines, as in 308).
- saltests -> `saltests: 27211 checks, 0 failed` (27170 before, +41 in `TestTarLink309`).
- Probes: link309 16 / 0; regressions 308 probe `probe/regress_308.txt` 12 / 0, 306 probe
  `probe/regress_306.txt` 28 / 0. Registry restored and identical after every run.

## Reviews (findings and what was done)

- Review 1 (independent, refute-first): no MUST. SHOULD-1 (a link target with `..` matched the wrong
  file through the legacy normalization - silent wrong content, archive deleted) fixed: such link names
  are never matched, reported; test + probe row. SHOULD-2 (link members not listed, so a Copy of the
  files shown in a folder misses hard links) -> Inbox. SHOULD-3 (CHANGELOG) done. Six NOTEs accepted
  (NUL in linkpath refuses the archive as for path; no progress during one copy; a `.deb` may show two
  boxes; skipped target reported as "not found"; duplicate-name edge cases; sound parts listed).
  Details in `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

- Nothing required: every probe row was driven on the hidden desktop. Optional (quickstart §5): a real
  GNU tar backup with hard links and a Linux tarball with symbolic links, unpacked by hand.

## New Inbox items (slug - title)

- `tar-member-name-with-dotdot-extracted-into-wrong-folder` - A tar member whose name contains .. is extracted into a wrong folder
- `tar-copy-of-listed-files-leaves-hard-links-out` - Copying the files of a tar folder leaves hard-linked names out silently
- `cpio-unpack-drops-links-and-may-delete-archive` - Unpacking a cpio or rpm leaves links out silently and may delete the archive
