# Research - 311 Find's Containing text and the viewer's Find text

## R1 Where the text is cut

- Decision: refuse before every read into `GREP_TEXT_LEN` / `FIND_TEXT_LEN`.
- Rationale: the combo limits text to 200 UTF-16 units (`CB_LIMITTEXT textLen - 1`), the buffer
  holds 200 UTF-8 bytes; `HistoryComboBox` reads with `SalGetWindowTextU8` (cuts at a whole
  character), writes the cut text back (`SalSetWindowTextU8`) and into the history. Measured at
  95145b44: 8 rows FAIL (see spec *Background*).
- Alternatives: grow the buffers (`GREP_TEXT_LEN` 601) - changes the search engine's buffers
  (`char hex[GREP_TEXT_LEN]`, `CFindSetDialog::Text`, `FIND_LINE_LEN` relation "must be >
  FIND_TEXT_LEN"), stored option sizes, and the item asks for the refusal; rejected.

## R2 Hex mode and regular expressions

- Decision: one check of the field covers both.
- Rationale: both read the same field through the same `HistoryComboBox`; hex mode allows quoted
  text of any characters (`"..."`), so its UTF-8 form can exceed 200 bytes too (measured: 206
  bytes searched as the quoted part alone). A cut unclosed quote would instead hit "not hex".

## R3 The copy into the viewer's Find

- Decision: skip the copy when the field does not fit `FIND_TEXT_LEN`.
- Rationale: `UpdateInternalViewerData` reads the field with the core `CTransferInfo::EditLine`,
  which cuts at a whole character (feature 093 contract D4), and stores the text into
  `GlobalFindDialog.Text` and `ViewerHistory`. The field can change after a search, so a validated
  search does not guard it. Skipping keeps viewing unchanged and stores nothing cut (clarification).
- Alternatives: refuse viewing with the message - blocks an unrelated action; rejected.

## R4 The viewer's Find dialog

- Decision: `CFindSetDialog::Validate` with `DlgItemTextFitsU8`.
- Rationale: winlib's `ValidateData()` runs before `TransferData` on OK; the refusal keeps the
  dialog open with the field focused and selected (`ErrorOn`). Measured: 67 CJK letters were
  searched cut (no "cannot find" for a text the file does not hold).
