---
title: Check a volume label with accented letters written by Drive Information (300)
type: person-step
status: open
severity: 4
area: encoding
source: leftover:300
who: person
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check a volume label with accented letters written by Drive Information (300)

## Problem

Feature 300 makes Drive Information write the volume label through the wide Windows call (it was
the code-page call: `Zálohy` was written as `ZĂˇlohy` on code page 1250). The run that made it
was not elevated and the machine has no removable drive, so no label could really be written: the
fix is proven by the program's import table (only `SetVolumeLabelW`) and by reading; the probe
drove only the unelevated error path.

## Evidence

`specs/300-volume-label-wide/fix-log.md` (*Measurement after*, *Owed to a person*);
`quickstart.md` step 6; probe `probe/vol300_probe.ps1` (rows `vol-fail`, `vol-same`, `vol-long` -
PASS 6, the error path only).

## Expected

A label with accented letters typed in Drive Information is on the drive exactly as typed;
clearing the field removes the label, as before.

## Steps

- [ ] USB stick (no admin needed) - or a VHD created and attached in Disk Management, with Tandem
      Commander started *as administrator*: open the drive in a panel, Drive Information
      (Alt+F1 menu / the drive's information), type the label `Zálohy`, OK → no message; Explorer
      shows the drive as `Zálohy` (0.1.10: `ZĂˇlohy`).
- [ ] Open Drive Information again → the label field shows `Zálohy`.
- [ ] Clear the field, OK → the drive has no label (Explorer shows the default name).
- [ ] (Optional) A fixed drive with the program *not* elevated: a new label, OK → "Unable to
      change drive label." with the access-denied text, the label unchanged.
- [ ] Restore the stick's original label afterwards.

## Log

- 2026-10-22 — created (source leftover:300)
- 2026-10-22 — moved to Person steps position 17
