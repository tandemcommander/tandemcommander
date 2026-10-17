---
title: Unshipped resources still carry 2023 Open Salamander-only copyright notices
type: tech-debt
status: new
severity: 1
area: build-release
source: review:243
who: agent
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Unshipped resources still carry 2023 Open Salamander-only copyright notices

## Problem

Four resource files still carry only "Copyright © 1997-2023 Open Salamander Authors" (salopen: 2000-2023), without the Tandem Commander holder that every shipped notice has since feature 040 (`VERSINFO_HOLDER_TANDEM`, the copyright rule of `architecture/12-project-reference.md`): the version resources of `salopen.exe`, the old `setup.exe` / `remove.exe` and `sfx7zip`, and the visible About texts of the old setup dialogs. None of these binaries is in the shipped Release tree today, so no user sees them; they are wrong the moment one is shipped again.

## Evidence

At `c3319ffa`: `src/salopen/salopen.rc:27`; `src/setup/setup.rc:56, 143, 398, 441, 680, 723, 962`; `src/setup/remove/remove.rc2:42`; `src/sfx7zip/resource.rc2:35`. The Release tree `build\tandemcommander\Release_x64` holds `tandemcommander.exe`, `plugins\`, `utils\sqlite.dll`, `lang\`, `toolbars\`, `convert\` and the VC++ runtime - no `salopen.exe`, `setup.exe`, `remove.exe` or 7-Zip SFX module. Found by the version sweep of feature 243 (`specs/243-tandem-release-skill/research.md` F12).

## Expected

Each notice follows the copyright rule (concatenating `VERSINFO_HOLDER_TANDEM`, as `src/versinfo.rh2` and the shipped standalone `.rc` files do), or the unshipped projects are recorded as not shipped so the rule's list of converted files is complete.

## Notes

Whether these projects are still built at all was not checked; if not, removing them from the solution may be the simpler fix. Not a release blocker (nothing shipped is affected).

## Log

- 2026-10-17 — created (source review:243)
