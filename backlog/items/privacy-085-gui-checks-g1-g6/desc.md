---
title: Privacy fixes of 085 on screen: checks G1-G6
type: person-step
status: open
severity: 6
area: privacy-security
source: leftover:085
who: person
created: 2026-10-01
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Privacy fixes of 085 on screen: checks G1-G6

## Problem

Feature 085 fixed the privacy defects F1-F7 found by 083 (F1 a password typed as part of an address reaching a history, F3 a Markdown document making the viewer open the browser, F4 WebView2 crash dumps, F6 password-manager salts, F7 cancelling the SFTP master-password prompt saving silently). Its GUI checks G1-G6 need the application on screen and are owed.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'The features' own quickstart.md person steps' ('085 G1-G6') (at 7993914c); 'the GUI steps of 085 join item 3' (revision 2026-10-01). Steps: specs/085-privacy-defect-fixes/quickstart.md 'Owed to a person (GUI)': G1 F1 five entry points (SC-001), G2 F1 cleaning of old entries, G3 F3 (SC-003), G4 F7 (SC-006), G5 F6 (SC-005), G6 F4 (US6).

## Expected

G1-G6 pass as the quickstart describes; recorded in 085's fix-log.

## Notes

Use a test profile: reg export HKCU\Software\Tandem Commander first and restore it afterwards; close your own Tandem Commander before starting the Debug build.

## Steps

- [ ] G1 - F1, five entry points: a password typed as part of an address (e.g. Zz085secret) never reaches a history
- [ ] G2 - F1, cleaning of old entries: an ftp://alice:Zz085secret@host entry from 0.1.8 in Change Dir History / Host Address History is shown without the password; save, export, search - 0 hits
- [ ] G3 - F3: F3 on each specs/085-privacy-defect-fixes/probe/autonav_*.md, wait 30 s - no browser window, no second viewer window, no message box; a click on the link opens once
- [ ] G4 - F7: with a Master Password set (after a restart), SFTP Save password, Cancel the Master Password prompt - Save password unchecked, no Password value stored; with the right Master Password - stored encrypted; the same for a key passphrase
- [ ] G5 - F6: a configuration saved by 0.1.8 with FTP / SFTP passwords with and without a Master Password - every bookmark logs in; a newly saved password logs in after a restart
- [ ] G6 - F4: a .md and a .cpp file in the same session both render; with 0.1.8 running and having shown a .md, the new build says 'engine unavailable' and closes the window; after closing 0.1.8 it renders

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
