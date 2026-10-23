---
title: ZIP says the archive was not changed after a failed replace, yet it changed and a temp file stays
type: bug
status: in-progress
severity: 5
area: archives
source: measure:319
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: 2026-10-23 4252bcb6
effort: ?
feature: 320
related: []
depends-on: []
reason: -
---

# ZIP says the archive was not changed after a failed replace, yet it changed and a temp file stays

## Problem

When the ZIP plug-in adds files to an existing archive and cannot replace the archive with its
temporary working file, it reports "Cannot replace original archive with temporary working file.
Archive was not changed." - but in the one case measured, the archive's content had changed and the
temporary file `Sal*.tmp` was left in the archive's folder. The user is told nothing happened while
the archive is no longer what it was, and a stray file remains.

## Evidence

Measured in feature 319 (`specs/319-pack-name-colon/fix-log.md`, *Measurement at e9c35c2e* and
*Review*), on the build of e9c35c2e (before 319), probe `specs/319-pack-name-colon/probe/pack319_probe.ps1`
row `colon-stream`: a file `report` holding an NTFS data stream `zip.zip` with a ZIP archive
(seed.txt); Pack (Alt+F5) with the name `report:zip.zip`, the "already exists - add or overwrite?"
question answered Add, the "Add Files to Archive" box OK -> the ZIP box above; afterwards the
stream's SHA-256 differed from before and `src\Sal5C0.tmp` was new (the review reproduced it with
the 319 refusal disabled: `Sal309.tmp`). Probe snapshot: every file and stream hashed through
`CreateFileW` (`\\?\`).

Since feature 319, Pack refuses a name with a colon in its last part, so this route is closed.

## Expected

After a failed replace the archive is byte-for-byte what it was before, the temporary file is
removed, and the message stays true - or, if the archive was changed, the message says so. A probe
row that makes the replace fail on an ordinary archive (e.g. the archive opened by another process
without delete sharing, or read-only) shows the before / after state.

## Notes

- Not verified: whether the same happens for an ordinary archive (not a stream) when the replace
  fails, and whether another route still reaches an archive inside a stream (copy into an archive
  opened from such a stream, one made by a pre-319 version). The stream case may be special - a
  stream cannot be renamed over like a file, so the plug-in's replace path may have written into it
  directly. Measure first.
- Severity 5: a wrong message and possibly changed archive content in a narrow case; no data loss
  was shown (the changed content was not inspected). Unsure of the band - the lower value chosen.
- The site was not read: the ZIP plug-in's update / replace code under `src/plugins/zip/`.

## Log

- 2026-10-23 — created (source measure:319)
- 2026-10-23 — moved to Next position 1
- 2026-10-23 — verified at 4252bcb6: reproduced at 4252bcb6: archive held open without delete sharing, Pack-add and Delete-in-archive both show the ZIP replace message and leave Sal*.tmp; archive unchanged
- 2026-10-23 — run started, feature 320
