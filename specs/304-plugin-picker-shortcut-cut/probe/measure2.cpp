// measurement 2: which ways write a target.lnk with a target of 260+ units, and what GetPath reads back
#include <windows.h>
#include <shlobj.h>
#include <stdio.h>
#include <string>
#include "splfiledlg.h"

static std::wstring L4(const std::wstring& p) { return p.length() >= 200 ? L"\\\\?\\" + p : p; }

static const char* ini = "[.ShellClassInfo]\r\nCLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}\r\nFlags=2\r\n";

static void Try(const std::wstring& sc, const std::wstring& tgt, int how)
{
    CreateDirectoryW(sc.c_str(), NULL);
    HANDLE h = CreateFileW((sc + L"\\desktop.ini").c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
    DWORD wr;
    WriteFile(h, ini, (DWORD)strlen(ini), &wr, NULL);
    CloseHandle(h);
    IShellLinkW* link = NULL;
    CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link);
    HRESULT sp = E_FAIL;
    if (how == 0)
        sp = link->SetPath(tgt.c_str());
    else if (how == 1)
        sp = link->SetPath((L"\\\\?\\" + tgt).c_str());
    else
    {
        PIDLIST_ABSOLUTE pidl = NULL;
        sp = SHParseDisplayName((how == 2 ? tgt : L"\\\\?\\" + tgt).c_str(), NULL, &pidl, 0, NULL);
        if (SUCCEEDED(sp))
        {
            sp = link->SetIDList(pidl);
            CoTaskMemFree(pidl);
        }
    }
    IPersistFile* pf = NULL;
    link->QueryInterface(IID_IPersistFile, (LPVOID*)&pf);
    HRESULT sv = SUCCEEDED(sp) ? pf->Save((sc + L"\\target.lnk").c_str(), TRUE) : E_FAIL;
    pf->Release();
    link->Release();
    wprintf(L"how %d units %zu: write 0x%08lx save 0x%08lx", how, tgt.length(), sp, sv);
    if (FAILED(sp) || FAILED(sv))
    {
        wprintf(L"\n");
        return;
    }
    CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link);
    link->QueryInterface(IID_IPersistFile, (LPVOID*)&pf);
    pf->Load((sc + L"\\target.lnk").c_str(), STGM_READ);
    WCHAR shortBuf[MAX_PATH];
    memset(shortBuf, 0, sizeof(shortBuf));
    WIN32_FIND_DATAW data;
    HRESULT g1 = link->GetPath(shortBuf, MAX_PATH, &data, SLGP_UNCPRIORITY);
    static WCHAR big[32768];
    big[0] = 0;
    HRESULT g2 = link->GetPath(big, 32768, NULL, SLGP_UNCPRIORITY);
    wprintf(L" | GetPath(MAX_PATH) 0x%08lx len %zu | GetPath(32768) 0x%08lx len %zu", g1, wcslen(shortBuf), g2, wcslen(big));
    pf->Release();
    link->Release();
    WCHAR* r = SplFileDlgDetail::ResolveNetHoodFolderW(sc.c_str());
    if (r == NULL)
        wprintf(L" | Resolve: NULL\n");
    else
    {
        wprintf(L" | Resolve: len %zu whole %d\n", wcslen(r), _wcsicmp(r, big) == 0 && wcslen(big) > 0);
        free(r);
    }
    DeleteFileW((sc + L"\\target.lnk").c_str());
}

int wmain()
{
    CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    WCHAR tmp[MAX_PATH], tmpL[1024];
    GetTempPathW(MAX_PATH, tmp);
    GetLongPathNameW(tmp, tmpL, 1024);
    std::wstring dir = std::wstring(tmpL) + L"tcm_plugpick2";
    CreateDirectoryW(dir.c_str(), NULL);
    std::wstring sc = dir + L"\\sc";
    int lens[] = {250, 259, 260, 261, 300};
    for (int li = 0; li < 5; li++)
    {
        // an existing local target of exactly lens[li] units
        std::wstring tgt = dir;
        while ((int)tgt.length() + 1 + 50 < lens[li])
        {
            tgt += L"\\" + std::wstring(49, L'a');
            CreateDirectoryW(L4(tgt).c_str(), NULL);
        }
        tgt += L"\\" + std::wstring(lens[li] - tgt.length() - 1, L'b');
        CreateDirectoryW(L4(tgt).c_str(), NULL);
        for (int how = 0; how < 4; how++)
            Try(sc, tgt, how);
        // a UNC target (a network location points at a share), not existing
        std::wstring unc = L"\\\\nosuchsrv\\share\\" + std::wstring(lens[li] - 18, L'u');
        for (int how = 0; how < 4; how++)
            Try(sc, unc, how);
    }
    return 0;
}
