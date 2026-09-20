# Data Model — mdview onto the Shared WebView2 Host (081)

No persisted data changes. Three in-memory entities matter to the design; their
shape is fixed by the shared component (`src/common/webhost/webhost.h`,
`webkeeper.h`) and only *filled in* by mdview.

## 1. Host configuration (per viewer window) — `TcWebHostConfig`

| Field | mdview value | Rule |
|---|---|---|
| `VirtualHost` | `L"mdview.invalid"` | the private origin; the host builds `https://mdview.invalid/` and refuses every navigation outside `https://mdview.invalid/doc.html…` |
| `DocumentPath` | `L"doc.html"` (default) | the one navigable resource; the host appends the CSP to its response |
| `ScriptsEnabled` | `false` | feature 021 FR-050; asserted in Debug by the host |
| `WebMessagesEnabled` | `false` | no page→host channel in mdview |
| `Serve` | mdview server (contract `mdview-host-config.md` §2) | receives `doc.html` / `img/<n>`; `false` ⇒ 403 |
| `Accelerator` | mdview key map (contract §3) | `0` lets the engine keep the key |
| `TraceName` | `"mdview"` | Debug trace prefix (parity with the old `"mdview: …"` lines) |

Everything not in this table is an invariant of the shared component and is
**not** configurable (070 contract §2).

**Lifetime**: filled by `MdConfigureHost()` in `WM_CREATE`, copied into the
host by `Create()`. The `Serve` lambda captures `&CViewerWindow::Html` — a
member whose address is stable for the window's life; the host is destroyed in
`WM_DESTROY` (`Web->Destroy()`) and deleted in the window destructor, before
the member goes away.

## 2. Callbacks (host → viewer window) — `CTcWebHost::Callbacks`

| Callback | Viewer action (unchanged from 0.1.7) |
|---|---|
| `OnReady` | if `RenderPending`: `DocVersion++`, `SetZoomPercent(g_zoom)`, `Navigate(DocVersion)` |
| `OnActivateLink(uri)` | `ActivateLink(uri)` — the `.md` link gate |
| `OnInitFailed` | `PostMessage(WM_APP+1)` → `EngineFailed()` (message + close) |
| `OnProcessFailed` | same as `OnInitFailed` |
| `OnZoomChanged(pct)` | `g_zoom = pct; UpdateTitle()` |
| `OnWebMessage` | not set (channel off) |

## 3. Session keeper (one per plugin) — `CTcWebKeeper` + `TcWebKeeperConfig`

| Field | mdview value |
|---|---|
| `ClassName` | `L"TandemMdKeeperWnd"` (kept from 065/070 for continuity; codeview: `TandemCvKeeperWnd`) |
| `Instance` | `DLLInstance` (the class is unregistered against it on unload — 069 F-P6-01) |
| `TraceName` | `"mdview keeper"` |

**States** (inside the shared keeper): `unarmed → arming → armed`;
`armed/arming → unarmed` on `Disarm()` (config toggle-off, `Release`, browser
death via `TC_KEEPER_DIED`). Transitions mdview triggers:

| Trigger | Site | Call |
|---|---|---|
| first actual view, `g_keepReady` on | `CPluginInterfaceForViewer::ViewFile` (main thread) | `MdKeeperArm()` |
| *Keep the rendering engine ready* turned off | `CfgDlgProc` IDOK | `MdKeeperDisarm()` |
| plugin unload | `CPluginInterface::Release` after `ThreadQueue.KillAll` | `MdKeeperDisarm()` |
| browser process died | shared keeper's hidden window | internal `Disarm()`; next `MdKeeperArm()` re-arms |

`MdKeeperArmed()` (declared today, called nowhere) is not carried over.

## 4. Generated document + version (per viewer window)

| Field | Type | Meaning |
|---|---|---|
| `Html` | `MdHtmlResult` (member) | `html` bytes, `images[]` (index n ⇔ `img/<n>`, each `Local` path or `Remote` URL — remote entries exist only after consent), `matchCount` |
| `DocDir` | `std::wstring` | directory of the file (image resolution, link gate); no longer passed to the host |
| `DocVersion` | `int` (member, new) | incremented whenever `Html` is regenerated and re-served; `Navigate(DocVersion, fragment)` yields `doc.html?v=<n>[#fragment]` |

**Rules** (unchanged semantics, moved from the host to the window):

- a new document, a scheme change, a consent change, a new search term:
  `DocVersion++` then `Navigate(DocVersion)` → fresh URL → full reload;
- find next/previous: `Navigate(DocVersion, L"mdfind-<i>")` with the **same**
  version → same-document scroll to the mark;
- `RenderPending` defers the first navigation until `OnReady`.

## 5. Browser-arguments set (product-wide, one value)

`TcWebBrowserArguments()` → `L"--disable-background-networking --disable-sync
--disable-component-update --disable-features=msWebOOUI,msPdfOOUI"`. Consumed
by `TcWebBuildEnvOptions()` (viewer surfaces) and the keeper's options
builder. Invariant: exactly one definition in `src/`.
