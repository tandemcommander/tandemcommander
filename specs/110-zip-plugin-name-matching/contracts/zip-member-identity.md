# Contract: ZIP member identity (`src/common/salzipname.h`, header-only)

Used by the ZIP plug-in wherever it decides that a member of the archive IS a named file or
folder. Names reach these functions in the plug-in's form: UTF-8 (interface 104; `ProcessName`
converts legacy OEM / code-page names), `\` separated, no trailing separator.

## Z1 - `SalZipNameEqual(a, aLen, b, bLen, ignoreCase)` -> BOOL

Lengths in bytes, `-1` = up to the terminator, NULL = "".

1. Byte-identical -> TRUE.
2. Both printable/any ASCII -> equal byte counts and equal after folding `a`-`z` (when
   `ignoreCase`), else byte equality.
3. Both valid WTF-8 (feature 066: strict UTF-8 whose 3-byte sequences may decode to a lone
   surrogate - the core's decoder exactly) -> `CompareStringOrdinal` on the UTF-16 forms,
   `bIgnoreCase = ignoreCase`. No normalization (NFC != NFD), no locale; equal to feature 092's
   `SalNameEqualOrdinalCI` for every such pair when `ignoreCase` (asserted in saltests by brute
   force over a hostile alphabet).
4. Neither valid WTF-8 (legacy text: a member whose UTF-8 flag lies, a failed conversion) -> the
   plug-in's old comparison: equal byte counts AND `CompareStringA(LOCALE_USER_DEFAULT,
   ignoreCase ? NORM_IGNORECASE : 0, ...) == CSTR_EQUAL`.
5. One valid, one not -> FALSE.
6. Low memory (a name over 259 bytes needs a heap buffer and none is left) -> only rule 1. The
   matching then adds instead of replacing; it never deletes a member it did not mean.

For names of one printable ASCII character rule 2 and the old comparison agree (measured over every
pair, `probe/zip_collision_set.py`, and asserted in saltests). Longer ASCII names can differ in one
direction only: the old linguistic comparison treats a digraph as one letter on Czech, Slovak,
Hungarian, Croatian ... locales ("ch"), so `cHata.txt` / `chata.txt` were two names and are one now
(what Windows sees). saltests asserts the ASCII fold over every pair of two-letter names and counts
the pairs that changed.

## Z2 - `SalZipNamePrefix(path, pathLen, prefix, prefixLen, ignoreCase, pathBytes)` -> BOOL

TRUE when `path` begins with a name equal (Z1) to the first `prefixLen` bytes of `prefix`.
`*pathBytes` = the bytes of `path` the prefix covers - measured on `path`, because 7 case pairs
differ in UTF-8 length (U+023A/U+2C65, U+023E/U+2C66, U+0250/U+2C6F, U+0251/U+2C6D,
U+026B/U+2C62, U+0271/U+2C6E, U+027D/U+2C64). The caller looks at `path[*pathBytes]`.

- Empty prefix -> TRUE, 0.
- Valid prefix: the bytes of `path` holding exactly as many UTF-16 units as the prefix, which
  must be valid WTF-8 and must not end inside a supplementary character or between the halves of
  a surrogate pair written as two sequences; then `CompareStringOrdinal`. Equal to 092's
  `SalPathHasPrefixOrdinalCI` for a valid path (saltests).
- Legacy prefix: only a path that is not valid WTF-8 (as a whole, and in its first `prefixLen`
  bytes), by the old `CompareStringA` over `prefixLen` bytes; `*pathBytes = prefixLen`.

## Z3 - `SalZipMemberIs(inZip, inZipLen, target, targetLen, rootLen, rootIgnoreCase, rootBytes)`

The update matching (`add.cpp CZipPack::MatchFiles`). `target` = panel folder (`ZipRoot`,
`rootLen` bytes) + `\` + the added file's relative path. The folder part by Z2 with
`rootIgnoreCase` (TRUE in a DOS/Windows archive, FALSE in a Unix one - as before), the rest by Z1
ignoring case (as before, also in a Unix archive). `*rootBytes` = the bytes of `inZip` holding
the folder (the Unix branch copies the member's spelling from `inZip + rootBytes + 1`).

## Z4 - `SalZipMemberIsOrIsIn(...)` - the member is the folder `target` or lies inside it

The Move branch for a folder that is not added (empty folders off): Z2 for the panel folder,
Z2 for the rest, then `inZip` ends or continues with `\`.

## Where the rule does NOT apply (unchanged, by decision)

- `CZipCommon::MatchFiles` / `BSearchName` / `CompareExtInfos` (extract and delete selection):
  a file is identified by its central-directory index plus the exact listed name; a folder by
  the core's byte fold (`StrICmp` / `MemICmp`), which is the rule the core's listing
  (`CSalamanderDirectory`) used to build the folders the user selected - the two must stay one
  rule until the listing changes (NEXT-WORK item 5, `CSalamanderDirectory`).
- `CZipUnpack::FindFile` (F3 / F4 of one member): the member is found by its index; the name
  check after it only confirms (its linguistic case-insensitive folder test accepts every pair
  the listing merges - measured: 0 pairs merged by the byte fold that it keeps apart).
- `CountFilesInRoot` (`del.cpp`) now uses exactly the selection's folder test (see fix-log).
- Archive file names on disk (`common.cpp`, `common2.cpp`: volume names) - disk paths, not members.
