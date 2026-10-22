// feature 305 probe helper: writes a shortcut (.lnk) whose item list names <base>\<part1>\<part2>...
// - built folder by folder (IShellLinkW::SetPath and WScript.Shell refuse targets of MAX_PATH
// units or more, SHParseDisplayName gives the 8.3 form on a volume with short names).
// Usage: mklnk305.exe <lnk file> <base folder> <part> [<part> ...]   (every folder must exist)
// Build: cl /nologo /EHsc /std:c++latest /utf-8 mklnk305.cpp ole32.lib shell32.lib
#include <windows.h>
#include <shlobj.h>
#include <stdio.h>

int wmain(int argc, WCHAR** argv)
{
    if (argc < 4)
    {
        fwprintf(stderr, L"usage: mklnk305 <lnk> <base> <part> [<part> ...]\n");
        return 2;
    }
    if (FAILED(CoInitializeEx(NULL, COINIT_APARTMENTTHREADED)))
        return 3;
    PIDLIST_ABSOLUTE abs = NULL;
    if (FAILED(SHParseDisplayName(argv[2], NULL, &abs, 0, NULL)) || abs == NULL)
    {
        fwprintf(stderr, L"base not parsed\n");
        return 4;
    }
    IShellFolder* desk = NULL;
    IShellFolder* cur = NULL;
    if (SUCCEEDED(SHGetDesktopFolder(&desk)))
    {
        desk->BindToObject(abs, NULL, IID_IShellFolder, (void**)&cur);
        desk->Release();
    }
    for (int i = 3; i < argc; i++)
    {
        PIDLIST_RELATIVE rel = NULL;
        if (cur == NULL || FAILED(cur->ParseDisplayName(NULL, NULL, argv[i], NULL, &rel, NULL)))
        {
            fwprintf(stderr, L"part %d not parsed\n", i - 2);
            return 5;
        }
        PIDLIST_ABSOLUTE next = ILCombine(abs, rel);
        IShellFolder* sub = NULL;
        if (i + 1 < argc)
            cur->BindToObject(rel, NULL, IID_IShellFolder, (void**)&sub);
        CoTaskMemFree(rel);
        CoTaskMemFree(abs);
        cur->Release();
        abs = next;
        cur = sub;
        if (abs == NULL)
            return 6;
    }
    if (cur != NULL)
        cur->Release();
    int ret = 7;
    IShellLinkW* link = NULL;
    if (CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link) == S_OK)
    {
        IPersistFile* file = NULL;
        if (link->SetIDList(abs) == S_OK && link->QueryInterface(IID_IPersistFile, (LPVOID*)&file) == S_OK)
        {
            if (file->Save(argv[1], TRUE) == S_OK)
                ret = 0;
            file->Release();
        }
        link->Release();
    }
    CoTaskMemFree(abs);
    CoUninitialize();
    return ret;
}
