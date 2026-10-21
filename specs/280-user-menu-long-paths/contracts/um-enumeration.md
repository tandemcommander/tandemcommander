# Contract - the User Menu's item enumeration (core-internal)

Not part of the plug-in interface: declared in `src/mainwnd.h`, implemented by
`GetNextFileFromPanel` (`src/mainwnd4.cpp`) and `GetNextItemFromFind` (`src/finddlg1.cpp`),
called only by `CMainWindow::UserMenu`.

```c++
#define UM_ITEM_TEXT_SIZE SAL_MAX_PATH_UTF8
#define UMNEXT_END 0     // no more items
#define UMNEXT_ITEM 1    // 'path' and 'name' hold the next item, whole
#define UMNEXT_TOOLONG 2 // the item's folder or name does not fit the buffers - nothing was cut
typedef int (*UM_GetNextFileName)(int index, char* path, char* name, void* param);
```

- `path` and `name` are buffers of `UM_ITEM_TEXT_SIZE` bytes (UTF-8 / WTF-8).
- The callback never cuts a value: it copies it whole or answers `UMNEXT_TOOLONG`.
- `UMNEXT_END` keeps its old meaning (the old `FALSE`), including the end-of-enumeration side
  effects (selection redraw, index freed) and feature 225's early refusal (a panel folder over
  259 bytes with no selection: the box, then `UMNEXT_END`).
- `UserMenu` refuses with "too long name" - before preparing that item's command, nothing run -
  on `UMNEXT_TOOLONG` or on a folder or name of `MAX_PATH` bytes or more; `ExpandCommand2` still
  refuses a folder + name over 259 bytes.
