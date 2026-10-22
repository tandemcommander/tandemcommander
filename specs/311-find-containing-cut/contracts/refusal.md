# Contract - refusal of a text that does not fit (311)

Same contract as features 251 / 270 / 291 (`DlgItemTextFitsU8`):

- Measured: the whole text of the field, as UTF-8 (WTF-8), plus NUL, against the buffer size
  (`GREP_TEXT_LEN` for Find's Containing, `FIND_TEXT_LEN` for the viewer's Find); no memory to
  measure = does not fit (fails closed).
- Refused: `SalMessageBox(IDS_TOOLONGPATH, IDS_ERRORTITLE, MB_OK | MB_ICONEXCLAMATION)` - "The path
  specified is too long."; the field keeps its whole text, gets the focus with the text selected;
  nothing is read, searched, written back or stored.
- Order in the Find dialog: Named (291) first, then Containing.
- The copy of Find's Containing into the viewer's Find (view of a found file) is not a user action
  on the field: a text that does not fit is not copied, without a message.
