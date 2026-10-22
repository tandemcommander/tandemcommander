// measurement: a plain shortcut (.lnk) whose item list names a target of 259..400 units (built
// folder by folder, so no 8.3 fallback), read through the core's SalShellLinkGetPathU8 (both flags
// the callers use) and a folder shortcut through SalFolderShortcutTargetU8
#include <windows.h>
#include <shlobj.h>
#include <stdio.h>
#include <string>
#include <vector>
#include "salunicode.h"
#include "salpath.h"
#include "salshelllink.h"

static std::wstring L4(const std::wstring& p) { return p.length() >= 200 ? L"\\\\?\\" + p : p; }

// minimal stand-ins of the core's conversions (salunicode.cpp / salpath.cpp need the core's precomp.h)
int SalWToU8(const WCHAR* src, int srcLen, char* buf, int bufSize)
{
    return WideCharToMultiByte(CP_UTF8, 0, src, srcLen, buf, bufSize, NULL, NULL);
}
WCHAR* SalU8ToWAlloc(const char* src, int srcLen)
{
    int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, src, srcLen, NULL, 0);
    WCHAR* w = n > 0 ? (WCHAR*)malloc((n + 1) * sizeof(WCHAR)) : NULL;
    if (w != NULL)
    {
        MultiByteToWideChar(CP_UTF8, 0, src, srcLen, w, n);
        w[n] = 0;
    }
    return w;
}
char* SalWToU8Alloc(const WCHAR* src, int srcLen)
{
    int n = WideCharToMultiByte(CP_UTF8, 0, src, srcLen, NULL, 0, NULL, NULL);
    char* u = n > 0 ? (char*)malloc(n + 1) : NULL;
    if (u != NULL)
    {
        WideCharToMultiByte(CP_UTF8, 0, src, srcLen, u, n, NULL, NULL);
        u[n] = 0;
    }
    return u;
}
WCHAR* SalPathToWExtAlloc(const char* u8path)
{
    WCHAR* w = SalU8ToWAlloc(u8path, -1);
    if (w == NULL)
        return NULL;
    std::wstring s = L4(w);
    free(w);
    WCHAR* r = (WCHAR*)malloc((s.length() + 1) * sizeof(WCHAR));
    memcpy(r, s.c_str(), (s.length() + 1) * sizeof(WCHAR));
    return r;
}

static const char* ini = "[.ShellClassInfo]\r\nCLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}\r\nFlags=2\r\n";

static PIDLIST_ABSOLUTE BuildPidl(const std::wstring& base, const std::vector<std::wstring>& parts)
{
    PIDLIST_ABSOLUTE abs = NULL;
    if (FAILED(SHParseDisplayName(base.c_str(), NULL, &abs, 0, NULL)))
        return NULL;
    IShellFolder* desk = NULL;
    SHGetDesktopFolder(&desk);
    IShellFolder* cur = NULL;
    desk->BindToObject(abs, NULL, IID_IShellFolder, (void**)&cur);
    desk->Release();
    for (size_t i = 0; i < parts.size() && cur != NULL; i++)
    {
        PIDLIST_RELATIVE rel = NULL;
        if (FAILED(cur->ParseDisplayName(NULL, NULL, (LPWSTR)parts[i].c_str(), NULL, &rel, NULL)))
        {
            cur->Release();
            CoTaskMemFree(abs);
            return NULL;
        }
        PIDLIST_ABSOLUTE n = ILCombine(abs, rel);
        IShellFolder* next = NULL;
        if (i + 1 < parts.size())
            cur->BindToObject(rel, NULL, IID_IShellFolder, (void**)&next);
        CoTaskMemFree(rel);
        CoTaskMemFree(abs);
        abs = n;
        cur->Release();
        cur = next;
    }
    if (cur != NULL)
        cur->Release();
    return abs;
}

static std::wstring W(const char* u8)
{
    WCHAR* w = SalU8ToWAlloc(u8);
    std::wstring s = w != NULL ? w : L"";
    free(w);
    return s;
}

int wmain(int argc, WCHAR** argv)
{
    CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    if (argc < 2)
        return 2;
    std::wstring dir = argv[1];
    CreateDirectoryW(dir.c_str(), NULL);
    std::wstring sc = dir + L"\\sc"; // a folder shortcut
    CreateDirectoryW(sc.c_str(), NULL);
    HANDLE h = CreateFileW((sc + L"\\desktop.ini").c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
    DWORD wr;
    WriteFile(h, ini, (DWORD)strlen(ini), &wr, NULL);
    CloseHandle(h);
    int lens[] = {250, 259, 260, 261, 300, 400};
    char* out = (char*)malloc(SAL_MAX_PATH_UTF8);
    for (int li = 0; li < _countof(lens); li++)
    {
        std::wstring tgt = dir;
        std::vector<std::wstring> parts;
        while ((int)tgt.length() + 1 + 50 < lens[li])
        {
            parts.push_back(std::wstring(49, (WCHAR)(L'a' + li)));
            tgt += L"\\" + parts.back();
            CreateDirectoryW(L4(tgt).c_str(), NULL);
        }
        parts.push_back(std::wstring(lens[li] - tgt.length() - 1, L'z'));
        tgt += L"\\" + parts.back();
        CreateDirectoryW(L4(tgt).c_str(), NULL);
        PIDLIST_ABSOLUTE pidl = BuildPidl(dir, parts);
        if (pidl == NULL)
        {
            wprintf(L"units %d: item list failed\n", lens[li]);
            continue;
        }
        std::wstring lnk = dir + L"\\t" + std::to_wstring(lens[li]) + L".lnk";
        IShellLinkW* link = NULL;
        CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link);
        link->SetIDList(pidl);
        CoTaskMemFree(pidl);
        IPersistFile* pf = NULL;
        link->QueryInterface(IID_IPersistFile, (LPVOID*)&pf);
        HRESULT sv1 = pf->Save(lnk.c_str(), TRUE);
        HRESULT sv2 = pf->Save((sc + L"\\target.lnk").c_str(), FALSE);
        pf->Release();
        link->Release();
        CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link);
        link->QueryInterface(IID_IPersistFile, (LPVOID*)&pf);
        HRESULT ld = pf->Load(lnk.c_str(), STGM_READ);
        HRESULT r1 = SalShellLinkGetPathU8(link, out, SAL_MAX_PATH_UTF8, SLGP_UNCPRIORITY);
        std::wstring a1 = W(out);
        DWORD at1 = a1.empty() ? INVALID_FILE_ATTRIBUTES : GetFileAttributesW(L4(a1).c_str());
        HRESULT r2 = SalShellLinkGetPathU8(link, out, SAL_MAX_PATH_UTF8, SLGP_RAWPATH);
        std::wstring a2 = W(out);
        wprintf(L"units %d (save 0x%08lx/0x%08lx load 0x%08lx):\n  UNCPRIORITY 0x%08lx len %zu whole %d exists %d\n  RAWPATH 0x%08lx len %zu whole %d\n",
                lens[li], sv1, sv2, ld, r1, a1.length(), _wcsicmp(a1.c_str(), tgt.c_str()) == 0 || _wcsicmp(a1.c_str(), L4(tgt).c_str()) == 0,
                at1 != INVALID_FILE_ATTRIBUTES, r2, a2.length(), _wcsicmp(a2.c_str(), tgt.c_str()) == 0 || _wcsicmp(a2.c_str(), L4(tgt).c_str()) == 0);
        wprintf(L"  answer: %s\n", a1.c_str());
        pf->Release();
        link->Release();
        char* scU8 = SalWToU8Alloc(sc.c_str());
        HRESULT r3 = SalFolderShortcutTargetU8(scU8, out, SAL_MAX_PATH_UTF8);
        std::wstring a3 = W(out);
        wprintf(L"  SalFolderShortcutTargetU8 0x%08lx len %zu whole %d\n", r3, a3.length(),
                _wcsicmp(a3.c_str(), tgt.c_str()) == 0 || _wcsicmp(a3.c_str(), L4(tgt).c_str()) == 0);
        free(scU8);
    }
    free(out);
    return 0;
}
