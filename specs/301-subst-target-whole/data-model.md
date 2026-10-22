# Data model - 301-subst-target-whole

No stored data. The values involved:

| Value | Form | Limits |
|---|---|---|
| Device text | the first string of `QueryDosDeviceW`'s answer, UTF-16 | up to ~32,767 units (`DefineDosDeviceW`); < MAX_PATH from `subst.exe` |
| Subst path | `X:...` (from `\??\X:...`) or `\\server\share...` (from `\??\UNC\server\share...`), UTF-8 / WTF-8 | the caller's buffer, terminator included; does not fit -> refused |
| Result of the parse | `SAL_SUBST_NONE` (not a subst: a volume device, a network redirector, ...), `SAL_SUBST_OK`, `SAL_SUBST_TOO_LONG` | - |

Rules (`src/common/salsubst.h`):

1. `\??\` followed by an ASCII letter and `:` -> the text from the letter on.
2. `\??\UNC\` -> `\` + the text after `\??\UNC` (that is `\\server\share...`).
3. Anything else -> NONE, the buffer emptied when `pathMax > 0` (callers test the return value
   only).
4. The UTF-8 size (terminator included) is measured first; size > `pathMax` -> TOO_LONG, the
   buffer emptied.
