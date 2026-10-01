# Contract: name identity helpers (`src/common/salunicode.{h,cpp}`)

## I1 — `SalNameCompareOrdinalCI(a, aLen, b, bLen)` → `<0`, `0`, `>0`

`aLen` / `bLen` are byte counts or `-1` for null-terminated. NULL counts as
an empty string.

1. **Both ASCII** (no byte ≥ 0x80): bytes compared after folding `a`–`z` to
   upper case; on a common prefix the shorter string is smaller.
2. **Both valid WTF-8** (feature 066): converted to UTF-16 and compared with
   `CompareStringOrdinal(…, bIgnoreCase = TRUE)` — the operating system's
   upper-case table per code unit, then binary. No normalization, no locale,
   no ignorable characters; lone surrogates compare as themselves.
3. **Otherwise** (either string is not valid WTF-8): the legacy rule — bytes
   folded to lower case by the system code page (`CharLowerBuffA`), exactly
   what `StrICmpEx` returns; shorter is smaller on a common prefix.

Properties: total order on valid WTF-8 strings (antisymmetric, transitive);
steps 1 and 2 are the same order (ASCII is a subset, same fold direction), so
mixing them is consistent. `== 0` ⇔ `SalNameEqualOrdinalCI`.

## I2 — `SalNameEqualOrdinalCI(a, aLen, b, bLen)` → BOOL

`SalNameCompareOrdinalCI(...) == 0`, with a byte-equal fast path.

## I3 — `SalPathEqualOrdinalCI(p1, p2)` → BOOL

The rules of the core's `IsTheSamePath`: one trailing backslash on either
side is ignored; otherwise I2 on the rest.

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
look-ups excluded, the intentional sites annotated); `byte-fold-on-name`
(strict, per converted file): `StrICmp`, `StrNICmp`, `StrICmpEx`, `StrICpy`,
`IsTheSamePath` applied to an identifier that names a file name or path.
