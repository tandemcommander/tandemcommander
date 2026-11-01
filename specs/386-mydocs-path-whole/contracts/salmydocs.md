# Contract - salmydocs.h and the probe seam (feature 386)

Internal to the core; not part of the plug-in interface.

## SalDocumentsOrDesktopToU8

```cpp
enum { SAL_DOCS_NONE = 0, SAL_DOCS_OK = 1, SAL_DOCS_TOO_LONG = 2 };
int SalDocumentsOrDesktopToU8(const WCHAR* docsW, const WCHAR* desktopW, char* path, int pathSize);
```

- `docsW` / `desktopW`: the folder as the shell reports it; `NULL` or `""` = no file-system path.
- Documents is used when it has a path; the Desktop only when Documents has none.
- The chosen path is converted to UTF-8 (WTF-8, `SalWToU8`) into `path` only when it fits
  `pathSize` bytes with the terminator: `SAL_DOCS_OK`. Otherwise `SAL_DOCS_TOO_LONG` - the
  Desktop is **not** tried for a Documents path that is too long.
- `path` is emptied whenever the result is not `SAL_DOCS_OK` (and `pathSize > 0`); never a prefix.
- Header-only; needs `SalWToU8` (`salunicode.h`).

## GetMyDocumentsOrDesktopPath (shellib.cpp)

`BOOL GetMyDocumentsOrDesktopPath(char* path, int pathLen)` - unchanged signature; TRUE only for
`SAL_DOCS_OK`. A refusal for `SAL_DOCS_TOO_LONG` writes `TRACE_E`.

## Probe seam TC_PROBE_MYDOCS_FILE (Debug builds only)

When the environment variable `TC_PROBE_MYDOCS_FILE` names a file (a path below `MAX_PATH`
units), the file's UTF-8 text (a BOM and trailing line ends dropped, at most 64 KB) replaces the
Documents folder the shell reports, as if `SHGetPathFromIDListW` had given it (the probe keeps it
below 260 units). A file and not the value itself: the program copies its environment through the
code page at start (`CEnvVariables`, `salamdr7.cpp`, measured: 90 CJK letters arrived as 90 `?`).
Release builds do not read it.
