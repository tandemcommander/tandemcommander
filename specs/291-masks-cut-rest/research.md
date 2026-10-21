# Research - 291-masks-cut-rest

## R1 - Where the cut happens

- `CTransferInfo::EditLine(id, buf, MAX_PATH)` (`src/common/winlib.cpp`) sets the field limit to
  259 UTF-16 units and reads with `SalWToU8Truncate` (cut at a whole character, 093). CJK letters
  take 3 bytes, so 87-259 letters are cut. Sites: System (Recycle Bin masks), Viewer (text / hex
  masks), Compare Directories (`ValidateMask` and `Transfer`).
- Find: `HistoryComboBox(..., NAMED_TEXT_LEN = MAX_PATH)` sets `CB_LIMITTEXT 259`; `Validate` and
  `HistoryComboBox` read with `SalGetWindowTextU8(.., 260)` (cut). `HistoryComboBox` in
  `ttDataFromWindow` writes what it read back into the field (`SalSetWindowTextU8`) and into the
  history - so a `TransferData` without `Validate` (Add Current, Manage, Ignore) leaves a cut text
  in the field that passes the next `Validate`.
- Find `LoadControls`: an option with an empty Named keeps the field's text through a cut read.
- Views: `LVN_ENDLABELEDIT` reads into `char name[VIEW_NAME_MAX = 30]`; the list view's label edit
  has no 30-byte limit (30 ASCII letters stored as 29, measured).

Decision: measure the whole text first (`DlgItemTextFitsU8`) where 251 / 270 do; keep the fixed
buffers. Alternatives rejected: growing the buffers (registry layout, other readers - maintainer's
area, and 270 kept the sizes); limiting fields to 86 units (would refuse ASCII text that fits).

## R2 - The view name message

No string says "name too long"; `IDS_TOOLONGNAME` is about a copy operation. 251 already uses
`IDS_TOOLONGPATH` for non-path fields. Decision: `IDS_TOOLONGPATH`, no new string.

## R3 - Disabled compare fields

`Transfer` stores both ignore mask fields whatever the check boxes; a field can hold an over-long
text only if typed (stored masks are below 260 bytes). Decision: refuse too (clarification 2); the
mark cannot focus a disabled field, the message still names the problem.
