---
title: ISO plug-in: APFS, original HFS and HFSX parts of a hybrid are never listed - mark them?
type: decision
status: new
severity: 6
area: other-plugins
source: measure:333
who: person
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: -
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: APFS, original HFS and HFSX parts of a hybrid are never listed - mark them?

## Problem

The ISO plug-in lists the HFS+ part of a hybrid disc image, but never an APFS part, an original HFS
part (a volume "BD" without an embedded HFS+ volume) or an HFSX part ("HX", case-sensitive HFS+).
Such a part is dropped without a mark: Unpack (Alt+F9) of the whole image with "Delete archive after
unpacking" extracts the ISO 9660 / UDF parts and deletes the image - files that exist only in that
part are lost. Feature 333 marks an HFS+ part that does not open, but deliberately not these three
(the backlog item it implemented reserved APFS for a decision; the other two are the same case).

## Evidence

- Feature 333 (`specs/333-uniso-hfs-part-missing/research.md` R3, `src/common/salhfscatalog.h`
  `SalHfsVolumeHeaderDeclaresHfsPlus`): only "H+" and "BD" + embedded "H+" declare a part that is marked.
- `src/plugins/uniso/isoimage.cpp` `CISOImage::DetectTrackFS` / `OpenTrack`: `fsISO9660_APFS`,
  `fsUDF_APFS`, `fsUDF_ISO9660_APFS` open `CUDFISO`, whose `CHFS::Open` fails on APFS; `fsAPFS` alone
  shows `IDS_UNSUPPORTED_APFS`. `src/plugins/uniso/hfs.cpp` `CHFS::Open`: original HFS ->
  `IDS_ERR_HFS_ORIGINAL_HFS`, "HX" -> `IDS_ERR_HFS_UNRECOGNIZED` (quiet in a hybrid).
- Not measured: no APFS / original HFS / HFSX hybrid image was made (xorriso writes HFS+ only).

## Expected

The maintainer decides whether such a part marks the listing incomplete.

## Question

Should a hybrid whose APFS, original HFS or HFSX part the plug-in cannot list be marked incomplete
(so a whole unpack fails and "Delete archive after unpacking" keeps the image)?

## Options

- **A - keep as today.** Such hybrids unpack whole and are deleted with "Delete archive after
  unpacking"; the files only in the unlisted part are lost.
- **B - mark them when the part's own signature is found** (APFS container "NXSB", "HX", "BD" without
  an embedded HFS+ volume). Every such hybrid's whole unpack then fails: its listed files are still
  extracted (as in feature 333's rows), but the image is never deleted by "Delete archive after
  unpacking" (and any other whole-image operation that requires a complete listing refuses).
- **C - B for APFS only** (the most common modern case), A for original HFS / HFSX.

## Recommendation

B: the cost is only that the image stays after the unpack; the gain is that a Mac-only part is never
deleted unseen (CLAUDE.md: a "safe to delete?" check fails closed). An agent can implement it with a
probe once decided (APFS images need a tool that writes them - not available in WSL Ubuntu by
default; a person step may be needed).

## Log

- 2026-10-24 — created (source measure:333)
- 2026-10-24 — related link set by mistake removed
