# Contract: the "whole text fits" helpers (core only, no plug-in interface)

## `BOOL SalWTextFitsU8(const WCHAR* src, int bufSize)` - `src/common/salunicode.h`

- TRUE when the UTF-8 form of the null-terminated `src`, with its terminator, needs at most
  `bufSize` bytes. WTF-8: a surrogate pair is 4 bytes, a lone surrogate 3.
- `src == NULL` is the empty text (needs 1 byte).
- FALSE for `bufSize <= 0` and when the size cannot be computed (fail closed).

## `BOOL SalWindowTextFitsU8(HWND hWnd, int u8BufSize)` - `src/common/winlib.h`

- `SalWTextFitsU8` of the window's whole text (`GetWindowTextLengthW` + `GetWindowTextW`).
- FALSE when there is no memory for the copy.

## `char* SalGetWindowTextU8Alloc(HWND hWnd)` - `src/common/winlib.h`

- The window's whole text as UTF-8 (WTF-8), `malloc`'d, never cut; the caller frees it.
- NULL when there is no memory.

## `BOOL DlgItemTextFitsU8(HWND dlg, int ctrlID, CTransferInfo* ti, int bufSize)` - `src/dialogs.h`

- TRUE when the control is missing or its whole text fits.
- Otherwise: "The path specified is too long." (`IDS_TOOLONGPATH`, owner `dlg`), then
  `ti->ErrorOn(ctrlID)` when `ti` is given, or the focus and the whole text selected in the
  control; returns FALSE.
