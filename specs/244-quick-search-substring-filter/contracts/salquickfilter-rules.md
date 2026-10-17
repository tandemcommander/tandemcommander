# Contract: `src/common/salquickfilter.h` (pure rules, `saltests`)

Header-only, no globals, depends on `salunicode.h` (`SalNameEqualCI`,
`SalU8Next`, `SalU8CharCount`, `SalIsASCII`). The core includes it from
`fileswn0.cpp` (matching, focus) and from the panel painting code (tint).

## 1. Matching

```cpp
enum { SALQF_NONE = 0, SALQF_SUBSTRING = 1, SALQF_PREFIX = 2 };
struct CSalQFMatch { int Kind; int MatchStart; int MatchEnd; };

// mask = the output of PrepareQSMask (literal segments separated by '/',
// no leading/trailing '/' collapsing beyond what PrepareQSMask does)
// substring = FALSE: prefix only (0.1.10 behaviour, the option off)
BOOL SalQFMatchName(const char* nameU8, BOOL hasExtension, const char* mask,
                    BOOL substring, CSalQFMatch& result);
```

| # | Rule | Checked by |
|---|------|------------|
| M1 | `substring = FALSE` gives exactly 0.1.10's `AgreeQSMaskU8(name, hasExt, mask, FALSE, offset)`: same TRUE/FALSE, `MatchEnd == offset`, `MatchStart == 0` | table of ≥ 60 (name, mask) pairs incl. ASCII, Czech, NFD, emoji, wildcards, trailing dot |
| M2 | A prefix match wins: if M1 matches, `Kind = PREFIX` even when `substring = TRUE` | table |
| M3 | Otherwise with `substring = TRUE`: the leftmost start at a UTF-8 character boundary from which the prefix rule matches the rest; `Kind = SUBSTRING`, `MatchStart` = that boundary | `2024_chatbot`/`chat` → 5..9; `aXbXc`/`b/c` → 2..5 |
| M4 | Case and canonical equivalence as `SalNameEqualCI`; ASCII mask + ASCII name byte-wise with ASCII case folding only | `Report.PDF`/`pdf`; `Účet`(NFD)/`úč` |
| M5 | The extension is part of the name; the trailing-dot tolerance applies only to a prefix match of a name without an extension | `readme`/`readme.` PREFIX; `x_readme`/`readme.` NONE |
| M6 | Never reads past the terminating zero; a mask of up to `3*MAX_PATH-1` bytes is accepted; an invalid UTF-8 byte is one character | fuzz-ish table: lone continuation bytes, truncated sequences |
| M7 | Monotone: if `mask + c` matches `name`, then `mask` matches `name` (the incremental narrowing of R5 relies on it) | property over the M1 table × appended characters |

## 2. Focus

```cpp
// kinds[i] in {SALQF_SUBSTRING, SALQF_PREFIX} for the visible items;
// returns the index to focus (0 <= result < count), count >= 1
int SalQFChooseFocus(const BYTE* kinds, int count, int current);
```

| # | Rule |
|---|------|
| F1 | `current` (clamped to `0..count-1`) is PREFIX → `current` |
| F2 | else the first PREFIX at `current+1 .. count-1`, then the last PREFIX at `current-1 .. 0` (nearest above) |
| F3 | no PREFIX → `current` |
| F4 | `count == 1` → 0 |

(After filtering, every visible item is a match, so F3 keeps the focus; the
focus of the full list is mapped to the nearest visible index first.)

## 3. Tint

```cpp
COLORREF SalQFTint(COLORREF normalBk, COLORREF accentBk, COLORREF normalFg);
double   SalQFContrast(COLORREF a, COLORREF b); // WCAG 2 contrast ratio
```

| # | Rule |
|---|------|
| T1 | result = mix(normalBk, accentBk, 12 %); if its distance to `normalBk` is below the visibility threshold, 25 %; if still below, luminance of `normalBk` moved 6 % away from `normalFg` |
| T2 | `SalQFContrast(normalFg, result) >= min(4.5, SalQFContrast(normalFg, normalBk)) - 0.25` for the four built-in schemes and Dark |
| T3 | result differs visibly from `normalBk`, and from the scheme's `ITEM_BK_SELECTED`, `ITEM_BK_FOCUSED`, `ITEM_BK_HIGHLIGHT` (threshold pinned in the test) |
| T4 | deterministic, no state |

Visibility threshold and the fixture colours are constants in `saltests.cpp`
copied from `salamdr1.cpp` (four schemes) and `themes_palette.h` (Dark),
with a comment naming the source lines; a scheme change that breaks T2/T3
fails the test.
