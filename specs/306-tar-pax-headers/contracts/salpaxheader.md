# Contract - src/common/salpaxheader.h (feature 306)

Header-only, no Windows types; for the tar plug-in and `saltests`. Not part of the plug-in ABI.

| Function | Contract |
|---|---|
| `SalPaxInit(v)` / `SalPaxClear(v)` | empty values / free `Path` and empty |
| `SalPaxNextRecord(data, size, &pos, &key, &keyLen, &val, &valLen)` | 1 = a record at `pos` (advanced past it); 0 = end (pos == size, or only NUL bytes left); -1 = malformed: length not decimal, not followed by a space, longer than the rest, shorter than `"N k=\n"`, not ending in `\n`, no `=` or an empty keyword |
| `SalPaxParseSize(s, n, &out)` | true for 1..19 decimal digits with a value <= 2^63-1 |
| `SalPaxParseTime(s, n, &sec, &frac)` | 1 = valid and representable; 0 = valid syntax, outside SAL_PAX_MTIME_MIN..MAX; -1 = malformed. Syntax `[-]digits[.digits]`, at most 18 integer digits |
| `SalPaxApply(data, size, v)` | applies every record to `v`: `path`, `size`, `mtime` (empty value → DELETED); other keywords ignored. SAL_PAX_OK / SAL_PAX_BAD (malformed record, invalid `size`, NUL inside `path`) / SAL_PAX_NOMEM. An invalid or out-of-range `mtime` leaves `v`'s time unchanged |
| `SalPaxEffectivePath(g, x)` / `SalPaxEffectiveSize(g, x, &out)` / `SalPaxEffectiveMTime(g, x, &sec, &frac)` | the precedence of data-model.md |
| `SalPaxPathHasTooLongComponentU8(path)` | true when a component between `/` or `\` separators has more than 255 UTF-16 units (UTF-8: a 4-byte sequence = 2 units; the rule of `SalNameUtf16UnitsU8`) |
