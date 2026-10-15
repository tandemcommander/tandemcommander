# Fix log: 213 - Change Attributes / Change Case / Convert never reach a link's target

Backlog (left by 197's review, `specs/NEXT-WORK.md`): Change Attributes / Change Case with
subfolders descend into every junction - the target's files change.

## Measured (before)

Probe `probe/attrs_case_link_probe.ps1` (a folder `sel` holding `OWN.TXT` and a junction `j` to a
folder OUTSIDE it holding `T.TXT`; `sel` focused, the command's dialog with "Include
subdirectories"); `probe/result_before.txt` is the negative control (the final probe on the build
without the fix, `fileswn6.cpp` stashed):
- **ATTR** (Change Attributes 748, Hidden): `OWN.TXT` hidden - and **the target's `T.TXT` hidden**;
- **CASE** (Change Case 747, lower case): `own.txt` - and **the target's `T.TXT` renamed `t.txt`**;
- **CONV** (Convert 814, line ends to LF; added after the review): `OWN.TXT` converted - and **the
  target's `T.TXT` rewritten** (its CR/LF line ends made LF);
- **SELJ** (the junction itself focused, Change Attributes Hidden + subdirectories): the junction
  hidden and **the target's `T.TXT` hidden**.

The walk of `CFilesWindow::BuildScriptDir` (`src/fileswn6.cpp`) went into the junction like into
a folder; files outside the selection changed (nothing deleted; Convert rewrote content).

## Work

`src/fileswn6.cpp` (`BuildScriptDir`): for Change Attributes, Change Case and recursive Convert a
directory with `FILE_ATTRIBUTE_REPARSE_POINT` that `DeleteAsDirLink` takes for a link (197's
fail-closed decision, as Delete uses it: a junction, a volume mount point, a symbolic link, a name
surrogate, a tag that cannot be read) is not walked; the link's entry (its attributes, its name's
case) still changes. A cloud placeholder (not a name surrogate) is walked as before.

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 8 / 0: ATTR - `OWN.TXT` hidden, `T.TXT` and the folder `tgt` not; CASE -
`own.txt`, `T.TXT` kept; CONV - `OWN.TXT` converted, `T.TXT` unchanged; SELJ - the junction
hidden, `T.TXT` and `tgt` not. Regression: 169's Change Case probe 12 / 0 (`probe/regress_169.txt`,
the build before Convert was added - the line it changed is not on that route).

## Review

Refute-first review: accept; the policy is right - a selected junction too changes only the link
(as Delete since 197, fail closed; a user who wants the target's content changed opens the
junction and selects inside it - those items are walked). Checked: `sourcePath` is the folder's
full path on every route (first level, nested, Copy / Move by name) and restored in the skipped
branch; `SetFileAttributesW` on a junction changes the link only (measured by the reviewer); the
Folders plug-in's Change Attributes is empty; Change Attributes has no counting walk; Count Size
still counts the target (no change of data). Taken: **recursive Convert** walked the same way and
rewrote the target's files - added (rows CONV, SELJ). Recorded in `specs/NEXT-WORK.md`
(pre-existing): the link's own Change Attributes op still reaches the target FOLDER itself for
compression (`CompressFile` / `UncompressFile` open without `FILE_FLAG_OPEN_REPARSE_POINT`,
`worker.cpp` 1645 / 1683), the times (`SalCreateFile` without that flag, `DoChangeAttrs` ~8125)
and probably encryption. Not driven: a directory symbolic link (needs the privilege or Developer
Mode), a cloud placeholder still walked. Explorer's / Total Commander's behaviour not measured.
