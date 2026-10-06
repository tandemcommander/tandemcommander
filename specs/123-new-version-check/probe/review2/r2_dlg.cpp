// Review 2 probe for feature 123 (stand-alone): a modeless dialog shaped like IDD_UPDATENOTICE
// (default button, two buttons, check box, a tab-stop static with SS_NOTIFY as CHyperLink makes it)
// whose WM_INITDIALOG returns FALSE and which is shown with SW_SHOWNOACTIVATE.
//  1. does it take activation/focus when created and shown?
//  2. when it is activated later (click on the caption, Alt+Tab), where does the keyboard focus go?
//  3. what does Enter do then; what does Enter do with the focus on the static; which button looks default?
#include <windows.h>
#include <stdio.h>
#include <string.h>

#ifdef R2_COMCTL6 // the product runs with the comctl32 6 manifest: its buttons are comctl32's, not user32's
#pragma comment(linker, "\"/manifestdependency:type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")
#pragma comment(lib, "comctl32.lib")
#include <commctrl.h>
#endif

#define ID_SKIP 6250
#define ID_CHECK 6249
#define ID_LINK 6247

static int gInitRet = 0;
static WPARAM gLastCmd = 0;
static int gCmdCount = 0;
static int gFocusAtCmd = 0;

static INT_PTR CALLBACK DlgProc(HWND h, UINT m, WPARAM w, LPARAM l)
{
    if (m == WM_INITDIALOG)
        return gInitRet;
    if (m == WM_COMMAND)
    {
        gCmdCount++;
        gLastCmd = w;
        gFocusAtCmd = GetFocus() != NULL ? GetDlgCtrlID(GetFocus()) : -1;
        return TRUE;
    }
    return FALSE;
}

static WORD* AddItem(WORD* p, DWORD style, short x, short y, short cx, short cy, WORD id, WORD cls, const wchar_t* text)
{
    if (((ULONG_PTR)p) & 2)
        p++;
    DLGITEMTEMPLATE* it = (DLGITEMTEMPLATE*)p;
    it->style = style | WS_CHILD | WS_VISIBLE;
    it->dwExtendedStyle = 0;
    it->x = x;
    it->y = y;
    it->cx = cx;
    it->cy = cy;
    it->id = id;
    p = (WORD*)(it + 1);
    *p++ = 0xFFFF;
    *p++ = cls;
    while (*text)
        *p++ = *text++;
    *p++ = 0;
    *p++ = 0;
    return p;
}

static HWND MakeDialog(HWND owner)
{
    static WORD buf[1024];
    memset(buf, 0, sizeof(buf));
    DLGTEMPLATE* t = (DLGTEMPLATE*)buf;
    t->style = WS_POPUP | WS_CAPTION | WS_SYSMENU | DS_MODALFRAME;
    t->cdit = 5;
    t->cx = 296;
    t->cy = 184;
    WORD* p = (WORD*)(t + 1);
    *p++ = 0;
    *p++ = 0;
    *p++ = 0;
    p = AddItem(p, BS_DEFPUSHBUTTON | WS_TABSTOP | WS_GROUP, 12, 162, 72, 14, IDOK, 0x0080, L"&Download");
    p = AddItem(p, BS_PUSHBUTTON | WS_TABSTOP, 90, 162, 92, 14, IDCANCEL, 0x0080, L"Remind Me &Later");
    p = AddItem(p, BS_PUSHBUTTON | WS_TABSTOP, 188, 162, 96, 14, ID_SKIP, 0x0080, L"&Skip This Version");
    p = AddItem(p, BS_AUTOCHECKBOX | WS_TABSTOP | WS_GROUP, 12, 144, 272, 12, ID_CHECK, 0x0080, L"&Check");
    p = AddItem(p, SS_LEFT | SS_NOTIFY | WS_TABSTOP, 12, 110, 272, 8, ID_LINK, 0x0082, L"Release notes");
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

static const char* Who(HWND dlg, HWND owner, HWND edit, HWND w)
{
    static char buf[64];
    if (w == NULL)
        return "NULL";
    if (w == dlg)
        return "the dialog window itself";
    if (w == owner)
        return "owner";
    if (w == edit)
        return "owner's edit";
    if (GetParent(w) == dlg)
    {
        sprintf_s(buf, "dialog control %d", GetDlgCtrlID(w));
        return buf;
    }
    return "other";
}

static void Key(HWND dlg, WPARAM vk)
{
    MSG msg;
    memset(&msg, 0, sizeof(msg));
    msg.hwnd = GetFocus();
    msg.message = WM_KEYDOWN;
    msg.wParam = vk;
    msg.lParam = 1;
    gCmdCount = 0;
    gLastCmd = 0;
    BOOL handled = IsDialogMessageW(dlg, &msg);
    Pump();
    printf("      IsDialogMessage(VK 0x%02X) -> %d; WM_COMMAND count %d, id %u\n", (unsigned)vk, handled, gCmdCount, LOWORD(gLastCmd));
}

int main()
{
#ifdef R2_COMCTL6
    InitCommonControls();
    printf("comctl32 6 manifest: yes\n");
#else
    printf("comctl32 6 manifest: no (user32 controls)\n");
#endif
    WNDCLASSW wc = {0};
    wc.lpfnWndProc = DefWindowProcW;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.lpszClassName = L"R2Owner";
    RegisterClassW(&wc);
    for (int ret = 0; ret <= 1; ret++)
    {
        gInitRet = ret;
        HWND owner = CreateWindowExW(0, L"R2Owner", L"owner", WS_OVERLAPPEDWINDOW | WS_VISIBLE, 50, 50, 600, 400, NULL, NULL, wc.hInstance, NULL);
        HWND edit = CreateWindowExW(0, L"EDIT", L"", WS_CHILD | WS_VISIBLE, 10, 10, 200, 24, owner, NULL, NULL, NULL);
        SetActiveWindow(owner);
        SetFocus(edit);
        Pump();
        printf("WM_INITDIALOG returns %d\n", ret);
        HWND dlg = MakeDialog(owner);
        Pump();
        printf("  created hidden: active = %s, focus = %s\n", Who(dlg, owner, edit, GetActiveWindow()), Who(dlg, owner, edit, GetFocus()));
        ShowWindow(dlg, SW_SHOWNOACTIVATE);
        Pump();
        printf("  SW_SHOWNOACTIVATE: active = %s, focus = %s\n", Who(dlg, owner, edit, GetActiveWindow()), Who(dlg, owner, edit, GetFocus()));
        // z-order: is the dialog above its owner?
        BOOL above = FALSE;
        for (HWND w = GetWindow(owner, GW_HWNDPREV); w != NULL; w = GetWindow(w, GW_HWNDPREV))
            if (w == dlg)
                above = TRUE;
        printf("  dialog above owner in z-order: %d\n", above);
        printf("  default id (DM_GETDEFID): %u; IDOK style has BS_DEFPUSHBUTTON: %d\n",
               LOWORD(SendMessageW(dlg, DM_GETDEFID, 0, 0)),
               (int)((GetWindowLongW(GetDlgItem(dlg, IDOK), GWL_STYLE) & 0xF) == BS_DEFPUSHBUTTON));

        // the user activates the window later (caption click / Alt+Tab)
        SetActiveWindow(dlg);
        Pump();
        printf("  activated later: active = %s, focus = %s\n", Who(dlg, owner, edit, GetActiveWindow()), Who(dlg, owner, edit, GetFocus()));
        printf("    Enter now:\n");
        Key(dlg, VK_RETURN);
        printf("    Tab, then where is the focus:\n");
        Key(dlg, VK_TAB);
        printf("      focus = %s\n", Who(dlg, owner, edit, GetFocus()));
        // back to the owner and to the dialog again: is the focus remembered?
        SetActiveWindow(owner);
        Pump();
        SetActiveWindow(dlg);
        Pump();
        printf("  owner and back: focus = %s\n", Who(dlg, owner, edit, GetFocus()));
        // focus on the link (what CHyperLink does on a click: SetFocus)
        SetFocus(GetDlgItem(dlg, ID_LINK));
        Pump();
        printf("  focus set to the link: focus = %s; IDOK still drawn default: %d; default id %u\n", Who(dlg, owner, edit, GetFocus()),
               (int)((GetWindowLongW(GetDlgItem(dlg, IDOK), GWL_STYLE) & 0xF) == BS_DEFPUSHBUTTON),
               LOWORD(SendMessageW(dlg, DM_GETDEFID, 0, 0)));
        printf("    Enter on the link:\n");
        Key(dlg, VK_RETURN);
        printf("    Space on the link (reaches the control when IsDialogMessage returns 0... or is translated):\n");
        Key(dlg, VK_SPACE);
        {
            // Alt+D (the mnemonic of the default button) while the link has the focus
            SetFocus(GetDlgItem(dlg, ID_LINK));
            Pump();
            MSG msg;
            memset(&msg, 0, sizeof(msg));
            msg.hwnd = GetFocus();
            msg.message = WM_SYSCHAR;
            msg.wParam = 'd';
            msg.lParam = 0x20000001;
            gCmdCount = 0;
            gFocusAtCmd = 0;
            BOOL handled = IsDialogMessageW(dlg, &msg);
            Pump();
            printf("    Alt+D with the focus on the link: handled %d, WM_COMMAND count %d id %u, focus at the command = control %d\n",
                   handled, gCmdCount, LOWORD(gLastCmd), gFocusAtCmd);
            SetFocus(GetDlgItem(dlg, ID_LINK));
            Pump();
        }
        {
            // a mouse click on the default button while the link has the focus
            SetFocus(GetDlgItem(dlg, ID_LINK));
            Pump();
            gCmdCount = 0;
            gFocusAtCmd = 0;
            HWND ok = GetDlgItem(dlg, IDOK);
            SendMessageW(ok, WM_LBUTTONDOWN, MK_LBUTTON, MAKELPARAM(5, 5));
            int focusAfterDown = GetFocus() != NULL ? GetDlgCtrlID(GetFocus()) : -1;
            SendMessageW(ok, WM_LBUTTONUP, 0, MAKELPARAM(5, 5));
            Pump();
            printf("    mouse click on the default button with the focus on the link: focus after button-down = control %d, WM_COMMAND count %d id %u, focus at the command = control %d\n",
                   focusAfterDown, gCmdCount, LOWORD(gLastCmd), gFocusAtCmd);
            SetFocus(GetDlgItem(dlg, ID_LINK));
            Pump();
        }
        // hide the focused link (About: RefreshUpdateLine hides the link that was just used)
        ShowWindow(GetDlgItem(dlg, ID_LINK), SW_HIDE);
        Pump();
        printf("  focused link hidden: focus = %s\n", Who(dlg, owner, edit, GetFocus()));
        printf("    Enter:\n");
        Key(dlg, VK_RETURN);
        printf("    Tab:\n");
        Key(dlg, VK_TAB);
        printf("      focus = %s\n", Who(dlg, owner, edit, GetFocus()));
        DestroyWindow(dlg);
        DestroyWindow(owner);
        Pump();
    }
    return 0;
}
