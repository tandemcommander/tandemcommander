---
title: Viewer shows a short code-page file ending in a non-ASCII letter as UTF-8
type: bug
status: new
severity: 3
area: encoding
source: measure:398
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: [viewer-find-does-not-find-non-ascii-text-in-a-file-shown-in]
depends-on: []
reason: -
---

# Viewer shows a short code-page file ending in a non-ASCII letter as UTF-8

## Problem

The internal viewer takes a code-page file for UTF-8 when its last byte is a non-ASCII letter that
looks like the start of a UTF-8 sequence and the file is shorter than the detection sample: a
Windows-1250 file `café` (or `Plzeň`) without a final line break is shown as UTF-8, with U+FFFD for the
last letter, instead of in the code page.

## Evidence

At the branch `398-viewer-find-seed` (feature 398), measured and by reading:
- `src/viewer2.cpp` `ViewerIsValidUTF8` (about line 60): `return TRUE; // sequence truncated by the
  sample boundary - accept` - also when the sample is the whole file, so the "truncated" sequence is
  the file's real end, not the sample's.
- `specs/398-viewer-find-seed/fix-log.md`, *Attempt 1 of the probe*: the fixture `caf` + byte E9
  (Windows-1250) was shown as UTF-8 (`ContentEncoding` VCE_UTF8); probe row `u8-tail` of
  `probe/seed398_probe.ps1` pre-fills `caf` + U+FFFD from it.
- Review 1 of 398 (SHOULD 2) found it not recorded.

## Expected

A cut sequence is accepted only when the sample ends before the file does; a file whose own last bytes
are an incomplete UTF-8 sequence is not taken for UTF-8 by that sequence, so a short code-page file is
shown in the code page.

## Notes

Detection lives in `ViewerDetectEncoding` (feature 015); the sample is `RECOGNIZE_FILE_TYPE_BUFFER_LEN`
bytes read with `Prepare`, so the caller knows whether the sample reached the file size. Not fixed in
398 (scope: the Find pre-fill).

## Log

- 2026-11-02 — created (source measure:398)
