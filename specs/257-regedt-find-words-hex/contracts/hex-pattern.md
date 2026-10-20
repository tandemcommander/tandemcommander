# Contract - the Registry Editor Find's hexadecimal pattern (feature 257)

The pattern typed with **HEX-mode** checked becomes a byte sequence:

| Part | Bytes |
|---|---|
| two hex digits `0-9 a-f A-F` | one byte |
| `"text"` | the text as UTF-16LE, 2 bytes per unit (unchanged) |
| `'text'` | the text in the program's ANSI code page, converted as one text (257: all bytes of each letter; was one byte per UTF-16 unit, 0x00 for a letter of 2+ bytes) |
| a space | nothing (a separator) |

- An unclosed quote runs to the end of the pattern.
- Before the search (strict): a lone digit or any other character outside quotes → "bad
  hexadecimal string"; a quoted text the code page cannot convert at all → the same box; more
  bytes than the search keeps (`MAX_KEYNAME`) → "too long" box. Nothing is cut.
- A letter the code page lacks becomes the code page's replacement, as in the plain-text search.
- Pure rule: `SalHexPatternToBytes` in `src/common/salregfind.h`; not part of the plug-in ABI.
