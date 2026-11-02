# Research - 398 viewer Find seed

## R1 What the search compares
- Decision: the seed's UTF-8 form must equal the selected bytes for UTF-8 content.
- Rationale: `HistoryComboBox` reads the field with `SalGetWindowTextU8`; `InitFindDialog` gives
  those bytes to `SearchData.Set`; the search compares them with the viewer's `Buffer`. For UTF-8
  content, decoding as UTF-8 and re-encoding gives the same bytes - the word is found.
- Alternatives: converting the search text to the file's encoding (would make code-page and UTF-16
  content searchable) - a search-engine change outside this item; Inbox item (`leftover:398`).

## R2 Which encodings occur
- Decision: decode by `ContentEncoding` (VCE_LEGACY / VCE_UTF8 / VCE_UTF16LE / VCE_UTF16BE).
- Rationale: at HEAD only VCE_LEGACY and VCE_UTF8 are ever set (viewer2.cpp: UTF-16 left to the old
  path); the UTF-16 rule costs little and is checked by saltests, ready for the follow-up.
- Code page content: `Buffer` already holds the bytes after the viewer's conversion table
  (`CodeCharacters` at load), so decoding them with the ANSI code page gives what the old ANSI
  `WM_SETTEXT` gave (measured: row `legacy` pre-filled `café` before) - unchanged.

## R3 The limits
- Decision: at most 200 UTF-16 units and 200 UTF-8 bytes (`FIND_TEXT_LEN - 1` each).
- Rationale: the combo's `CB_LIMITTEXT` is `FIND_TEXT_LEN - 1` units; `CFindSetDialog::Validate`
  refuses when the UTF-8 form plus the terminator exceeds `FIND_TEXT_LEN` bytes. A seed within both
  is never refused.

## R4 How many bytes to read
- Decision: `2 * (FIND_TEXT_LEN - 1) + 2` bytes (402).
- Rationale: 200 UTF-16 units need 400 bytes (+2 for a pair across the end); UTF-8 and code-page
  content reach 200 units / 200 bytes within 200 input bytes for valid text, the rest is cut by the
  rule. The hex pre-fill keeps using the first `(FIND_TEXT_LEN - 1) / 3` bytes as before.

## R5 Invalid / incomplete sequences
- Decision: an incomplete sequence at the end of the bytes read is left out; an invalid byte inside
  becomes U+FFFD consuming one byte (the viewer's `ViewerDecodeChar` rule); a lone UTF-16 surrogate
  becomes U+FFFD; a double-byte code page's lead byte at the end is left out.
- Rationale: whole characters only (FR-003/004); U+FFFD as the viewer draws it (clarification).

## R6 Setting the field
- Decision: `SetWindowTextW` on the combo box (CLAUDE.md: controls keep `SetWindowTextW`, 100).
- Rationale: the combo's edit is a wide window (`AttachToWindowKeepKind`, 093); `WM_SETTEXT`
  through `SendMessageW` is the same.
