# Fix log: 237 - a popup menu item is chosen by its accented hot key

Backlog (236's review): `CMenuPopup::FindNextItemIndex` (`menu2.cpp`) compared the typed ANSI byte
(`OnChar((char)wParam)`, the popup's `PeekMessageA` loop) with the byte after '&' through
`UpperCase`: a UTF-8 item's (plug-in menus, contract 052) non-ASCII mnemonic never matched, and a
byte could match another letter (cp1250: "&\u010C" is 26 C4 8C - C4 is "\u00C4"). The menu bar was
fixed in 093 (`SalMnemonicMatchW`); popups were not.

## Work (by reading; saltests)

- `src/common/salmenuhotkey.h` `SalMenuKeyMatch` (saltests in `TestMenuHotKey236`): 2 - the item's
  mnemonic (`SalMnemonicMatchW`: UTF-8 or legacy code-page text, case ignored); 1 - no mnemonic and
  the first character; 0 - neither ("&&" is a literal '&').
- `src/menu2.cpp`: `OnChar` converts the key (`SalACPCharToW`), `FindNextItemIndex(int, WCHAR)` uses
  the rule; the cycling and priority logic is unchanged.

Not driven: popup menus are not driven by the probes (234 tried). Build: BUILD SUCCEEDED; saltests
22,720 checks, 0 failed.

Known limits (review): a key `SalACPCharToW` cannot take alone - a DBCS lead byte, or (not measured)
a UTF-8 byte of an ANSI loop on a system with code page 65001 - matches nothing now (before, its byte
could match an identical byte); the real fix is a wide popup loop. The '&' key no longer matches an
item holding "&&". A code-page mnemonic whose two bytes form valid UTF-8 (cp1250 "\u0102\u0161" =
C3 9A) is read as another letter (093's decision per mnemonic, not per text).

## Review

Refute-first review: no MUST; ASCII menus behave as before. Taken: more tests (a code-page item on
cp1250, a trailing '&', an emoji, "&&"), the header's note. Recorded in NEXT-WORK: `OnChar`'s
`WM_MENUCHAR` passes no character (`wParam = MF_POPUP` - the TortoiseSVN fallback can never match;
upstream); a wide popup loop; `GetControlHotKey` (`finddlg1.cpp:2956`) compares a dialog control's
text with a key byte-wise.
