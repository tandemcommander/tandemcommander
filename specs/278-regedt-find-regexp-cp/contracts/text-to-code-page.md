# Contract - SalRegFindTextToCodePage (src/common/salregfind.h)

```cpp
int SalRegFindTextToCodePage(const WCHAR* text, int units, UINT codePage, char* out, int outSize);
```

- `units <= 0` or `text == NULL`: returns 0 (nothing to convert; `out` untouched).
- `out == NULL`: returns the byte count of `text[0, units)` in `codePage`
  (`WideCharToMultiByte(codePage, 0, ...)`, no NUL added), or -1 when it cannot be converted.
- `out != NULL`: converts into `out`; returns the byte count when the whole text fits
  `outSize`, otherwise -1. On -1 the content of `out` is unspecified and must not be searched.
- Never a partial result: a non-negative return is always the whole text's count.
- Header-only, needs `<windows.h>`; checked by saltests (feature 278).

Caller (`CFindThread::Test`, regexp branch): `need = f(text, units, CP_ACP, NULL, 0)`;
`need < 0` → no match; reserve `need` bytes (out of memory → no match, unchanged);
`len = f(text, units, CP_ACP, buffer, size)`; `len != need` → no match; search `[0, len)`.
