---
title: Clean-machine start: the installer on Windows without the Visual C++ runtime
type: person-step
status: open
severity: 6
area: build-release
source: leftover:077
who: person
created: 2026-09-17
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [rar-and-7zip-checks-087-089]
depends-on: []
reason: -
---

# Clean-machine start: the installer on Windows without the Visual C++ runtime

## Problem

Since 077 the Visual C++ runtime ships with the product (no release before it could start on a machine without the redistributable). That fix - advertised by 0.1.8 - has never been verified on a machine without the runtime; it was the most valuable step of the 0.1.8 ship gate.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'Environment or hardware' ('a clean machine without the Visual C++ runtime (077; item 0, point 1)') and §0 point 1 / §3 'Clean-machine start' (at 7993914c). Steps: specs/077-fix-antivirus-findings/quickstart.md 'Owed human step (cannot be done from this session - R7)'.

## Expected

On a Windows 10/11 VM or Windows Sandbox with no 'Microsoft Visual C++ 2015-2022 Redistributable (x64)' entry, the signed installer installs, the program starts from the final page, the main window opens and Plugins Manager lists all 20 plug-ins; the Windows build, the absence of the redistributable and the result are recorded in 077's fix-log.

## Notes

Windows Sandbox needs the optional feature Containers-DisposableClientVM (admin and a reboot on the development PC). The same Sandbox serves 087 step 1 (rar-and-7zip-checks-087-089).

## Steps

- [ ] Prepare a Windows 10/11 VM or Windows Sandbox without 'Microsoft Visual C++ 2015-2022 Redistributable (x64)' in Installed apps
- [ ] Run the signed installer; launch Tandem Commander from the final page
- [ ] The main window opens; Plugins > Plugins Manager lists all 20 plug-ins
- [ ] Record the Windows build, the absence of the redistributable and the result in specs/077-fix-antivirus-findings/fix-log.md

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
