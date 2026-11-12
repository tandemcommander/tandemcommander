# Contract - DPI mode of the shared WebView2 host (feature 424)

An addition to `architecture/11-webview2-integration.md` for consumers of `src/common/webhost/`.
It is not part of the plug-in ABI. Both consumers are plug-ins of the tree that compile the shared
host themselves.

1. **Every WebView2 environment of the product is created per-monitor-v2 aware.**
   `CTcWebHost::Create` and `CTcWebKeeper::Arm` create theirs inside a `CTcWebPerMonitorDpiScope`
   (the keeper's holder window too). WebView2 gives the browser process the DPI mode of the thread
   that creates the environment (`--embedded-browser-webview-dpi-awareness`), and all environments
   on one user data folder must agree: a later environment of the other mode is created, but its
   controller fails with `0x8007139F` (`ERROR_INVALID_STATE`, measured by the 424 review). That is
   also why an older version (system mode) and this one cannot show their viewers at the same time. A new consumer never calls
   `CreateCoreWebView2EnvironmentWithOptions` itself (rule 11 already says so).
2. **A window that hosts a `CTcWebHost` is per-monitor-v2 aware.** Its thread calls
   `TcWebEnterPerMonitorDpiThread()` before creating it. The thread keeps that context for its
   life, so code outside the window procedure sees the same coordinates as the window.
3. **Rectangles from the core** (system coordinates) are mapped with
   `TcWebSystemRectToPerMonitor` before a window is created at them. A rectangle that was stored by
   the window's own thread is used as-is.
4. **`WM_DPICHANGED`**: call `TcWebApplyDpiChanged(hwnd, lParam)` (the suggested rectangle), then
   re-derive every DPI-dependent metric of the window's own (non-WebView) parts.

Header API (`webhost.h`, COM-free):

```cpp
class CTcWebPerMonitorDpiScope;                       // RAII: per-monitor v2 for the scope, restores
void TcWebEnterPerMonitorDpiThread();                 // per-monitor v2 for the rest of the thread
RECT TcWebSystemRectToPerMonitor(const RECT& rc);     // system -> per-monitor coordinates
void TcWebApplyDpiChanged(HWND hwnd, LPARAM lParam);  // WM_DPICHANGED: the suggested rectangle
```
