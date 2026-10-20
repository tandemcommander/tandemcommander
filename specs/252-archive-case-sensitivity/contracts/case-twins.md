# Contract: case twins of a listing (`src/common/salcasetwins.h`, feature 252)

Header-only; for the core, `saltests` and plug-ins (needs `salnameorder.h` beside it).

```cpp
struct SalCaseTwinName { const char* Name; int Len; };

// TRUE when two of the 'count' names are byte-different but the same name by
// SalNameOrderCompareCI (the file system's rule, = SalNameCompareOrdinalCI) or by the legacy
// byte fold (= StrICmpEx). Low memory: TRUE.
BOOL SalNamesHaveCaseTwins(const SalCaseTwinName* names, int count);

// TRUE when any folder of the tree (the root and every sub-folder) holds case twins among its
// folders and files together. TDir provides GetFilesCount(), GetDirsCount(), GetFile(i),
// GetDir(i) (-> Name, NameLen) and GetSalDir(i) (-> const TDir*, NULL allowed). No recursion.
// Low memory: TRUE.
template <class TDir> BOOL SalDirTreeHasCaseTwins(const TDir* root);
```

## Use by an archive plug-in

```cpp
dir->SetFlags(SALDIRFLAG_CASESENSITIVE);   // before the first AddFile / AddDir
... list ...
if (!SalDirTreeHasCaseTwins(dir))
    dir->SetFlags(0);                        // the archives' default: exactly today's listing
```

## Guarantees

1. No twins -> the listing equals the one built without the flag (every merge the case-insensitive
   build makes joins byte-identical names).
2. Twins -> the listing stays case-sensitive: the core never merges, selects, hides or pastes one
   twin for the other.
3. "Low memory" never clears the flag (the exact listing is kept).
