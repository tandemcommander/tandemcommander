# Feature Specification: The small leftovers of features 097-100

**Feature Branch**: `101-small-leftovers`
**Created**: 2026-10-03
**Status**: Draft
**Input**: the maintainer: *"ok oprav je"* - fix the minor items left in `specs/NEXT-WORK.md` item 5 by features 097-100. (The File Comparator's code-page-only file names are a larger, separate item: feature 102.)

## Clarifications

### Session 2026-10-03

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Which items? → A:
  1. **Tray icon tip** (`SetTrayIconText`, `mainwnd1.cpp`): UTF-8 copied into the ANSI tip - every non-ASCII name is garbled and can be cut mid-character. Fix: the Unicode notification-icon structure.
  2. **Clipboard path paste** (Ctrl+Shift+V, `ClipboardPastePath`) refuses paths of 520 bytes or more, although Change Directory now takes any length: accept any length the program handles.
  3. **Find window's "copy UNC name"** fails silently on a too-long path (the old clipboard content stays and could be pasted by mistake): show the existing "path too long" message.
  4. **Share-prefix matching** (`CShares::GetUNCPath`) cuts the path to 259 bytes: compare the whole path.
  5. **Dragging a directory-line component** of a path over ~7,500 characters builds a drag image ~280,000 pixels wide: cap the image width.
  6. **The link warning names an unreadable or too-deep folder as a "Link"** (feature 098/099 reuse of `IDS_DELFILESAFTERPACKINGNOLINKS`), and at nesting depth 1,001 the message says "too long" although the cause is the depth: **new, exact strings**, translated to the eight enabled languages with the project's pipeline (`translate.merge`, formal register pinned where DeepL drifts).
  7. **The probes' posted-F4 timing flake** (096's probe; seen in several regression runs): make the probe wait for the editor reliably.
- Q: New strings - the earlier features avoided them? → A: They avoided them to keep their scope; here the misleading text *is* the defect, so new strings are right. Translation work follows the established pipeline (features 079, 084): English source, `translate.merge` for the eight enabled languages, provenance recorded, pins in `translations/ui-overrides.json` where needed.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The tray tip shows the folder name exactly (Priority: P2)
**Acceptance**: with the program minimised to the tray in a folder named with Czech, Cyrillic or Chinese characters, the tip shows the name exactly; long names are cut at a whole character.

### User Story 2 - Clipboard paths of any length (Priority: P2)
**Acceptance**: a 600- and a 5,000-byte path pasted with Ctrl+Shift+V goes there; a path that cannot exist shows the usual error; nothing is cut.

### User Story 3 - Messages say what happened (Priority: P3)
**Acceptance**: a Move with an unreadable folder in the selection says that the folder cannot be read and that the files will not be deleted; a folder nested deeper than the limit says so; a link still says "link"; every enabled language has the new texts.

### User Story 4 - No silent failures and no absurd drag image (Priority: P3)
**Acceptance**: the Find window's UNC copy of a too-long path shows the message; share look-up of a deep path under a share gives the right UNC path; dragging a component of a very long directory line works with a reasonably sized image.

### Edge Cases
- Tray tip limit (128 UTF-16 units) with a surrogate pair at the cut.
- Clipboard holding only `CF_TEXT` (code page) vs `CF_UNICODETEXT`.

## Requirements *(mandatory)*
- **FR-001**: The tray tip MUST be set through the Unicode structure, cut at a whole character.
- **FR-002**: The clipboard path paste MUST accept any length the program handles.
- **FR-003**: Silent refusals listed above MUST show the existing message.
- **FR-004**: Share matching MUST use the whole path.
- **FR-005**: The drag image width MUST be capped.
- **FR-006**: The new messages MUST be exact and present in all enabled languages (English + 8), with recorded provenance.
- **FR-007**: The 096 probe MUST NOT depend on a lucky timing for F4.
- **FR-008**: No plug-in interface change; behaviour unchanged for everything else.

## Success Criteria *(mandatory)*
- **SC-001**: Probe rows for each item pass on the new build; the build before shows the old behaviour where it can be driven.
- **SC-002**: The translation merge reports 0 gaps for the enabled languages; the formal register is kept (pins checked).
- **SC-003**: Debug and full Release builds (language modules included), unit tests, strict guard, and the probes of 093 and 095-100 pass; 096's probe passes 17/17 three times in a row.
