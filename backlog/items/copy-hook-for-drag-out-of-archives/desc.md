---
title: Is the missing shell copy hook (drag out of archives into Explorer) intended?
type: decision
status: open
severity: 3
area: archives
source: measure:083
who: person
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: -
feature: -
related: [encoding-sites-069-chose-not-to-convert]
depends-on: []
reason: -
---

# Is the missing shell copy hook (drag out of archives into Explorer) intended?

## Problem

The shell extension (`salext*.dll`, the copy hook used when dragging or copying out of archives into Explorer) is not shipped: its registration only runs if `utils\salext*.dll` exists (`src/salamdr1.cpp:4384-4398`), and the product ships neither DLL, so nothing is registered. Without it, the clipboard copy from an archive and its paste into Explorer are unreachable.

## Evidence

`specs/083-privacy-policy-winget/research.md` *Side findings*, F8 (withdrawn after T010; "whether the copy hook's absence is intended is a separate question"); `specs/085-privacy-defect-fixes/research.md` (end of file, open question); specs/NEXT-WORK.md item 7, F8 (L2075-2079 at 7993914c); `specs/160-drop-into-long-archive/fix-log.md` *Reachability* (the copy hook is the code-page `ICopyHookA` in `src/shellext/copyhook.c` and cuts the Explorer target at `MAX_PATH`). Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L497-499, at 7993914c).

## Expected

(not stated in the source)

## Notes

Shipping the extension again would touch the installer and `PRIVACY.md` (what the installer writes), and needs the cross-binary DROPFAKE/CLIPFAKE fix that 069 left unconverted (item encoding-sites-069-chose-not-to-convert) plus 160's MAX_PATH findings in the copy hook.

If the extension is shipped again (option B), its own defects come with it (NEXT-WORK §A item 12, L325 at 7993914c): clipboard copy FROM an archive into Explorer needs the shell extension; its copy hook is the code-page `ICopyHookA` and cuts the Explorer target at `MAX_PATH`, and the core cuts that target again (`src/mainwnd3.cpp` ~6175 `char tgtPath[MAX_PATH]`, `DoPasteOperation` `pathBuf`); `src/shellext/shellext.h` ~138 (`ICopyHookA`). Drop / paste INTO a 260+ byte archive was done by 160. Expected then: a wide copy hook and a target that is refused, never cut.

## Question

Is it intended that the product ships without the shell extension's copy hook, so that dragging or copying files out of an archive into Explorer is not supported?

## Options

- A - intended: keep the shell extension out; record the limitation.
- B - not intended: build, ship and register `salext*.dll`; first fix its code-page `ICopyHookA` and `MAX_PATH` cuts (160) and the DROPFAKE/CLIPFAKE pair together with `copyhook.c` (069 §2 item 2); update the installer and `PRIVACY.md` in the same change.

## Recommendation

(not stated in the source)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
- 2026-10-17 — migration review N3: merged paragraph reworded, migration remark removed
