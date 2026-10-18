# Contract: pure rules `src/common/salcfgimport.h`

Header-only, no globals, no registry access, no STL (usable by the core, by
plug-ins and by `saltests`). Strings UTF-8. Every function below has
`saltests` checks in `TestCfgImport245` (positive, negative control, edge).

## Snapshot tree

```cpp
struct CSalCfgValue { char* Name; DWORD Type; BYTE* Data; DWORD Size; };
struct CSalCfgKey   { char* Name; CSalCfgValue* Values; int ValueCount;
                      CSalCfgKey* Keys; int KeyCount; };
```
- `SalCfgKeyFind(key, "A\\B")` — subkey by path, ASCII case-insensitive (the
  registry's rule for these ASCII names); NULL when absent.
- `SalCfgValueFind(key, name)`; `SalCfgGetDword(key, name, &v)` (FALSE when
  absent or not `REG_DWORD`/4 bytes); `SalCfgGetString(key, name)` (NULL when
  absent or not `REG_SZ`/`REG_EXPAND_SZ`; strings are stored NUL-terminated).
- Builders for tests and the reader: `SalCfgKeyAddKey`, `SalCfgKeyAddValue`,
  `SalCfgKeyFree` (recursive). Limits are enforced by the reader (research R1).

## Sources

- `SalCfgImpRootCount()`, `SalCfgImpRoot(i)` → `{ const char* KeyPath; }` —
  the table of R2 (Open Salamander 5.0 first, then Altap 4.0 …, Servant
  Salamander last); never contains `Tandem Commander` or `Newt Commander`.
- `SalCfgImpProductName(keyPath, buf, size)` — last path component.
- `SalCfgImpClassify(DWORD cfgVer)` → `SALCFGIMP_TOO_OLD` (< 39),
  `SALCFGIMP_SUPPORTED` (39–106), `SALCFGIMP_TOO_NEW` (> 106).
- `SalCfgImpCompareSources(a, b)` — newest configuration version first,
  ties by table order.

## Conversions

- `SalCfgImpDuplicateDollars(in, out, outSize)` — `$` → `$$` (< 47); FALSE
  when it does not fit (the item is then skipped, never cut).
- `SalCfgImpLowerAscii(in, out, outSize)` — masks < 44.

## Identities

- `SalCfgImpMasksKey(masks, out, outSize)` — R5 normalisation (split `;`,
  trim spaces, ASCII lower-case, drop empty, sort, join with `;`).
- `SalCfgImpHotPathKey`-style path compare is done by the core with
  `SalPathEqualOrdinalCI` (not duplicated here); the header offers
  `SalCfgImpTrimTrailingSlash(path, out, size)` (keeps `C:\` and `\\server\share\`).
- `SalCfgImpUniqueName(base, suffixFmtIndex, existsFn, ctx, out, size)` —
  "base", "base (imported)", "base (imported 2)" … first not existing
  (the suffix text is passed in, translated by the caller).

## Placement and merging

- `SalCfgImpPlaceHotPath(const BOOL occupied[30], int srcSlot)` → slot or −1:
  `srcSlot` when free, else the lowest free slot.
- `SalCfgImpMergeHistory(cur[], curCount, imp[], impCount, out[], cap)` →
  count: current first, then imported not present (exact compare), at most
  `cap`; input arrays are not modified.
- `SalCfgImpDefaultDirValid(name, value)` — 057 F2.

## Options allow-list guard

- `SalCfgImpIsForbiddenOption(subkey, name)` — TRUE for every TC-owned value
  of R15 (theme, tabs, quick search filter, command shell ×3, language ×4,
  plugins.ver ×2, icon overlays ×2, window/dialog geometry, main window icon,
  conversion table, only one instance, last focused page, configuration
  height, expanded ×2, skill level, toolbar layouts ×4, save on exit). The
  core's table is checked against it by a `saltests` check (the table's names
  are mirrored into the test).

## Plugin DLL matching

- `SalCfgImpSameDll(srcDll, tcDll)` — equal relative paths
  (case-insensitive, `/`≡`\`), or, for an absolute `srcDll`, equal last two
  components.
