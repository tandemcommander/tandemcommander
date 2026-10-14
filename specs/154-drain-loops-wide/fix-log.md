# Fix log: 154 - typed text survives the core's drain loops

Backlog: `specs/NEXT-WORK.md` item 9 (093's fix-log, "Recorded, not changed" 1 and 2).

## Before (measured)

`probe/drain_loop_probe.ps1`: WM_CHAR posted per UTF-16 unit to the command line's inner Edit
(Unicode since 093). The application is deactivated (WM_ACTIVATEAPP sent FALSE); then, with the
program's main thread held still (SuspendThread), `WM_USER_END_SUSPMODE` - what an activation
posts - and the characters are posted and the thread resumed: the handler (`mainwnd3.cpp`) drains
the queue with a code-page loop before the panels refresh, and that loop dispatches them.

**A finding of the first probe:** it posted the characters right after a SENT activation - a race
with the program's main loop: on the build before, the row failed in 2 of 4 runs (and passed in
4 of 4 on the 151 build) - a pass there proved nothing. Holding the thread makes the order fixed:
the builds before fail 7 of 7, the fix passes 4 of 4.

| row | build before (`probe/result_pre154.txt`) | fix (`probe/result.txt`) |
|-----|-----|-----|
| main-* (the main loop, wide since 093) | PASS | PASS |
| susp-cyrillic | **FAIL** (7 of 7 runs, 151 and 153 builds): 0416 0443 043A arrived as 003F 003F 003F | PASS (4 of 4) |
| susp-latin1 (code page 1252, the layout's) | PASS | PASS |
| susp-ascii | PASS | PASS |

As 093 found, a code-page loop converts through the keyboard layout's code page: what a layout
types in its own code page survives; what lies outside it (another script through an input method
or a Unicode-only layout, the emoji panel, text posted by another program) arrives as `?`.

## Work

The loops that dispatch messages to windows take the wide forms (093's pattern for the thread
main loops): `dialogs.cpp` (the worker's suspension drain), `dialogs6.cpp`
(`CCmpDirProgressDialog::Continue`, with `IsDialogMessageW`), `mainwnd2.cpp` (the start-up
drain), `mainwnd3.cpp` (the end of suspend mode; the wait at `WM_QUERYENDSESSION`), `pack3.cpp`
(waiting for an external archiver), `regwork.cpp`, `zip.cpp` (`CZIPUnpackProgress`, with
`IsDialogMessageW`), `viewer2.cpp` (the internal viewer thread's main loop, with
`TranslateAcceleratorW` - consistency only: the viewer window handles no characters and its Find /
Go to dialogs are modal with loops of their own; `IDA_VIEWERACCELS` has only VIRTKEY entries).

Not changed, each with its reason:
- loops that only discard messages (`WM_KEYFIRST..WM_KEYLAST` removed without dispatch) or peek one
  private message - nothing reaches a window;
- the help mode (`mainwnd4.cpp`): it peeks with `PM_NOREMOVE` and removes later with a filter - a
  mixed A/W pair; a key ends the mode, there is no text input;
- the tooltip's modal loop (`tooltip.cpp`): `WM_KEYDOWN` ends it before its character exists;
- the wait-window thread (`salamdr2.cpp`): its own windows only, no text input;
- the menus' own loops (`menubar.cpp`, `menu2.cpp`): the mnemonic is matched as a code-page byte
  against the code-page menu texts (`LoadStr` in `CMenuPopup::LoadFromTemplate2`) - consistent as
  it is, with the layout's code page equal to the system's (the usual case); a wide loop would
  need a matcher of its own (`SalMnemonicMatchW` exists for the menu bar since 093).

## Review (refute-first agent, 2026-10-14)

No critical or medium finding. Confirmed: none of the nine loops reads `msg.wParam` of a key or a
character or mixes A and W on one message; the handlers' own peeks only discard; the queue holds
UTF-16 (a `PostMessageA` converts at post time), `DispatchMessageW` to an A window converts through
the thread's input code page as the A peek did - the main loop has done so since 093; the two
`IsDialogMessageW` dialogs hold buttons and progress bars only; no A loop left delivers a typed
character to a Unicode field (`msgbox.cpp` commented out; help mode dispatches only system
commands and keys; `salamdr1.cpp`'s `TranslateAccelerator` A on a wide message is harmless - no
character entries in `IDA_MAINACCELS1/2`, pre-existing). Taken over: the viewer change described
as consistency only, its owed step dropped; one of nine loops is driven, the others rest on the
pattern (stated). LOW, pre-existing: a CJK DBCS character for an A window is now split in user32's
dispatch instead of in the A peek (as for the main loop since 093; zh-CN is off).

## After

- Debug build clean; `check_encoding.py` TOTAL 0.
- `probe/result.txt` 7/0 (before 6/1).
- Regression: 093 `cmdline_probe` 63/0 (`probe/regress_cmdline093_154.txt`); 093 `dialogs_probe`
  128/8 twice (`probe/regress_dialogs093_154.txt`; the build before: `regress_dialogs093_pre152.txt`
  140/0) - the 8 rows are the Find menu's Alt+M/E/V/O (posted and key), the known hidden-desktop
  artefact of NEXT-WORK item 18. **Sampled** with `-Only drive`: the 151 build (`Debug_x64_pre152`)
  failed them in 1 of 5 runs; every later build failed them in 3 to 5 of 5 - with 154, without the
  drain loop of the suspend mode, the 153 build WITHOUT 154 (4 of 5), and the 153 program inside the
  151 build's folder (3 of 5). So not 154; neither 153 nor 154 code runs in that scenario (Find and
  its menu bar on the Find thread). Recorded in NEXT-WORK item 18: the rate depends on the build.
- LOSSY 1 in both builds: the Configuration first-page edit row (pre-existing, unchanged).
- Owed to a person: a real keyboard with an input method or a Unicode-only layout, typing while the
  program comes back to the foreground.
