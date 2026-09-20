# Contract: mdview's Configuration of the Shared WebView2 Host

**Status**: binding for feature 081 and for any later change to the Markdown
Viewer's rendering surface. Implements the mdview column of
`specs/070-source-viewer-plugin/contracts/webview-host-sharing.md` §2 and
completes §1 of that contract. mdview's user-visible behaviour MUST NOT change
relative to 0.1.7 except where §5 says "stricter".

## 1. What the plugin may configure (and nothing else)

| `TcWebHostConfig` field | Value | Why |
|---|---|---|
| `VirtualHost` | `L"mdview.invalid"` | the 021 private origin; the link gate in `viewer.cpp` matches `https://mdview.invalid/` and `doc.html` |
| `DocumentPath` | `L"doc.html"` | unchanged URL scheme `doc.html?v=<n>[#fragment]` |
| `ScriptsEnabled` | `false` | 021 FR-050 |
| `WebMessagesEnabled` | `false` | no channel |
| `Serve` | §2 | |
| `Accelerator` | §3 | |
| `TraceName` | `"mdview"` | |

Every other setting is applied by the shared lockdown routine and MUST NOT be
re-applied, overridden or "restored" from the plugin.

## 2. `Serve` — the document and image server

Input: URL path relative to the origin, query and fragment stripped, no
leading slash. Output: `TcWebResponse`; return `false` for anything not
listed.

| Path | Status | `ContentType` | Body | Notes |
|---|---|---|---|---|
| `doc.html` | 200 `OK` | `text/html; charset=utf-8` | `Html.html` | the host appends `kCspStatic`; `ExtraHeaders` empty |
| `img/<n>`, `0 ≤ n < images.size()`, bytes obtained | 200 `OK` | sniffed: `image/png`, `image/jpeg`, `image/gif`, `image/bmp`, `image/webp`, `image/svg+xml`, else `application/octet-stream` | file bytes (`Local`, `\\?\`-prefixed read, ≤ 64 MB) or fetched bytes (`Remote`, WinHTTP GET, no cookies, ≤ 32 MB) | a `Remote` entry exists only when the user consented for this document (the generator emits a placeholder otherwise) |
| `img/<n>` otherwise (index out of range, unreadable, fetch failed, empty) | **404 `Not Found`** | `application/octet-stream` | empty | returned as `true` with `Status = 404` so the status mdview always used is preserved (returning `false` would make it the host's 403) |
| anything else | — | — | — | `false` → 403 by the host (default-deny is the host's invariant, not the plugin's choice) |

### Buffer lifetime — the trap in this callback

`TcWebResponse::Data` is **borrowed, and the host reads it after `Serve`
returns**: the shared host calls `MakeAndSetResponse` → `SHCreateMemStream`
*after* the callback, so a buffer local to the callback body is already
destroyed when the copy happens. (codeview never met this: its answers are a
module resource and a window member, both of which outlive everything.)

| Answer | Owner | Lives as long as |
|---|---|---|
| `doc.html` bytes | `CViewerWindow::Html.html` | the viewer window |
| `img/<n>` bytes | a scratch `std::vector<BYTE>` held by the `Serve` lambda (a captured `shared_ptr`) | the host (the lambda is stored in its config copy) |

One scratch buffer is enough because `WebResourceRequested` is raised on the
single thread that created the controller, so two requests never overlap.

Its capacity is released **at the start of the next image request**, not at
the end of the current one — the bytes still have to be there when the host
copies them. So at most one image is held between requests (up to 64 MB local,
32 MB consented remote), never for the life of the window.

## 3. `Accelerator` — the 0.1.7 key map, verbatim

| Key | Command | Notes |
|---|---|---|
| `F3` / `Shift+F3` | `CM_EDIT_FINDNEXT` / `CM_EDIT_FINDPREV` | |
| `Esc` | `CM_FILE_CLOSE` | |
| `F9` / `Shift+F9` | `CM_SCHEME_NEXT` / `CM_SCHEME_PREV` | |
| `Ctrl+F` | `CM_EDIT_FIND` | |
| `Ctrl+U` | `CM_FILE_OPENTEXT` | View Source toggle |
| `Ctrl+0` / `Ctrl+Numpad 0` | `CM_VIEW_ZOOMRESET` | a browser accelerator the lockdown disables; the plugin owns *reset* only |
| everything else | `0` | Ctrl+wheel and Ctrl+Plus/Minus stay the engine's (`IsZoomControlEnabled` TRUE; `ZoomFactorChanged` syncs `g_zoom` and the title) |

The frame's `HACCEL` table in `InitViewer()` is untouched (it serves keys while
focus is outside the WebView).

## 4. Keeper, folder, callbacks

- Keeper: `TcWebKeeperConfig{ ClassName = L"TandemMdKeeperWnd", Instance =
  DLLInstance, TraceName = "mdview keeper" }` behind `MdKeeperArm()` /
  `MdKeeperDisarm()`; call sites and their conditions unchanged
  (`ViewFile` when `g_keepReady`; `CfgDlgProc` on turning the option off;
  `Release` after the thread queue is down).
- Folder: `TcWebUserDataFolder()` for every environment; `MdCleanupOldUserDataFolder()`
  still runs once per session at the first view.
- Callbacks: see `data-model.md` §2 — a 1:1 mapping of the 0.1.7 handlers.
- Document version: `CViewerWindow::DocVersion`, incremented at each of the
  three former `SetDocument` sites; `Navigate(DocVersion, fragment)`.

## 5. Behaviour the plugin inherits (must hold after the migration)

**Same as 0.1.7** (rows of `quickstart.md` § A/C): rendering, schemes,
follow-system, zoom (mouse, keys, title, persistence), find (new-term reload,
next/prev scroll, not-found), View Source, all link kinds, remote-image
consent + placeholder, dark menus, engine-unavailable fallback, resize/focus,
keeper arm/disarm/re-arm, cache folder and janitor.

**Stricter, and nothing legitimate lost** (rows § D):

| Delta | Old | New |
|---|---|---|
| CSP on the document | none | `default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'` — inline styles, `img/<n>` and `data:` images render; iframes/media/remote fonts/forms refused one layer earlier than the interceptor |
| downloads | engine default | cancelled (`DownloadStarting`) |
| permission requests | engine default | denied (unreachable while scripts are off) |
| script dialogs | engine default | disabled (unreachable while scripts are off) |
| worker-source interception | document-only filter | all source kinds on runtime 111+ (no workers in mdview) |
| close during cold start | latent use-after-free window | late completions discarded |
| Debug read-back | none | `AssertLockdown` traces any regressed setting |

**Accepted tiny deltas**:

- an embedded `<form>` submission is refused silently instead of showing
  *link blocked* (spec Edge Cases);
- the 404 for a broken `img/<n>` slot now carries
  `Content-Type: application/octet-stream`; before it carried no headers at
  all. Status, reason and the empty body are unchanged, and the engine shows
  the same empty slot.

## 6. Forbidden

- Any `#include <wrl.h>` / `"WebView2.h"` / `"WebView2EnvironmentOptions.h"`
  under `src/plugins/mdview/` (guard G2).
- A second definition of the browser-arguments set anywhere (see
  `browser-arguments-single-source.md`).
- Relaxing a shared lockdown setting for mdview's benefit — a legitimate need
  is a change to the shared component and a coordinated review, never a
  per-plugin override.
