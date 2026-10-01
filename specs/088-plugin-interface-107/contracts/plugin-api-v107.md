# Contract: plug-in interface 107

Additions only. A plug-in built for interface 104, 105 or 106 loads and runs
unchanged (pure append at the end of `CSalamanderGeneralAbstract`, new
constants, corrected comments). In-tree plug-ins are built against 107 and
therefore require a 107 core, as with every earlier bump.

## A1 — `CSalamanderGeneralAbstract::IsUnattendedClose()`

```cpp
virtual BOOL WINAPI IsUnattendedClose() = 0;
```

TRUE while the program is closing because an installer asked it to (Windows
Restart Manager: `WM_ENDSESSION` with `ENDSESSION_CLOSEAPP`, feature 080), with
nobody at the machine. FALSE at every other time — normal exit, critical
shutdown, sign-out.

Rule for `CPluginInterfaceAbstract::Release(parent, force)` when it is TRUE
and `force` is FALSE: **show nothing.** Either release everything without a
question and return TRUE, or return FALSE (the program then stays running and
the installer's request fails cleanly). Never cancel work the user did not ask
to cancel: a plug-in with running operations returns FALSE.

It is the opposite policy of `IsCriticalShutdown()` (*"hurry, lose what must
be lost"*): *"ask nobody, lose nothing"*. Callable from any thread.

## A2 — `CSalamanderGeneralAbstract::SetWindowClosesUnattended(HWND, BOOL)`

```cpp
virtual void WINAPI SetWindowClosesUnattended(HWND hWindow, BOOL closes) = 0;
```

Declares (`closes` TRUE) or withdraws (FALSE) that the top-level window
`hWindow` of this process can be closed during an unattended close without a
question and without losing anything. The program then does not decline an
installer's request because of this window.

- The declaring plug-in MUST, in `Release()` during an unattended close,
  close the window without a prompt (A1).
- Only for windows that hold nothing to lose (viewers). A window with
  unsaved input, a running operation or a transfer MUST NOT be declared.
- A dialog or any other top-level window owned by the declared window is
  **not** covered; while one is open, the program declines.
- The declaration lives with the window: it ends when the window is
  destroyed. Withdraw it explicitly when the window stops being safe.
- `hWindow` NULL or not a window: ignored. Callable from any thread.

Implementation note (not part of the contract): the core stores the
declaration as a window property, so its decision reads it without sending
the window a message.

## A3 — decision D8 (amends `specs/080-…/contracts/close-request.md`)

A top-level window of the process is *foreign* — and makes the program
decline — when it is visible, of a kind the core does not know, a real
window (not a captionless tool / no-activate window), **and not declared by
A2**.

## B1 — `SAL_MAX_PATH_UTF8` in the plug-in headers

```cpp
#define SAL_MAX_PATH_UTF8 (3 * 32767 + 1)   // spl_base.h; the core's value
```

The size in bytes, terminator included, of a buffer that holds any full path
or full file name the program can hand to a plug-in (UTF-8 since interface
104). Plug-ins that defined a private `U8_MAX_PATH` may keep it; the value is
the same.

## B2 — buffer sizes stated by the header

| Service | Parameter | Was documented | Is (and always was since 104) |
|---|---|---|---|
| `GetNextFileNameForViewer` | `fileName` | at least `MAX_PATH` | `SAL_MAX_PATH_UTF8` |
| `GetPreviousFileNameForViewer` | `fileName` | at least `MAX_PATH` | `SAL_MAX_PATH_UTF8` |
| `SalSplitGeneralPath` | `path` | at least `2 * MAX_PATH` | `SAL_MAX_PATH_UTF8` |
| `SalSplitGeneralPath` | `newDirs` | at least `MAX_PATH` | `SAL_MAX_PATH_UTF8` |
| `SalSplitWindowsPath` | `path` | at least `2 * MAX_PATH` | `SAL_MAX_PATH_UTF8` |

## B3 — older plug-ins and the viewer file-name services

For a plug-in whose `SalamanderPluginGetReqVer()` (or SDK version) is below
107, `GetNextFileNameForViewer` / `GetPreviousFileNameForViewer` never write
more than `MAX_PATH` bytes: when the found name does not fit, the call
returns FALSE with `*noMoreFiles` TRUE and `*srcBusy` FALSE, `fileName` and
`*lastFileIndex` untouched. A plug-in built for 107 or later receives every
name.

## Version record

`LAST_VERSION_OF_SALAMANDER` 106 → 107, history entry in `spl_vers.h`
pointing here. `REQUIRE_LAST_VERSION_OF_SALAMANDER` names the first version
that will carry 107.
