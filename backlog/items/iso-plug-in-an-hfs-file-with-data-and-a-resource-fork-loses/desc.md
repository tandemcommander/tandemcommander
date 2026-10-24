---
title: ISO plug-in: HFS+ resource forks beside file data are dropped by Unpack
type: decision
status: new
severity: 5
area: archives
source: measure:339
who: person
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: ?
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: HFS+ resource forks beside file data are dropped by Unpack

## Problem

A file on an HFS+ volume (a Mac-made disc image) can have both a data fork and a resource fork (classic Mac
applications, fonts, documents with custom icons or previews). The ISO plug-in extracts only the data fork and
counts the file as extracted whole; a whole unpack (Alt+F9) with "Delete archive after unpacking" then deletes
the image with the resource fork's only copy. Feature 339 refuses a file whose content is only in its resource
fork or HFS+ compressed (the image is kept), but kept this case as before because changing it is a trade-off.

## Evidence

- Feature 339 (`specs/339-uniso-hfs-fork-content/`), spec *Clarifications* (the both-forks question) and probe
  row H-BOTH of `probe/iso339_probe.ps1`: a crafted resource fork beside `side.txt`'s data fork - the data is
  extracted, no box, the image deleted (unchanged on purpose).
- `src/common/salhfscatalog.h` `SalHfsFileContentKind`: a non-empty data fork gives `SAL_HFSFILE_DATA` whatever
  the resource fork holds; `src/plugins/uniso/hfs.cpp` `CHFS::UnpackFile` reads `dataFork` only.

## Expected

The maintainer decides how a resource fork beside data is treated; the chosen option is then implemented.

## Question

Should a whole unpack that drops a non-empty resource fork of a file that also has data count as incomplete
(the image kept), or keep deleting the image as today?

## Options

- A. Keep as today: only the data fork is extracted, the image is deleted. Consequence: resource forks are lost
  without a word; Windows users rarely need them, but Mac documents lose icons / previews and old Mac
  applications become unusable.
- B. Count such files as incomplete (no box, the data fork still extracted, the image kept). Consequence: no
  loss; but most classic Mac images (and many modern ones with custom icons) can then never be deleted by
  "Delete archive after unpacking" - the option stops working for them, silently.
- C. Extract the resource fork too, as an NTFS alternate data stream (`name:AFP_Resource`, the name Windows' own
  Services for Macintosh used) or as an AppleDouble file `._name` beside it, and count the file as complete
  only when that succeeded. Consequence: no loss and the option keeps working; a feature of its own (ADS are
  lost on FAT / exFAT / network targets - those would fall back to B), and new files appear in the target.
- D. B plus a message after the unpack that names why the image was kept (the Inbox's "kept image gets no
  explanation" idea). Consequence: as B, but the user understands it.

## Recommendation

C with B as its fallback for targets without alternate streams, if Mac images matter to users; otherwise A (the
lowest cost - feature 339 already protects the files whose whole content is outside the data fork). Severity 5:
narrow (Mac-made HFS+ images), the data the user usually wants is extracted.

## Log

- 2026-10-24 — created (source measure:339)
- 2026-10-24 — set title=ISO plug-in: HFS+ resource forks beside file data are dropped by Unpack
- 2026-10-24 — related item iso-plug-in-an-hfs-file-whose-data-is-compressed-or-only-in done in feature 339
