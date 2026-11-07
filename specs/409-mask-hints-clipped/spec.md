# Feature Specification: The mask hints link fits in every translated dialog

**Feature Branch**: `409-mask-hints-clipped`
**Created**: 2026-11-07
**Status**: Draft
**Input**: User description: "Backlog item porovnani-adresaru - The mask hints link is clipped in translated dialogs (Compare Directories and 10 more)." From backlog item porovnani-adresaru.

## Clarifications

### Session 2026-11-07

- Q: Should the merge's widening pass (`tools/translate/layout.py`) learn to grow right-aligned controls to the left instead of setting the width in the English layout? → A: No - the 11 controls get their width in the English layout; the widening pass is not changed, because changing it would re-lay out every right-aligned control of every module on its next merge, outside this item (autonomous run: conservative).
- Q: Which language besides Czech is pictured on the hidden desktop? → A: French, the longest text of the enabled languages (autonomous run: conservative).
- Q: Are the Czech, Slovak, Dutch and Hungarian texts pinned although they do not change? → A: No - only the texts this feature changes are pinned (German, French, Spanish, Romanian); the others keep their committed wording, which a merge with no new English text leaves alone (autonomous run: conservative).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The mask hints link is readable in Compare Directories (Priority: P1)

A user of the Czech translation opens *Compare Directories* (the dialog reported in GitHub issue #11). Under the *Ignore directories* field there is a link that explains the mask syntax ("nápověda k masce"). Today its first letters are cut off because the text is wider than the control. After the change the whole text is visible and the link still opens the mask hint when clicked.

**Why this priority**: it is the reported defect.

**Independent Test**: open Compare Directories in Czech and in one more enabled language on the hidden desktop and capture the dialog; the link text is complete. The layout checker reports no clipped row for this control in the dialog.

**Acceptance Scenarios**:

1. **Given** the Czech translation, **When** the user opens Compare Directories, **Then** the whole "nápověda k masce" is shown, its right end aligned where it was.
2. **Given** French, Slovak, Spanish or Romanian, **When** the user opens Compare Directories, **Then** the whole link text is shown.
3. **Given** English, **When** the user opens any of the 11 dialogs, **Then** the link looks and behaves exactly as before (same text, same right edge, clickable only on its text).

---

### User Story 2 - The same link fits in the other ten dialogs (Priority: P1)

The same mask-hints link appears in ten more dialogs of the core: Select files (D100), Unselect files (D104), Copy/Move more options (D205), Change filter (D405), Unpack (D520), Configuration > System (D535, the recycle-bin masks), Configuration > Viewer (D630), Configuration > Unpackers (D2320), Configuration > Archive associations (D2350, "extended mask hints") and Convert (D2490). In every enabled translation the link text fits its control in all of them.

**Why this priority**: the same defect, the same control; the item covers all dialogs at once.

**Independent Test**: `python -I -X utf8 specs/166-translation-layout/probe/layout_check.py translations --list` prints no `CLIP <enabled language>/salamand D<n> #102` row and no `CROSS` row that HEAD did not print.

**Acceptance Scenarios**:

1. **Given** any enabled language (czech, german, french, dutch, hungarian, romanian, slovak, spanish), **When** the checker runs, **Then** none of the 11 mask-hints rows is reported as clipped.
2. **Given** a later translation merge of the core module, **When** it runs with no new English text, **Then** the mask-hints rows keep their wording and fit (the wording is pinned, the width comes from the English layout).

---

### User Story 3 - The Romanian text says what the link does (Priority: P2)

The Romanian link reads "mascheaza indiciile" ("masks the hints") in Compare Directories and "masca indicii" in some others. After the change it reads "indicii pentru măști" ("hints for masks") in every dialog, and the extended variant "indicii pentru măști extinse".

**Why this priority**: a mistranslation named by the item; small and independent.

**Independent Test**: read the Romanian `.slt` rows of control 102 in all 11 dialogs.

**Acceptance Scenarios**:

1. **Given** the Romanian translation, **When** any of the 11 dialogs opens, **Then** the link reads "indicii pentru măști" (D2350: "indicii pentru măști extinse").

### Edge Cases

- A translation whose text already fits (Dutch, Hungarian) keeps its wording.
- A dialog where the link has a neighbour to its left on the same line (Configuration > System: the "Hold SHIFT…" text; Configuration > Unpackers: the *Unpack with* box) - the link grows only into free space and overlaps nothing new.
- Configuration > Recycle Bin (D535): the wider link would take the room the merge gives the "Hold SHIFT to delete…" label on the lines they share; the label and the one below it move 2 du down inside their group box, so the two no longer share a line (measured in fix-log.md; English: the two lines are 3 px lower).
- A later merge: the merge re-derives every control's geometry from the English layout and grows a too-narrow control to the right; the English width must be large enough that the merge leaves these rows alone, so the right edge stays.
- Disabled languages (russian, ukrainian, chinesesimplified) are not built or shipped; their rows are not a goal, but they also must not get worse.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: In every enabled language, the mask-hints link text MUST fit its control in all 11 dialogs that have it (the checker reports no clipped row for control 102).
- **FR-002**: Where a shorter natural wording exists, the translated text MUST be shortened to it and pinned in `translations/ui-overrides.json`: German "Maskenhinweise" / "erweiterte Maskenhinweise", French "aide sur les masques" / "aide sur les masques étendus", Spanish "ayuda de plantillas" / "ayuda de plantillas ampliadas". Czech and Slovak keep "nápověda k masce" / "nápoveda k maske" (no shorter natural wording) and their extended variants.
- **FR-003**: The Romanian text MUST read "indicii pentru măști" (extended "indicii pentru măști extinse") and be pinned.
- **FR-004**: The control MUST be widened to the left only, keeping its right edge, inside the dialog's free room, so that it fits every enabled language's text; the width MUST be set in the English layout so that a later merge reproduces it and does not grow the control to the right.
- **FR-005**: English MUST look and behave as before: same text, same right edge; the link is still clickable only on its text.
- **FR-006**: The change MUST NOT add a `CROSS` row to the checker's output and MUST NOT make the link overlap another control it did not overlap before.
- **FR-007**: The per-language items `translations-clipped-labels-<lang>` MUST get a *Log* line saying their `#102` rows are done by feature 409.
- **FR-008**: Pictures of Compare Directories in Czech and in at least one more enabled language, taken on the hidden desktop with the registry backed up and restored, MUST show the whole link.

### Key Entities

- **Mask-hints link**: the right-aligned link control 102 (`IDC_FILEMASK_HINT`) in 11 dialogs of the core; English text "mask hints" (D2350: "extended mask hints").
- **Pin**: a hand-chosen translation in `translations/ui-overrides.json`, keyed by the English text, that every merge applies as a human text.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The checker lists 0 clipped mask-hints rows for the 8 enabled languages (at HEAD: 55 - cs 11, fr 11, sk 11, es 11, de 10, ro 1).
- **SC-002**: The checker's `CROSS` rows are no more than at HEAD (none new).
- **SC-003**: Compare Directories pictures in Czech and one more language show the complete link text.
- **SC-004**: English dialogs are unchanged to the user (same text and right edge in all 11 dialogs).
- **SC-005**: A dry-run merge of the core module after the change reports no new gaps, and the committed rows round-trip byte-exact.

## Assumptions

- Assumption (autonomous run): the width is set in the English template `src/lang/lang.rc` rather than only in the per-language `.slt` files, because every merge re-derives the `.slt` geometry from the English template (`tools/translate/merge.py`, feature 244 onwards) - a `.slt`-only edit would not survive.
- Assumption (autonomous run): the English width is chosen to be at least the merge's own width estimate for every enabled language's pinned text, so the merge's widening pass (which grows controls to the right, `tools/translate/layout.py`) leaves these rows alone and the right edge stays.
- Assumption (autonomous run): Dutch and Hungarian texts already fit and keep their wording; disabled languages are not pinned.
- Assumption (autonomous run): Romanian pins use the diacritics the recent pins of the corpus use (feature 404: "celălalt", "Filă").
- The link draws its text right-aligned and its hit test and focus rectangle cover only the text (`CStaticText`, `src/gui.cpp`), so a wider control is invisible in English.
