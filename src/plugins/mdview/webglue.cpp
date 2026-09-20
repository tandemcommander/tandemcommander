// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// webglue.cpp - mdview's configuration of the shared WebView2 host: the
// document and image server, the key map, the pre-065 cache-folder janitor and
// the session keeper. See webglue.h for what moved to src/common/webhost/ in
// feature 081 and why.
//
// Nothing in this file touches COM or WebView2. The one rule that must survive
// every later edit: a plugin may only ADD answers to the interceptor; what
// happens to everything else (403) is the shared host's invariant, not ours.

#include "precomp.h"
#include "render.h"

#include <winhttp.h>
#include <memory>

#include "webglue.h"
#include "webkeeper.h"

// ==========================================================================
// local file and network helpers (unchanged from the pre-081 webview.cpp)
// ==========================================================================

static std::wstring MakeExtPath(const std::wstring& p)
{
    if (p.size() >= 4 && p.compare(0, 4, L"\\\\?\\") == 0)
        return p;
    if (p.size() >= 2 && p[0] == L'\\' && p[1] == L'\\')
        return L"\\\\?\\UNC\\" + p.substr(2);
    return L"\\\\?\\" + p;
}

static bool ReadFileBytes(const std::wstring& path, std::vector<BYTE>& out)
{
    HANDLE h = CreateFileW(MakeExtPath(path).c_str(), GENERIC_READ,
                           FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                           NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE)
        return false;
    LARGE_INTEGER sz;
    bool ok = false;
    if (GetFileSizeEx(h, &sz) && sz.QuadPart >= 0 && sz.QuadPart <= (64LL * 1024 * 1024))
    {
        DWORD n = (DWORD)sz.QuadPart;
        out.resize(n);
        DWORD rd = 0;
        if (ReadFile(h, n ? &out[0] : NULL, n, &rd, NULL))
        {
            out.resize(rd);
            ok = true;
        }
    }
    CloseHandle(h);
    return ok;
}

// The BARE media type: the shared host writes the "Content-Type: " prefix
// itself (TcWebResponse::ContentType), unlike the pre-081 code which built the
// whole header line here.
static const wchar_t* SniffContentType(const BYTE* d, size_t n)
{
    if (n >= 8 && d[0] == 0x89 && d[1] == 'P' && d[2] == 'N' && d[3] == 'G')
        return L"image/png";
    if (n >= 3 && d[0] == 0xFF && d[1] == 0xD8 && d[2] == 0xFF)
        return L"image/jpeg";
    if (n >= 6 && (memcmp(d, "GIF87a", 6) == 0 || memcmp(d, "GIF89a", 6) == 0))
        return L"image/gif";
    if (n >= 2 && d[0] == 'B' && d[1] == 'M')
        return L"image/bmp";
    if (n >= 12 && memcmp(d, "RIFF", 4) == 0 && memcmp(d + 8, "WEBP", 4) == 0)
        return L"image/webp";
    if (n >= 4 && (memcmp(d, "<svg", 4) == 0 || memcmp(d, "<?xm", 4) == 0))
        return L"image/svg+xml";
    return L"application/octet-stream";
}

// Minimal WinHTTP GET (no cookies, capped size). Only reached for a remote
// image the user explicitly consented to: the generator puts a Remote entry in
// the image table only after View > Load Remote Images.
static bool FetchRemote(const std::wstring& url, std::vector<BYTE>& out)
{
    URL_COMPONENTS uc;
    ZeroMemory(&uc, sizeof(uc));
    uc.dwStructSize = sizeof(uc);
    wchar_t host[256] = {0}, path[2048] = {0};
    uc.lpszHostName = host;
    uc.dwHostNameLength = _countof(host);
    uc.lpszUrlPath = path;
    uc.dwUrlPathLength = _countof(path);
    if (!WinHttpCrackUrl(url.c_str(), (DWORD)url.size(), 0, &uc))
        return false;
    bool https = (uc.nScheme == INTERNET_SCHEME_HTTPS);

    HINTERNET hs = WinHttpOpen(L"OpenSalamander-mdview", WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                               WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!hs)
        return false;
    bool ok = false;
    HINTERNET hc = WinHttpConnect(hs, host, uc.nPort, 0);
    if (hc)
    {
        HINTERNET hr = WinHttpOpenRequest(hc, L"GET", path, NULL, WINHTTP_NO_REFERER,
                                          WINHTTP_DEFAULT_ACCEPT_TYPES,
                                          https ? WINHTTP_FLAG_SECURE : 0);
        if (hr)
        {
            if (WinHttpSendRequest(hr, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
                                   WINHTTP_NO_REQUEST_DATA, 0, 0, 0) &&
                WinHttpReceiveResponse(hr, NULL))
            {
                out.clear();
                DWORD avail = 0;
                ok = true;
                do
                {
                    avail = 0;
                    if (!WinHttpQueryDataAvailable(hr, &avail))
                    {
                        ok = false;
                        break;
                    }
                    if (avail == 0)
                        break;
                    size_t base = out.size();
                    out.resize(base + avail);
                    DWORD rd = 0;
                    if (!WinHttpReadData(hr, &out[base], avail, &rd))
                    {
                        ok = false;
                        break;
                    }
                    out.resize(base + rd);
                    if (out.size() > 32u * 1024 * 1024)
                    {
                        ok = false;
                        break;
                    } // cap
                } while (avail > 0);
            }
            WinHttpCloseHandle(hr);
        }
        WinHttpCloseHandle(hc);
    }
    WinHttpCloseHandle(hs);
    return ok && !out.empty();
}

// ==========================================================================
// the per-plugin host configuration (contracts/mdview-host-config.md)
// ==========================================================================

void MdConfigureHost(TcWebHostConfig& cfg, const MdHtmlResult* doc)
{
    cfg.VirtualHost = L"mdview.invalid";
    cfg.DocumentPath = L"doc.html";
    // Feature 021's lockdown: a rendered Markdown document needs no script and
    // has nothing to say back to the host. The shared host asserts both in a
    // debug build and serves the scripts-off CSP because of them.
    cfg.ScriptsEnabled = false;
    cfg.WebMessagesEnabled = false;
    cfg.TraceName = "mdview";

    // Image bytes must OUTLIVE the Serve call: the host copies them into a
    // stream in MakeAndSetResponse, which runs after we return. A vector local
    // to the lambda body would already be destroyed there (a dangling
    // TcWebResponse::Data). One scratch buffer per host, owned by the lambda,
    // is enough -- WebResourceRequested is raised on the single thread that
    // created the controller, so two requests never overlap, and the buffer is
    // only required to survive until the host has copied it.
    auto scratch = std::make_shared<std::vector<BYTE>>();

    cfg.Serve = [doc, scratch](const std::wstring& path, TcWebResponse& out) -> bool
    {
        if (doc == NULL)
            return false; // nothing generated yet -> the host's 403

        if (path == L"doc.html")
        {
            out.Data = (const BYTE*)doc->html.data();
            out.Size = doc->html.size();
            out.ContentType = L"text/html; charset=utf-8";
            return true; // the host appends the Content-Security-Policy
        }

        // img/<n>: index into the table the generator built for THIS document.
        // A Remote entry can only exist once the user consented for it.
        static const wchar_t kImgPrefix[] = L"img/";
        const size_t pl = _countof(kImgPrefix) - 1;
        if (path.compare(0, pl, kImgPrefix) == 0)
        {
            int idx = _wtoi(path.c_str() + pl);
            scratch->clear();
            if (idx >= 0 && idx < (int)doc->images.size())
            {
                const MdImageRef& ref = doc->images[idx];
                bool ok = (ref.kind == MdImageRef::Local) ? ReadFileBytes(ref.pathOrUrl, *scratch)
                                                          : FetchRemote(ref.pathOrUrl, *scratch);
                if (ok && !scratch->empty())
                {
                    out.Data = scratch->data();
                    out.Size = scratch->size();
                    out.ContentType = SniffContentType(scratch->data(), scratch->size());
                    return true;
                }
            }
            scratch->clear();
            scratch->shrink_to_fit(); // a refused 32 MB fetch must not be held
            // Answered, but Not Found: the status mdview has always used for a
            // broken image slot. Returning false here would turn it into the
            // host's 403 and change what the engine reports.
            out.Data = NULL;
            out.Size = 0;
            out.ContentType = L"application/octet-stream";
            out.Status = 404;
            out.Reason = L"Not Found";
            return true;
        }

        return false; // everything else -> the host's default-deny 403
    };

    // Accelerator routing: focus lives inside the WebView2 HWND, so the frame's
    // accelerator table never sees these. The map is feature 021's, unchanged.
    cfg.Accelerator = [](UINT vk, bool ctrl, bool shift) -> int
    {
        if (vk == VK_F3)
            return shift ? CM_EDIT_FINDPREV : CM_EDIT_FINDNEXT;
        if (vk == VK_ESCAPE)
            return CM_FILE_CLOSE;
        if (vk == VK_F9)
            return shift ? CM_SCHEME_PREV : CM_SCHEME_NEXT;
        if (ctrl)
        {
            if (vk == 'F')
                return CM_EDIT_FIND;
            if (vk == 'U')
                return CM_FILE_OPENTEXT;
            // Ctrl+- / Ctrl++ / Ctrl+wheel are handled natively by the engine
            // (IsZoomControlEnabled); we only own zoom RESET, because Ctrl+0 is
            // a browser-accelerator key the shared lockdown disables.
            if (vk == '0' || vk == VK_NUMPAD0)
                return CM_VIEW_ZOOMRESET;
        }
        return 0; // everything else stays the engine's
    };
}

// ==========================================================================
// the pre-065 user data folder janitor (mdview history, stays here)
// ==========================================================================

// Deletes the pre-065 cache folder on its own short-lived thread so the
// one-time cleanup never stalls the main thread or a viewer window.
class CMdUdfJanitorThread : public CThread
{
public:
    CMdUdfJanitorThread(const std::wstring& path) : CThread("MDView UDF Janitor"), Path(path) {}

    virtual unsigned Body()
    {
        CALL_STACK_MESSAGE1("CMdUdfJanitorThread::Body()");
        std::vector<wchar_t> from(Path.begin(), Path.end());
        from.push_back(0);
        from.push_back(0); // SHFileOperationW: double-null-terminated list
        SHFILEOPSTRUCTW op = {};
        op.wFunc = FO_DELETE;
        op.pFrom = from.data();
        op.fFlags = FOF_NO_UI;
        SHFileOperationW(&op); // best-effort; a locked folder is retried next session
        return 0;
    }

protected:
    std::wstring Path;
};

void MdCleanupOldUserDataFolder()
{
    static LONG done = 0;
    if (InterlockedCompareExchange(&done, 1, 0) != 0)
        return;
    wchar_t path[MAX_PATH] = {0};
    if (FAILED(SHGetFolderPathW(NULL, CSIDL_LOCAL_APPDATA, NULL, 0, path)))
        return;
    std::wstring old = std::wstring(path) + L"\\Tandem Commander\\mdview.WebView2";
    if (GetFileAttributesW(old.c_str()) == INVALID_FILE_ATTRIBUTES)
        return; // already gone
    CMdUdfJanitorThread* t = new CMdUdfJanitorThread(old);
    if (t != NULL && t->Create(ThreadQueue) == NULL)
        delete t; // thread creation failed; the folder is retried next session
}

// ==========================================================================
// the session keeper (feature 065; shared implementation since 081)
// ==========================================================================

// One keeper per plugin. The window class name MUST stay unique across the
// process -- codeview registers TandemCvKeeperWnd -- and it is kept from
// feature 065 for continuity (070 contract S1).
static CTcWebKeeper g_keeper;
static const wchar_t* MD_KEEPER_CLASS = L"TandemMdKeeperWnd";

void MdKeeperArm()
{
    TcWebKeeperConfig kc;
    kc.ClassName = MD_KEEPER_CLASS;
    kc.Instance = DLLInstance;
    kc.TraceName = "mdview keeper";
    g_keeper.Arm(kc);
}

// Feature 069 (F-P6-01): Disarm also unregisters the window class, which must
// happen on the unload path even when the keeper is already unarmed -- see
// CTcWebKeeper::Disarm.
void MdKeeperDisarm()
{
    g_keeper.Disarm();
}
