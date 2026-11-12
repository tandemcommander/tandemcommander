// Review 424: does re-setting MIIM_FTYPE of owner-drawn items (darkmenu.cpp RemeasureMenu)
// make Windows send WM_MEASUREITEM again, for the bar and for popups? Negative controls
// without the re-set.
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

static int g_measures = 0, g_barMeasures = 0, g_popMeasures = 0;
static int g_height = 19;
static HMENU g_bar = NULL, g_pop = NULL;

static void ApplyOwnerDraw(HMENU menu, bool bar)
{
    int n = GetMenuItemCount(menu);
    for (int i = 0; i < n; i++)
    {
        MENUITEMINFOA mii = {sizeof(mii)};
        mii.fMask = MIIM_FTYPE | MIIM_SUBMENU;
        GetMenuItemInfoA(menu, i, TRUE, &mii);
        MENUITEMINFOA set = {sizeof(set)};
        set.fMask = MIIM_FTYPE | MIIM_DATA;
        set.fType = mii.fType | MFT_OWNERDRAW;
        set.dwItemData = bar ? 1000 + i : 2000 + i;
        SetMenuItemInfoA(menu, i, TRUE, &set);
        if (mii.hSubMenu)
            ApplyOwnerDraw(mii.hSubMenu, false);
    }
}

// verbatim logic of darkmenu.cpp RemeasureMenu
static void RemeasureMenu(HMENU menu)
{
    int count = GetMenuItemCount(menu);
    for (int i = 0; i < count; i++)
    {
        MENUITEMINFOA mii;
        memset(&mii, 0, sizeof(mii));
        mii.cbSize = sizeof(mii);
        mii.fMask = MIIM_FTYPE | MIIM_SUBMENU | MIIM_BITMAP;
        if (!GetMenuItemInfoA(menu, i, TRUE, &mii))
            continue;
        if ((mii.fType & MFT_OWNERDRAW) != 0)
        {
            MENUITEMINFOA set;
            memset(&set, 0, sizeof(set));
            set.cbSize = sizeof(set);
            set.fMask = MIIM_BITMAP;
            set.hbmpItem = mii.hbmpItem;
            SetMenuItemInfoA(menu, i, TRUE, &set);
        }
        if (mii.hSubMenu != NULL)
            RemeasureMenu(mii.hSubMenu);
    }
}

// the first version of 424 (re-set MIIM_FTYPE): the negative control, mode 5
static void RemeasureMenuFirst(HMENU menu)
{
    int count = GetMenuItemCount(menu);
    for (int i = 0; i < count; i++)
    {
        MENUITEMINFOA mii;
        memset(&mii, 0, sizeof(mii));
        mii.cbSize = sizeof(mii);
        mii.fMask = MIIM_FTYPE | MIIM_SUBMENU;
        if (!GetMenuItemInfoA(menu, i, TRUE, &mii))
            continue;
        if ((mii.fType & MFT_OWNERDRAW) != 0)
        {
            MENUITEMINFOA set;
            memset(&set, 0, sizeof(set));
            set.cbSize = sizeof(set);
            set.fMask = MIIM_FTYPE;
            set.fType = mii.fType;
            SetMenuItemInfoA(menu, i, TRUE, &set);
        }
        if (mii.hSubMenu != NULL)
            RemeasureMenuFirst(mii.hSubMenu);
    }
}


static int g_mode = 0;
// variant 1: toggle MFT_OWNERDRAW off and on again
// variant 2: ModifyMenuA with MF_OWNERDRAW (keeps id, data from lpNewItem)
// variant 3: re-set MIIM_FTYPE | MIIM_DATA (same values)
static void Variant(HMENU menu)
{
    int count = GetMenuItemCount(menu);
    for (int i = 0; i < count; i++)
    {
        MENUITEMINFOA mii = {sizeof(mii)};
        mii.fMask = MIIM_FTYPE | MIIM_SUBMENU | MIIM_DATA | MIIM_ID | MIIM_STATE;
        if (!GetMenuItemInfoA(menu, i, TRUE, &mii))
            continue;
        if ((mii.fType & MFT_OWNERDRAW) != 0)
        {
            MENUITEMINFOA set = {sizeof(set)};
            if (g_mode == 1)
            {
                set.fMask = MIIM_FTYPE;
                set.fType = mii.fType & ~MFT_OWNERDRAW;
                SetMenuItemInfoA(menu, i, TRUE, &set);
                set.fType = mii.fType;
                SetMenuItemInfoA(menu, i, TRUE, &set);
            }
            else if (g_mode == 3)
            {
                set.fMask = MIIM_FTYPE | MIIM_DATA;
                set.fType = mii.fType;
                set.dwItemData = mii.dwItemData;
                SetMenuItemInfoA(menu, i, TRUE, &set);
            }
            else if (g_mode == 4)
            {
                set.fMask = MIIM_BITMAP;
                set.hbmpItem = NULL;
                SetMenuItemInfoA(menu, i, TRUE, &set);
            }
        }
        if (mii.hSubMenu != NULL)
            Variant(mii.hSubMenu);
    }
}

static LRESULT CALLBACK Proc(HWND h, UINT m, WPARAM w, LPARAM l)
{
    switch (m)
    {
    case WM_MEASUREITEM:
    {
        MEASUREITEMSTRUCT* mis = (MEASUREITEMSTRUCT*)l;
        if (mis->CtlType == ODT_MENU)
        {
            g_measures++;
            if (mis->itemData >= 1000 && mis->itemData < 2000)
                g_barMeasures++;
            else
                g_popMeasures++;
            mis->itemWidth = 60;
            mis->itemHeight = g_height;
            return TRUE;
        }
        break;
    }
    case WM_DRAWITEM:
        return TRUE;
    case WM_TIMER:
        KillTimer(h, w);
        EndMenu();
        return 0;
    }
    return DefWindowProcW(h, m, w, l);
}

static void Pump(int ms)
{
    DWORD end = GetTickCount() + ms;
    while ((int)(end - GetTickCount()) > 0)
    {
        MSG msg;
        while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE))
        {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        Sleep(10);
    }
}

static int BarHeight(HWND h)
{
    MENUBARINFO mbi = {sizeof(mbi)};
    if (!GetMenuBarInfo(h, OBJID_MENU, 0, &mbi))
        return -1;
    return mbi.rcBar.bottom - mbi.rcBar.top;
}

static void ShowPopup(HWND h, const char* label)
{
    int b = g_popMeasures;
    SetTimer(h, 1, 300, NULL);
    BOOL ok = TrackPopupMenu(g_pop, TPM_LEFTALIGN | TPM_TOPALIGN, 100, 100, 0, h, NULL);
    Pump(100);
    printf("%-44s popup shown %d, popup measures +%d\n", label, ok, g_popMeasures - b);
}

int main(int argc, char** argv)
{
    g_mode = argc > 1 ? atoi(argv[1]) : 0;
    printf("mode %d\n", g_mode);
    WNDCLASSW wc = {0};
    wc.lpfnWndProc = Proc;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.lpszClassName = L"rv424menutest";
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    RegisterClassW(&wc);
    g_bar = CreateMenu();
    for (int p = 0; p < 3; p++)
    {
        HMENU sub = CreatePopupMenu();
        for (int i = 0; i < 4; i++)
            AppendMenuA(sub, MF_STRING, 100 + p * 10 + i, "Item\tCtrl+X");
        AppendMenuA(g_bar, MF_POPUP, (UINT_PTR)sub, p == 0 ? "&File" : p == 1 ? "&View" : "&Help");
    }
    ApplyOwnerDraw(g_bar, true);
    g_pop = GetSubMenu(g_bar, 0);
    HWND h = CreateWindowExW(0, wc.lpszClassName, L"menutest", WS_OVERLAPPEDWINDOW, 50, 50, 600, 400, NULL, g_bar,
                             wc.hInstance, NULL);
    ShowWindow(h, SW_SHOW);
    UpdateWindow(h);
    Pump(300);
    printf("%-44s bar measures %d, bar height %d\n", "initial show (item height 19)", g_barMeasures, BarHeight(h));

    // control 1: item height changes, only DrawMenuBar
    g_height = 40;
    int b = g_barMeasures;
    DrawMenuBar(h);
    Pump(300);
    printf("%-44s bar measures +%d, bar height %d\n", "control: height 40, DrawMenuBar only", g_barMeasures - b, BarHeight(h));
    // control 2: + SetWindowPos (what WM_DPICHANGED does after)
    b = g_barMeasures;
    SetWindowPos(h, NULL, 60, 60, 580, 380, SWP_NOZORDER | SWP_NOACTIVATE);
    Pump(300);
    printf("%-44s bar measures +%d, bar height %d\n", "control: + SetWindowPos (size change)", g_barMeasures - b, BarHeight(h));

    ShowPopup(h, "popup first show");
    ShowPopup(h, "control: popup second show, no remeasure");

    // the feature's trick
    b = g_barMeasures;
    if (g_mode == 0) RemeasureMenu(g_bar); else if (g_mode == 5) RemeasureMenuFirst(g_bar); else Variant(g_bar);
    DrawMenuBar(h);
    Pump(300);
    printf("%-44s bar measures +%d, bar height %d\n", "RemeasureMenu + DrawMenuBar", g_barMeasures - b, BarHeight(h));
    b = g_barMeasures;
    SetWindowPos(h, NULL, 50, 50, 600, 400, SWP_NOZORDER | SWP_NOACTIVATE);
    Pump(300);
    printf("%-44s bar measures +%d, bar height %d\n", "+ SetWindowPos", g_barMeasures - b, BarHeight(h));
    g_height = 25;
    ShowPopup(h, "popup after RemeasureMenu");
    ShowPopup(h, "popup again (no remeasure)");
    DestroyWindow(h);
    return 0;
}
