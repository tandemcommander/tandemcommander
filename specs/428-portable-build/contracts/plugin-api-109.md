# Contract: plug-in interface 109 — edition and data folders (FR-009, R-07)

`LAST_VERSION_OF_SALAMANDER` 108 → **109**. Append-only: three methods appended at the **end** of
`CSalamanderGeneralAbstract` (`src/plugins/shared/spl_gen.h`), history entry in
`src/common/spl_vers.h`. Older plug-ins keep loading (they never call them); a plug-in built
against 109 that may run on an older core checks `SalamanderGeneral->GetVersion()` /
the version passed at entry (≥ 109) before calling.

```cpp
// 109 (feature 428): TRUE in the portable edition of Tandem Commander.
virtual BOOL WINAPI IsPortableEdition() = 0;

// 109 (feature 428): a folder for per-user data of the given kind, as a full UTF-16 path without a
// trailing backslash, created if missing. FALSE (and buf[0] = 0) when bufSize is too small or the
// folder cannot be created. Never a path that is cut.
//   SALUSERDATA_WEBVIEW2 (1): WebView2 user data folder
//       normal:   %LOCALAPPDATA%\Tandem Commander\WebView2
//       portable: %TEMP%\TandemCommander-portable-<scope>\WebView2   (removed at exit)
//   SALUSERDATA_LOCAL (2): the program's local data folder
//       normal:   %LOCALAPPDATA%\Tandem Commander
//       portable: <program folder>\settings
virtual BOOL WINAPI GetUserDataFolderW(int kind, WCHAR* buf, int bufSize) = 0;

// 109 (feature 428): a suffix for names of kernel objects a plug-in shares between processes of
// ONE copy of the program (e.g. "_P0123456789abcdef"); "" in the normal edition. Always ASCII,
// at most 20 characters + terminator. FALSE when bufSize is too small.
virtual BOOL WINAPI GetInstanceScopeSuffix(char* buf, int bufSize) = 0;
```

Threading: all three may be called from any thread (unlike `GetConfigParameter`).

## Users in the tree

| Plug-in / code | Use |
|----------------|-----|
| `src/common/webhost` `TcWebUserDataFolder()` (the one definition, architecture/11) | `GetUserDataFolderW(SALUSERDATA_WEBVIEW2)` when the core is ≥ 109, else today's `%LOCALAPPDATA%` path; the core's own use (`webkeeper.cpp`) calls the core function directly |
| mdview | skips the clean-up of the old `mdview.WebView2` folder when `IsPortableEdition()` |
| pictview | in the portable edition keeps its `PrevWallpaper*` record in its plug-in configuration instead of `HKCU\Control Panel\Desktop`; the wallpaper bitmap path is unchanged (research R-09) |
| filecomp / fcremote | appends `GetInstanceScopeSuffix()` to its `RemoteComparator …` object names; fcremote.exe receives the suffix on its command line from the plug-in |

## Documentation

`architecture/06-plugin-api.md` gets the three methods; `architecture/11-webview2-integration.md`
gets the rule "in the portable edition the one user data folder is the session folder's
`WebView2`" (binding contract, same change).
