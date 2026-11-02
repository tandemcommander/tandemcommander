# Contract - `SalHexFieldTidyW` (`src/common/salhexfield.h`, feature 397)

```cpp
// text: NUL-terminated, buffer of `capacity` units; start/end: the caret in UTF-16 units;
// maxLen: a space is inserted only while the text is shorter than maxLen.
// Returns false (nothing changed) when text is NULL, capacity is 0 or capacity <= maxLen while
// the text is shorter than maxLen (no room to insert): the caller sizes the buffer
// max(len, maxLen) + 1.
bool SalHexFieldTidyW(wchar_t* text, size_t capacity, int* start, int* end, size_t maxLen);
```

Behaviour = the loop of `DoHexValidation` before 397, character for character, on `wchar_t`:

1. leading spaces removed, the caret moved left by their number (not below 0);
2. an opening `"` glued to a previous character gets a space before it;
3. a closing `"` glued to a next character gets a space after it;
4. outside quotes, a second space in a row is removed;
5. outside quotes, a token of three characters gets a space before the third (`ABC` → `AB C`) -
   **new**: not when the third unit is a low surrogate following a high surrogate;
6. every insertion needs `length < maxLen`; the caret moves by the same rules as before
   (`>` for an opening quote, `>=` elsewhere).

Callers: `DoHexValidation(HWND combo, int textLen)` with `maxLen = textLen - 1`, from
`CFindDialog::DialogProc` (`IDC_FIND_CONTAINING`) and `CFindSetDialog::DialogProc`
(`IDC_FINDTEXT`), on `CBN_EDITUPDATE` in hex mode without regular expressions.
