# Contract: diacritic folding of quick-search keys (`src/common/salquickfilter.h`, feature 313)

Extends `specs/244-quick-search-substring-filter/contracts/salquickfilter-rules.md` section 1b.
Core-only header; no plug-in relies on it.

| # | Rule | Checked by (saltests `TestQuickFilter244`, 313 block) |
|---|------|------------|
| F1 | With `substring = TRUE` and a non-ASCII name or mask, the marks U+0300-036F, U+1AB0-1AFF, U+1DC0-1DFF, U+20D0-20FF, U+FE20-FE2F of the canonical decomposition are ignored, in the name and the mask | `žluťoučký`/`zlut`, `zlutý`/`žlut`, `Český`/`cesky`, `Übersicht`/`ubersicht`, NFD names, NFC/NFD masks |
| F2 | `ł Ł`->l, `ø Ø`->o, `đ Đ`->d, `ß ẞ`->ss, `æ Æ`->ae, `œ Œ`->oe, `ı`->i, both directions; nothing else | one case per letter and direction; `ð`, `þ`, `ħ` stay unmatched by `d`, `th`, `h` |
| F3 | Marks of other blocks stay: `が` != `か`, Hebrew point, Devanagari virama | three cases |
| F4 | A match starts and ends on character boundaries; marks after the last matched letter are inside the match; a typed `s` does not end inside `ß` | offsets of NFD matches; `ß`/`s` |
| F5 | A lone mark has an empty key: it adds no unit; a mask of marks only matches every name as `PREFIX`; an empty segment between wildcards is ignored | name `◌́abc`/`a`; mask U+0301; `a/◌́/c` |
| F6 | WTF-8 lone surrogates and invalid bytes: no crash, compared as before | lone surrogate name/mask cases |
| F7 | `substring = FALSE` (option off) unchanged | M1 (0 differences) |
| F8 | The per-character cache returns the same key as the uncached computation for every BMP code point | loop over U+0000-FFFF, twice |
