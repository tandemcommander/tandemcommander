# Research - 397 hex mode in Find keeps quoted letters

## R1 - Where the letters are lost

- Decision: only in `DoHexValidation` (`src/viewer.cpp`): `SendMessage(edit, WM_GETTEXT, …)` and
  `SendMessage(edit, WM_SETTEXT, …)` are code-page messages in this non-UNICODE build; the combo box
  is a Unicode window (feature 093: manifest, `AttachToWindowKeepKind`), so the system converts
  through the ACP and every character outside it becomes `?`.
- Evidence: `probe/result_before.txt` (`"?????" 41`, the decoys found).
- Downstream is UTF-8 already: `HistoryComboBox` reads with `SalGetWindowTextU8`, its hex check
  lets anything through inside quotes, `ConvertHexToString` copies quoted bytes. No change there.

## R2 - Units of the caret

- Decision: work on UTF-16; the caret from `CB_GETEDITSEL` and the one written by `CB_SETEDITSEL`
  are positions in the Unicode edit's text (UTF-16 units). The old code mixed them with byte
  offsets of the ACP text - equal only for single-byte code pages.
- Alternative: UTF-8 (`SalGetWindowTextU8`) - rejected: the caret would need converting both ways
  and the length limit would be counted in bytes while the field limits units.

## R3 - Length handling (item's *Notes*)

- Old: a buffer of `textLen` bytes; a space is inserted only while `strlen < textLen - 1`, so the
  tidied text never exceeds `textLen - 1` = the field's `CB_LIMITTEXT` (200).
- Decision: read the whole text (`GetWindowTextLengthW`) into a heap buffer of
  `max(len, textLen - 1) + 1` units; insert a space only while the length is below `textLen - 1`
  units (the same limit, now in the field's own units). Nothing is removed except the spaces the
  rule always folded; a text longer than the limit (only possible through `WM_SETTEXT` by the
  program) is kept whole, never cut. The UTF-8 length is checked at OK by `DlgItemTextFitsU8`
  (feature 311) in both dialogs: refused, not cut.

## R4 - Surrogate pairs

- Outside quotes the rule inserts a space before every third character of a token (`ABC` →
  `AB C`), counting units. A pair at that place would be split. Decision: no insertion before a low
  surrogate that follows a high surrogate (the token then stays ungrouped; it is not hex and is
  refused at OK as before). Inside quotes nothing is inserted between characters.

## R5 - Writing back

- Decision: `SetWindowTextW` on the combo box then `CB_SETEDITSEL`, as before (always written).
  A combo box's `WM_SETTEXT` does not send `CBN_EDITUPDATE` (311's note: probe rows that set the
  text do not run the validation), so no recursion.

## R6 - Related site seen on the way

- `HistoryComboBox` selects the first non-hex character with `CB_SETEDITSEL` at `s - Text`, a byte
  offset of the UTF-8 text: after quoted non-ASCII letters it selects the wrong characters. A
  different site and function (the OK-time check) -> Inbox item (`measure:397`), not this feature.
