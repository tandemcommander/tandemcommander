---
title: FTP: a file name with an unpaired surrogate comes back garbled from a UTF-8 server; re-upload may overwrite
type: bug
status: in-progress
severity: 7
area: ftp
source: review:255
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: 2026-10-20 b1feb7ab
effort: M
feature: 269
related: []
depends-on: []
reason: -
---

# FTP: a file name with an unpaired surrogate comes back garbled from a UTF-8 server; re-upload may overwrite

## Problem

Uploading a local file whose name holds an unpaired UTF-16 surrogate (legal on NTFS, WTF-8 in the
program) to a byte-transparent UTF-8 FTP server sends the WTF-8 bytes as they are
(`FTPU8NameToServer`). The next listing reads them through `FTPListingFieldToU8`, whose raw strict
UTF-8 probe rejects the surrogate form and re-reads the **whole** name in the code page
(`a<U+D800>.txt` → `aí €.txt` with cp1250) and registers it as a code-page name. So:

1. the panel shows a different name;
2. downloading the file back creates a file with a different name;
3. by reading (review 2 of feature 255): the upload's "target exists?" check compares the cached
   listing's name with the local one, they never match, so a second upload of the same file does
   not ask and STOR **overwrites the remote file**.

## Evidence

Found by review 2 of feature 255 (`specs/255-plugin-encoding-findings/fix-log.md`, *Review*, on
branch `255-plugin-encoding-findings`), by reading, at e849e68c: `src/plugins/ftp/ftputils.cpp`
`FTPListingFieldToU8` (strict probe, then `CP_ACP` + `FTPAddCodePageName`) and `FTPU8NameToServer`;
the existence check: `CUploadPathListing::FindItem` (`operats9.cpp`), reached through
`GetListing(..., curItem->TgtName, ...)` (`operatsa.cpp`, `operatsb.cpp`); the cached listing is
decoded the same way (`parser2.cpp`). Reported by `python tools/check_encoding.py --plugins`
(`strict-probe-rejects-wtf8`, `ftputils.cpp`). Not reproduced on a server.

## Expected

On a UTF-8 server (the Docker test servers of `CLAUDE.md` / memory, e.g. vsftpd), `a<U+D800>.txt`
uploads, lists, downloads and re-uploads under its own name; the second upload asks "file exists";
`check_encoding.py --plugins` no longer reports `ftputils.cpp`.

## Approach

Measure first on a byte-transparent UTF-8 server (rows: upload, list, download, re-upload with
"ask"). Probe with `SplU8ToW` (WTF-8) instead of the raw strict call, so the surrogate form is kept
as UTF-8 and not taken for a code-page name (feature 224's code-page detection must keep working).

## Notes

Severity 7: data loss in a narrow scenario (special names), by reading only - lower it if the
overwrite path does not reproduce. Needs an FTP server (an agent can run one in Docker).

## Log

- 2026-10-20 — created (source review:255)
- 2026-10-20 — moved to Inbox
- 2026-10-20 — moved to Next position 2
- 2026-10-20 — verified at b1feb7ab: reproduced at b1feb7ab: hidden-desktop probe, ftpmini wtf-8 mode - download made a different name, re-upload overwrote without asking
- 2026-10-20 — run started, feature 269
