---
title: A cpio name stored after its data on a refused name is reported, not extracted
type: improvement
status: new
severity: 3
area: archives
source: review:393
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# A cpio name stored after its data on a refused name is reported, not extracted

## Problem

In a newc / crc cpio (or an rpm), the names of a hard-linked file share one copy of the data, which
is stored with one of the names. Since feature 393 a name no file system takes (a component over 255
UTF-16 units) is refused. When the refused name is the one that carries the data and it comes FIRST
(the data-first layout), the file's other names never get the data: Copy of the listed names and a
whole Unpack (Alt+F9) leave `a.txt` out and report it ("(2)", `a.txt -> <long name>`), and the operation
fails, so the archive is kept. Nothing is lost or written empty, but the file cannot be extracted under
any of its names although one of them is valid. When the data comes with a refused LAST name (the
order GNU cpio, libarchive and rpm write), the other names do get it (feature 393).

## Evidence

At 3f3481b0 (branch `393-cpio-long-name`), `src/plugins/tar/untar.cpp`: `DoUnpackArchive` passes a
refused name to the group as not asked (`found && !header.NameRefused`, line 892);
`WriteOutCpioGroupMember` then takes `SAL_CPIO_LINK_SKIP` (line 1928) and marks the group
`SAL_CPIO_GROUP_LOST` (line 1932); the later asked size-0 name hits `SAL_CPIO_LINK_REPORT` (line 1845).
Review 1 of feature 393 (SHOULD-1) measured it; the probe rows COPY-HARD-FIRST and UNP-HARD-FIRST-DEL of
`specs/393-cpio-long-name/probe/cpio393_probe.ps1` record the current behaviour (`a.txt` reported,
`ok.txt` extracted, archive kept) in `probe/result_after.txt`.

## Expected

A name of a hard-linked file stored after its data, where the data's own name is refused, gets the
data - for example by a further pass over the archive, as feature 325 writes deferred hard links
(`ExtractDeferredLinks`) - in Copy, whole Unpack and View of one file (F3); the refused name itself
stays reported and the operation still fails for it.

## Notes

Severity from the band "a function does not work": such names do not occur on real file systems and
the common writers put the data with the last name; nothing is lost (the operation fails, the archive
is kept). Feature 310 already records the related limit for names asked alone ("the data stored with
an EARLIER name and only a later name asked is reported, not shown").

## Log

- 2026-11-02 — created (source review:393)
- 2026-11-02 — related link removed: set by mistake
