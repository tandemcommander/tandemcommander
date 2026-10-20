---
title: F3 / F4 refuse archive members whose path inside the archive has 520 bytes or more
type: improvement
status: open
severity: 4
area: archives
source: leftover:260
who: agent
created: 2026-10-20
updated: 2026-10-21
verified: 2026-10-21 66245537
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# F3 / F4 refuse archive members whose path inside the archive has 520 bytes or more

## Problem

Feature 260 lets F3 (View) and F4 (Edit) of archive members take temporary copies up to the Windows path limit (259 UTF-16 units), but before the disk cache is asked, F3 / F4 still refuse a member whose path inside the archive (folders + name) has 520 bytes or more - feature 095's limit, "the longest name a plug-in has ever received". A valid member of 172+ CJK letters at the top of an archive, or a shorter name inside folders with CJK names, still gets "Unable to unpack file from archive to temporary directory because resulting filename is too long." although its temporary copy would fit. F5 (extract) works for such members.

## Evidence

At aec864cf: `src/fileswn5.cpp` F3 of an archive member (`CFilesWindow::ViewFile`, "feature 095: the name handed to the archiver stays under 2 * MAX_PATH bytes", `strlen(dcFileName + dcKeyLen + 1) >= 2 * MAX_PATH` -> IDS_UNPACKTOOLONGNAME) and `src/fileswn6.cpp` `ExecuteFromArchive` (the same test on `nameInArchive`). Probe `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` row ARCCAP: a member of 200 CJK letters + ".txt" (604 bytes, 204 units; temporary path 249 units) is refused. Review 1 of feature 260, M1 (`specs/260-archive-cache-long-names/fix-log.md`, *Review*).

## Expected

F3 / F4 of a member whose path inside the archive is longer than 519 bytes works whenever its temporary copy fits the cache's rule (`salcachename.h`), with every enabled archiver plug-in; a plug-in that cannot take the name refuses it with a message, never cuts it. Probe row ARCCAP turns into a PASS of the viewer / editor.

## Approach

Audit each archiver plug-in's `UnpackOneFile` (and the external packers' route in `pack1.cpp`) for fixed buffers that take `nameInArchive`: ZIP, 7-Zip, tar, uniso, uncab (enabled), unrar / unchm / unole (disabled - see the unrar item). Then lift the 095 test for F3 / F4 (or move it to the plug-ins that need it).

## Notes

Raising the limit hands plug-ins - also third-party ones built against the interface - names they never got through F3 / F4; F5 has given them such names since feature 222. The contract `specs/260-archive-cache-long-names/contracts/cache-tmp-path.md` records the current state.

## Log

- 2026-10-20 — created (source leftover:260)
- 2026-10-20 — moved to Next position 13
- 2026-10-21 — verified at 66245537: present at 66245537: probe cache260 row ARCCAP (604-byte ZIP member) F3 refused too long; 095 test in fileswn5/fileswn6
