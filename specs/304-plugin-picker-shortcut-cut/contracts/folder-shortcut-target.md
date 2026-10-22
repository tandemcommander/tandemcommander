# Contract: the plug-ins' folder-shortcut target (splfiledlg.h, feature 304)

Header-only helpers compiled into each plug-in; not part of the plug-in interface
(`spl_*.h`, `LAST_VERSION_OF_SALAMANDER` unchanged).

```cpp
namespace SplFileDlgDetail {
// the pure rule (data-model.md): malloc'ed target, or NULL = refuse
WCHAR* WholeFolderShortcutTargetW(const WCHAR* answer, const WCHAR* listName);

// 'path' = the picked folder. Returns a malloc'ed target, or NULL. With NULL, '*refused'
// (when given) tells: TRUE = a folder shortcut whose target could not be read whole - refuse
// the pick; FALSE = not a folder shortcut (or unreadable as before) - the folder itself.
WCHAR* ResolveNetHoodFolderW(const WCHAR* path, BOOL* refused = NULL);
}

// unchanged signature; a refused target shows SplShowNameTooLongW and returns FALSE
BOOL SplBrowseForFolderU8(...);
```

Callers outside the header: saltests only (one-argument calls stay valid).
