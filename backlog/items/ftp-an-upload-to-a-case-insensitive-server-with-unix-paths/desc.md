---
title: FTP: an upload to a case-insensitive server with Unix paths replaces b.txt by B.txt without the question
type: bug
status: in-progress
severity: 7
area: ftp
source: review:302
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: 2026-10-22 17febaaf
effort: M
feature: 303
related: [ftp-server-path-compare-code-page-fold]
depends-on: []
reason: -
---

# FTP: an upload to a case-insensitive server with Unix paths replaces b.txt by B.txt without the question

## Problem

Many FTP servers list Unix-style paths but store files on a case-insensitive file system (FileZilla Server and other Windows-backed servers). The FTP plug-in compares names and paths of a Unix path type case-sensitively, so the upload's "does the target exist?" check does not see `b.txt` when uploading `B.txt`: the file is sent with `STOR B.txt` without the overwrite question, and the server replaces its `b.txt`. The same rule makes an existing folder `Docs` invisible when a path says `docs` (feature 302 review 2 measured that through Create Directory `docs/new`).

## Evidence

By reading, not measured (feature 302, review 2, NOTE 3; `specs/302-ftp-upload-cache-args/fix-log.md`, *Review 2*):
- `src/plugins/ftp/ftputils.cpp` - `FTPIsPrefixOfServerPath` / `FTPIsTheSameServerPath`: the Unix path type is compared case-sensitively (the case-insensitive types use `StrNICmp`).
- The upload worker's collision check (`src/plugins/ftp/operatsa.cpp`, `fwssWorkStartWork` and the file variant in `operatsb.cpp`) asks `UploadListingCache.GetListing(..., curItem->TgtName, &existingItem, ...)`; the name lookup in the cached listing follows the path type's case rule (to be confirmed).
- Related measurement in feature 302 review 2: the MKD-CASE row (`specs/302-ftp-upload-cache-args/probe/review2/ftp302_rv.ps1`, ftpmini on NTFS = a case-insensitive server with Unix paths): `docs` did not match the existing `Docs`.

## Expected

An upload whose target name differs only by case from a listed name on a server whose file system may be case-insensitive asks the overwrite question (or the conservative rule: a case-only match counts as "exists" for the overwrite decision on every server type), never replaces the other file silently. A probe row with 215's `ftpmini.py` on NTFS: server `b.txt` = OLD, upload of local `B.txt` - the question appears, `b.txt` keeps OLD.

## Notes

Severity 7 (data loss in a narrow scenario: a case-only name difference on a Windows-backed server with Unix-style listings); not measured - measure first. The plug-in cannot know whether a Unix-type server is case-insensitive; treating a case-only match as a collision only for the overwrite decision (not for path identity) avoids changing what "the same folder" means. Related to `ftp-server-path-compare-code-page-fold` (non-ASCII case folding on case-insensitive server types), which is a different rule. Pre-existing (upstream), not caused by 302.

## Log

- 2026-10-22 — created (source review:302)
- 2026-10-22 — moved to Next position 1
- 2026-10-22 — verified at 17febaaf: reproduced at 17febaaf: hidden-desktop probe with ftpmini on NTFS - upload of B.txt sent STOR B.txt without the question, server b.txt replaced (also c-caron vs C-caron)
- 2026-10-22 — run started, feature 303
