# Contract: name identity helpers (`src/common/salunicode.{h,cpp}`)

## I1 — `SalNameCompareOrdinalCI(a, aLen, b, bLen)` → `<0`, `0`, `>0`

`aLen` / `bLen` are byte counts or `-1` for null-terminated. NULL counts as
an empty string.

The order is lexicographic over the leading ASCII characters and then "the
tail" (everything from the first non-ASCII byte on):

1. **Leading ASCII characters**: compared after folding `a`–`z` to upper
   case; an ASCII character is smaller than a tail; on a common prefix the
   shorter string is smaller.
2. **Two valid WTF-8 tails** (feature 066): converted to UTF-16 and compared
   with `CompareStringOrdinal(…, bIgnoreCase = TRUE)` — the operating
   system's upper-case table per code unit, then binary. No normalization,
   no locale, no ignorable characters; lone surrogates compare as themselves.
3. **Two tails that are not valid WTF-8** (legacy text): bytes folded to
   lower case by the system code page (`CharLowerA`), shorter is smaller —
   the legacy rule, so the *equality* of two legacy strings is exactly
   `StrICmpEx(...) == 0`.
4. **One valid, one not**: the valid one is smaller; they are never equal.

Properties: for two valid WTF-8 strings the result is that of
`CompareStringOrdinal(…, TRUE)` on the whole strings (an ASCII unit is below
every other unit and equal to none — asserted by a unit test against the
operating system's table). It is a **total order over all byte strings**
(antisymmetric, transitive), so a sorted list may mix ASCII, non-ASCII and
legacy names. The order of ASCII strings differs from the legacy
`StrICmpEx` only where one of ``[ \ ] ^ _ ` `` meets a letter (upper-case
instead of lower-case fold). `== 0` ⇔ `SalNameEqualOrdinalCI`.

*Revised after the analysis of stage S5*: the first version sent every pair
with a non-WTF-8 member to the legacy comparison, which made the relation
intransitive over a list holding valid and invalid names together (names
pasted from the clipboard can be legacy text).

## I2 — `SalNameEqualOrdinalCI(a, aLen, b, bLen)` → BOOL

`SalNameCompareOrdinalCI(...) == 0`, with a byte-equal fast path.

## I3 — `SalPathEqualOrdinalCI(p1, p2)` → BOOL

The rules of the core's `IsTheSamePath`: one leading and one trailing
backslash on either side are ignored; otherwise I2 on the rest.

## I4 — `SalPathHasPrefixOrdinalCI(path, prefix, prefixLen, pathBytes)` → BOOL

TRUE when `path` starts with a string equal (I2) to the first `prefixLen`
bytes of `prefix` (`-1` = all of it). On TRUE `*pathBytes` (may be NULL) is the
number of bytes of `path` that the prefix covers — the caller then looks at
`path[*pathBytes]` (a backslash or the end) as it did with `StrNICmp`. The
prefix must end on a character boundary of `path`; a prefix that would end
inside a multi-byte character (or inside a surrogate pair) is not a prefix.
Two units that are equal ignoring case need not have the same UTF-8 length,
so the function returns the count measured on `path`, never `prefixLen`.

When `path` is not valid WTF-8 (legacy text): the legacy answer, `*pathBytes =
prefixLen`. When `path` is valid and the prefix is not (a prefix cut inside a
character): not a prefix.

## I5 — where the rule applies

Core-internal decisions about identity only (spec FR-004…FR-007). The
exported plug-in services and `src/common/str.cpp` keep the byte fold.

## I6 — guard

`tools/check_encoding.py`: `acp-byte-table-on-name` strict (drive-letter
look-ups excluded, the intentional sites annotated). A second rule,
`byte-fold-on-name` (the old comparison functions applied to a name in a
converted file), was planned and is **not implemented**: the converted files
keep legitimate uses on text that is not a name and deferred sites, so it
would need an annotation per line. Deferred with the remaining clusters.
