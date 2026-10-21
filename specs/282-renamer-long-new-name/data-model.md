# Data model: 282

- **CSourceFile** (`crenamer.h`): `FullName` (heap, UTF-8 / WTF-8), `Name`, `Ext` (pointers into
  it), `NameLen` - now 29 bits (was 15): holds `strlen(FullName)` up to `REN_MAX_NAME - 1`.
  `IsDir : 1`, `State : 1` unchanged.
- **New name** (built per item): `REN_MAX_NAME` bytes of storage incl. the terminator; the folder
  part (file-name mode: the item's folder; relative-path mode: `Root\`; full-path mode: none) +
  the expanded pattern. Valid when it fits; otherwise refused ("Expanded string is too large.").
- **CRenameScriptEntry**: `NewName` (`DupStr` of the built name - exact size, unchanged).
