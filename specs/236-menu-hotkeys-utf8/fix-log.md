# Fix log: 236 - a menu hot key never splits a UTF-8 letter

Backlog (127, item 4): `CMenuPopup::AssignHotKeys` (`menu2.cpp`) gives popup items without a hot key
an '&' - byte by byte with the ANSI code page's tables. Popup texts are UTF-8 (drawn through
`SalU8ToW`): in a text without a free ASCII letter the second round took a byte >= 0x80 the code page
calls a letter - also a UTF-8 continuation byte (0x9A, 0x9E, 0xBE ... in cp1250) - and put '&' inside
a UTF-8 character (broken text). Such a hot key could not work anyway: the popup matches the typed
ANSI byte against the byte after '&'.

## Work (by reading; saltests)

`src/common/salmenuhotkey.h` (new; saltests `TestMenuHotKey236`):
- `SalMenuHotKeyPos`: the first ASCII letter not yet assigned, or none;
- `SalMenuHotKeyOf`: the byte after the item's hot-key '&' - "&&" is a literal '&' (review: "R&&D",
  e.g. a folder in the path history, took 'D' and the item got no hot key of its own).

`src/menu2.cpp` `AssignHotKeys` uses both. A few popup items are code-page text ("Internal viewer"
of View with, the file history's "(View)" column); they lose a code-page hot key only when no ASCII
letter of theirs is free.

Not driven: the popup's text cannot be read by the probes (custom drawing). Build: BUILD SUCCEEDED;
saltests 22,701 checks, 0 failed; `check_encoding.py` TOTAL 0.

## Review

Refute-first review: no MUST. Corrected: my note of a negative `UpperCase[char]` index was wrong - the
core builds with `/J` (unsigned `char`, `sal_base.props`); the cast and the claim are gone. Taken:
the code-page note, the "&&" rule, more tests. Recorded in NEXT-WORK (the next item): **the popup's
key matching (`FindNextItemIndex(int, char)`) compares the typed ANSI byte with the byte after '&'**
- a UTF-8 item (plug-in menus, by contract 052) with a non-ASCII hot key can never be chosen by key,
and a byte can match another letter (cp1250: "&\u010C" is C4 8C, C4 is "\u00C4") - the menu bar was
fixed in 093 (`SalMnemonicMatchW`), popups were not.
