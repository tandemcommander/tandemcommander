# Research: feature 125 (GitHub issue #5)

## R1 - Is the report reproducible?

**Measured** (`probe/unc_probe.ps1 -Expect measure`, hidden desktop, English UI):
`probe/unc_measure_v019.txt` (the Debug tree of the 0.1.9 release commit).

- `\\localhost\`, `\\localhost`, `\\PC-DOMA\`: box *Error Changing Directory* - `Path: "\\localhost\"`, `Error: A share name is missing in the path specified.`, then the Change Directory dialog again. **Confirmed.**
- `\\`: *A server name is missing in the path specified.*
- `\\tc125-no-such-host\`: the same "share name is missing" box, at once - the check is syntactic (`SalGetFullName`, `src/salamdr3.cpp`), the network is never asked.

Cause as reported: `CFilesWindow::ChangeDir` (`src/fileswn3.cpp`, branch
`errTextID == IDS_SERVERNAMEMISSING || IDS_SHARENAMEMISSING` with `callNethood`) hands the
path to `Plugins.GetFirstNethoodPluginFSName`, which finds nothing: `plugins.cfg` has
`nethood=off` (feature 007, FR-008).

## R2 - The proposed remedy: `nethood=on`

Built (`build.cmd full` with `nethood=on`: compiles without a change, 21 plug-ins) and
measured: `probe/unc_measure_with_nethood_plugin.txt`.

| Observation | Evidence |
|---|---|
| `\\localhost\` opens `net:\\localhost`, no error | rows S1-S3 |
| `\\` opens `net:\` with "Scanning network..." | row S4, crop |
| a server that does not exist: `net:\\tc125-no-such-host`, empty, no message (2.8 s) | row S5 |
| **every exit after the plug-in was used: Debug heap box "Detected memory leaks!"** (the probe's END rows all fail on it; the 0.1.9 rows exit clean) | all END rows |

A read-only audit of the plug-in by a separate agent (file:line evidence in the session log,
summarised here):

1. **Shutdown**: `Release()` ignores `force` and calls `Destroy()` -> `KillAll(TRUE, 0, 0)`: the
   enumeration and management threads are terminated with zero wait, possibly inside WNet/COM
   or holding the cache lock (`nethood.cpp`, `cache.cpp`). This is the leak box above and a
   possible hang or crash at exit, also on an installer's close request.
2. **Wider behaviour change than the report**: with the plug-in every UNC root gains `..`
   leading to `net:`, *Go to root* jumps there, and the Change Drive menu's *Network* item
   becomes the plug-in panel instead of the Windows folder picker - whose root
   (`WNetOpenEnum(RESOURCE_CONTEXT)`) depends on legacy network discovery
   (`architecture/10-plugin-maintenance-outlook.md` already calls it dead).
3. **Encoding residue**: names cross the interface as UTF-8 (ported in feature 004), but name
   matching is `_tcsicmp` on UTF-8 (rule 092), `LoadStr`/`FormatMessageA` texts go to UTF-8
   sinks, and the core's logon path that only this plug-in reaches
   (`SalWNetAddConnection2Interactive`, `CredUIPromptForCredentialsA`, `src/drivelst.cpp`) is
   ANSI.
4. **Buffers**: `MAX_PATH` everywhere with silent cuts; an unbounded copy in `ChangePath`.
5. **Texts**: "Salamander" / "Open Salamander" in `lang.rc` and in all eight `.slt` files; a
   `forum.altap.cz` header in the Czech one.
6. **Public claims**: `PRIVACY.md` (a plug-in enabled in the default build; a "scan network on
   start" option), plug-in counts in `CLAUDE.md`, `architecture/09`, `CHANGELOG.md`.

- **Decision**: the plug-in is **not** enabled by this feature. Which plug-ins ship is a
  recorded policy (007) and a public claim; items 1-6 are a feature of their own; the maintainer
  is away. The list goes to `specs/NEXT-WORK.md` as an open decision with its price.
- **Alternative considered**: enable and fix items 1-6 here. Rejected for this session: a
  7,000-line network component with threads, shipped in a patch release, on the judgement of an
  unattended session - and still a policy change nobody approved.

## R3 - What the program can do by itself

There is no file system to "list" a server in a disk panel, so the shares are offered as a
**choice**, after which the ordinary path change to `\\server\share` runs.

- **Decision**: a popup menu (`CMenuPopup`) under the panel's directory line - the place and
  the look of the directory history (`CFilesWindow::OpenDirHistory`, `src/fileswnb.cpp`); item
  texts are UTF-8 (the history fills paths the same way). No dialog resource, no new string.
- **Alternatives rejected**: the Windows folder picker rooted at the server (`GetTargetDirectory`)
  - slow, modal, foreign, and it shows the whole tree where one level is wanted; a new dialog
  with a list - new resources and texts in eight languages for what a menu does.

## R4 - Reading the shares

- **Decision**: `NetShareEnum(\\server, level 1)` - names, types and remarks, including hidden
  shares; when it fails, `WNetOpenEnumW(RESOURCE_GLOBALNET, RESOURCETYPE_DISK)` on the server's
  `NETRESOURCE` (visible disk shares, works with the session Windows already has). The first
  error is reported if both fail. Measured on this machine: `net view \\PC-DOMA /all` (the same
  API) lists `ADMIN$`, `C$`..`H$`, `IPC$` and no visible share.
- Offered: `STYPE_DISKTREE` only (`type & STYPE_MASK`); `IPC$`, printers and devices are not
  folders. Hidden = `STYPE_SPECIAL` or a name ending with `$`. Order: visible first, then
  hidden, each by `SalNameCompareOrdinalCI` (rule 092; header `salnameorder.h`).
- Both calls can block for tens of seconds on a dead host - **never on the main thread**.

## R5 - Not freezing

- **Decision**: a worker thread owns a reference-counted job (server name in, share list and
  error out, a "done" event). The main thread waits 400 ms quietly, then shows the existing
  safe wait window with the existing text `IDS_CHECKINGPATHESC` ("Checking path "%s", press the
  ESC key to cancel...") and polls `UserWantsToCancelSafeWaitWindow()` - the pattern of
  `SalCheckPath` (`src/salamdr5.cpp`). On Esc the main thread drops its reference and goes on;
  the thread finishes its system call whenever Windows lets it and frees the job. Nothing is
  terminated by force.
- At program exit an abandoned worker may still be blocked in a network call. It is registered
  with `AddAuxThread` like the core's other helpers, so the exit path closes it with them
  (corrected after the review: the first version closed the thread handle at once and claimed
  the worker "holds no lock" - its call-stack object does take the global call-stack section
  when the thread ends).

## R6 - Where the path comes from; what "cancel" means

`ChangeDir` serves the Change Directory dialog (`newDir == NULL`) and callers with a ready
path. The existing branch for a plug-in FS path shows the shape to follow:

- picked: the new path replaces `path` / `newDir`, `goto CHANGE_AGAIN_NO_DLG`;
- cancelled or an error already shown: with a dialog `goto CHANGE_AGAIN` (the dialog opens
  again with the text - as after every other error of this function), otherwise
  `*failReason = CHPPFR_INVALIDPATH; return FALSE`;
- no folder share: fall through to the existing message (`IDS_SHARENAMEMISSING`).

Only `IDS_SHARENAMEMISSING` with `callNethood` takes the new route; `\\` alone
(`IDS_SERVERNAMEMISSING`) keeps its message.

## R7 - Never cut a name

`\\server\share` in UTF-8 can exceed `MAX_PATH` bytes (a share name of 80 non-Latin letters is
240 bytes). The built path goes into a `SAL_MAX_PATH_UTF8` buffer; the builder refuses
(`IDS_TOOLONGPATH` through the existing error format) instead of cutting. Menu texts double
`&` (the menu's accelerator mark).

## R8 - Testing without a second machine

This computer has only hidden shares and the session cannot create one (no administrator
rights are assumed). 

- **Decision**: a **Debug-only** seam in the enumeration (compiled out of Release, checked by a
  string search of the Release binary as in feature 123): `TC_PROBE_UNC_SHARES` (a `|`-separated
  list of `name` or `name*type`), `TC_PROBE_UNC_DELAY` (milliseconds before answering),
  `TC_PROBE_UNC_ERROR` (a Windows error instead of a list). The probe uses it for the list's
  content, order, non-ASCII names, the wait window and Esc, errors. The **real** path is driven
  too: `\\localhost\` without the seam lists this machine's hidden disk shares, and picking
  `C$` must land in `\\localhost\C$`.
- The menu is owner-drawn: read by capture + text recognition (`shotocr_lib.ps1` of feature 124).

## R9 - Privacy statement

`PRIVACY.md` § *Other network use*, bullet *Network drives and shared folders* says only "when
you open a network location, Windows connects to it". Asking a named server for its list of
shares is a new, user-initiated network request of the program: the bullet is extended in the
same change (CLAUDE.md, rule 083). Nothing is stored; no credentials are handled.
