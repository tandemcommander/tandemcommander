---
title: Check drive labels and folder type names outside the code page on real hardware (289)
type: person-step
status: new
severity: 3
area: encoding
source: leftover:289
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check drive labels and folder type names outside the code page on real hardware (289)

## Problem

Feature 289 reads a CD / DVD label, a removable drive's name and the folder type name from the
wide Windows calls (they were code page: '?' for every character outside it). The machine of the
run has no CD or removable drive and a Czech display language inside its code page (1250), so
the end-to-end symptom could not be shown there: the probe proved the stored bytes are UTF-8 and
the display unchanged, the two drive paths were checked by code reading only (independent review
of 289, S1).

## Evidence

`specs/289-drive-list-wide-texts/fix-log.md` (*Measurement before*, T019, *Review* S1);
`quickstart.md` step 3; probe `probe/run289.ps1` (fixed drives, type names, Documents, Network,
As Other Panel - PASS 8).

## Expected

The Change Drive menu, the drive bar tooltip and the *Type* column show these texts exactly as
Explorer does.

## Steps

- [ ] CD: make an ISO whose volume label is `Диск` (or Greek `Δίσκος`) - e.g. with ImgBurn or
      `oscdimg -l` - mount it in Explorer (right click, *Mount*); Alt+F1 shows `Диск` next to its
      letter (0.1.10: `????`), the drive bar tooltip reads the same; unmount afterwards.
- [ ] USB stick: rename its volume in Explorer to `Флешка`; Alt+F1 and the drive bar tooltip show
      `Флешка` (0.1.10: `??????`).
- [ ] A CD drive with no medium still shows the localized "Compact Disc"; a USB stick without a
      label still shows its Windows name or "Removable Drive".
- [ ] (Optional, another machine) Windows display language outside the system code page - e.g.
      Japanese display language with "Language for non-Unicode programs" English: the *Type*
      column of a folder shows the Japanese "File folder" text (0.1.10: question marks).

## Log

- 2026-10-21 — created (source leftover:289)
