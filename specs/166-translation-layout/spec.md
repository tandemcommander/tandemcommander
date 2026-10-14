# Feature Specification: translation layout - the drift measured, an untranslated dialog

**Feature Branch**: `166-translation-layout`
**Created**: 2026-10-14
**Status**: Implemented in part - see fix-log.md
**Input**: `specs/NEXT-WORK.md` item 16 (106): the merge tool would re-lay out the committed
ZIP translations; measure what that drift is before deciding.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - every shipped dialog is translated (Priority: P1)

A user with a translation opens the Markdown Viewer's configuration: it was English in every
language. Now it is translated and every text fits its control (measured in the dialog font).

### User Story 2 - the tool does not make labels cross a frame (Priority: P2)

The merge widens a clipped label only into free space inside its group box.

### Out of scope (recorded)

The 711 labels clipped in the committed translations (no free space - shorter texts or wider
dialogs per language, with a visual check per dialog).

## Requirements *(mandatory)*

- **FR-001**: Translations through the pipeline (DeepL + pins for what does not fit or the
  corpus' form); no new source string.
- **FR-002**: `widen` never grows a control past the frame that contains it.
