// Review probe for feature 123 (stand-alone, does not touch the product or its registry).
//   r1_probe focus   - does CreateDialog of a HIDDEN modeless dialog whose WM_INITDIALOG returns
//                      TRUE take activation/focus away from the owner?
//   r1_probe static  - does a static with SS_NOTIFY (what CHyperLink sets) send
//                      WM_COMMAND(id, STN_CLICKED) to its parent on WM_LBUTTONDOWN?
//   r1_probe cancel  - WinHttpCloseHandle from another thread during a synchronous
//                      WinHttpSendRequest (connect to a black-hole address) / WinHttpReceiveResponse
//                      (local server that never answers): how fast does the pending call return,
//                      and with which error?
#include <winsock2.h>
#include <windows.h>
#include <winhttp.h>
#include <stdio.h>
#include <string.h>
#pragma comment(lib, "winhttp.lib")
#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "user32.lib")

static int gInitRet = 1;
static int gCmdCount = 0;
static WPARAM gLastCmd = 0;

static INT_PTR CALLBACK DlgProc(HWND h, UINT m, WPARAM w, LPARAM l)
{
    if (m == WM_INITDIALOG)
        return gInitRet;
    return FALSE;
}

static LRESULT CALLBACK OwnerProc(HWND h, UINT m, WPARAM w, LPARAM l)
{
    if (m == WM_COMMAND)
    {
        gCmdCount++;
        gLastCmd = w;
        return 0;
    }
    return DefWindowProcW(h, m, w, l);
}

static HWND MakeOwner()
{
    WNDCLASSW wc = {0};
    wc.lpfnWndProc = OwnerProc;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.lpszClassName = L"R1ProbeOwner";
    RegisterClassW(&wc);
    return CreateWindowExW(0, L"R1ProbeOwner", L"owner", WS_OVERLAPPEDWINDOW | WS_VISIBLE, 50, 50, 400, 300,
                           NULL, NULL, wc.hInstance, NULL);
}

// in-memory DLGTEMPLATE: popup, caption, NOT visible, one default push button with WS_TABSTOP
static HWND MakeHiddenDialog(HWND owner)
{
    static WORD buf[256];
    memset(buf, 0, sizeof(buf));
    DLGTEMPLATE* t = (DLGTEMPLATE*)buf;
    t->style = WS_POPUP | WS_CAPTION | WS_SYSMENU | DS_MODALFRAME;
    t->cdit = 1;
    t->x = 0;
    t->y = 0;
    t->cx = 100;
    t->cy = 50;
    WORD* p = (WORD*)(t + 1);
    *p++ = 0; // menu
    *p++ = 0; // class
    *p++ = 0; // title
    // align to DWORD
    if (((ULONG_PTR)p) & 2)
        p++;
    DLGITEMTEMPLATE* it = (DLGITEMTEMPLATE*)p;
    it->style = WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_DEFPUSHBUTTON;
    it->x = 10;
    it->y = 10;
    it->cx = 50;
    it->cy = 14;
    it->id = IDOK;
    p = (WORD*)(it + 1);
    *p++ = 0xFFFF;
    *p++ = 0x0080; // button
    *p++ = L'O';
    *p++ = L'K';
    *p++ = 0;
    *p++ = 0; // no creation data
    return CreateDialogIndirectParamW(GetModuleHandleW(NULL), t, owner, DlgProc, 0);
}

static void Pump()
{
    MSG msg;
    while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE))
    {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
}

static int ProbeFocus()
{
    for (int ret = 1; ret >= 0; ret--)
    {
        HWND owner = MakeOwner();
        HWND edit = CreateWindowExW(0, L"EDIT", L"", WS_CHILD | WS_VISIBLE, 10, 10, 200, 24, owner, NULL, NULL, NULL);
        SetActiveWindow(owner);
        SetFocus(edit);
        Pump();
        printf("WM_INITDIALOG returns %d\n", ret);
        printf("  before: active==owner %d, focus==edit %d\n", GetActiveWindow() == owner, GetFocus() == edit);
        gInitRet = ret;
        HWND dlg = MakeHiddenDialog(owner);
        Pump();
        printf("  after CreateDialog (hidden): dlg %p visible %d, active==owner %d, active==dlg %d, focus==edit %d, focus in dlg %d\n",
               (void*)dlg, IsWindowVisible(dlg), GetActiveWindow() == owner, GetActiveWindow() == dlg,
               GetFocus() == edit, GetFocus() != NULL && GetParent(GetFocus()) == dlg);
        ShowWindow(dlg, SW_SHOWNOACTIVATE);
        Pump();
        printf("  after SW_SHOWNOACTIVATE: active==owner %d, active==dlg %d, focus==edit %d, focus in dlg %d\n",
               GetActiveWindow() == owner, GetActiveWindow() == dlg, GetFocus() == edit,
               GetFocus() != NULL && GetParent(GetFocus()) == dlg);
        DestroyWindow(dlg);
        DestroyWindow(owner);
        Pump();
    }
    return 0;
}

static int ProbeStatic()
{
    HWND owner = MakeOwner();
    HWND st = CreateWindowExW(0, L"STATIC", L"link", WS_CHILD | WS_VISIBLE | SS_NOTIFY, 10, 10, 300, 20, owner,
                              (HMENU)(INT_PTR)6247, NULL, NULL);
    Pump();
    gCmdCount = 0;
    SendMessageW(st, WM_LBUTTONDOWN, MK_LBUTTON, MAKELPARAM(250, 5));
    printf("after WM_LBUTTONDOWN: WM_COMMAND count %d, id %u, code %u\n", gCmdCount, LOWORD(gLastCmd), HIWORD(gLastCmd));
    SendMessageW(st, WM_LBUTTONUP, 0, MAKELPARAM(250, 5));
    printf("after WM_LBUTTONUP:   WM_COMMAND count %d\n", gCmdCount);
    SendMessageW(st, WM_LBUTTONDBLCLK, MK_LBUTTON, MAKELPARAM(250, 5));
    printf("after WM_LBUTTONDBLCLK: WM_COMMAND count %d, id %u, code %u\n", gCmdCount, LOWORD(gLastCmd), HIWORD(gLastCmd));
    EnableWindow(st, FALSE);
    printf("after EnableWindow(FALSE): WM_COMMAND count %d, id %u, code %u\n", gCmdCount, LOWORD(gLastCmd), HIWORD(gLastCmd));
    DestroyWindow(owner);
    return 0;
}

struct CCancel
{
    HINTERNET Request;
    DWORD DelayMs;
    DWORD ClosedAt;
};

static DWORD WINAPI CancelThread(void* p)
{
    CCancel* c = (CCancel*)p;
    Sleep(c->DelayMs);
    c->ClosedAt = GetTickCount();
    BOOL ok = WinHttpCloseHandle(c->Request);
    printf("  [canceller] WinHttpCloseHandle -> %d (err %lu) took %lu ms\n", ok, ok ? 0 : GetLastError(),
           GetTickCount() - c->ClosedAt);
    return 0;
}

static SOCKET gListen = INVALID_SOCKET;
static DWORD WINAPI SilentServer(void* p)
{
    // accepts connections and never answers
    for (;;)
    {
        SOCKET s = accept(gListen, NULL, NULL);
        if (s == INVALID_SOCKET)
            return 0;
        // keep it open
    }
}

static void CancelCase(const WCHAR* host, INTERNET_PORT port, const char* what)
{
    printf("%s\n", what);
    HINTERNET session = WinHttpOpen(L"r1-probe", WINHTTP_ACCESS_TYPE_NO_PROXY, WINHTTP_NO_PROXY_NAME,
                                    WINHTTP_NO_PROXY_BYPASS, 0);
    WinHttpSetTimeouts(session, 30000, 30000, 30000, 30000); // long: only the cancel may end the call early
    HINTERNET connect = WinHttpConnect(session, host, port, 0);
    HINTERNET request = WinHttpOpenRequest(connect, L"GET", L"/x", NULL, WINHTTP_NO_REFERER,
                                           WINHTTP_DEFAULT_ACCEPT_TYPES, 0);
    CCancel c = {request, 700, 0};
    HANDLE t = CreateThread(NULL, 0, CancelThread, &c, 0, NULL);
    DWORD start = GetTickCount();
    BOOL sent = WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0);
    DWORD err = sent ? 0 : GetLastError();
    DWORD t1 = GetTickCount();
    printf("  WinHttpSendRequest -> %d (err %lu) after %lu ms\n", sent, err, t1 - start);
    if (sent)
    {
        BOOL recv = WinHttpReceiveResponse(request, NULL);
        err = recv ? 0 : GetLastError();
        DWORD t2 = GetTickCount();
        printf("  WinHttpReceiveResponse -> %d (err %lu) after %lu ms from start", recv, err, t2 - start);
        if (c.ClosedAt != 0)
            printf(", %lu ms after the close", t2 - c.ClosedAt);
        printf("\n");
    }
    else if (c.ClosedAt != 0)
        printf("  returned %ld ms after the close\n", (long)(t1 - c.ClosedAt));
    WaitForSingleObject(t, INFINITE);
    CloseHandle(t);
    // what does a further call on the closed handle return?
    DWORD read = 0;
    char b[16];
    BOOL r = WinHttpReadData(request, b, sizeof(b), &read);
    printf("  WinHttpReadData on the closed handle -> %d (err %lu)\n", r, r ? 0 : GetLastError());
    r = WinHttpCloseHandle(request);
    printf("  second WinHttpCloseHandle -> %d (err %lu)\n", r, r ? 0 : GetLastError());
    WinHttpCloseHandle(connect);
    WinHttpCloseHandle(session);
}

static int ProbeCancel()
{
    WSADATA wsa;
    WSAStartup(MAKEWORD(2, 2), &wsa);
    gListen = socket(AF_INET, SOCK_STREAM, 0);
    sockaddr_in a;
    memset(&a, 0, sizeof(a));
    a.sin_family = AF_INET;
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    a.sin_port = 0;
    bind(gListen, (sockaddr*)&a, sizeof(a));
    listen(gListen, 5);
    int len = sizeof(a);
    getsockname(gListen, (sockaddr*)&a, &len);
    INTERNET_PORT port = ntohs(a.sin_port);
    CreateThread(NULL, 0, SilentServer, NULL, 0, NULL);

    CancelCase(L"127.0.0.1", port, "A: server accepts and never answers (close arrives during WinHttpReceiveResponse)");
    CancelCase(L"10.255.255.1", 81, "B: black-hole address (close arrives during the connect inside WinHttpSendRequest)");
    CancelCase(L"r1-probe-no-such-host.invalid", 80, "C: unresolvable name (resolve phase)");
    closesocket(gListen);
    return 0;
}

int main(int argc, char** argv)
{
    if (argc < 2)
        return 1;
    if (strcmp(argv[1], "focus") == 0)
        return ProbeFocus();
    if (strcmp(argv[1], "static") == 0)
        return ProbeStatic();
    if (strcmp(argv[1], "cancel") == 0)
        return ProbeCancel();
    return 1;
}
