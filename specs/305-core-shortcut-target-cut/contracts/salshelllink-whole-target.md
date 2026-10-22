# Contract: the core's shortcut target is whole or refused (salshelllink.h, feature 305)

Header-only helpers of the core (`src/common/salshelllink.h`); not part of the plug-in
interface.

```cpp
// plain form: "\\?\UNC\x" -> "\\x", "\\?\x" -> "x", else a copy. malloc'ed; NULL on low memory
WCHAR* SalPlainPathAllocW(const WCHAR* p);

// the pure rule (data-model.md): malloc'ed target, or NULL = refuse
WCHAR* SalShellLinkWholeTargetW(const WCHAR* answer, const WCHAR* listName);

// unchanged signature; new: an answer of 259+ units is whole (proven by the item list) or
// refused with HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE); SLGP_RAWPATH 259+ always refused
HRESULT SalShellLinkGetPathU8(IShellLinkW* link, char* path, int pathSize, DWORD flags);

// new (review 1, SHOULD 1): the part after target.lnk is loaded - NOERROR / too long (does not
// fit or refused by the reader) / S_FALSE (no path, unreadable) / E_INVALIDARG / E_OUTOFMEMORY
HRESULT SalFolderShortcutLinkTargetU8(IShellLinkW* link, char* target, int targetSize);

// unchanged signature; a refused target.lnk target is ERROR_FILENAME_EXCED_RANGE (was S_FALSE
// for a reader failure, NOERROR with a cut path for the measured case)
HRESULT SalFolderShortcutTargetU8(const char* folderU8, char* target, int targetSize);
```

Callers (unchanged): `fileswn0.cpp` `FocusShortcutTarget`, `fileswn2.cpp` `Execute`,
`shellsup.cpp` `GetCurrentDir`, `shellib.cpp` `ResolveNetHoodPath`; saltests.
