// measurement for backlog item plug-in-folder-picker-may-cut-a-folder-shortcut-target-of
#include <windows.h>
#include <shlobj.h>
#include <stdio.h>
#include <string>
#include "splfiledlg.h"

static std::wstring L4(const std::wstring& p) { return p.length() >= 200 ? L"\\\\?\\" + p : p; }

int wmain()
{
    CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    WCHAR tmp[MAX_PATH], tmpL[1024];
    GetTempPathW(MAX_PATH, tmp);
    GetLongPathNameW(tmp, tmpL, 1024);
    std::wstring dir = std::wstring(tmpL) + L"tcm_plugpick";
    CreateDirectoryW(dir.c_str(), NULL);
    // target of ~300 units: nested folders of 100 'a'
    std::wstring tgt = dir;
    while (tgt.length() < 300)
    {
        tgt += L"\\" + std::wstring(60, L'a');
        CreateDirectoryW(L4(tgt).c_str(), NULL);
    }
    wprintf(L"target units: %zu\n", tgt.length());
    std::wstring sc = dir + L"\\sc";
    CreateDirectoryW(sc.c_str(), NULL);
    const char* ini = "[.ShellClassInfo]\r\nCLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}\r\nFlags=2\r\n";
    HANDLE h = CreateFileW((sc + L"\\desktop.ini").c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
    DWORD wr;
    WriteFile(h, ini, (DWORD)strlen(ini), &wr, NULL);
    CloseHandle(h);
    IShellLinkW* link = NULL;
    CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link);
    HRESULT sp = link->SetPath(tgt.c_str());
    IPersistFile* pf = NULL;
    link->QueryInterface(IID_IPersistFile, (LPVOID*)&pf);
    HRESULT sv = pf->Save((sc + L"\\target.lnk").c_str(), TRUE);
    pf->Release();
    link->Release();
    wprintf(L"SetPath 0x%08lx Save 0x%08lx\n", sp, sv);

    // direct read: MAX_PATH buffer vs 32768
    CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link);
    link->QueryInterface(IID_IPersistFile, (LPVOID*)&pf);
    HRESULT ld = pf->Load((sc + L"\\target.lnk").c_str(), STGM_READ);
    WCHAR shortBuf[MAX_PATH];
    memset(shortBuf, 0, sizeof(shortBuf));
    WIN32_FIND_DATAW data;
    HRESULT g1 = link->GetPath(shortBuf, MAX_PATH, &data, SLGP_UNCPRIORITY);
    static WCHAR big[32768];
    HRESULT g2 = link->GetPath(big, 32768, NULL, SLGP_UNCPRIORITY);
    wprintf(L"Load 0x%08lx\nGetPath(MAX_PATH) 0x%08lx len %zu\nGetPath(32768) 0x%08lx len %zu equal-to-target %d\n", ld, g1,
            wcslen(shortBuf), g2, wcslen(big), _wcsicmp(big, tgt.c_str()) == 0);
    wprintf(L"shortBuf is prefix of target: %d\n", _wcsnicmp(shortBuf, tgt.c_str(), wcslen(shortBuf)) == 0);
    pf->Release();
    link->Release();

    WCHAR* r = SplFileDlgDetail::ResolveNetHoodFolderW(sc.c_str());
    if (r == NULL)
        wprintf(L"ResolveNetHoodFolderW: NULL\n");
    else
    {
        DWORD a = GetFileAttributesW(L4(r).c_str());
        wprintf(L"ResolveNetHoodFolderW: len %zu equal-to-target %d exists %d\n%s\n", wcslen(r), _wcsicmp(r, tgt.c_str()) == 0,
                a != INVALID_FILE_ATTRIBUTES, r);
        free(r);
    }
    return 0;
}
