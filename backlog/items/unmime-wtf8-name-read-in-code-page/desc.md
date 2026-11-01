---
title: UnMIME: an attachment name with an unpaired surrogate is read in the code page
type: bug
status: parked
severity: 1
area: other-plugins
source: measure:379
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: [tar-wtf8-names-read-in-code-page, uncab-wtf8-flagged-name-refused, unmime-progress-title-name-mojibake]
depends-on: []
reason: plug-in unmime not built or shipped (plugins.cfg off); fix before enabling it; auto-triage, maintainer 2026-11-01
---

# UnMIME: an attachment name with an unpaired surrogate is read in the code page

## Problem

UnMIME (not shipped: `plugins.cfg` unmime=off) keeps an attachment name verbatim only when it passes a strict UTF-8 probe; anything else is read in the system code page. A name holding an unpaired surrogate in its 3-byte WTF-8 form (as a Windows mail client using a 7-Zip-style converter could write it) fails the probe, and the whole name is re-read in the code page - the listing and the extracted file get another name.

## Evidence

Found by feature 379 (`specs/379-plugin-encoding-verdicts/fix-log.md`, *Re-judged rows*; feature 255's review 2 NOTE 1), by reading at 3e0da39c: `src/plugins/unmime/parser.cpp` `NameToU8` (strict probe, then `CP_ACP`). Reported by `python tools/check_encoding.py --plugins` (`strict-probe-rejects-wtf8`, `unmime/parser.cpp`). Not measured: whether any mail client writes such names.

## Expected

An attachment name that is valid WTF-8 keeps its bytes; other non-UTF-8 names keep the code-page fallback; `check_encoding.py --plugins` no longer reports `unmime/parser.cpp`.

## Approach

Accept the WTF-8 form in the probe, as for TAR and UnCAB.

## Notes

The plug-in is not shipped, hence severity 1; fix before enabling it. Sibling items: `tar-wtf8-names-read-in-code-page`, `uncab-wtf8-flagged-name-refused`; same plug-in: `unmime-progress-title-name-mojibake`.

## Log

- 2026-11-01 — created (source measure:379)
- 2026-11-01 — moved to Parked: plug-in unmime not built or shipped (plugins.cfg off); fix before enabling it; auto-triage, maintainer 2026-11-01
