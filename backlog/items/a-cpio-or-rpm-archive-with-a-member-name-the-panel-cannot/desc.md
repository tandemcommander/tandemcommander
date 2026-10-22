---
title: A cpio or rpm archive with a member name the panel cannot hold fails as a whole
type: bug
status: new
severity: 4
area: archives
source: review:307
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: [opening-a-tar-whose-member-name-has-a-300-letter-component]
depends-on: []
reason: -
---

# A cpio or rpm archive with a member name the panel cannot hold fails as a whole

## Problem

A cpio archive (or an rpm, whose payload is cpio), opened by the TAR plug-in, whose top-level member has a name of 780 bytes or more cannot be used at all: on `main` the program crashes on opening (the same panel overflow as the GNU tar case of item `opening-a-tar-whose-member-name-has-a-300-letter-component`); with that item's core bound (branch `307-tar-long-component`) it no longer crashes, but the whole archive refuses to open with "Internal error: file data structure corrupted." - the other members are out of reach. GNU and PAX tar members are refused alone (features 306 / 307); cpio names are not.

## Evidence

Measured by review 1 of feature 307 on branch `307-tar-long-component` (probe row CPIO-TOOLONG of `specs/307-tar-long-component/probe/tar307_probe.ps1`, newc cpio made by `mktar307.py`: a 904-byte CJK name + ok.txt): "TAR Plugin Error - Internal error: file data structure corrupted.", the archive does not open (`probe/result_after.txt` on that branch). The cpio reader names (`src/plugins/tar/untar.cpp`, the cpio header branches of `CArchive::ReadArchiveHeader` / `GetArchiveType`) never get the `SalPaxNameFitsListingU8` check; `CArchive::ListArchive` gives up the whole listing when `AddFile` / `AddDir` fail.

## Expected

A cpio / rpm member the listing cannot hold is refused alone with the same "(206)" message and its whole path as a tar member (feature 306's rule, listing pass only), and every other member lists and extracts. Measured with a cpio row like CPIO-TOOLONG and a deep-path cpio row.

## Notes

Severity from the band "a function does not work, rare": such names do not occur on real file systems. On `main` the crash is fixed by the core part of item `opening-a-tar-whose-member-name-has-a-300-letter-component` (blocked, branch `307-tar-long-component`); this item is the per-member refusal on top of it. Keep the refusal out of extraction passes - see item `whole-archive-unpack-of-a-pax-tar-skips-deep-members-and-may`.

## Log

- 2026-10-22 — created (source review:307)
