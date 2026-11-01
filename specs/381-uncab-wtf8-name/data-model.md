# Data model - 381

**Cabinet entry name** (from FDI's notification): `psz1` = the stored bytes (NUL-terminated),
`attribs` = the entry's attributes (`-1` where FDI reports none: `fdintPARTIAL_FILE`).

| flag `_A_NAME_IS_UTF` | bytes valid WTF-8 | read as |
|---|---|---|
| set | yes | UTF-8, byte for byte (was: refused when only WTF-8) |
| set | no | refused (unchanged) |
| clear | any | code page -> UTF-8 (unchanged) |
| not reported (-1) | yes | UTF-8, byte for byte (was: code page when only WTF-8) |
| not reported (-1) | no | code page -> UTF-8 (unchanged) |

Next-cabinet / next-disk names are always passed with `attribs` = 0 (code page, unchanged).
