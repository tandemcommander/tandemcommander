# Research: 249

## R1 - Is the external unpacker's walk reachable?

- Decision: yes, narrowly - fix it.
- Rationale: measured (fix-log): with 7-Zip 22.01's default `x` no junction pointing outside the
  output folder is ever created (TAR "dangerous link ignored", WIM re-targeted inside, 7z/TAR store
  content). An unpacker that restores a junction (configured as the 7-Zip executable) makes the walk
  move the junction target's files into the target with no question (probe row UNPACK FAIL).
- Alternatives: "not reproduced" - rejected, the code path is reachable from F5 with a user-chosen
  executable and loses data silently.

## R2 - What to do when the archive path meets a link

- Decision: refuse the whole unpack before anything is moved; error `IDS_PACKERR_GENERAL` with
  `<path>: GetErrorText(ERROR_REPARSE_POINT_ENCOUNTERED)`; `RemoveTemporaryDir(tmpDir)` (feature 212
  removes the link as a link); return `FALSE`.
- Rationale: CLAUDE.md "refuse rather than guess" and rule 099 (a link is never a route for moving
  the user's files); `FALSE` keeps the callers' success-only follow-ups (selection cleared, F6 delete)
  from running; an existing string avoids the `.slt` refresh.
- Alternatives: follow links that point inside the temporary folder (needs resolving the target -
  rejected, conservative); skip the link and unpack nothing silently (a "success" that did nothing -
  rejected); a new message text (needs the translation refresh - rejected for a run).

## R3 - Which directories count as links

- Decision: `(attr & FILE_ATTRIBUTE_REPARSE_POINT) && DeleteAsDirLink(path)` - feature 197's
  fail-closed decision (junction, mount point, symbolic link, any name surrogate, an unreadable tag;
  a cloud placeholder is a folder), as 212 and 213 use.
- Alternatives: any reparse attribute - would refuse a target folder synced by OneDrive (a cloud
  placeholder) where unpacking works today; rejected.

## R4 - The self-extractor

- Decision: minimal source fix - a directory with `FILE_ATTRIBUTE_REPARSE_POINT` is removed with
  `RemoveDirectory` (the entry) and never walked; checked with a compile-only `cl /Zs` run.
- Rationale: the item's *Expected* names it; the file is not built by any project, so a fail-closed
  rule without 197's helper (not available there) is enough: a cloud placeholder in the
  self-extractor's own temporary folder is left behind rather than walked.
- Alternatives: leave it (unreachable) - rejected, the item asks for it and the change is contained.

## R5 - `src/sfx7zip/install.c`

- Decision: out of scope, recorded in the fix-log only.
- Rationale: not named by the item; `sfx7zip.vcxproj` builds only in the "Utils (Release)"
  configuration, not by `build.cmd`, and is not shipped (the installer is Inno Setup).
