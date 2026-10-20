# Data model - 269-ftp-wtf8-listing

## Listing field

- Bytes `beg[0..len)` of one column of a server listing or a PWD path; not NUL-terminated; may hold
  any byte.
- Decoded once by `FTPListingFieldToU8` into a heap UTF-8 (WTF-8) string:

| Bytes | Result | Code-page name set |
|---|---|---|
| empty, ASCII | kept | not added |
| valid WTF-8 (strict UTF-8, or with a surrogate in a 3-byte sequence) | kept byte for byte | not added (changed: WTF-8 with a surrogate was read in the code page and added) |
| other | ANSI code page -> UTF-8 | added (feature 224) |
| undecodable in the code page | raw bytes | not added |

## Code-page name set (feature 224, unchanged)

- Process-wide hash set of UTF-8 texts a listing or PWD gave in the code page; `FTPU8NameToServer`
  sends a name in the code page only when it, a component or a leading part is in the set.
