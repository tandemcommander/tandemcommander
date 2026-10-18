# Contract: plug-in interface 108 — settings import

Additions only. A plug-in built for interface 104–107 loads and runs unchanged
(pure append at the end of `CSalamanderPluginEntryAbstract`, two new abstract
classes, new constants). In-tree plug-ins are built against 108 and therefore
require a 108 core, as with every earlier bump.

## A1 — `CSalamanderPluginEntryAbstract::SetPluginSettingsImport`

```cpp
virtual void WINAPI SetPluginSettingsImport(CPluginSettingsImportAbstract* handler) = 0;
```

Called by a plug-in from `SalamanderPluginEntry` (each time it is loaded) to
say that it can import its own settings from an older program (Altap
Salamander 2.5–4.0, Open Salamander 5.0) through the core's settings-import
wizard. `handler` must stay valid until the plug-in is unloaded (a static
object of the plug-in). `NULL` withdraws it. A plug-in that does not call it
is offered by the wizard only as "take over its settings as a whole" (the
core then replaces the plug-in's registry subtree while the plug-in is
unloaded) — or not at all.

## A2 — `CPluginSettingsImportAbstract` (implemented by the plug-in)

```cpp
class CPluginSettingsImportAbstract
{
public:
    virtual BOOL WINAPI ImportSettings(HWND parent, CSalamanderSettingsImportAbstract* import,
                                       BOOL dryRun) = 0;
};
```

- Called on the main thread, while the plug-in is loaded, with the wizard's
  window as `parent`, between `EnterPlugin` and `LeavePlugin` like every other
  plug-in entry point. Never shows a window: the core asks for the program's
  master password before the preview (A3), not during a call.
- A crash in the handler is not caught: the plug-in's state would be unknown
  and the configuration save that follows the import would store it. The
  program's own crash handling applies; the backup of the settings is already
  written at that point.
- `dryRun` TRUE (preview): read the source, decide, **report** every item
  through `import->Report` exactly as an apply would, change nothing.
- `dryRun` FALSE (apply): the same decisions, then change the plug-in's
  in-memory settings. All-or-nothing: build the new state completely, swap it
  in only when complete; on failure leave the settings unchanged and return
  FALSE. The core saves the configuration afterwards (the plug-in's
  `SaveConfiguration` is called by the core's normal save).
- Return TRUE when planned/applied completely, FALSE when nothing was
  changed.
- The plug-in must produce the same reports for the same source, mode and
  current settings in both passes (the preview is the user's consent).

## A3 — `CSalamanderSettingsImportAbstract` (implemented by the core)

```cpp
#define SALIMPORT_MODE_ADD 1     // keep everything current, add what is new
#define SALIMPORT_MODE_REPLACE 2 // the plug-in's imported part becomes the source's

#define SALIMPORT_REPORT_ADDED 1    // added
#define SALIMPORT_REPORT_PRESENT 2  // already present, not added
#define SALIMPORT_REPORT_REPLACED 3 // a current item was replaced
#define SALIMPORT_REPORT_REMOVED 4  // a current item was removed (Replace)
#define SALIMPORT_REPORT_SKIPPED 5  // not imported; the text says why
#define SALIMPORT_REPORT_FLAGGED 6  // imported; the user should check it
#define SALIMPORT_REPORT_NOTE 7     // information

class CSalamanderSettingsImportAbstract
{
public:
    virtual int WINAPI GetMode() = 0;                          // SALIMPORT_MODE_*
    virtual const char* WINAPI GetSourceName() = 0;            // UTF-8, e.g. "Altap Salamander 4.0"
    virtual DWORD WINAPI GetSourceConfigVersion() = 0;         // the source's core configuration version
    virtual BOOL WINAPI GetSourceKey(HKEY* key, CSalamanderRegistryAbstract** registry) = 0;
    virtual void WINAPI Report(int kind, const char* text) = 0; // UTF-8 line, one item
    virtual int WINAPI GetPasswordPolicy() = 0;                // SALIMPORT_PWD_*
    virtual BOOL WINAPI DecryptSourcePassword(const BYTE* blob, int blobSize, char** plain) = 0;
    virtual BOOL WINAPI EncryptForStorage(const char* plain, BYTE** blob, int* blobSize) = 0;
};

#define SALIMPORT_PWD_NONE 0          // import no saved passwords at all
#define SALIMPORT_PWD_SCRAMBLED_ONLY 1 // passwords stored without a master password in the source
#define SALIMPORT_PWD_ALL 2           // also master-password-protected ones (verified source master password)
```

- `GetSourceKey`: the plug-in's own key `Plugins Configuration\<its key>` of
  the source, as a **read-only** view over the core's in-memory copy of the
  source (the source registry is not touched again). `registry` reads it:
  `OpenKey`, `GetValue`, `GetSize`, `CloseKey` work; `CreateKey`,
  `SetValue`, `DeleteValue`, `DeleteKey`, `ClearKey` return FALSE. Strings are
  UTF-8 as with the normal registry object; a wrongly typed or too long value
  makes `GetValue` return FALSE quietly. FALSE when the source has no key for
  the plug-in. The handles are valid until `ImportSettings` returns.
- `DecryptSourcePassword`: decrypts a password blob **as stored by the
  source** (signature 1 scrambled; signature 2 AES under the source's master
  password, which the user typed and the core verified). FALSE when the blob
  cannot be decrypted or the policy does not allow it. `*plain` is freed with
  `CSalamanderGeneralAbstract::Free` after the plug-in wiped it.
- `EncryptForStorage`: encrypts a plain password the way the program stores
  passwords now (AES under the program's master password when it uses one,
  otherwise scrambled). It never asks: when passwords would be imported and the
  program uses a master password that is not entered, the core asks for it
  once, **before the preview**. If it is still not entered,
  `DecryptSourcePassword` answers FALSE in the preview and in the import alike,
  so both report the same items "without their password".
- A source master password longer than 127 bytes is used with its first 127
  bytes, as the old program read it (`GetDlgItemText(..., 128)`).
- The policy is chosen by the user on the wizard's password page; a password
  the policy excludes is not imported (the item comes without it, reported as
  SKIPPED-password or FLAGGED).

## A4 — rules for an implementing plug-in

1. Only read through `GetSourceKey`; never open the source registry yourself.
2. Never change the program's master password or any password the program
   already protects; never store a password with weaker protection than
   `EncryptForStorage` gives.
3. Report every source item exactly once (ADDED / PRESENT / REPLACED /
   SKIPPED / FLAGGED); report every current item a REPLACE removes (REMOVED)
   and every current item a REPLACE overwrites (REPLACED) — REPLACED and
   REMOVED lines are what the wizard asks consent for. One line per item: when
   several reasons apply (renamed, no password, no proxy server), the line
   names them all.
4. Keep references inside the plug-in's settings consistent (e.g. FTP
   bookmarks → proxy servers).
5. Wipe plain passwords after use.
6. All or nothing: build the complete new state first, then exchange it with
   the current one in steps that cannot fail; a dry run builds and reports the
   same and discards it.

## FTP client (the first implementation)

Imports the lists *Bookmarks*, *Proxy Servers*, *Server Types* (user-defined
types). Add / Replace per research R9; passwords per R10. Its other options
are not part of this group.

- The three new lists are complete copies before anything changes; the
  commit swaps them in (`ImportSwap`, no allocation).
- A bookmark's proxy server is part of its identity (re-mapped to the new
  list first). The first source proxy server of a UID wins; UIDs below 1 are
  never mapped.
- Replace keeps the UID of a current proxy server that the source has
  identically, and new UIDs continue after the current ones, so a reference to
  a removed proxy server never points to another one; a removed default proxy
  server resets the default to "not used" (reported as removed).
- Server types: a source user type whose name (without `*`) the current list
  has: PRESENT when the definitions are equal; Add keeps the current one
  (SKIPPED with the reason); Replace replaces it in place (REPLACED). An entry
  of the source list that does not load is reported by its number.

## Version record

`LAST_VERSION_OF_SALAMANDER` 107 → 108, history entry in `spl_vers.h`
pointing here. `REQUIRE_LAST_VERSION_OF_SALAMANDER` names the version that
will carry 108 ("first shipped in version 0.1.11").
