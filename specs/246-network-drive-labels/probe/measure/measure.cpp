// 246 measurement tool: mapped network drive name and accessibility states.
#define UNICODE
#define _UNICODE
#define _WIN32_WINNT 0x0A00
#define WINVER 0x0A00
#include <windows.h>
#include <winnetwk.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <shobjidl.h>
#include <shellapi.h>
#include <string>
#include <functional>
#include <cstdio>
#include <cstdarg>
#pragma comment(lib, "mpr.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "user32.lib")

// Not in the public SDK headers; declared as in Wine's winnetwk.h, resolved from mpr.dll at run time.
typedef struct
{
    DWORD dwState;
} WNGC_CONNECTION_STATE;
#define WNGC_INFOLEVEL_DISCONNECTED 1
static DWORD WNetGetConnection3W(LPCWSTR local, LPCWSTR provider, DWORD level, LPVOID buf, LPDWORD cb)
{
    typedef DWORD(WINAPI * P)(LPCWSTR, LPCWSTR, DWORD, LPVOID, LPDWORD);
    static P p = (P)GetProcAddress(LoadLibraryW(L"mpr.dll"), "WNetGetConnection3W");
    if (!p)
        return 0xDEAD;
    return p(local, provider, level, buf, cb);
}

static FILE* g_log;
static DWORD g_timeout = 60000;

static void Out(const std::wstring& s)
{
    int n = WideCharToMultiByte(CP_UTF8, 0, s.c_str(), (int)s.size(), 0, 0, 0, 0);
    std::string u(n, 0);
    WideCharToMultiByte(CP_UTF8, 0, s.c_str(), (int)s.size(), u.data(), n, 0, 0);
    if (g_log)
    {
        fwrite(u.data(), 1, u.size(), g_log);
        fwrite("\n", 1, 1, g_log);
        fflush(g_log);
    }
    std::string a;
    for (wchar_t c : s)
    {
        if (c >= 32 && c < 127)
            a += (char)c;
        else
        {
            char b[8];
            sprintf_s(b, "\\u%04X", (unsigned)c);
            a += b;
        }
    }
    puts(a.c_str());
    fflush(stdout);
}

static std::wstring F(const wchar_t* fmt, ...)
{
    wchar_t b[8192];
    va_list v;
    va_start(v, fmt);
    _vsnwprintf_s(b, _TRUNCATE, fmt, v);
    va_end(v);
    return b;
}

static double NowMs()
{
    LARGE_INTEGER f, c;
    QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&c);
    return c.QuadPart * 1000.0 / f.QuadPart;
}

struct Job
{
    std::function<void()> fn;
};
static DWORD WINAPI JobThread(LPVOID p)
{
    CoInitializeEx(0, COINIT_APARTMENTTHREADED);
    ((Job*)p)->fn();
    CoUninitialize();
    return 0;
}

static bool Timed(const wchar_t* name, std::function<void(std::wstring&)> fn)
{
    auto* res = new std::wstring; // leaked on purpose (abandoned threads)
    Job* j = new Job{[=] { fn(*res); }};
    double t0 = NowMs();
    HANDLE h = CreateThread(0, 0, JobThread, j, 0, 0);
    DWORD w = WaitForSingleObject(h, g_timeout);
    double t = NowMs() - t0;
    if (w == WAIT_TIMEOUT)
    {
        Out(F(L"%-38s STILL BLOCKED after %.0f ms (abandoned)", name, t));
        return false;
    }
    CloseHandle(h);
    Out(F(L"%-38s [%8.1f ms] %s", name, t, res->c_str()));
    return true;
}

static std::wstring StockIcon(SHSTOCKICONID id)
{
    SHSTOCKICONINFO si = {sizeof(si)};
    HRESULT hr = SHGetStockIconInfo(id, SHGSI_SYSICONINDEX | SHGSI_ICONLOCATION, &si);
    return F(L"hr=0x%08X sysIndex=%d loc='%s',%d", hr, si.iSysImageIndex, si.szPath, si.iIcon);
}

static void Info(std::wstring drv)
{
    std::wstring root = drv + L"\\";
    int idx = towupper(drv[0]) - L'A';
    static std::wstring remote;
    remote.clear();
    Out(L"---- info " + drv + L" ----");
    Timed(L"GetLogicalDrives bit", [=](std::wstring& r) {
        DWORD m = GetLogicalDrives();
        r = F(L"%d (mask 0x%08X)", (m >> idx) & 1, m);
    });
    Timed(L"GetDriveTypeW", [=](std::wstring& r) {
        UINT t = GetDriveTypeW(root.c_str());
        r = F(L"%u", t);
    });
    Timed(L"WNetGetConnectionW", [=](std::wstring& r) {
        wchar_t b[1024] = L"";
        DWORD n = 1024;
        DWORD e = WNetGetConnectionW(drv.c_str(), b, &n);
        r = F(L"ret=%u remote='%s'", e, b);
        remote = b;
    });
    Timed(L"WNetGetConnection3W DISCONNECTED", [=](std::wstring& r) {
        WNGC_CONNECTION_STATE st = {0xFFFFFFFF};
        DWORD n = sizeof st;
        DWORD e = WNetGetConnection3W(drv.c_str(), nullptr, WNGC_INFOLEVEL_DISCONNECTED, &st, &n);
        r = F(L"ret=%u state=%u (0=connected 1=disconnected)", e, st.dwState);
    });
    Timed(L"shell32 IsNetDrive", [=](std::wstring& r) {
        int v = IsNetDrive(idx);
        r = F(L"%d (0=no 1=connected 2=disconnected)", v);
    });
    Timed(L"WNetGetUniversalNameW UNIVERSAL", [=](std::wstring& r) {
        alignas(8) BYTE buf[4096];
        DWORD n = sizeof buf;
        DWORD e = WNetGetUniversalNameW(root.c_str(), UNIVERSAL_NAME_INFO_LEVEL, buf, &n);
        r = F(L"ret=%u", e);
        if (!e)
            r += F(L" universal='%s'", ((UNIVERSAL_NAME_INFOW*)buf)->lpUniversalName);
    });
    Timed(L"WNetGetUniversalNameW REMOTE", [=](std::wstring& r) {
        alignas(8) BYTE buf[4096];
        DWORD n = sizeof buf;
        DWORD e = WNetGetUniversalNameW(root.c_str(), REMOTE_NAME_INFO_LEVEL, buf, &n);
        r = F(L"ret=%u", e);
        if (!e)
        {
            auto* p = (REMOTE_NAME_INFOW*)buf;
            r += F(L" universal='%s' connection='%s' remaining='%s'", p->lpUniversalName ? p->lpUniversalName : L"(null)",
                   p->lpConnectionName ? p->lpConnectionName : L"(null)", p->lpRemainingPath ? p->lpRemainingPath : L"(null)");
        }
    });
    if (!remote.empty())
    {
        std::wstring rem = remote;
        Timed(L"WNetGetResourceInformationW", [=](std::wstring& r) {
            NETRESOURCEW nr = {};
            nr.dwType = RESOURCETYPE_DISK;
            nr.lpRemoteName = (LPWSTR)rem.c_str();
            alignas(8) BYTE buf[8192];
            DWORD n = sizeof buf;
            LPWSTR sys = nullptr;
            DWORD e = WNetGetResourceInformationW(&nr, buf, &n, &sys);
            r = F(L"ret=%u", e);
            if (!e)
            {
                auto* p = (NETRESOURCEW*)buf;
                r += F(L" scope=%u type=%u displayType=%u usage=0x%X provider='%s' remote='%s' system='%s'", p->dwScope,
                       p->dwType, p->dwDisplayType, p->dwUsage, p->lpProvider ? p->lpProvider : L"",
                       p->lpRemoteName ? p->lpRemoteName : L"", sys ? sys : L"(null)");
            }
        });
    }
    Timed(L"GetVolumeInformationW", [=](std::wstring& r) {
        wchar_t label[MAX_PATH + 1] = L"", fs[MAX_PATH + 1] = L"";
        DWORD serial = 0, maxc = 0, flags = 0;
        BOOL ok = GetVolumeInformationW(root.c_str(), label, MAX_PATH + 1, &serial, &maxc, &flags, fs, MAX_PATH + 1);
        r = ok ? F(L"ok label='%s' serial=%08X fs='%s' flags=0x%X", label, serial, fs, flags) : F(L"FAILED err=%u", GetLastError());
    });
    Timed(L"GetFileAttributesW(root)", [=](std::wstring& r) {
        DWORD a = GetFileAttributesW(root.c_str());
        r = a == INVALID_FILE_ATTRIBUTES ? F(L"INVALID err=%u", GetLastError()) : F(L"0x%X", a);
    });
    Timed(L"SHGetFileInfoW DISPLAYNAME", [=](std::wstring& r) {
        SHFILEINFOW fi = {};
        DWORD_PTR ret = SHGetFileInfoW(root.c_str(), 0, &fi, sizeof fi, SHGFI_DISPLAYNAME);
        r = F(L"ret=%Iu name='%s'", ret, fi.szDisplayName);
    });
    Timed(L"SHGetFileInfoW TYPENAME", [=](std::wstring& r) {
        SHFILEINFOW fi = {};
        DWORD_PTR ret = SHGetFileInfoW(root.c_str(), 0, &fi, sizeof fi, SHGFI_TYPENAME);
        r = F(L"ret=%Iu type='%s'", ret, fi.szTypeName);
    });
    Timed(L"SHGetFileInfoW SYSICONINDEX|SMALL", [=](std::wstring& r) {
        SHFILEINFOW fi = {};
        DWORD_PTR ret = SHGetFileInfoW(root.c_str(), 0, &fi, sizeof fi, SHGFI_SYSICONINDEX | SHGFI_SMALLICON);
        r = F(L"ret=%Iu iIcon=%d", ret != 0, fi.iIcon);
    });
    Timed(L"SHGetFileInfoW ICONLOCATION", [=](std::wstring& r) {
        SHFILEINFOW fi = {};
        DWORD_PTR ret = SHGetFileInfoW(root.c_str(), 0, &fi, sizeof fi, SHGFI_ICONLOCATION);
        r = F(L"ret=%Iu loc='%s',%d", ret, fi.szDisplayName, fi.iIcon);
    });
    Timed(L"SHGetFileInfoW ICON|OVERLAYINDEX|SMALL", [=](std::wstring& r) {
        SHFILEINFOW fi = {};
        DWORD_PTR ret = SHGetFileInfoW(root.c_str(), 0, &fi, sizeof fi, SHGFI_ICON | SHGFI_OVERLAYINDEX | SHGFI_SMALLICON);
        r = F(L"ret=%Iu iIcon=0x%08X (index %d overlay %d)", ret, fi.iIcon, fi.iIcon & 0xFFFFFF, (fi.iIcon >> 24) & 0xFF);
        if (fi.hIcon)
            DestroyIcon(fi.hIcon);
    });
    Timed(L"SHGetFileInfoW ATTRIBUTES", [=](std::wstring& r) {
        SHFILEINFOW fi = {};
        fi.dwAttributes = 0xFFFFFFFF;
        DWORD_PTR ret = SHGetFileInfoW(root.c_str(), 0, &fi, sizeof fi, SHGFI_ATTRIBUTES);
        r = F(L"ret=%Iu attrs=0x%08X ghosted=%d", ret, fi.dwAttributes, (fi.dwAttributes & SFGAO_GHOSTED) != 0);
    });
    Timed(L"IShellItem display names", [=](std::wstring& r) {
        IShellItem* si = nullptr;
        HRESULT hr = SHCreateItemFromParsingName(root.c_str(), nullptr, IID_PPV_ARGS(&si));
        r = F(L"create hr=0x%08X", hr);
        if (FAILED(hr))
            return;
        SIGDN kinds[] = {SIGDN_NORMALDISPLAY, SIGDN_PARENTRELATIVEEDITING, SIGDN_PARENTRELATIVE, SIGDN_PARENTRELATIVEPARSING,
                         SIGDN_DESKTOPABSOLUTEEDITING};
        const wchar_t* names[] = {L"NORMALDISPLAY", L"PARENTRELATIVEEDITING", L"PARENTRELATIVE", L"PARENTRELATIVEPARSING",
                                  L"DESKTOPABSOLUTEEDITING"};
        for (int i = 0; i < 5; i++)
        {
            PWSTR s = nullptr;
            hr = si->GetDisplayName(kinds[i], &s);
            r += F(L" | %s='%s'", names[i], SUCCEEDED(hr) ? s : F(L"hr=0x%08X", hr).c_str());
            CoTaskMemFree(s);
        }
        SFGAOF a = 0;
        si->GetAttributes(0xFFFFFFFF, &a);
        r += F(L" | attrs=0x%08X", a);
        si->Release();
    });
    Timed(L"IExtractIconW GetIconLocation", [=](std::wstring& r) {
        PIDLIST_ABSOLUTE pidl = nullptr;
        HRESULT hr = SHParseDisplayName(root.c_str(), nullptr, &pidl, 0, nullptr);
        if (FAILED(hr))
        {
            r = F(L"parse hr=0x%08X", hr);
            return;
        }
        IShellFolder* psf = nullptr;
        PCUITEMID_CHILD child = nullptr;
        hr = SHBindToParent(pidl, IID_PPV_ARGS(&psf), &child);
        if (SUCCEEDED(hr))
        {
            IExtractIconW* ei = nullptr;
            hr = psf->GetUIObjectOf(nullptr, 1, &child, IID_IExtractIconW, nullptr, (void**)&ei);
            if (SUCCEEDED(hr))
            {
                wchar_t file[MAX_PATH] = L"";
                int index = 0;
                UINT flags = 0;
                hr = ei->GetIconLocation(GIL_FORSHELL, file, MAX_PATH, &index, &flags);
                r = F(L"hr=0x%08X loc='%s',%d flags=0x%X", hr, file, index, flags);
                ei->Release();
            }
            else
                r = F(L"GetUIObjectOf hr=0x%08X", hr);
            IShellIconOverlay* ov = nullptr;
            if (SUCCEEDED(psf->QueryInterface(IID_PPV_ARGS(&ov))))
            {
                int oi = -1;
                HRESULT h2 = ov->GetOverlayIndex(child, &oi);
                r += F(L" | overlay hr=0x%08X index=%d", h2, oi);
                ov->Release();
            }
            psf->Release();
        }
        else
            r = F(L"bind hr=0x%08X", hr);
        CoTaskMemFree(pidl);
    });
}

static void Enum()
{
    DWORD scopes[] = {RESOURCE_CONNECTED, RESOURCE_REMEMBERED};
    const wchar_t* sn[] = {L"CONNECTED", L"REMEMBERED"};
    for (int s = 0; s < 2; s++)
    {
        HANDLE h;
        double t0 = NowMs();
        DWORD e = WNetOpenEnumW(scopes[s], RESOURCETYPE_DISK, 0, nullptr, &h);
        if (e)
        {
            Out(F(L"enum %s open ret=%u", sn[s], e));
            continue;
        }
        int cnt = 0;
        for (;;)
        {
            alignas(8) BYTE buf[16384];
            DWORD c = (DWORD)-1, n = sizeof buf;
            e = WNetEnumResourceW(h, &c, buf, &n);
            if (e != NO_ERROR)
                break;
            for (DWORD i = 0; i < c; i++)
            {
                auto* p = ((NETRESOURCEW*)buf) + i;
                Out(F(L"enum %s: local='%s' remote='%s' provider='%s' comment='%s' scope=%u displayType=%u usage=0x%X",
                      sn[s], p->lpLocalName ? p->lpLocalName : L"", p->lpRemoteName ? p->lpRemoteName : L"",
                      p->lpProvider ? p->lpProvider : L"", p->lpComment ? p->lpComment : L"", p->dwScope, p->dwDisplayType,
                      p->dwUsage));
                cnt++;
            }
        }
        WNetCloseEnum(h);
        Out(F(L"enum %s: %d entries, last ret=%u [%.1f ms]", sn[s], cnt, e, NowMs() - t0));
    }
}

static void Rename(const std::wstring& drv, const std::wstring& name)
{
    std::wstring root = drv + L"\\";
    Timed(L"SetNameOf", [=](std::wstring& r) {
        PIDLIST_ABSOLUTE pidl = nullptr;
        HRESULT hr = SHParseDisplayName(root.c_str(), nullptr, &pidl, 0, nullptr);
        if (FAILED(hr))
        {
            r = F(L"parse hr=0x%08X", hr);
            return;
        }
        IShellFolder* psf = nullptr;
        PCUITEMID_CHILD child = nullptr;
        hr = SHBindToParent(pidl, IID_PPV_ARGS(&psf), &child);
        if (SUCCEEDED(hr))
        {
            PITEMID_CHILD np = nullptr;
            hr = psf->SetNameOf(nullptr, child, name.c_str(), SHGDN_NORMAL, &np);
            r = F(L"SetNameOf('%s') hr=0x%08X", name.c_str(), hr);
            if (np)
                CoTaskMemFree(np);
            psf->Release();
        }
        else
            r = F(L"bind hr=0x%08X", hr);
        CoTaskMemFree(pidl);
    });
}

int wmain(int argc, wchar_t** argv)
{
    wchar_t logPath[MAX_PATH];
    GetModuleFileNameW(nullptr, logPath, MAX_PATH);
    PathRemoveFileSpecW(logPath);
    PathAppendW(logPath, L"measure.log");
    _wfopen_s(&g_log, logPath, L"ab");
    CoInitializeEx(0, COINIT_APARTMENTTHREADED);
    if (argc < 2)
        return 1;
    std::wstring cmd = argv[1];
    std::wstring line = L"### " + cmd;
    for (int i = 2; i < argc; i++)
        line += L" " + std::wstring(argv[i]);
    Out(line);
    if (cmd == L"info" && argc >= 3)
    {
        if (argc >= 4)
            g_timeout = _wtoi(argv[3]);
        Info(argv[2]);
    }
    else if (cmd == L"light" && argc >= 3)
    {
        std::wstring drv = argv[2];
        int idx = towupper(drv[0]) - L'A';
        double t0 = NowMs();
        DWORD m = GetLogicalDrives();
        wchar_t b[1024] = L"";
        DWORD n = 1024;
        DWORD e = WNetGetConnectionW(drv.c_str(), b, &n);
        WNGC_CONNECTION_STATE st = {0xFFFFFFFF};
        DWORD sn = sizeof st;
        DWORD e3 = WNetGetConnection3W(drv.c_str(), nullptr, WNGC_INFOLEVEL_DISCONNECTED, &st, &sn);
        int nd = IsNetDrive(idx);
        Out(F(L"light %s: bit=%d WNetGetConnection=%u WNetGetConnection3=%u/state=%u IsNetDrive=%d [%.1f ms]", drv.c_str(),
              (m >> idx) & 1, e, e3, st.dwState, nd, NowMs() - t0));
    }
    else if (cmd == L"enum")
        Enum();
    else if (cmd == L"stock")
    {
        Out(L"SIID_DRIVENET         " + StockIcon(SIID_DRIVENET));
        Out(L"SIID_DRIVENETDISABLED " + StockIcon(SIID_DRIVENETDISABLED));
        Out(L"SIID_DRIVEFIXED       " + StockIcon(SIID_DRIVEFIXED));
    }
    else if (cmd == L"map" && argc >= 5)
    {
        std::wstring drv = argv[2], rem = argv[3];
        DWORD flags = wcstoul(argv[4], nullptr, 16);
        Timed(L"WNetAddConnection2W", [=](std::wstring& r) {
            NETRESOURCEW nr = {};
            nr.dwType = RESOURCETYPE_DISK;
            nr.lpLocalName = (LPWSTR)drv.c_str();
            nr.lpRemoteName = (LPWSTR)rem.c_str();
            DWORD e = WNetAddConnection2W(&nr, nullptr, nullptr, flags);
            r = F(L"flags=0x%X ret=%u", flags, e);
        });
    }
    else if (cmd == L"unmap" && argc >= 5)
    {
        std::wstring drv = argv[2];
        DWORD flags = wcstoul(argv[3], nullptr, 16);
        BOOL force = _wtoi(argv[4]);
        Timed(L"WNetCancelConnection2W", [=](std::wstring& r) {
            DWORD e = WNetCancelConnection2W(drv.c_str(), flags, force);
            r = F(L"flags=0x%X force=%d ret=%u", flags, force, e);
        });
    }
    else if (cmd == L"restore1" && argc >= 3)
    {
        std::wstring drv = argv[2];
        Timed(L"WNetRestoreSingleConnectionW(noUI)", [=](std::wstring& r) {
            typedef DWORD(WINAPI * P)(HWND, LPCWSTR, BOOL);
            P p = (P)GetProcAddress(LoadLibraryW(L"mpr.dll"), "WNetRestoreSingleConnectionW");
            if (!p)
            {
                r = L"not exported";
                return;
            }
            DWORD e = p(nullptr, drv.c_str(), FALSE);
            r = F(L"ret=%u", e);
        });
    }
    else if (cmd == L"restore2" && argc >= 4)
    {
        std::wstring drv = argv[2];
        DWORD flags = wcstoul(argv[3], nullptr, 16);
        Timed(L"WNetRestoreConnection2W", [=](std::wstring& r) {
            typedef DWORD(WINAPI * P)(HWND, LPCWSTR, DWORD, BOOL*);
            P p = (P)GetProcAddress(LoadLibraryW(L"mpr.dll"), "WNetRestoreConnection2W");
            if (!p)
            {
                r = L"not exported";
                return;
            }
            BOOL failed = -1;
            DWORD e = p(nullptr, drv.c_str(), flags, &failed);
            r = F(L"flags=0x%X ret=%u reconnectFailed=%d", flags, e, failed);
        });
    }
    else if (cmd == L"rename" && argc >= 4)
        Rename(argv[2], argv[3]);
    else
        Out(L"bad args");
    fflush(stdout);
    // abandoned threads may still block: exit hard
    if (g_log)
        fclose(g_log);
    TerminateProcess(GetCurrentProcess(), 0);
    return 0;
}
