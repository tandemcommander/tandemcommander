# Research - 276 the information line shows items with very long names

## R1 - where the box comes from (measured at de31d72a)

- Decision: the default Information Line content
  `$(FileName): $(FileSize), $(FileDate), $(FileTime), $(FileAttributes), $(FileDOSName)`
  (src/dialogs4.cpp) expands the name twice when the item has no short name -
  `FileDataExpFileDOSName` (src/execute.cpp) returns `DosName != NULL ? DosName : Name`. A 604-byte
  name needs 2 x 604 + about 50 bytes; `ItemFocused` gives 1000; `DoExpandVarString` reports
  IDS_EXP_SMALLBUFFER and returns FALSE; `ItemFocused` then leaves the information line alone.
- Evidence: probe `infoline276_probe.ps1` before: ARCCAP / ARCDEEP one box each, the line's pixels
  unchanged; DISK (754-byte file with the 8.3 name 0771~1.TXT) no box - a short name keeps it
  under 1000 bytes.
- Callers: `ExpandInfoLineItems` has one caller, `CFilesWindow::ItemFocused`. The selection
  summary (src/fileswnb.cpp) and the empty panel text (src/fileswn3.cpp) do not expand names.

## R2 - grow or shorten

- Decision: grow the buffer; the text is never shortened.
- Rationale: CLAUDE.md "a path or name is never cut"; the item's *Expected* asks for a shortening
  only "if it does not fit" - with growth everything reachable fits. `CStatusWindow::SetText`
  copies any length to the heap and draws with clipping.
- Alternatives: shortening each value to a byte budget at a whole letter (needs a change inside
  `DoExpandVarString` shared with the User Menu, Make File List and others - more risk, and it
  would cut the name for no reason).

## R3 - the bound

- Decision: 65,535 bytes (`SAL_INFOLINE_MAX_LEN`).
- Rationale: hot-text placements are `MAKELPARAM(position, length)` - WORDs; a longer buffer would
  wrap them. Largest text from names alone: the content holds at most 199 characters, a
  name-valued variable token is at least 11 (`$(FileName)`), so at most 18 names; a listed name
  has at most 255 UTF-16 units = 765 bytes (the ZIP listing refuses longer names, feature 222; a
  disk name is limited by Windows) - 18 x 765 + 199 = 13,969 bytes. Another lister (7-Zip, tar,
  a plug-in file system) that took longer names still fits names of up to 3,600 bytes each. Only width modifiers
  (`:9999`, padding spaces) can exceed the bound; then the old box is shown (FR-006).
- Growth: 1000 (stack) -> 2000 -> 4000 -> ... -> 64000 -> 65535 -> stop; 8 attempts at most.

## R4 - boxes during the attempts

- Decision: attempts before the last pass `msgParent = NULL` (`DoExpandVarString` then only
  traces); the last attempt passes the panel window.
- Rationale: a size failure of an intermediate attempt must not show a box; a malformed content
  (syntax error - the Configuration dialog validates, the registry may not) fails every attempt
  and gets its box once, from the last attempt - the old behaviour (FR-006). The environment
  variable errors are already ignored (`ignoreEnvVarNotFoundOrTooLong = TRUE`).
- Low memory while growing: a trace, the line keeps its text (no box, nothing lost).

## R5 - the plug-in route

- Decision: unchanged. `GetInfoLineContent` writes into the 1000-byte stack buffer
  (spl_com.h documents 1000 bytes); only when it returns FALSE does the core expand.
