// Feature 116 scratch measurement: what a code-page subclass (winliblt CWindow::AttachToWindow:
// SetWindowLongPtrA + CallWindowProcA) does to an ES_PASSWORD edit's text - typed (WM_CHAR posted
// and dispatched through a W loop and through an A loop), set (WM_SETTEXT W, as winliblt's
// EditLine does) and read (WM_GETTEXT W, as EditLine does; WM_GETTEXT A, as "Show password" does).
// Compared with a subclass that keeps the window's kind (SetWindowLongPtrW, feature 102) and none.
#include <windows.h>
#include <stdio.h>
#include <string>

static WNDPROC g_orig = NULL;
static bool g_ansiSub = false;

static LRESULT CALLBACK SubProc(HWND h, UINT m, WPARAM w, LPARAM l)
{
    return g_ansiSub ? CallWindowProcA(g_orig, h, m, w, l) : CallWindowProcW(g_orig, h, m, w, l);
}

static std::wstring Hex(const wchar_t* s)
{
    std::wstring r;
    wchar_t b[16];
    for (; *s; s++)
    {
        if (*s >= 0x20 && *s < 0x7F) { b[0] = *s; b[1] = 0; }
        else swprintf_s(b, L"<%04X>", (unsigned)*s);
        r += b;
    }
    return r;
}

static void Pump(bool ansiLoop)
{
    MSG msg;
    if (ansiLoop)
    {
        while (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE))
            DispatchMessageA(&msg);
    }
    else
    {
        while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE))
            DispatchMessageW(&msg);
    }
}

// kind: 0 none, 1 code-page subclass (winliblt AttachToWindow), 2 kind-keeping subclass (102)
static HWND Make(HWND parent, int kind)
{
    HWND e = CreateWindowExW(0, L"Edit", L"", WS_CHILD | ES_PASSWORD | ES_AUTOHSCROLL, 0, 0, 200, 20,
                             parent, (HMENU)100, GetModuleHandleW(NULL), NULL);
    if (kind == 1)
    {
        g_ansiSub = true;
        g_orig = (WNDPROC)GetWindowLongPtrA(e, GWLP_WNDPROC);
        SetWindowLongPtrA(e, GWLP_WNDPROC, (LONG_PTR)SubProc);
    }
    else if (kind == 2)
    {
        g_ansiSub = false;
        g_orig = (WNDPROC)GetWindowLongPtrW(e, GWLP_WNDPROC);
        SetWindowLongPtrW(e, GWLP_WNDPROC, (LONG_PTR)SubProc);
    }
    return e;
}

static std::wstring TrueText(HWND e, int kind) // the edit's own text, read without the subclass
{
    if (kind == 1)
        SetWindowLongPtrA(e, GWLP_WNDPROC, (LONG_PTR)g_orig);
    else if (kind == 2)
        SetWindowLongPtrW(e, GWLP_WNDPROC, (LONG_PTR)g_orig);
    wchar_t buf[256] = {0};
    GetWindowTextW(e, buf, 256);
    return buf;
}

int wmain()
{
    HWND top = CreateWindowExW(0, L"Static", L"m116", WS_OVERLAPPED, 0, 0, 300, 100, NULL, NULL,
                               GetModuleHandleW(NULL), NULL);
    printf("ACP %u\n", GetACP());
    const wchar_t* texts[] = {L"heslo-\x0159", L"voil\x00E0", L"\x0416\x0430\x0431\x0430", L"\x65E5\x672C\x8A9E",
                              L"\xD83D\xDCC1", L"lone\xD800x", L"\xFF21\xFF22"};
    const char* kinds[] = {"none", "code-page subclass", "kind-keeping subclass"};
    for (int kind = 0; kind < 3; kind++)
    {
        for (int t = 0; t < (int)(sizeof(texts) / sizeof(texts[0])); t++)
        {
            for (int loop = 0; loop < 2; loop++) // typed through a W loop / an A loop
            {
                HWND e = Make(top, kind);
                for (const wchar_t* p = texts[t]; *p; p++)
                    PostMessageW(e, WM_CHAR, (WPARAM)*p, 1);
                Pump(loop == 1);
                wchar_t viaW[256] = {0};
                GetWindowTextW(e, viaW, 256);
                std::wstring tr = TrueText(e, kind);
                wprintf(L"%-22hs TYPED %hs-loop %-28ls -> edit holds %-28ls read W %ls\n", kinds[kind],
                        loop ? "A" : "W", Hex(texts[t]).c_str(), Hex(tr.c_str()).c_str(), Hex(viaW).c_str());
                DestroyWindow(e);
            }
            HWND e = Make(top, kind);
            SendMessageW(e, WM_SETTEXT, 0, (LPARAM)texts[t]);
            wchar_t viaW[256] = {0};
            GetWindowTextW(e, viaW, 256);
            char viaA[256] = {0};
            GetWindowTextA(e, viaA, 256);
            std::string ha;
            for (char* q = viaA; *q; q++) { char b[8]; sprintf_s(b, "%02X", (unsigned char)*q); ha += b; }
            std::wstring tr = TrueText(e, kind);
            wprintf(L"%-22hs SET          %-28ls -> edit holds %-28ls read W %-28ls read A hex %hs\n", kinds[kind],
                    Hex(texts[t]).c_str(), Hex(tr.c_str()).c_str(), Hex(viaW).c_str(), ha.c_str());
            DestroyWindow(e);
        }
    }
    DestroyWindow(top);
    return 0;
}
