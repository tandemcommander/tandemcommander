---
title: Opening a tar whose member name has a 300-letter component crashes the program
type: bug
status: blocked
severity: 7
area: archives
source: measure:306
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: the independent review rejected the fix twice: review 2 MUST - the GNU refusal also runs in whole-archive Unpack, drops extractable deep members and lets Delete archive after unpacking delete the archive (feature 307, branch 307-tar-long-component)
---

# Opening a tar whose member name has a 300-letter component crashes the program

## Problem

Opening a tar archive in a panel crashes the program when a member's name has a component longer than any file system takes - measured with a GNU long name (type `L`) of 300 CJK letters + `.txt` (904 bytes, 304 UTF-16 units): the run-time check reports "Stack memory corruption" and the program closes with a bug report. Such archives are rare (Linux itself takes at most 255 bytes per component), but a crafted or damaged archive is enough; the crash happens on opening, before the user can do anything. Feature 306 refuses such names when they come from a PAX `path` (the same crash was measured there with the refusal disabled); GNU long names and the ustar name still reach the listing whole. Other archive plug-ins that list such names may hit the same stack buffer in the core.

## Evidence

At 88855a5c (feature 306 branch `306-tar-pax-headers`, Debug x64): probe `specs/306-tar-pax-headers/probe/pax306_probe.ps1 -Only GNU-TOOLONG` (fixture by `mkpax306.py`, Python `tarfile` GNU format) - result in `specs/306-tar-pax-headers/probe/result_before.txt`, row GNU-TOOLONG: "A problem has occurred, forcing Tandem Commander to close", report "Error Number: 2 / Description: Stack memory corruption", call-stack messages `CFilesWindow::ChangeDir(...\t.tar)` -> `CFilesWindow::ChangePathToArchive` -> `CFilesWindow::CommonRefresh`. The same crash with a PAX path when feature 306's refusal is disabled: `specs/306-tar-pax-headers/probe/result_negctl_refusal.txt`. The overflowing function is not located: the innermost call-stack message is `CommonRefresh` (`src/fileswn1.cpp`), whose own code has no fixed buffer - the corrupted frame is a callee without a call-stack message (`RefreshListBox` and below: name width measuring / drawing are the first candidates). The tar reader names: `src/plugins/tar/untar.cpp` `CArchive::ReadTarHeader` (GNU long name branch, the ustar name) and `CArchive::ReadArchiveHeader` (feature 306's `SalPaxPathHasTooLongComponentU8` check applies only when `header.NameFromPax`).

## Expected

Opening such an archive never crashes. Either the core's listing code takes a name of any length the listing holds (find and fix the stack buffer - the root cause, also for other plug-ins), and/or the tar reader refuses a GNU long name with a component over 255 UTF-16 units the way feature 306 refuses a PAX path (the member not listed, the system's "(206)" text with the path, the rest of the archive usable). Measured first by the GNU-TOOLONG row; then a 7-Zip / ZIP archive with the same name if one can be made.

## Notes

Related, same route (measured by review 1 of feature 306, fixture R-GNU2K: a GNU long name of 12 components of 200 letters): a GNU long name whose folder part is longer than the panel listing's 255-byte limit (`CSalamanderDirectory::AddFile` / `AddDir`, `src/zip.cpp`, feature 222) fails the whole listing - "Internal error: file data structure corrupted.", the archive does not open (the same in 0.1.10). Feature 306 refuses such PAX members alone (`SalPaxNameFitsListingU8`, `src/common/salpaxheader.h`); the same rule could be applied to GNU long names in this item.

Severity from the band "crashes in an unusual scenario". The probe row is excluded from the default run of 306's probe because it crashes; it runs with `-Only GNU-TOOLONG`.

## Log

- 2026-10-22 — created (source measure:306)
- 2026-10-22 — related item tar-plug-in-ignores-pax-extended-headers done in feature 306
- 2026-10-22 — moved to Next position 1
- 2026-10-22 — blocked: the independent review rejected the fix twice: review 2 MUST - the GNU refusal also runs in whole-archive Unpack, drops extractable deep members and lets Delete archive after unpacking delete the archive (feature 307, branch 307-tar-long-component)
- 2026-10-22 — feature 308 made the PAX refusal pass-dependent: SalPaxNameUsableU8 (salpaxheader.h) applies the listing bound only while listing (CArchive::Listing); an extraction refuses only a component over 255 UTF-16 units, reports a refused member it was asked for and returns FALSE. When branch 307 is resumed its GNU refusal must use the same rule (fixes its review-2 MUST)
