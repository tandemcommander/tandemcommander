# Contract - SalMaskOptimizeKind (src/common/salmaskopt.h, feature 283)

```cpp
// 0 = none, 1 = all ("*" or "*.*"), 2 = extension ("*.xxx": the byte shortcut)
int SalMaskOptimizeKind(const char* preparedMask, BOOL extendedMode);
```

Input: one mask after `PrepareMask` (spaces trimmed, `**` -> `*`, `*?` -> `?*`), NUL-terminated.

| Mask | Result |
|---|---|
| `*`, `*.*` | 1 |
| `*.` + at least one byte, none of them `*`, `?`, `.` (and `#` in extended mode), **all bytes < 0x80** | 2 |
| anything else (including `*.` + an extension with any byte >= 0x80) | 0 |

Rules:
- For every mask whose bytes are all < 0x80 the result equals the classification of
  `CMaskGroup::PrepareMasks` at cb0d80f5 (differential saltests check).
- The values equal `MASK_OPTIMIZE_NONE` / `_ALL` / `_EXTENSION` of `src/masks.h`
  (`static_assert` in `masks.cpp`).
- Pure: no globals, no allocation. The `*` / `*.*` test stays `lstrcmpA` as in the old code (the
  only code-page-dependent part, kept so ASCII masks decide exactly as before).
