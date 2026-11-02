# Data model - 387

- **Value data**: `data` / `size` bytes as `RegQueryValueExW` returned them; for a text type
  UTF-16LE with its NUL(s); `units = size / 2` (an odd last byte is not converted).
- **Result of `SalRegViewTextToCodePageAlloc(data, size, codePage, &out, &outLen)`**:
  - `SALREGVIEW_CONVERTED` - `out` is a `malloc`'d buffer of exactly `outLen` bytes, the whole
    code-page form of all units; the caller writes it and frees it;
  - `SALREGVIEW_UTF16` - `out` NULL, `outLen` 0: nothing to convert (`units == 0`) or the
    conversion is impossible; the caller writes `data` / `size` unchanged;
  - `SALREGVIEW_LOWMEM` - `out` NULL: the caller reports low memory and writes nothing.
