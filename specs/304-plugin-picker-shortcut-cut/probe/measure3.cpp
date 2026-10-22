// measurement 3: a target.lnk whose ID list names a long-name target of 260+ units (built folder by
// folder, so no 8.3 fallback), then GetPath with MAX_PATH and 32768 units and ResolveNetHoodFolderW
#include <windows.h>
#include <shlobj.h>
#include <stdio.h>
#include <string>
#include <vector>
#include "splfiledlg.h"

static std::wstring L4(const std::wstring& p) { return p.length() >= 200 ? L"\\\\?\\" + p : p; }

static const char* ini = "[.ShellClassInfo]\r\nCLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}\r\nFlags=2\r\n";

// the absolute ID list of 'base' (short enough to parse) + the components one by one
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
        HRESULT hr = cur->ParseDisplayName(NULL, NULL, (LPWSTR)parts[i].c_str(), NULL, &rel, NULL);
        if (FAILED(hr))
        {
            wprintf(L"  parse part %zu failed 0x%08lx\n", i, hr);
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

int wmain(int argc, WCHAR** argv)
{
    CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    WCHAR tmp[MAX_PATH], tmpL[1024];
    GetTempPathW(MAX_PATH, tmp);
    GetLongPathNameW(tmp, tmpL, 1024);
    std::wstring dir = argc > 1 ? std::wstring(argv[1]) : std::wstring(tmpL) + L"tcm_plugpick3";
    CreateDirectoryW(dir.c_str(), NULL);
    std::wstring sc = dir + L"\\sc";
    CreateDirectoryW(sc.c_str(), NULL);
    HANDLE h = CreateFileW((sc + L"\\desktop.ini").c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
    DWORD wr;
    WriteFile(h, ini, (DWORD)strlen(ini), &wr, NULL);
    CloseHandle(h);
    int lens[] = {259, 260, 261, 300, 400};
    for (int li = 0; li < 5; li++)
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
            continue;
        WCHAR* disp = NULL;
        SHGetNameFromIDList(pidl, SIGDN_DESKTOPABSOLUTEPARSING, &disp);
        wprintf(L"units %d: pidl name len %zu equal %d\n", lens[li], disp ? wcslen(disp) : 0, disp && _wcsicmp(disp, tgt.c_str()) == 0);
        CoTaskMemFree(disp);
        IShellLinkW* link = NULL;
        CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link);
        HRESULT sp = link->SetIDList(pidl);
        CoTaskMemFree(pidl);
        IPersistFile* pf = NULL;
        link->QueryInterface(IID_IPersistFile, (LPVOID*)&pf);
        HRESULT sv = pf->Save((sc + L"\\target.lnk").c_str(), TRUE);
        pf->Release();
        link->Release();
        wprintf(L"  SetIDList 0x%08lx Save 0x%08lx\n", sp, sv);
        CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link);
        link->QueryInterface(IID_IPersistFile, (LPVOID*)&pf);
        HRESULT ld = pf->Load((sc + L"\\target.lnk").c_str(), STGM_READ);
        WCHAR shortBuf[MAX_PATH];
        wmemset(shortBuf, L'X', MAX_PATH);
        WIN32_FIND_DATAW data;
        HRESULT g1 = link->GetPath(shortBuf, MAX_PATH, &data, SLGP_UNCPRIORITY);
        size_t l1 = wcsnlen(shortBuf, MAX_PATH);
        static WCHAR big[32768];
        big[0] = 0;
        HRESULT g2 = link->GetPath(big, 32768, NULL, SLGP_UNCPRIORITY);
        wprintf(L"  Load 0x%08lx | GetPath(MAX_PATH) 0x%08lx len %zu prefix-of-target %d | GetPath(32768) 0x%08lx len %zu whole %d\n",
                ld, g1, l1, l1 < MAX_PATH && l1 > 0 && _wcsnicmp(shortBuf, tgt.c_str(), l1) == 0, g2, wcslen(big),
                _wcsicmp(big, tgt.c_str()) == 0);
        {
            PIDLIST_ABSOLUTE lp = NULL;
            WCHAR* fsName = NULL;
            HRESULT gi = link->GetIDList(&lp);
            HRESULT gn = lp != NULL ? SHGetNameFromIDList(lp, SIGDN_FILESYSPATH, &fsName) : E_FAIL;
            wprintf(L"  GetIDList 0x%08lx SIGDN_FILESYSPATH 0x%08lx len %zu: %s\n", gi, gn, fsName ? wcslen(fsName) : 0, fsName ? fsName : L"-");
            CoTaskMemFree(fsName);
            CoTaskMemFree(lp);
        }
        pf->Release();
        link->Release();
        WCHAR* r = SplFileDlgDetail::ResolveNetHoodFolderW(sc.c_str());
        if (r == NULL)
            wprintf(L"  ResolveNetHoodFolderW: NULL (the shortcut folder itself would be the result)\n");
        else
        {
            DWORD a = GetFileAttributesW(L4(r).c_str());
            wprintf(L"  ResolveNetHoodFolderW: len %zu whole %d exists %d\n  %s\n", wcslen(r), _wcsicmp(r, tgt.c_str()) == 0,
                    a != INVALID_FILE_ATTRIBUTES, r);
            free(r);
        }
    }
    return 0;
}
