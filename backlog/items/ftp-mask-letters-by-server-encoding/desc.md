---
title: FTP: a mask ? takes two code-page bytes of a legacy server as one letter
type: bug
status: open
severity: 2
area: ftp
source: manual
who: agent
created: 2026-10-20
updated: 2026-10-23
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# FTP: a mask ? takes two code-page bytes of a legacy server as one letter

## Problem

Part of `ftp-long-name-and-path-leftovers` (split at 4c6fd132). On a legacy (code-page) FTP server, a name whose code-page bytes happen to form a valid UTF-8 sequence (a byte `0xC0-0xF7` followed by the right number of `0x80-0xBF` bytes) is taken for UTF-8 by the listing and kept as it is; a Copy / Move mask's `?` (and a literal) then consumes those two or more code-page letters as ONE letter (the whole-letter rule of feature 141), so the target name built for a download or upload differs from what the user's mask means for that server.

## Evidence

By reading at 4c6fd132: `src/plugins/ftp/ftputils.cpp:3627` `FTPListingFieldToU8` (valid UTF-8 kept verbatim, else the ANSI code page); the mask: `src/common/salmaskname.h` (`SalMaskNameU8`), reached through `CSalamanderGeneral::MaskName` from `src/plugins/ftp/fs4.cpp:1124` (download) and `fs5.cpp` (upload's target name). Recorded as a known deviation by feature 141: `specs/141-mask-name-cut/impl-notes.md`, finding 5 (~L185).

## Expected

Names of a server known to be legacy are decoded and masked by that server's encoding, so `?` counts the server's letters.

## Notes

Needs the per-server encoding state of `ftp-per-server-encoding-flag` (depends-on): without it the listing can only guess, and the mask follows the guess (the panel shows the same letters the mask counts). Once that item is done this may need no own change beyond a probe row - check, then close or fix. Severity 2: only legacy servers with such byte pairs, and only with a `?` mask.

## Log

- 2026-10-20 — created (source manual)
- 2026-10-20 — moved to Next position 68
- 2026-10-21 — dependency ftp-per-server-encoding-flag done in feature 288
- 2026-10-21 — feature 288 added the per-server encoding state (CFTPServerEnc in ftputils.cpp, src/common/salftpsrvenc.h); listing fields are still decoded one by one (valid UTF-8 kept), so the guess this item describes is unchanged
- 2026-10-23 — related item ftp-long-name-and-path-leftovers closed: split into: ftp-pwd-and-created-path-cut (done in 277), ftp-escaped-path-does-not-fit-decision, ftp-local-long-paths, ftp-mask-letters-by-server-encoding - the parts replace it; maintainer 2026-10-23
