# Contract: `src/common/salquickfilter.h` (pure rules, `saltests`)

Header-only, depends on `salunicode.h` (`SalNameEqualCI`, `SalU8Next`,
`SalU8CharCount`, `SalIsASCII`) and on Windows `NormalizeString` and
`LCMapStringEx`. Its only state is a per-character key cache (static storage,
GUI thread and tests only). The core includes it from `fileswn0.cpp`
(matching, focus, tint).

*Updated at the end of implementation (2026-10-18): the keys of section 1b
replaced the per-position comparison after review 244 measured seconds per
keystroke on non-ASCII names; the tint rule of section 3 is the one built.*

## 1. Matching

```cpp
enum { SALQF_NONE = 0, SALQF_SUBSTRING = 1, SALQF_PREFIX = 2 };
struct CSalQFMatch { int Kind; int MatchStart; int MatchEnd; }; // byte offsets in the UTF-8 name

// mask = PrepareQSMask output (literal segments, '/' = any run of characters)
// substring = FALSE: the 0.1.10 rule (the option off); TRUE: the new mode
// nameKey/maskKeys: keys kept by the caller (a scan of many names), else built per call
BOOL SalQFMatchName(const char* nameU8, BOOL hasExtension, const char* mask, BOOL substring,
                    CSalQFMatch& result, const CSalQFKey* nameKey = NULL,
                    const CSalQFMaskKeys* maskKeys = NULL);
```

| # | Rule | Checked by |
|---|------|------------|
| M1 | `substring = FALSE` gives exactly 0.1.10's `AgreeQSMaskU8(name, hasExt, mask, FALSE, offset)`: same TRUE/FALSE, `MatchEnd == offset`, `MatchStart == 0` | 901 (name, mask) pairs against a copy of the old matcher: ASCII, Czech, NFD, emoji, CJK, sharp s, invalid bytes, wildcards, trailing dot |
| M2 | With `substring = TRUE` a prefix match is `PREFIX`: the first segment at the start (anywhere after a leading `/`), the dot tolerance included | the same 901 pairs |
| M3 | Otherwise with `substring = TRUE`: the leftmost start at a character boundary where the first segment matches, later segments at their first occurrence after it, ending on a character boundary; `Kind = SUBSTRING` | the same 901 pairs against an independent reference; `2024_chatbot`/`chat` → 5..9; `aXbXc`/`b/c` → 2..5 |
| M4 | Case and canonical equivalence: an ASCII mask against an ASCII name byte-wise with ASCII case folding; anything else on keys (section 1b). The 0.1.10 comparison's linguistic extras (`ss` = `ß`) belong to M1 only — the one documented difference in the table | `Report.PDF`/`pdf`; `Účet` (NFD)/`úč`; `Straße`/`strasse` |
| M5 | The extension is part of the name; the trailing-dot tolerance applies only to a prefix match of a name without an extension | `readme`/`readme.` PREFIX; `x_readme`/`readme.` NONE; `Účet`/`účet.` PREFIX |
| M6 | Never reads past the end; a mask of up to `3*MAX_PATH-1` bytes is accepted; a byte that is not a character is one unit of its own | long mask/name; lone continuation bytes, truncated sequences |
| M7 | Monotone for ASCII names and masks (property, informational: the view rescans the full listing on every keystroke, so nothing depends on it) | property table |

### 1b. Keys

```cpp
struct CSalQFKey { WCHAR* Units; int* Offsets; BYTE* Starts; int Count; void* Block; };
BOOL SalQFBuildKey(const char* textU8, int len, CSalQFKey& key);   // FALSE only without memory
void SalQFFreeKey(CSalQFKey& key);
BOOL SalQFBuildMaskKeys(const char* mask, CSalQFMaskKeys& mk);     // segments, leading '/', trailing '.'
void SalQFFreeMaskKeys(CSalQFMaskKeys& mk);
BOOL SalQFKeyFind(const CSalQFKey& name, const CSalQFMaskKeys& mk, int minStart, CSalQFMatch& r);
BOOL SalQFMatchKeys(const CSalQFKey& name, BOOL hasExtension, const CSalQFMaskKeys& mk, CSalQFMatch& r);
```

- **The key of a text:** per WTF-8 character, its canonical decomposition (NFD) in invariant lower case. Every unit remembers the byte offset of its character, and the first unit of a character is marked.
- **Matching:** a segment matches at unit `s` when the units are equal and both `s` and the end are character starts. A base letter of a decomposed character is not a match; an NFD name's own combining mark is a character of its own, as in 0.1.10.
- **Memory:** a key is one exact-size block, built in a stack scratch area. The panel keeps the keys of the full listing for the whole search and drops them whenever the full listing goes back.

## 2. Focus

```cpp
// kinds[i] in {SALQF_NONE, SALQF_SUBSTRING, SALQF_PREFIX}; current is clamped;
// returns the index to focus, -1 when nothing matches
int SalQFChooseFocus(const BYTE* kinds, int count, int current);
```

| # | Rule |
|---|------|
| F1 | `current` is PREFIX → `current` |
| F2 | else the first PREFIX below, then the nearest PREFIX above |
| F3 | no PREFIX → `current` if SUBSTRING, else the first SUBSTRING below, then the nearest above |
| F4 | `count == 1` → 0; nothing matches → -1 |

## 3. Tint

```cpp
COLORREF SalQFTint(COLORREF normalBk, COLORREF accentBk, COLORREF normalFg,
                   const COLORREF* avoid, int avoidCount);
double   SalQFContrast(COLORREF a, COLORREF b);   // WCAG 2 contrast ratio
double   SalQFDistance(COLORREF a, COLORREF b);   // RGB distance
```

The core passes the scheme's panel caption colour (`ACTIVE_CAPTION_BK`) as
the accent. The cursor colour was rejected: in the Salamander scheme it is
light grey, so a tint toward it is indistinguishable from the cursor bar. The
avoid list holds the selected, focused, focused+selected and full-row
backgrounds.

| # | Rule |
|---|------|
| T1 | the smallest share of the accent (10 %, 15 %, … 40 %) whose result is at RGB distance ≥ 18 from `normalBk` and from every avoided colour different from `normalBk`, and keeps the text contrast (T2); else the same with a blue of the brightness opposite to the background; else the visible candidate (accent, blue, white or black, 10–40 %) with the highest text contrast |
| T2 | `SalQFContrast(normalFg, result) >= min(4.5, SalQFContrast(normalFg, normalBk)) - 0.25` — met for the four built-in schemes (caption as the scheme value and as Windows 11 shows it), Dark and two custom schemes |
| T3 | the result differs visibly from `normalBk` and the avoided colours in those schemes (saltests passes the three it knows; the full-row background is computed at run time) |
| T4 | deterministic |

The fixture colours are constants in `saltests.cpp`, copied from
`salamdr1.cpp` (four schemes) and `themes_palette.h` (Dark).
