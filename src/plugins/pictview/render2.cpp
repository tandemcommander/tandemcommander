// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <shlobj.h>

#include "lib/pvw32dll.h"
#include "renderer.h"
#include "wicengine.h" // feature 111: the wallpaper image through the Windows encoder
#include "pictview.h"
#include "pictview.rh"
#include "pictview.rh2"
#include "lang/lang.rh"

//****************************************************************************
//
// MultipleMonitors
//
// Returns TRUE if more than one monitor is present.
// If 'boundingRect' is not NULL, it receives the bounding rectangle of all monitors,
// i.e. the dimensions of the virtual desktop.
//

struct MonitorEnumProcData
{
    int Count;
    RECT* BoundingRect;
};

BOOL CALLBACK
MonitorEnumProc(HMONITOR hMonitor, HDC hdcMonitor, LPRECT lprcMonitor, LPARAM dwData)
{
    MonitorEnumProcData* data = (MonitorEnumProcData*)dwData;
    data->Count++;

    if (data->BoundingRect != NULL)
    {
        MONITORINFO mi;
        mi.cbSize = sizeof(mi);
        GetMonitorInfo(hMonitor, &mi);

        UnionRect(data->BoundingRect, &mi.rcMonitor, data->BoundingRect);
    }

    return TRUE;
}

BOOL MultipleMonitors(RECT* boundingRect)
{
    MonitorEnumProcData enumData;
    enumData.Count = 0;
    enumData.BoundingRect = boundingRect;
    if (enumData.BoundingRect != NULL)
        SetRectEmpty(enumData.BoundingRect);
    EnumDisplayMonitors(NULL, NULL, MonitorEnumProc, (LPARAM)&enumData);
    return enumData.Count > 1;
}

/**********************************************************

GetCurrentCursorHandle (KB Q230495)

  Purpose:
    Retrieves a handle to the current cursor regardless of
    whether or not it's owned by the current thread. This is
    useful, for example, when you need to draw the image
    of the current cursor into a screen capture using
    DrawIcon().

  Input:
    <none>

  Return:
    The return value is the handle to the current cursor.
    If there is no cursor, the return value is NULL.

  Notes:
    This function cannot be used to capture the cursor on
    another desktop.

**********************************************************/

HCURSOR GetCurrentCursorHandle()
{
    POINT pt;
    HWND hWnd;
    DWORD dwThreadID, dwCurrentThreadID;
    HCURSOR hCursor = NULL;

    // Find out which window owns the cursor
    GetCursorPos(&pt);
    hWnd = WindowFromPoint(pt);

    // Get the thread ID for the cursor owner.
    dwThreadID = GetWindowThreadProcessId(hWnd, NULL);

    // Get the thread ID for the current thread
    dwCurrentThreadID = GetCurrentThreadId();

    // If the cursor owner is not us then we must attach to
    // the other thread in so that we can use GetCursor() to
    // return the correct hCursor
    if (dwCurrentThreadID != dwThreadID)
    {
        // Attach to the thread that owns the cursor
        if (AttachThreadInput(dwCurrentThreadID, dwThreadID, TRUE))
        {
            // Get the handle to the cursor
            hCursor = GetCursor();

            // Detach from the thread that owns the cursor
            AttachThreadInput(dwCurrentThreadID, dwThreadID, FALSE);
        }
    }
    else
        hCursor = GetCursor();

    return hCursor;
}

void CRendererWindow::ScreenCapture()
{
    HDC hMonitorDC = CreateDC(_T("DISPLAY"), NULL, NULL, NULL);
    HDC hMemDC = CreateCompatibleDC(hMonitorDC);

    HRGN hWndRgn = CreateRectRgn(0, 0, 0, 0); // window region, will be used for clipping of non-rectangular windows (XP, Vista, ...)
    int wndRgnType = NULLREGION;

    RECT bndR;
    MultipleMonitors(&bndR);
    RECT rect;
    switch (G.CaptureScope)
    {
    case CAPTURE_SCOPE_DESKTOP:
    {
        rect.left = 0;
        rect.top = 0;
        rect.right = GetDeviceCaps(hMonitorDC, HORZRES);
        rect.bottom = GetDeviceCaps(hMonitorDC, VERTRES);
        break;
    }

    case CAPTURE_SCOPE_WINDOW:
    case CAPTURE_SCOPE_CLIENT:
    case CAPTURE_SCOPE_APPL:
    {
        HWND hForeground = GetForegroundWindow();
        if (hForeground != NULL)
        {
            if (G.CaptureScope == CAPTURE_SCOPE_WINDOW)
            {
                GetWindowRect(hForeground, &rect);
                wndRgnType = GetWindowRgn(hForeground, hWndRgn);
            }
            else if (G.CaptureScope == CAPTURE_SCOPE_APPL)
            {
                HWND hParent;

                while (((hParent = GetParent(hForeground)) != NULL) && IsWindowVisible(hParent))
                {
                    hForeground = hParent;
                }
                GetWindowRect(hForeground, &rect);
                wndRgnType = GetWindowRgn(hForeground, hWndRgn);
            }
            else
            {
                GetClientRect(hForeground, &rect);
                MapWindowPoints(hForeground, NULL, (LPPOINT)&rect, 2);
            }
            RECT dummy;
            if (IntersectRect(&dummy, &bndR, &rect))
                break;
        }
        // if the window does not exist or lies outside the usable area, fall back to the virtual screen
    }
    case CAPTURE_SCOPE_VIRTUAL:
    {
        rect = bndR;
        break;
    }
    }
    IntersectRect(&rect, &bndR, &rect);

    int width = rect.right - rect.left;
    int height = rect.bottom - rect.top;

    HBITMAP hBitmap = CreateCompatibleBitmap(hMonitorDC, width, height);

    HBITMAP hOldBitmap = (HBITMAP)SelectObject(hMemDC, hBitmap);

    ShowWindow(Viewer->HWindow, SW_HIDE);
    Sleep(0); // let the window disappear from the taskbar

    if (wndRgnType == COMPLEXREGION) // clip only non-rectangular windows
    {
        // fill "transparent" background
        HBRUSH hBrush = CreateSolidBrush(GetCOLORREF(G.Colors[vceTransparent]));
        RECT fillR = {0, 0, width, height};
        FillRect(hMemDC, &fillR, hBrush);
        DeleteObject(hBrush);

        // clip painting using windows region
        SelectClipRgn(hMemDC, hWndRgn);
    }

    BOOL ret = BitBlt(hMemDC,
                      0, 0,
                      width, height,
                      hMonitorDC,
                      rect.left, rect.top,
                      SRCCOPY);

    ShowWindow(Viewer->HWindow, SW_SHOW);

    // if the user also wants to capture the cursor, add it to the bitmap
    if (G.CaptureCursor)
    {
        HCURSOR hCursor = GetCurrentCursorHandle();

        POINT cursorPos;
        GetCursorPos(&cursorPos);
        ICONINFO ii;
        GetIconInfo(hCursor, &ii);
        DrawIconEx(hMemDC, cursorPos.x - ii.xHotspot - rect.left, cursorPos.y - ii.yHotspot - rect.top,
                   hCursor, 0, 0, 0, NULL, DI_DEFAULTSIZE | DI_NORMAL);
        DeleteObject(ii.hbmMask);
        if (ii.hbmColor != NULL)
            DeleteObject(ii.hbmColor);
    }

    SelectObject(hMemDC, hOldBitmap);

    // clean up after ourselves
    DeleteDC(hMonitorDC);
    DeleteDC(hMemDC);
    // DeleteObject(hBitmap);   // hBitmap is destroyed in OpenFile()
    DeleteObject(hWndRgn);

    CancelCapture();

    // pass the bitmap to PictView
    EnumFilesSourceUID = -1;
    OpenFile(CAPTURE, -1, hBitmap);

    SalamanderGeneral->Free(FileName);
    FileName = SalamanderGeneral->DupStr(LoadStr(IDS_CAPTURE_TITLE));

    // when entering this function the window was minimized, now restore it to its original position
    Viewer->UpdateEnablers();
    Viewer->UpdateToolBar();
    ShowWindow(Viewer->HWindow, SW_RESTORE);
    SetForegroundWindow(Viewer->HWindow);
}

void CRendererWindow::CancelCapture()
{
    if (Capturing)
    {
        if (G.CaptureTrigger == CAPTURE_TRIGGER_HOTKEY)
            UnregisterHotKey(HWindow, G.CaptureAtomID);
        else
            KillTimer(HWindow, CAPTURE_TIMER_ID);
        Capturing = FALSE;
    }
}

void CRendererWindow::FreeComment(void)
{
    if (Comment)
    {
        free(Comment);
        Comment = NULL;
    }
}

void CRendererWindow::DuplicateComment(void)
{
    FreeComment();
    if (pvii.CommentSize && pvii.Comment)
    {
        Comment = (char*)malloc(pvii.CommentSize + 1);
        if (Comment)
        {
            memcpy(Comment, pvii.Comment, pvii.CommentSize);
            Comment[pvii.CommentSize] = 0;
        }
    }
}

PVCODE CRendererWindow::InitiatePageLoad(void)
{
    PVCODE result;
    PVImageInfo pviiNew;

    result = PVW32DLL.PVGetImageInfo(PVHandle, &pviiNew, sizeof(pviiNew), pvii.CurrentImage);
    if (PVC_OK == result)
    {

        SetScrollPos(HWindow, SB_BOTH, 0, TRUE);
        memcpy(&pvii, &pviiNew, sizeof(PVImageInfo));

        DuplicateComment(); // automatically frees the old comment
        XStretchedRange = XRange = max(1, pvii.Width);
        if (pvii.HorDPI && pvii.VerDPI)
        {
            YRange = pvii.Height * pvii.HorDPI / pvii.VerDPI;
        }
        else
        {
            YRange = pvii.Height;
        }
        YStretchedRange = YRange;
        ZoomFactor = ZOOM_SCALE_FACTOR;
        ZoomIndex = 0;
        Canceled = ImageLoaded = DoNotAttempToLoad = FALSE;
        InvalidateRect(HWindow, NULL, FALSE);
        InvalidateCage(&SelectRect);
        Viewer->SetStatusBarTexts();
        WMSize();
        if (pvii.Format == PVF_ANI)
        {
            if (PVSequence)
            {
                // User requested specific page -> stop animating
                KillTimer(HWindow, IMGSEQ_TIMER_ID);
                PVCurImgInSeq = PVSequence = NULL;
            }
            pvii.Flags &= ~PVFF_IMAGESEQUENCE;
        }
    }
    else
    {
        SalamanderGeneral->SalMessageBox(HWindow, (PVC_UNKNOWN_FILE_STRUCT == result) ? LoadStr(IDS_UNSUPPORTED_IMAGE_TYPE) : PVW32DLL.PVGetErrorText(result),
                                         LoadStr(IDS_ERROR_CALLING_PVW32_DLL), MB_ICONEXCLAMATION);
    }
    return result;
} /* CRendererWindow::InitiatePageLoad */

void CRendererWindow::TryEnterHandToolMode(void)
{
    if ((XStretchedRange > PageWidth) || (YStretchedRange > PageHeight))
    {
        ShutdownTool();
        SelectTool(RT_HAND);
        SetCursor(LoadCursor(DLLInstance, MAKEINTRESOURCE(IDC_HAND1)));
    }
} /* CRendererWindow::TryEnterHandToolMode */

void CRendererWindow::ShutdownTool(void)
{
    switch (CurrTool)
    {
    case RT_PIPETTE:
        SetCursor(LoadCursor(NULL, IDC_ARROW));
        SendMessage(PipWindow, WM_CLOSE, 0, 0);
        PipWindow = NULL;
        break;
    }
    //  CurrTool = RT_HAND;
} /* CRendererWindow::ShutdownTool */

//****************************************************************************
//
// SetAsWallpaper
//

// Feature 111. Before: the image was "saved" by PVSaveImage into %WINDIR%\PictView_Wallpaper.bmp -
// the WIC engine writes no files and a user cannot write into %WINDIR% - so Center, Tile and
// Stretch always failed ("Unable to save the image"); then they, like Restore and None, called
// SystemParametersInfo(SPI_SETDESKWALLPAPER) with NULL - documented as "reverts to the default
// wallpaper" - and the HKCU\Control Panel\Desktop values were read through the core's UTF-8
// registry facade but written back as code-page text (a path outside ASCII got garbled).
// Now: a 24-bit BMP of what the window shows (the 105 rule: a temporary file next to the target,
// replaced only when complete) at %LOCALAPPDATA%\Tandem Commander\PictView_Wallpaper.bmp, the
// style values and the backup of the previous wallpaper (Prev*, the same value names as before)
// written with the wide API, then SPI_SETDESKWALLPAPER with that file's path. Restore swaps the
// current and the backed-up wallpaper (nothing when nothing is backed up), None sets no wallpaper
// ("" - never NULL); the backup is written only after the new wallpaper took effect and never with
// an empty value; Center/Tile/Stretch and None back up only a wallpaper that is not our own file,
// Restore backs up the one it replaces (also ours) so that Restore again swaps back.
//
// Test seam: when the environment variable TC_PICTVIEW_WALLPAPER_DRYRUN names a file, no registry
// value is written and SystemParametersInfo is not called; each of those calls is appended to that
// file instead, one UTF-8 line each: "SET <value>=<data>", "SPI_SETDESKWALLPAPER <path>". A GUI probe
// must never change the desktop of the session it runs in (a hidden desktop shares the user's
// wallpaper). The wallpaper file itself is written in both modes.

static const WCHAR WP_FILE_NAME[] = L"PictView_Wallpaper.bmp";
static const WCHAR WP_DRYRUN_VAR[] = L"TC_PICTVIEW_WALLPAPER_DRYRUN";

// the dry-run log named by the environment (malloc'ed), or NULL for the real calls
static WCHAR* WpDryRunLog()
{
    DWORD n = GetEnvironmentVariableW(WP_DRYRUN_VAR, NULL, 0);
    if (n <= 1)
        return NULL;
    WCHAR* log = (WCHAR*)malloc(n * sizeof(WCHAR));
    if (log != NULL && GetEnvironmentVariableW(WP_DRYRUN_VAR, log, n) == n - 1 && log[0] != 0)
        return log;
    free(log);
    return NULL;
}

// one line "<a><b>" appended to the dry-run log as UTF-8
static void WpLogLine(const WCHAR* log, const WCHAR* a, const WCHAR* b)
{
    size_t len = wcslen(a) + wcslen(b) + 3;
    WCHAR* line = (WCHAR*)malloc(len * sizeof(WCHAR));
    if (line == NULL)
        return;
    swprintf_s(line, len, L"%s%s\r\n", a, b);
    char* u8 = SplWToU8Alloc(line);
    free(line);
    if (u8 == NULL)
        return;
    HANDLE h = CreateFileW(log, FILE_APPEND_DATA, FILE_SHARE_READ, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h != INVALID_HANDLE_VALUE)
    {
        DWORD written;
        WriteFile(h, u8, (DWORD)strlen(u8), &written, NULL);
        CloseHandle(h);
    }
    free(u8);
}

// a REG_SZ value of HKCU\Control Panel\Desktop (malloc'ed, "" when missing or not a string)
static WCHAR* WpRegRead(HKEY key, const WCHAR* name)
{
    DWORD type = 0, size = 0;
    if (RegQueryValueExW(key, name, NULL, &type, NULL, &size) != ERROR_SUCCESS || (type != REG_SZ && type != REG_EXPAND_SZ))
        size = 0;
    WCHAR* value = (WCHAR*)malloc(size + 2 * sizeof(WCHAR));
    if (value == NULL)
        return NULL;
    if (size > 0 && RegQueryValueExW(key, name, NULL, &type, (BYTE*)value, &size) != ERROR_SUCCESS)
        size = 0;
    value[size / sizeof(WCHAR)] = 0; // a stored value need not end with a NUL
    return value;
}

// writes a REG_SZ value - or, in the dry run, logs it
static BOOL WpRegWrite(HKEY key, const WCHAR* name, const WCHAR* value, const WCHAR* dryLog)
{
    if (dryLog != NULL)
    {
        WCHAR head[64];
        swprintf_s(head, L"SET %s=", name);
        WpLogLine(dryLog, head, value);
        return TRUE;
    }
    return RegSetValueExW(key, name, 0, REG_SZ, (const BYTE*)value, (DWORD)((wcslen(value) + 1) * sizeof(WCHAR))) == ERROR_SUCCESS;
}

// the wallpaper of the session: 'path' ("" = none; never NULL) - or, in the dry run, logged
static BOOL WpApply(const WCHAR* path, const WCHAR* dryLog, DWORD* err)
{
    if (dryLog != NULL)
    {
        WpLogLine(dryLog, L"SPI_SETDESKWALLPAPER ", path);
        return TRUE;
    }
    if (SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0, (void*)path, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE))
        return TRUE;
    *err = GetLastError();
    return FALSE;
}

// "Unable to save the image." with the system's reason (or the engine's), composed as UTF-8
static void WpShowError(HWND parent, int code, DWORD err)
{
    char detail[1000];
    if (err != 0)
        SalamanderGeneral->GetErrorText(err, detail, SizeOf(detail)); // UTF-8
    else
        lstrcpyn(detail, PVW32DLL.PVGetErrorText(code), SizeOf(detail));
    char msg[1200];
    FormatSaveErrorU8(msg, SizeOf(msg), detail);
    SalamanderGeneral->SalMessageBox(parent, msg, LoadStr(IDS_ERRORTITLE), MB_ICONEXCLAMATION | MB_OK);
}

// writes what the window shows into %LOCALAPPDATA%\Tandem Commander\PictView_Wallpaper.bmp;
// '*path' (malloc'ed) is that file's plain path. Returns a PVC_* code ('*err': the system error)
int CRendererWindow::SaveWallpaperFile(WCHAR** path, DWORD* err)
{
    *path = NULL;
    *err = 0;
    WCHAR dir[MAX_PATH];
    if (SHGetFolderPathW(NULL, CSIDL_LOCAL_APPDATA, NULL, SHGFP_TYPE_CURRENT, dir) != S_OK)
    {
        *err = ERROR_PATH_NOT_FOUND;
        return PVC_WRITING_ERROR;
    }
    size_t len = wcslen(dir) + 20 + _countof(WP_FILE_NAME) + 2;
    WCHAR* file = (WCHAR*)malloc(len * sizeof(WCHAR));
    if (file == NULL)
        return PVC_OOM;
    swprintf_s(file, len, L"%s\\Tandem Commander", dir);
    CreateDirectoryW(file, NULL); // created on demand, as for the bug reports; an error shows below
    wcscat_s(file, len, L"\\");
    wcscat_s(file, len, WP_FILE_NAME);
    char* fileU8 = SplWToU8Alloc(file);
    WCHAR* wExt = fileU8 != NULL ? SplU8ToWExtAlloc(fileU8) : NULL; // the \\?\ form for the file steps
    free(fileU8);
    if (wExt == NULL)
    {
        free(file);
        return PVC_OOM;
    }
    DWORD attr = GetFileAttributesW(wExt);
    int code;
    if (attr != INVALID_FILE_ATTRIBUTES && (attr & FILE_ATTRIBUTE_DIRECTORY))
    {
        *err = ERROR_ALREADY_EXISTS; // a folder of that name is never replaced
        code = PVC_WRITING_ERROR;
    }
    else
    {
        CWicEncodeParams ep;
        memset(&ep, 0, sizeof(ep));
        ep.Format = PVF_BMP;
        ep.Compression = PVCS_DEFAULT;
        ep.Colors = PV_COLOR_TC24;
        ep.ColorModel = PVCM_RGB;
        ep.JPEGQuality = 75;
        WCHAR* leftAt = NULL;
        code = EncodeReplaceSafe(wExt, &ep, attr != INVALID_FILE_ATTRIBUTES, TRUE, err, &leftAt);
        free(leftAt); // our own file: the temporary one is not worth a message
    }
    free(wExt);
    if (code == PVC_OK)
        *path = file;
    else
        free(file);
    return code;
}

void CRendererWindow::SetAsWallpaper(WORD command)
{
    if (FileName == NULL)
        return;
    WCHAR* dryLog = WpDryRunLog();
    HKEY key;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Control Panel\\Desktop", 0, KEY_QUERY_VALUE | KEY_SET_VALUE, &key) != ERROR_SUCCESS)
    {
        free(dryLog);
        return;
    }
    WCHAR* cur = WpRegRead(key, L"Wallpaper");
    WCHAR* curStyle = WpRegRead(key, L"WallpaperStyle");
    WCHAR* curTile = WpRegRead(key, L"TileWallpaper");
    DWORD err = 0;
    int code = PVC_OK;
    if (cur != NULL && curStyle != NULL && curTile != NULL)
    {
        // the backup (Prev*) is written only after the new wallpaper took effect and never with an
        // empty value; Center/Tile/Stretch and None back up only a wallpaper that is not our own file
        // (review S2: None run twice, or after Center, destroyed a valid backup), Restore the one it
        // replaces (so Restore again swaps back); style values written for the SPI call (Windows reads
        // them there) are put back when the call fails
        const WCHAR* curName = wcsrchr(cur, L'\\');
        curName = curName != NULL ? curName + 1 : cur;
        BOOL curWorthBackup = cur[0] != 0 && _wcsicmp(curName, WP_FILE_NAME) != 0;
        switch (command)
        {
        case CMD_WALLPAPER_CENTER:
        case CMD_WALLPAPER_TILE:
        case CMD_WALLPAPER_STRETCH:
        {
            WCHAR* file = NULL;
            code = SaveWallpaperFile(&file, &err);
            if (code != PVC_OK)
                break; // nothing in the registry or on the desktop changes
            WpRegWrite(key, L"WallpaperStyle", command == CMD_WALLPAPER_STRETCH ? L"2" : L"0", dryLog);
            WpRegWrite(key, L"TileWallpaper", command == CMD_WALLPAPER_TILE ? L"1" : L"0", dryLog);
            if (WpApply(file, dryLog, &err)) // writes the Wallpaper value itself (SPIF_UPDATEINIFILE)
            {
                if (curWorthBackup)
                {
                    WpRegWrite(key, L"PrevWallpaper", cur, dryLog);
                    WpRegWrite(key, L"PrevWallpaperStyle", curStyle, dryLog);
                    WpRegWrite(key, L"PrevTileWallpaper", curTile, dryLog);
                }
            }
            else
            {
                code = PVC_WRITING_ERROR;
                WpRegWrite(key, L"WallpaperStyle", curStyle, dryLog);
                WpRegWrite(key, L"TileWallpaper", curTile, dryLog);
            }
            free(file);
            break;
        }

        case CMD_WALLPAPER_RESTORE: // swap the current and the backed-up wallpaper
        {
            WCHAR* prev = WpRegRead(key, L"PrevWallpaper");
            WCHAR* prevStyle = WpRegRead(key, L"PrevWallpaperStyle");
            WCHAR* prevTile = WpRegRead(key, L"PrevTileWallpaper");
            // nothing backed up: nothing to restore (review S2 - it removed the wallpaper)
            if (prev != NULL && prevStyle != NULL && prevTile != NULL && prev[0] != 0)
            {
                if (prevStyle[0] != 0)
                    WpRegWrite(key, L"WallpaperStyle", prevStyle, dryLog);
                if (prevTile[0] != 0)
                    WpRegWrite(key, L"TileWallpaper", prevTile, dryLog);
                if (WpApply(prev, dryLog, &err))
                {
                    if (cur[0] != 0) // the one replaced becomes the backup (Restore again swaps back)
                    {
                        WpRegWrite(key, L"PrevWallpaper", cur, dryLog);
                        WpRegWrite(key, L"PrevWallpaperStyle", curStyle, dryLog);
                        WpRegWrite(key, L"PrevTileWallpaper", curTile, dryLog);
                    }
                }
                else
                {
                    code = PVC_WRITING_ERROR;
                    if (prevStyle[0] != 0)
                        WpRegWrite(key, L"WallpaperStyle", curStyle, dryLog);
                    if (prevTile[0] != 0)
                        WpRegWrite(key, L"TileWallpaper", curTile, dryLog);
                }
            }
            free(prev);
            free(prevStyle);
            free(prevTile);
            break;
        }

        case CMD_WALLPAPER_NONE: // no wallpaper; the current one backed up (if it is worth it)
        {
            if (cur[0] == 0)
                break; // no wallpaper already
            if (WpApply(L"", dryLog, &err))
            {
                if (curWorthBackup)
                {
                    WpRegWrite(key, L"PrevWallpaper", cur, dryLog);
                    WpRegWrite(key, L"PrevWallpaperStyle", curStyle, dryLog);
                    WpRegWrite(key, L"PrevTileWallpaper", curTile, dryLog);
                }
            }
            else
                code = PVC_WRITING_ERROR;
            break;
        }

        default:
            TRACE_E("Unknown command: " << command);
            break;
        }
    }
    free(cur);
    free(curStyle);
    free(curTile);
    RegCloseKey(key);
    free(dryLog);
    if (code != PVC_OK && code != PVC_CANCELED)
        WpShowError(HWindow, code, err);
}

void CRendererWindow::SelectTool(eTool tool)
{
    if (tool == CurrTool)
        return;

    CurrTool = tool;
    Viewer->UpdateToolBar();
    Viewer->SetStatusBarTexts();
    POINT p;
    GetCursorPos(&p);
    SetCursorPos(p.x, p.y);
}
