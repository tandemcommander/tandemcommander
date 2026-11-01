# Contract - SalArcPathResolveCase (core-internal, header-only)

`src/common/salarcpathspell.h`, beside `SalArcPathRespell` (273). Not part of the plug-in API.

```cpp
template <class TDirPtr, class TAccess>
int SalArcPathResolveCase(TDirPtr root, const char* path, char* out, int outSize, const TAccess& acc);
```

- `path`: components separated by `\`, optional leading / trailing `\`.
- Result `SAL_ARCRESPELL_OK`: `out` = the path without a leading / trailing `\`, where every
  leading component that resolves is replaced by its folder's name, and the rest (from the first
  component that does not resolve) is copied as typed. A component resolves when:
  1. a sub-folder is equal by `acc.Equal` (the listing's comparison) - the first one; or
  2. none is, `acc.CaseSensitive(dir)` is true, exactly one sub-folder is equal by
     `acc.AnyCaseEqual`, and that sub-folder is equal by `acc.FoldEqual`.
- Result `SAL_ARCRESPELL_TOOLONG`: `out` too small; `out[0] = 0`; the caller keeps the typed path.
- An empty component (`a\\b`) or a component below an empty folder does not resolve.

Accessor (in addition to 273's `Count`, `Name`, `Sub`, `Equal`):

| Method | Core implementation |
|---|---|
| `bool CaseSensitive(TDirPtr d)` | `d->GetFlags() & SALDIRFLAG_CASESENSITIVE` |
| `bool FoldEqual(name, nameLen, comp, compLen)` | `StrICmpEx(...) == 0` |
| `bool AnyCaseEqual(name, nameLen, comp, compLen)` | `StrICmpEx(...) == 0 \|\| SalNameCompareOrdinalCI(...) == 0` |

Core wrapper: `BOOL CSalamanderDirectory::ResolvePathCase(const char* path, char* out, int outSize)`
- TRUE when `SAL_ARCRESPELL_OK`.
