# Data model: feature 124

No stored data. Two in-memory texts of the plug-in change their form:

| Text | Before | After | Readers |
|------|--------|-------|---------|
| `KeyText` | `char[10]`, code page, cut by `lstrcpyn` | `char[100]`, UTF-8, whole or `KEY` | `GetSizeText` (Size column, `$(Size)` of the information line) |
| `KeyTextW` | - | `WCHAR[32]`, the resource text, whole or `KEY` | `CFoundFilesData::GetText` (Find window, Size cell) |
| `KeyTextLen` | byte length of `KeyText` | the same (of the UTF-8 text) | `GetSizeText` |
| selection templates | code page (`LoadStr`) into `char[200]` | UTF-8 (`LoadStrU8`) into `char[600]` | `ExpandPluralSelection`, `GetInfoLineContent` |

Invariants

- `KeyText` is always valid UTF-8 and is the UTF-8 form of `KeyTextW`.
- Neither text is ever a shortened translation: a text that does not fit is replaced by `KEY`.
