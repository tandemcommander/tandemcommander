// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include <zmouse.h>
#include <shlobj.h>

#include "lib\\pvw32dll.h"
#include "renderer.h"
#include "wicengine.h"                   // feature 105: Save As through the Windows encoders
#include "../../common/salsamefile.h"    // feature 105: is the target the shown file?
#include "../../common/salsafereplace.h" // feature 105: replace only by a complete file
#include "../../common/salpvsource.h"    // feature 111: the alpha question
#include "dialogs.h"
#include "pictview.h"
#include "pictview.rh"
#include "pictview.rh2"
#include "lang\lang.rh"

#define SAVEAS_GRAY_FLAG 0x40000000
#define SAVEAS_GRAY_MASK 0x3FFFFFFF

#define SAVEAS_COMMENT_FLAG 0x4000
#define SAVEAS_COMMENT_MASK 0x3FFF

typedef struct _gen_ftype
{
    LPCTSTR ext;
    int type;
} PVFS_FTYPE;

static PVFS_FTYPE fs_types[] = {
    {_T("jpg"), PVF_JPG | SAVEAS_COMMENT_FLAG},
    {_T("bmp"), PVF_BMP},
    {_T("tif"), PVF_TIFF | SAVEAS_COMMENT_FLAG},
    {_T("gif"), PVF_GIF | SAVEAS_COMMENT_FLAG},
    {_T("tga"), PVF_TGA},
    {_T("wbmp"), PVF_WBMP},
    {_T("cel"), PVF_CEL},
    {_T("cit"), PVF_IRF | SAVEAS_COMMENT_FLAG},
    {_T("dat"), PVF_IRF | SAVEAS_COMMENT_FLAG},
    {_T("pbm"), PVF_PNM},
    {_T("pnm"), PVF_PNM},
    {_T("png"), PVF_PNG | SAVEAS_COMMENT_FLAG},
    {_T("iff"), PVF_LBM},
    {_T("rgb"), PVF_SGI},
    {_T("bw"), PVF_SGI},
    {_T("ras"), PVF_RAS},
    {_T("ska"), PVF_SKA},
    {_T("rle"), PVF_RLE},
    {_T("pcx"), PVF_PCX},
    {NULL, 0}};

static PVFS_FTYPE fs_comptypes[] = {
    {_T("ASCII"), PVCS_ASCII},
    {_T("CCITT G3"), PVCS_CCITT_3},
    {_T("CCITT G4"), PVCS_CCITT_4},
    {_T("Deflating (LZ77)"), PVCS_DEFLATE},
    {_T("Huffman"), PVCS_HUFFMAN},
    {_T("JPEG"), PVCS_JPEG_HUFFMAN},
    {_T("Lempel-Ziv-Welch (LZW)"), PVCS_LZW},
    {_T("PackBits"), PVCS_PACKBITS},
    {_T("Run-Length Encoding"), PVCS_RLE},
    {_T("Uncompressed"), PVCS_NO_COMPRESSION},
    {NULL, 0}};

void GetMyDocumentsPath(LPTSTR initDir)
{
    // feature 104: UTF-8 (the start folder of the Unicode Save As dialog); 'initDir' is
    // MAX_PATH bytes - a longer UTF-8 form leaves it empty (the dialog's own default)
    initDir[0] = 0;
    ITEMIDLIST* pidl = NULL;
    if (SHGetSpecialFolderLocation(NULL, CSIDL_PERSONAL, &pidl) == NOERROR)
    {
        WCHAR pathW[MAX_PATH];
        if (!SHGetPathFromIDListW(pidl, pathW) || SplWToU8(pathW, initDir, MAX_PATH) == 0)
            initDir[0] = 0;
        IMalloc* alloc;
        if (SUCCEEDED(CoGetMalloc(1, &alloc)))
        {
            alloc->Free(pidl);
            alloc->Release();
        }
    }
}

// feature 104: a message naming the save target: the code-page template (LoadStr) with the
// UTF-8 name, composed as UTF-16 and stored as UTF-8 - the whole text in one encoding, so the
// core shows the name exactly (a code-page template with a UTF-8 name in it showed one of the
// two garbled). Falls back to the plain composition if anything fails.
static void FormatNameMessageU8(char* out, int outSize, const char* cpTemplate, const char* u8Name)
{
    WCHAR* fmtW = SplFileDlgDetail::CodePageToWAlloc(cpTemplate);
    WCHAR* nameW = SplU8ToWAlloc(u8Name);
    BOOL done = FALSE;
    if (fmtW != NULL && nameW != NULL)
    {
        // feature 105: IDS_SAVEERROR has "%hs" (a char* text); the text is wide here
        for (WCHAR* f = wcsstr(fmtW, L"%hs"); f != NULL; f = wcsstr(f + 1, L"%hs"))
            memmove(f + 1, f + 2, (wcslen(f + 2) + 1) * sizeof(WCHAR)); // "%hs" -> "%s"
        WCHAR text[2048];
        if (_snwprintf_s(text, _TRUNCATE, fmtW, nameW) >= 0 && SplWToU8(text, out, outSize) > 0)
            done = TRUE;
    }
    free(fmtW);
    free(nameW);
    if (!done)
        _snprintf_s(out, outSize, _TRUNCATE, cpTemplate, u8Name);
}

// feature 111: the same for the wallpaper commands (render2.cpp)
void FormatSaveErrorU8(char* out, int outSize, const char* detailU8)
{
    FormatNameMessageU8(out, outSize, LoadStr(IDS_SAVEERROR), detailU8);
}

typedef struct tagProgBarInfo
{
    CViewerWindow* pViewer;
    DWORD lastUpdateTicks;
    DWORD lastCheckTicks;
} sProgBarInfo, *psProgBarInfo;

BOOL WINAPI SaveProgressProcedure(int done, void* data)
{
    DWORD ticks = GetTickCount();

    if ((ticks - ((psProgBarInfo)data)->lastUpdateTicks > 100) || (done > 95))
    {
        // for performance reasons, do it just 3 times a second
        ((psProgBarInfo)data)->pViewer->SetProgress(done);
        ((psProgBarInfo)data)->lastUpdateTicks = ticks;
    }
    if (ticks - ((psProgBarInfo)data)->lastCheckTicks > 500)
    {
        // for performance reasons, do it just twice a second
        MSG msg;
        HWND hWnd = ((psProgBarInfo)data)->pViewer->HWindow;

        while (PeekMessage(&msg, hWnd, WM_KEYUP, WM_KEYUP, PM_NOREMOVE))
        {
            int nVirtKey;    // virtual-key code
            LPARAM lKeyData; // key data

            GetMessage(&msg, hWnd, WM_KEYUP, WM_KEYUP);
            nVirtKey = (int)msg.wParam;
            lKeyData = msg.lParam;
            if (nVirtKey == 27)
            { // virtual-key code for ESC
                while (PeekMessage(&msg, hWnd, WM_KEYDOWN, WM_KEYDOWN, PM_REMOVE))
                {
                }
                return TRUE;
            }
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }
        ((psProgBarInfo)data)->lastCheckTicks = ticks;
    }

    return FALSE;
}

// feature 105: the format (PVF_xxx) of a filter pattern ("*.jpg;*.jpeg"), by the same rule as
// GetFormatInfo (the first extension the table knows); 0 = unknown
static DWORD FormatOfPattern(LPCTSTR s)
{
    PVFS_FTYPE* ftype = fs_types;
    while ((s = _tcschr(s, '.')) != NULL)
    {
        s++;
        while (ftype->ext)
        {
            if (!_tcsnicmp(ftype->ext, s, _tcslen(ftype->ext)))
                return ftype->type & SAVEAS_COMMENT_MASK;
            ftype++;
        }
    }
    return 0;
}

// feature 105: 'all' is the language's "description|pattern|..." list (split in place); 'out'
// gets the double-NUL list of the entries whose format the Windows encoders write, 'keptFull'
// their 1-based indexes in the whole list. Returns how many were kept.
static int BuildSaveFilter(LPTSTR all, LPTSTR out, int outSize, int* keptFull, int maxKept)
{
    int kept = 0, index = 0;
    LPTSTR o = out;
    LPTSTR end = out + outSize - 1; // room for the closing NUL
    LPTSTR p = all;
    while (*p != 0)
    {
        LPTSTR desc = p;
        LPTSTR bar = _tcschr(p, '|');
        if (bar == NULL)
            break;
        *bar = 0;
        LPTSTR pattern = bar + 1;
        LPTSTR bar2 = _tcschr(pattern, '|');
        if (bar2 != NULL)
            *bar2 = 0;
        index++;
        size_t descLen = _tcslen(desc), patLen = _tcslen(pattern);
        if (WicCanEncodeFormat(FormatOfPattern(pattern)) && kept < maxKept &&
            (size_t)(end - o) > descLen + patLen + 2)
        {
            memcpy(o, desc, (descLen + 1) * sizeof(TCHAR));
            o += descLen + 1;
            memcpy(o, pattern, (patLen + 1) * sizeof(TCHAR));
            o += patLen + 1;
            keptFull[kept++] = index;
        }
        if (bar2 == NULL)
            break;
        p = bar2 + 1;
    }
    *o = 0;
    return kept;
}

// feature 105: the dialog's (1-based) filter index for the stored index of the whole list; a
// stored format that is not offered any more falls back to Windows Bitmap (the old default)
static DWORD SaveFilterShownIndex(int lastFull, LPCTSTR filter, const int* keptFull, int keptCount)
{
    for (int k = 0; k < keptCount; k++)
        if (keptFull[k] == lastFull)
            return k + 1;
    LPCTSTR s = filter;
    for (int k = 0; k < keptCount && *s != 0; k++)
    {
        s += _tcslen(s) + 1; // the pattern
        if (FormatOfPattern(s) == PVF_BMP)
            return k + 1;
        s += _tcslen(s) + 1;
    }
    return 1;
}

void EnableDisableControls(HWND hDlg, int firstID, int lastID, BOOL bEnable)
{
    for (; firstID <= lastID; firstID++)
    {
        EnableWindow(GetDlgItem(hDlg, firstID), bEnable);
    }
} /* EnableDisableControls */

void PositionControl(HWND hDlg, int baseID, int moveID)
{
    RECT r1, r2;
    HWND hParent;

    hParent = GetParent(hDlg);
    // Our templated dialog is a subwindow of the main common dlg window
    // GetWindowRect returns screen coordinates
    GetWindowRect(GetDlgItem(hParent, baseID), &r1);
    GetWindowRect(GetDlgItem(hDlg, moveID), &r2);
    ScreenToClient(hParent, (LPPOINT)&r1);
    ScreenToClient(hParent, &((LPPOINT)&r1)[1]);
    ScreenToClient(hDlg, (LPPOINT)&r2);
    ScreenToClient(hDlg, &((LPPOINT)&r2)[1]);
    SetWindowPos(GetDlgItem(hDlg, moveID), 0, r1.left, r2.top,
                 r1.right - r1.left, r2.bottom - r2.top, SWP_NOZORDER | SWP_SHOWWINDOW);
} /* PositionControl */

void FillCombo(HWND hWnd, int controlID, TwoDWords* pData, DWORD value)
{
    hWnd = GetDlgItem(hWnd, controlID);

    while (pData[0][0])
    {
        LRESULT index = SendMessage(hWnd, CB_ADDSTRING, 0, (LPARAM)LoadStr(pData[0][0]));
        SendMessage(hWnd, CB_SETITEMDATA, index, pData[0][1]);
        if (!index || (pData[0][1] == value))
        {
            // select first or with required data
            SendMessage(hWnd, CB_SETCURSEL, index, 0);
        }
        pData++;
    }
} /* FillCombo */

DWORD GetItemData(HWND hWnd, int controlID)
{
    hWnd = GetDlgItem(hWnd, controlID);
    return (DWORD)SendMessage(hWnd, CB_GETITEMDATA, SendMessage(hWnd, CB_GETCURSEL, 0, 0), 0);
} /* GetItemData */

BOOL GetFormatInfo(OPENFILENAME* lpOFN, DWORD* pFormat, LPTSTR* pExt)
{
    // given list of filters & filter index, extract PVF_xxx & default format extension
    // returns TRUE if the format supports comment (or better to say, we support saving it ;))
    // feature 104: 'lpOFN' may be the Unicode dialog's OPENFILENAMEW (the hook's lParam, the
    // notification's lpOFN) - only nFilterIndex and lCustData are read from it (the same offsets
    // in both forms); the code-page filter list comes from SAVEAS_INFO::FilterA
    int i = 2 * lpOFN->nFilterIndex - 1;
    LPTSTR s = (LPTSTR)((SAVEAS_INFO_PTR)lpOFN->lCustData)->FilterA;
    PVFS_FTYPE* ftype = fs_types;

    while (i--)
    {
        s += _tcslen(s) + 1;
    }
    *pFormat = 0;
    while ((s = (LPTSTR)_tcschr(s, '.')) != NULL)
    {
        if (pExt)
            *pExt = s;
        s++;
        while (ftype->ext)
        {
            if (!_tcsnicmp(ftype->ext, s, _tcslen(ftype->ext)))
            {
                *pFormat = ftype->type & SAVEAS_COMMENT_MASK;
                return (ftype->type & SAVEAS_COMMENT_FLAG) ? TRUE : FALSE;
            }
            ftype++;
        }
    }
    return FALSE;
} /* GetFormatInfo */

void FillTypeFmt(HWND hDlg, OPENFILENAME* lpOFN, BOOL bUpdCompressions, BOOL bUpdBitDepths, BOOL onlyEnable)
{
    DWORD format;
    //  char   *ext;
    PVFS_FTYPE* ctype = fs_comptypes;
    int cnt = 0, i, compr = PVCS_DEFAULT;
    LRESULT index;
    DWORD cm, clrs;
    BOOL bSelected = FALSE;
    HWND hCtrl;
    static TwoWords colorDepths[] = {{2, IDS_CLRS_MONO},
                                     {16, IDS_CLRS_16},
                                     {256, IDS_CLRS_256},
                                     {256, IDS_CLRS_256GR},
                                     {PV_COLOR_HC15, IDS_CLRS_HC15},
                                     {PV_COLOR_HC16, IDS_CLRS_HC16},
                                     {PV_COLOR_TC24, IDS_CLRS_TC24},
                                     {PV_COLOR_TC32, IDS_CLRS_TC32}};

    EnableDisableControls(hDlg, IDC_SAVE_COMMENT_FIRST, IDC_SAVE_COMMENT_LAST,
                          GetFormatInfo(lpOFN, &format, NULL /*&ext*/));
    if (!onlyEnable)
    {
        cm = ((SAVEAS_INFO_PTR)lpOFN->lCustData)->pvii->ColorModel;
        clrs = ((SAVEAS_INFO_PTR)(lpOFN->lCustData))->pvii->Colors;

        if (clrs == 2)
        {
            // save bilevel images as bilevel by default: some format may claim PVCM_GRAYS
            cm = PVCM_RGB;
        }
        hCtrl = GetDlgItem(hDlg, IDC_SAVE_BIT_DEPTH);
        if (bUpdBitDepths)
        {
            if (!bUpdCompressions)
            {
                // user clicked compressions -> update available bit-depths
                compr = GetItemData(hDlg, IDC_SAVE_COMPRESSION);
                if (compr < 0)
                {
                    compr = PVCS_DEFAULT;
                }
            }
            SendMessage(hCtrl, CB_RESETCONTENT, 0, 0);
            if ((clrs > 2) && (clrs < 16))
                clrs = 16;
            if ((clrs > 16) && (clrs < 256))
                clrs = 256;
            // Patera 2005.03.20: Save originally 32bit images as 24bit: The alpha was lost anyway
            if (clrs == PV_COLOR_TC32)
                clrs = PV_COLOR_TC24;
            // 256 Grayscale are coded as 256 | SAVEAS_GRAY_FLAG in item data
            for (i = 0; i < sizeof(colorDepths) / sizeof(colorDepths[0]); i++)
            {
                if ((colorDepths[i][0] >= clrs) || (i > 0))
                {
                    if (PVW32DLL.PVIsOutCombSupported(format, compr, colorDepths[i][0],
                                                      colorDepths[i][1] != IDS_CLRS_256GR ? PVCM_RGB : PVCM_GRAYS) != -1)
                    {
                        index = SendMessage(hCtrl, CB_ADDSTRING, 0, (LPARAM)LoadStr(colorDepths[i][1]));
                        SendMessage(hCtrl, CB_SETITEMDATA, index, colorDepths[i][0] | (colorDepths[i][1] != IDS_CLRS_256GR ? 0 : SAVEAS_GRAY_FLAG));
                        if ((clrs == colorDepths[i][0]) && ((colorDepths[i][1] != IDS_CLRS_256GR) ^ (cm == PVCM_GRAYS)))
                        {
                            SendMessage(hCtrl, CB_SETCURSEL, index, 0);
                            bSelected = TRUE;
                        }
                    }
                }
            }
            if (!bSelected)
            {
                // Selected format doesn't support chosen bitdepth -> find the smallest higher
                // or highest smaller non-grays if there is no higher
                for (i = 0; i < SendMessage(hCtrl, CB_GETCOUNT, 0, 0); i++)
                {

                    DWORD clrs2 = (DWORD)SendMessage(hCtrl, CB_GETITEMDATA, i, 0); // X64 - ITEMDATA contains a DWORD
                    if (!(clrs2 & SAVEAS_GRAY_FLAG))
                    {
                        SendMessage(hCtrl, CB_SETCURSEL, i, 0);
                    }
                    if (((clrs2 & SAVEAS_GRAY_MASK) >= clrs) && (((clrs2 & SAVEAS_GRAY_FLAG) == 0) ^ (cm == PVCM_GRAYS)))
                    {
                        // Note: can never be equal
                        clrs = clrs2;
                        break;
                    }
                    if ((clrs == PV_COLOR_TC32) && (clrs2 == PV_COLOR_TC24))
                    {
                        // saving 32bit image to a format supporting 24 bits at max
                        clrs = PV_COLOR_TC24;
                    }
                }
            }
        }
        else
        {
            clrs = GetItemData(hDlg, IDC_SAVE_BIT_DEPTH);
            if (clrs & SAVEAS_GRAY_FLAG)
            {
                cm = PVCM_GRAYS;
                clrs &= SAVEAS_GRAY_MASK;
            }
        }
        hCtrl = GetDlgItem(hDlg, IDC_SAVE_COMPRESSION);
        if (bUpdCompressions)
        {
            LRESULT oldCompr = -1;

            bSelected = FALSE;
            // Get the current selection, if any
            index = SendMessage(hCtrl, CB_GETCURSEL, 0, 0);
            if (index >= 0)
            {
                oldCompr = SendMessage(hCtrl, CB_GETITEMDATA, index, 0);
                if (bUpdBitDepths && (((oldCompr == PVCS_JPEG_HUFFMAN) || (oldCompr == PVCS_NO_COMPRESSION)) && (format == PVF_TIFF)))
                {
                    // looks like changing file format from JPEG to TIFF -> don't make JPEG-compr or raw the default for TIFF
                    oldCompr = -1;
                }
            }
            SendMessage(hCtrl, CB_RESETCONTENT, 0, 0);
            while (ctype->ext)
            {
                if (PVW32DLL.PVIsOutCombSupported(format, ctype->type, clrs,
                                                  cm == PVCM_CMYK ? PVCM_RGB : cm) != -1)
                {
                    index = SendMessage(hCtrl, CB_ADDSTRING, 0, (LPARAM)ctype->ext);
                    SendMessage(hCtrl, CB_SETITEMDATA, index, ctype->type);
                    if (ctype->type == oldCompr)
                    {
                        // restore the original selection
                        SendMessage(hCtrl, CB_SETCURSEL, index, 0);
                        bSelected = TRUE;
                    }
                    cnt++;
                }
                ctype++;
            }
            if (cnt != 1)
            {
                // Note: cnt is zero for formats not directly supporting this bit depth (i.e. saving TC img as GIF)
                SendMessage(hCtrl, CB_INSERTSTRING, 0, (LPARAM)LoadStr(IDS_SAVE_DEFAULT));
            }
            if (!bSelected)
            {
                // select the first (default or only) compression if nothing is selected yet
                SendMessage(hCtrl, CB_SETCURSEL, 0 /*index*/, 0);
            }
        }
    }
    cnt = GetItemData(hDlg, IDC_SAVE_COMPRESSION);
    // feature 105: the Windows GIF encoder has no interlacing and always writes GIF89a, the TIFF
    // encoder has no strip size - those options stay visible but cannot be chosen
    EnableDisableControls(hDlg, IDC_SAVE_GIF_FIRST, IDC_SAVE_GIF_LAST, FALSE);
    EnableDisableControls(hDlg, IDC_SAVE_JPEG_FIRST, IDC_SAVE_JPEG_LAST, (format == PVF_JPG) || (cnt == PVCS_JPEG_HUFFMAN));
    EnableDisableControls(hDlg, IDC_SAVE_TIFF_FIRST, IDC_SAVE_TIFF_LAST, FALSE);

    RECT r1, r2;
    GetWindowRect(GetParent(hDlg), &r1);
    GetWindowRect(GetDlgItem(hDlg, IDC_SAVE_ADVANCED), &r2);
    BOOL advancedVersion = r2.bottom + 50 <= r1.bottom;
    if (!advancedVersion)
        EnableDisableControls(hDlg, IDC_SAVE_ADVANCED_FIRST, IDC_SAVE_ADVANCED_LAST, FALSE); // Advanced section is collapsed -> disable everything (prevents TAB navigation through it)
} /* FillTypeFmt */

void OnSaveAsCommand(HWND hDlg, WPARAM wParam, LPARAM lParam)
{
    RECT r1, r2;

    switch
        LOWORD(wParam)
        {
        case IDC_SAVE_ADVANCED:
        {
            GetWindowRect(GetParent(hDlg), &r1);
            GetWindowRect(GetDlgItem(hDlg, IDC_SAVE_ADVANCED), &r2);
            BOOL shortVersion = (r2.bottom + 50 > r1.bottom);
            CheckDlgButton(hDlg, IDC_SAVE_ADVANCED, shortVersion ? BST_CHECKED : BST_UNCHECKED);
            if (shortVersion)
            {
                // only the short version is visible
                GetWindowRect(GetDlgItem(hDlg, IDC_SAVE_GROUP_TIFF), &r2);
                EnableDisableControls(hDlg, IDC_SAVE_ADVANCED_FIRST, IDC_SAVE_ADVANCED_LAST, TRUE); // Advanced section will be expanded -> enable everything (allows TAB navigation through it)
            }
            r1.bottom = r2.bottom + 10;
            SetWindowPos(GetParent(hDlg), 0, 0, 0,
                         r1.right - r1.left, r1.bottom - r1.top, SWP_NOZORDER | SWP_NOMOVE | SWP_SHOWWINDOW);
            SetWindowPos(hDlg, 0, 0, 0,
                         r1.right - r1.left, r2.bottom - r1.top, SWP_NOZORDER | SWP_NOMOVE | SWP_SHOWWINDOW);
            FillTypeFmt(hDlg, (OPENFILENAME*)GetWindowLongPtr(hDlg, GWLP_USERDATA), FALSE, FALSE, TRUE);
            break;
        }
        case IDC_SAVE_COMPRESSION:
            if (HIWORD(wParam) == CBN_SELCHANGE)
            {
                FillTypeFmt(hDlg, (OPENFILENAME*)GetWindowLongPtr(hDlg, GWLP_USERDATA), FALSE, TRUE, FALSE);
            }
            break;
        case IDC_SAVE_BIT_DEPTH:
            if (HIWORD(wParam) == CBN_SELCHANGE)
            {
                FillTypeFmt(hDlg, (OPENFILENAME*)GetWindowLongPtr(hDlg, GWLP_USERDATA), TRUE, FALSE, FALSE);
            }
            break;
        }
} /* OnSaveAsCommand */

BOOL CALLBACK MoveControlsProc(HWND hWnd, LPARAM shift)
{
    int ID = GetDlgCtrlID(hWnd);

    if ((ID != IDC_SAVE_COMPRESSION_LABEL) && (ID != IDC_SAVE_COMPRESSION) && (ID != IDC_SAVE_ADVANCED))
    {
        RECT r;

        GetWindowRect(hWnd, &r);
        ScreenToClient(GetParent(hWnd), (LPPOINT)&r);
        SetWindowPos(hWnd, 0, r.left + (int)shift, r.top, 0, 0, SWP_NOZORDER | SWP_SHOWWINDOW | SWP_NOSIZE);
    }
    return TRUE;
}

void PositionControls(HWND hDlg)
{
    RECT r1, r2;

    // Determine the horizontal shift
    GetWindowRect(GetDlgItem(hDlg, IDC_SAVE_COMPRESSION_LABEL), &r1);
    PositionControl(hDlg, 0x441, IDC_SAVE_COMPRESSION_LABEL);
    GetWindowRect(GetDlgItem(hDlg, IDC_SAVE_COMPRESSION_LABEL), &r2);
    PositionControl(hDlg, 0x470, IDC_SAVE_COMPRESSION);
    PositionControl(hDlg, IDCANCEL, IDC_SAVE_ADVANCED);
    EnumChildWindows(hDlg, MoveControlsProc, r2.left - r1.left);
} /* PositionControls */

UINT_PTR CALLBACK SaveAsDlgProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    union
    {
        LPOFNOTIFY lpOFNot;
        SAVEAS_INFO_PTR psai;
        HWND hCtrl;
    };
    static TwoDWords sRots[] = {
        {IDS_ROT_NONE, 0},
        {IDS_ROT_90, PVSF_ROTATE90},
        {IDS_ROT_180, PVSF_FLIP_VERT | PVSF_FLIP_HOR},
        {IDS_ROT_270, PVSF_ROTATE90 | PVSF_FLIP_VERT | PVSF_FLIP_HOR},
        {0, 0}};
    static TwoDWords sFlips[] = {
        {IDS_FLIP_NONE, 0},
        {IDS_FLIP_VERT, PVSF_FLIP_VERT},
        {IDS_FLIP_HOR, PVSF_FLIP_HOR},
        {0, 0}};

    CALL_STACK_MESSAGE5("SaveAsDlgProc(h: 0x%p, m: 0x%x, w: 0x%IX, l: 0x%IX", hDlg, uMsg, wParam, lParam);

    switch (uMsg)
    {
    case WM_INITDIALOG:
        // SalamanderGUI->ArrangeHorizontalLines(hDlg);  // not used for Windows common dialogs
        PositionControls(hDlg);

        SalamanderGUI->AttachButton(hDlg, IDC_SAVE_ADVANCED, BTF_MORE | BTF_CHECKBOX);

        FillTypeFmt(hDlg, (OPENFILENAME*)lParam, TRUE, TRUE, FALSE);
        EnableDisableControls(hDlg, IDC_SAVE_ADVANCED_FIRST, IDC_SAVE_ADVANCED_LAST, FALSE); // Advanced section is collapsed -> disable everything (prevents TAB navigation through it)
        SetWindowLongPtr(hDlg, GWLP_USERDATA, lParam);
        psai = (SAVEAS_INFO_PTR)(((OPENFILENAME*)lParam)->lCustData);
        FillCombo(hDlg, IDC_SAVE_ROTATION, sRots, psai->Rotation);
        FillCombo(hDlg, IDC_SAVE_FLIP, sFlips, psai->Flip);
        if (psai->Flags & PVSF_INVERT)
        {
            CheckDlgButton(hDlg, IDC_SAVE_INVERT, BST_CHECKED);
        }
        if (G.Save.Flags & PVSF_INTERLACE)
        {
            CheckDlgButton(hDlg, IDC_SAVE_GIF_INTERLACED, BST_CHECKED);
        }
        if (G.Save.Flags & PVSF_GIF89)
        {
            CheckDlgButton(hDlg, IDC_SAVE_GIF_89a, BST_CHECKED);
        }
        if (!(G.Save.Flags & PVSF_DO_NOT_STRIP))
        {
            CheckDlgButton(hDlg, IDC_SAVE_TIFF_MAKE_STRIPS, BST_CHECKED);
        }

        SetDlgItemInt(hDlg, IDC_SAVE_JPEG_QUALITY, G.Save.JPEGQuality, FALSE);
        SendDlgItemMessage(hDlg, IDC_SAVE_JPEG_QUALITY, EM_LIMITTEXT, 3, 0);
        hCtrl = GetDlgItem(hDlg, IDC_SAVE_JPEG_SUBSAMPLING);
        SendMessage(hCtrl, CB_ADDSTRING, 0, (LPARAM) _T("1:1:1"));
        SendMessage(hCtrl, CB_ADDSTRING, 0, (LPARAM) _T("2:1:1"));
        SendMessage(hCtrl, CB_SETCURSEL, G.Save.JPEGSubsampling, 0);
        SetDlgItemInt(hDlg, IDC_SAVE_TIFF_STRIP_SIZE, G.Save.TIFFStripSize, FALSE);
        SendDlgItemMessage(hDlg, IDC_SAVE_COMMENT, EM_LIMITTEXT, SAVEAS_MAX_COMMENT_SIZE - 1, 0);
        SalamanderGeneral->MultiMonCenterWindow(GetParent(hDlg), GetParent(GetParent(hDlg)), FALSE);
        break;
    case WM_COMMAND:
        OnSaveAsCommand(hDlg, wParam, lParam);
        break;
    case WM_DESTROY:
        psai = (SAVEAS_INFO_PTR)((OPENFILENAME*)GetWindowLongPtr(hDlg, GWLP_USERDATA))->lCustData;
        psai->Compression = GetItemData(hDlg, IDC_SAVE_COMPRESSION);
        psai->Flags = 0;
        psai->Flip = psai->Flags |= GetItemData(hDlg, IDC_SAVE_FLIP);
        // Note: must remain ^= to anihilate double flip flags
        psai->Flags ^= psai->Rotation = GetItemData(hDlg, IDC_SAVE_ROTATION);
        psai->Colors = GetItemData(hDlg, IDC_SAVE_BIT_DEPTH);
        if (IsDlgButtonChecked(hDlg, IDC_SAVE_INVERT))
        {
            psai->Flags |= PVSF_INVERT;
        }
        {
            // feature 105: the field is a Unicode control (the dialog is GetSaveFileNameW since 104);
            // the comment is stored in the image as UTF-8 text
            WCHAR commentW[SAVEAS_MAX_COMMENT_SIZE];
            if (GetDlgItemTextW(hDlg, IDC_SAVE_COMMENT, commentW, SAVEAS_MAX_COMMENT_SIZE) == 0 ||
                SplWToU8(commentW, psai->Comment, SAVEAS_MAX_COMMENT_BYTES) == 0)
                psai->Comment[0] = 0;
        }
        G.Save.Flags = 0;
        if (IsDlgButtonChecked(hDlg, IDC_SAVE_GIF_INTERLACED))
        {
            G.Save.Flags |= PVSF_INTERLACE;
        }
        if (IsDlgButtonChecked(hDlg, IDC_SAVE_GIF_89a))
        {
            G.Save.Flags |= PVSF_GIF89;
        }
        if (!IsDlgButtonChecked(hDlg, IDC_SAVE_TIFF_MAKE_STRIPS))
        {
            G.Save.Flags |= PVSF_DO_NOT_STRIP;
        }
        G.Save.JPEGQuality = GetDlgItemInt(hDlg, IDC_SAVE_JPEG_QUALITY, NULL, FALSE);
        G.Save.JPEGQuality = min(100, G.Save.JPEGQuality);
        G.Save.JPEGQuality = max(G.Save.JPEGQuality, 1);
        G.Save.JPEGSubsampling = (DWORD)SendDlgItemMessage(hDlg, IDC_SAVE_JPEG_SUBSAMPLING, CB_GETCURSEL, 0, 0);
        G.Save.TIFFStripSize = GetDlgItemInt(hDlg, IDC_SAVE_TIFF_STRIP_SIZE, NULL, FALSE);
        break;
    case WM_NOTIFY:
        lpOFNot = (LPOFNOTIFY)lParam;
        if (lpOFNot->hdr.code == CDN_TYPECHANGE)
        {
            FillTypeFmt(hDlg, lpOFNot->lpOFN, TRUE, TRUE, FALSE);
        }
        break;
    }
    return FALSE;
}

const char* StrIStr(const char* txt, const char* pattern)
{
    if (txt == NULL || pattern == NULL)
        return NULL;

    const char* s = txt;
    int len = (int)strlen(pattern);
    int txtLen = (int)strlen(txt);
    while (txtLen >= len)
    {
        if (SalamanderGeneral->StrNICmp(s, pattern, len) == 0)
            return s;
        s++;
        txtLen--;
    }
    return NULL;
}

// feature 104: GetSaveFileNameW for the Save As dialog's OPENFILENAME: lpstrFile and
// lpstrInitialDir are UTF-8 (in/out, nMaxFile bytes), lpstrFilter and lpstrDefExt code-page
// text; the hook (SaveAsDlgProc) and the template stay. nFilterIndex, nFileOffset and
// nFileExtension (bytes of the UTF-8 result) come back as from the A dialog. The core's
// SafeGetSaveFileName retry (Windows refuses an initial name like "C:\") is kept. A picked
// name whose UTF-8 form does not fit is refused with a message (FALSE, as Cancel).
static BOOL SaveAsDialogU8(OPENFILENAME* ofn)
{
    const DWORD fileUnits = 32768;
    WCHAR* file = (WCHAR*)malloc(fileUnits * sizeof(WCHAR));
    if (file == NULL)
        return FALSE;
    if (SplU8ToW(ofn->lpstrFile, file, fileUnits) == 0)
        file[0] = 0;
    WCHAR* initDir = ofn->lpstrInitialDir != NULL && ofn->lpstrInitialDir[0] != 0 ? SplU8ToWAlloc(ofn->lpstrInitialDir) : NULL;
    size_t prefixLen = SplFileDlgDetail::NameIntoInitialDir(file, fileUnits, initDir); // feature 121: open in initDir (Windows may ignore it)
    WCHAR* filter = SplFileDlgDetail::CodePageListToWAlloc(ofn->lpstrFilter);
    WCHAR* defExt = SplFileDlgDetail::CodePageToWAlloc(ofn->lpstrDefExt);
    WCHAR* title = SplFileDlgDetail::CodePageToWAlloc(ofn->lpstrTitle);

    OPENFILENAMEW w;
    memset(&w, 0, sizeof(w));
    w.lStructSize = sizeof(w);
    w.hwndOwner = ofn->hwndOwner;
    w.hInstance = ofn->hInstance;
    w.lpstrFilter = filter;
    w.nFilterIndex = ofn->nFilterIndex;
    w.lpstrFile = file;
    w.nMaxFile = fileUnits;
    w.lpstrInitialDir = initDir;
    w.lpstrTitle = title;
    w.Flags = ofn->Flags;
    w.lpstrDefExt = defExt;
    w.lCustData = ofn->lCustData;
    w.lpfnHook = ofn->lpfnHook;
    w.lpTemplateName = IS_INTRESOURCE(ofn->lpTemplateName) ? (LPCWSTR)ofn->lpTemplateName : NULL;

    BOOL ret = GetSaveFileNameW(&w);
    if (!ret && CommDlgExtendedError() == FNERR_INVALIDFILENAME && SplFileDlgDetail::BareNameBack(file, prefixLen))
        ret = GetSaveFileNameW(&w); // feature 121 (review SF1): a remembered folder that is gone - the bare name as before
    if (!ret && CommDlgExtendedError() == FNERR_INVALIDFILENAME)
    {
        file[0] = 0;
        w.lpstrInitialDir = NULL;
        ret = GetSaveFileNameW(&w);
    }
    if (ret)
    {
        ofn->nFilterIndex = w.nFilterIndex;
        if (SplWToU8(file, ofn->lpstrFile, ofn->nMaxFile) == 0)
        {
            ofn->lpstrFile[0] = 0;
            SplShowNameTooLong(ofn->hwndOwner, LoadStr(IDS_ERRORTITLE));
            ret = FALSE;
        }
        else
            SplFileDlgDetail::NameOffsets(ofn->lpstrFile, &ofn->nFileOffset, &ofn->nFileExtension);
    }
    free(file);
    free(initDir);
    free(filter);
    free(defExt);
    free(title);
    return ret;
}

BOOL CRendererWindow::OnFileSaveAs(LPCTSTR pInitDir)
{
    static int cntClipboard = 1;
    static int cntCapture = 1;
    static int cntScan = 1;
    static SAVEAS_INFO sai = {PVCS_DEFAULT, 0, 0, 0, 0, 0, ""};
    SAVEAS_INFO lsai;
    TCHAR errBuff[1000];
    TCHAR fileName[MAX_PATH];
    LPTSTR s;
    int* pCnt = NULL;
    struct
    {
        OPENFILENAME ofn;
#if _WIN32_WINNT < 0x0500
        // Ver5 struct size needed for showing Favorites when template is used
        void* pvReserved;
        DWORD dwReserved;
        DWORD FlagsEx;
#endif
    } ofn;
    int ret;
    DWORD format;
    TCHAR initDir[MAX_PATH] = _T("");

    // feature 111: the source as the file holds it. The engine reports every image as 32-bit (its rows),
    // so every PNG/TIFF/ICO asked about a lost alpha channel and "2 colors" (with the CCITT TIFF
    // compressions) was never offered; now the question comes only when the alpha channel is really
    // used (a pixel that is not opaque), and the dialog starts from the source's depth
    PVImageInfo srcInfo;
    GetSourceImageInfo(&srcInfo);
    CWicSourceFormat srcFormat;
    BOOL alphaLost = PVHandle != NULL && WicGetSourceFormat(PVHandle, &srcFormat) &&
                     SalAlphaWouldBeLost(srcFormat.HasAlpha, srcFormat.AlphaUsed);
    if (alphaLost)
    {
        /*     MSGBOXEX_PARAMS  mboxParams;

     memset(&mboxParams, 0, sizeof(mboxParams));
     mboxParams.HParent = HWindow;
     mboxParams.Text = LoadStr(IDS_SAVE_LOST_ALPHA); mboxParams.Caption = LoadStr(IDS_PLUGINNAME);
     mboxParams.Flags = MSGBOXEX_YESNO | MSGBOXEX_ICONQUESTION | MSGBOXEX_SILENT | MSGBOXEX_ESCAPEENABLED;
     mboxParams.CheckBoxText = LoadStr(IDS_DONT_SHOW_AGAIN);
*/
        if (!(G.DontShowAnymore & DSA_ALPHA_LOST))
        {
            BOOL bChecked = FALSE;
            int ret2 = ShowOneTimeMessage(HWindow, IDS_SAVE_LOST_ALPHA, &bChecked,
                                          MSGBOXEX_YESNO | MSGBOXEX_ICONQUESTION | MSGBOXEX_SILENT,
                                          IDS_DONT_SHOW_AGAIN_SLA);

            if (bChecked)
            {
                G.DontShowAnymore |= DSA_ALPHA_LOST;
            }
            if (IDYES != ret2)
            {
                //            SalamanderGeneral->SalMessageBoxEx(&mboxParams)
                return FALSE;
            }
        }
    }
    // use local copy to make several simultaneously open SaveAs dialogs work
    lsai = sai;
    lsai.FilterA = NULL; // set below, together with the filter list
    if (pInitDir)
    {
        lstrcpyn(initDir, pInitDir, SizeOf(initDir));
    }
    else
    {
        if (FileName[0] == '<')
        {
            lstrcpyn(initDir, G.Save.InitDir, SizeOf(initDir));
        }
        else
        {
            lstrcpyn(initDir, FileName, SizeOf(initDir));
            if (!SalamanderGeneral->CutDirectory(initDir))
                initDir[0] = 0;
        }
    }

    if (initDir[0] == 0)
        GetMyDocumentsPath(initDir);

    // store the filename without path and suffix
    s = (LPTSTR)_tcsrchr(FileName, '\\');
    // feature 105: bounded - a name component of the shown file may take up to 765 bytes of UTF-8,
    // 'fileName' holds MAX_PATH (a longer name is not suggested; the dialog's own default applies)
    if (_tcslen(s ? (s + 1) : FileName) < SizeOf(fileName))
        _tcscpy(fileName, s ? (s + 1) : _T(""));
    else
        fileName[0] = 0;
    s = (LPTSTR)_tcsrchr(fileName, '.');
    if (s)
        *s = 0; // ".cvspass" is extension in Windows
    if (FileName[0] == '<')
    {
        int nameID;

        if (!_tcscmp(FileName, LoadStr(IDS_CLIPBOARD_TITLE)))
        {
            nameID = IDS_CLIPBOARD_FNAME;
            pCnt = &cntClipboard;
        }
        else if (!_tcscmp(FileName, LoadStr(IDS_CAPTURE_TITLE)))
        {
            nameID = IDS_CAPTURE_FNAME;
            pCnt = &cntCapture;
        }
        else if (!_tcscmp(FileName, LoadStr(IDS_SCAN_TITLE)))
        {
            nameID = IDS_SCAN_FNAME;
            pCnt = &cntScan;
        }
        else
        { // can only be deleted image -> no name provided
            fileName[0] = 0;
            nameID = -1;
        }
        if (nameID != -1)
        {
            _stprintf(fileName, _T("%s%d"), LoadStr(nameID), *pCnt);
        }
    }

    memset(&ofn, 0, sizeof(ofn));
    ofn.ofn.lStructSize = sizeof(OPENFILENAME);
    ofn.ofn.lStructSize = sizeof(ofn);
    ofn.ofn.hwndOwner = HWindow;
    // feature 105: the dialog offers only the formats the Windows encoders write. The language's
    // list (IDS_SAVEASFILTER*) is filtered here; G.LastSaveAsFilterIndex* keep counting in the
    // whole list, as before (the stored value means the same to every version)
    TCHAR filterAll[1000];
    TCHAR filterStr[1000];
    int* lastFilterIndex = srcInfo.Colors == 2 ? &G.LastSaveAsFilterIndexMono : &G.LastSaveAsFilterIndexColor;
    lstrcpyn(filterAll, LoadStr(srcInfo.Colors == 2 ? IDS_SAVEASFILTERMONO : IDS_SAVEASFILTERCOLOR), SizeOf(filterAll));
    int keptFull[64]; // 1-based indexes into the whole list of the offered entries
    int keptCount = BuildSaveFilter(filterAll, filterStr, SizeOf(filterStr), keptFull, _countof(keptFull));
    if (keptCount == 0) // a broken translation: nothing to offer, nothing touched
    {
        _stprintf(errBuff, LoadStr(IDS_SAVEERROR), PVW32DLL.PVGetErrorText(PVC_UNSUP_OUT_PARAMS));
        SalamanderGeneral->SalMessageBox(HWindow, errBuff, LoadStr(IDS_ERRORTITLE), MB_ICONEXCLAMATION | MB_OK);
        return FALSE;
    }
    ofn.ofn.nFilterIndex = SaveFilterShownIndex(*lastFilterIndex, filterStr, keptFull, keptCount);
    ofn.ofn.lpstrFilter = filterStr;
    ofn.ofn.lpstrFile = fileName;
    ofn.ofn.nMaxFile = SizeOf(fileName);
    ofn.ofn.lpstrInitialDir = initDir;
    ofn.ofn.lpfnHook = SaveAsDlgProc;
    ofn.ofn.lpTemplateName = MAKEINTRESOURCE(IDD_SAVEEX);
    ofn.ofn.hInstance = HLanguage;
    ofn.ofn.lCustData = (LPARAM)&lsai;
    ofn.ofn.Flags = OFN_EXPLORER | OFN_ENABLEHOOK | OFN_ENABLETEMPLATE | OFN_PATHMUSTEXIST | OFN_LONGNAMES | OFN_NOCHANGEDIR | OFN_NOTESTFILECREATE | OFN_HIDEREADONLY;
    lsai.FilterA = filterStr;
    lsai.pvii = &srcInfo; // feature 111: the depths are offered from the source's colors
    // the options are kept for the next Save As without the pointer to 'srcInfo' (this function's stack)
    auto storeOptions = [&lsai]()
    {
        sai = lsai;
        sai.pvii = NULL;
    };
    // Start with no rotation & no flip
    lsai.Rotation = lsai.Flip = 0;
    CALL_STACK_MESSAGE2(_T("OnFileSaveAs: GSFN(%s)"), FileName);
    BOOL targetExists = FALSE;
    BOOL clearReadOnly = FALSE;
    for (;;)
    {
        LPTSTR s2;

        // feature 104: the Unicode Save As dialog; the names (fileName, initDir) are UTF-8. The
        // code-page dialog (SafeGetSaveFileName) gave the typed name with best fit: a name outside
        // the code page became '?' or a look-alike - and when the look-alike existed, the
        // "overwrite?" question below named it and Yes DELETED that other file
        if (!SaveAsDialogU8(&ofn.ofn))
        {
            // don't save options
            return FALSE;
        }

        format = 0;
        // remember the filter index for the next time (feature 105: as an index of the whole list)
        if (ofn.ofn.nFilterIndex >= 1 && (int)ofn.ofn.nFilterIndex <= keptCount)
            *lastFilterIndex = keptFull[ofn.ofn.nFilterIndex - 1];
        lstrcpyn(initDir, fileName, ofn.ofn.nFileOffset);
        initDir[ofn.ofn.nFileOffset - 1] = 0;
        GetFormatInfo(&ofn.ofn, &format, &s);
        if (_tcschr(s, '*') && (format == PVF_IRF))
        {
            // suffix depends on compression
            if ((lsai.Compression == PVCS_CCITT_4) || (lsai.Compression == PVCS_DEFAULT))
            {
                static char buffCIT[] = ".cit";
                s = _T(buffCIT);
            }
            else
            {
                static char buffDAT[] = ".dat";
                s = _T(buffDAT);
            }
        }

        if ((FileName[0] == '<') && G.Save.RememberPath)
            lstrcpyn(G.Save.InitDir, initDir, SizeOf(G.Save.InitDir));

        ret = (int)_tcslen(fileName);
        if (fileName[ret - 1] == '.')
        {
            // user doesn't want us to append any suffix
            fileName[ret - 1] = 0;
        }
        else
        {
            LPTSTR ext;

            ext = (LPTSTR)_tcsrchr(fileName /* + ofn.nFileOffset*/, '.');
            if (ext < fileName + ofn.ofn.nFileOffset)
            { // ".cvspass" is extension in Windows
                ext = fileName + ret;
            }
            if (StrIStr(s, ext))
                s = (LPTSTR)StrIStr(s, ext);
            // strip off additional suffixes, if present
            s2 = (LPTSTR)_tcschr(s, ';');
            if (s2)
                *s2 = 0;

            if (_tcsicmp(ext, s))
            {
                // not a default one
                s2 = (LPTSTR)_tcsrchr(fileName + ofn.ofn.nFileOffset, '\\');
                // find file name beginning
                if (!s2)
                {
                    s2 = fileName + ofn.ofn.nFileOffset;
                }
                else
                {
                    s2++;
                }
                // check whether it consists just of upper-case letters & digits
                while (((*s2 >= 'A') && (*s2 <= 'Z')) || ((*s2 >= '0') && (*s2 <= '9')) || (*s2 == '_'))
                    s2++;
                if (!*s2)
                {
                    // yes, it does -> make it lower-case like extension
                    _tcslwr(fileName + ofn.ofn.nFileOffset);
                }
                if ((ext - fileName) + strlen(s) < _countof(fileName))
                    _tcscat(ext, s); // append the default suffix
                else
                {
                    SalamanderGeneral->SalMessageBox(HWindow, LoadStr(IDS_TOOLONGNAME),
                                                     LoadStr(IDS_ERRORTITLE),
                                                     MB_OK | MB_ICONEXCLAMATION);
                    return FALSE;
                }
            }
        }
        // feature 105: a format the Windows encoders cannot write is refused here, before anything
        // is touched (the filtered list offers none; this is the backstop)
        if (!WicCanEncodeFormat(format))
        {
            _stprintf(errBuff, LoadStr(IDS_SAVEERROR), PVW32DLL.PVGetErrorText(PVC_UNSUP_OUT_PARAMS));
            SalamanderGeneral->SalMessageBox(HWindow, errBuff, LoadStr(IDS_ERRORTITLE), MB_ICONEXCLAMATION | MB_OK);
            storeOptions();
            return TRUE;
        }
        // feature 105: only LOOK at an existing target here. Before 105 the target was deleted at
        // this point and the image written afterwards - a failed write (every write since feature
        // 006) lost the file. Now the image goes into a temporary file and replaces the target
        // only when complete (SaveImageSafe). The attribute query opens nothing, so it also sees
        // a file another program - or this viewer, for the image it shows - holds open.
        targetExists = FALSE;
        clearReadOnly = FALSE;
        WCHAR* wFileName = SplU8ToWExtAlloc(fileName); // 'fileName' is a UTF-8 save-target path (interface 104)
        WIN32_FILE_ATTRIBUTE_DATA fad;
        BOOL found = wFileName != NULL && GetFileAttributesExW(wFileName, GetFileExInfoStandard, &fad);
        DWORD findErr = found ? NO_ERROR : (wFileName != NULL ? GetLastError() : ERROR_INVALID_NAME);
        free(wFileName);
        if (found)
        {
            if (fad.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) // a folder of that name: never replaced
            {
                SalamanderGeneral->GetErrorText(ERROR_ALREADY_EXISTS, errBuff, SizeOf(errBuff));
                if (IDCANCEL == SalamanderGeneral->SalMessageBox(HWindow, errBuff,
                                                                 LoadStr(IDS_ERRORTITLE), MB_ICONEXCLAMATION | MB_OKCANCEL))
                {
                    storeOptions();
                    return TRUE;
                }
                continue; // ask for a new name
            }
            // a read-only file: the read-only question only (as before)
            BOOL readOnly = (fad.dwFileAttributes & FILE_ATTRIBUTE_READONLY) != 0;
            FormatNameMessageU8(errBuff, SizeOf(errBuff), LoadStr(readOnly ? IDS_READ_ONLY_REWRITE : IDS_SAVE_ERR_EXISTS_OVERWRITE), fileName); // feature 104
            ret = SalamanderGeneral->SalMessageBox(HWindow, errBuff,
                                                   LoadStr(IDS_ERRORTITLE), MB_ICONEXCLAMATION | MB_YESNOCANCEL);
            if (ret == IDCANCEL)
            {
                // store options
                storeOptions();
                return TRUE;
            }
            if (ret != IDYES)
            {
                // ask for a new name
                continue;
            }
            targetExists = TRUE;
            clearReadOnly = readOnly; // cleared only for the replace itself, restored if that fails
            break;
        }
        if (findErr == ERROR_FILE_NOT_FOUND)
            break;
        // the target cannot be looked at (no access to the folder, an invalid name, ...): say why
        SalamanderGeneral->GetErrorText(findErr, errBuff, SizeOf(errBuff));
        if (IDCANCEL == SalamanderGeneral->SalMessageBox(HWindow, errBuff,
                                                         LoadStr(IDS_ERRORTITLE), MB_ICONEXCLAMATION | MB_OKCANCEL))
        {
            storeOptions();
            return TRUE;
        }
    }
    DWORD saveErr = 0;
    char* leftAt = NULL;
    ret = SaveImageSafe(fileName, format, &lsai, targetExists, clearReadOnly, &saveErr, &leftAt);

    // report the change on the path (our file has appeared)
    TCHAR changedPath[MAX_PATH];
    lstrcpyn(changedPath, fileName, MAX_PATH);
    SalamanderGeneral->CutDirectory(changedPath);
    SalamanderGeneral->PostChangeOnPathNotification(changedPath, FALSE);

    if (ret != PVC_OK)
    {
        if (ret != PVC_CANCELED)
        {
            // the system's text for the failed step (disk full, access denied, in use, ...), else the
            // engine's; the temporary file that holds the only copy of the image is named
            char errText[1000];
            if (saveErr != 0)
                SalamanderGeneral->GetErrorText(saveErr, errText, SizeOf(errText)); // UTF-8
            else
                lstrcpyn(errText, PVW32DLL.PVGetErrorText(ret), SizeOf(errText)); // ASCII
            size_t detailSize = strlen(errText) + (leftAt != NULL ? strlen(leftAt) : 0) + 4;
            char* detail = (char*)malloc(detailSize);
            if (detail != NULL)
            {
                if (leftAt != NULL)
                    sprintf_s(detail, detailSize, "%s\n\n%s", errText, leftAt);
                else
                    strcpy_s(detail, detailSize, errText);
            }
            FormatNameMessageU8(errBuff, SizeOf(errBuff), LoadStr(IDS_SAVEERROR), detail != NULL ? detail : errText);
            free(detail);
            SalamanderGeneral->SalMessageBox(HWindow, errBuff, LoadStr(IDS_ERRORTITLE),
                                             MB_ICONEXCLAMATION | MB_OK);
        }
        else
        {
            SalamanderGeneral->SalMessageBox(HWindow, LoadStr(IDS_CANCELED_BY_USER),
                                             LoadStr(IDS_PLUGINNAME), MB_OK | MB_ICONINFORMATION | MSGBOXEX_SILENT);
        }
    }
    else
    {
        if (pCnt)
        {
            (*pCnt)++; // increase counter only on successful save
        }
        if (!(G.DontShowAnymore & DSA_SAVE_SUCCESS))
        {
            BOOL checked = FALSE;

            ShowOneTimeMessage(HWindow, IDS_SAVE_AS_SUCCESS, &checked, MSGBOXEX_OK);
            if (checked)
            {
                G.DontShowAnymore |= DSA_SAVE_SUCCESS;
            }
        }
        else
        {
            Viewer->SetStatusBarTexts(IDS_SAVE_AS_SUCCESS);
            bEatSBTextOnce = TRUE;
        }
        sai.PrevInputColors = srcInfo.Colors;
    }
    free(leftAt);
    storeOptions();
    // feature 105 opened a shown target again here; since feature 111 the windows that let it go
    // take it back inside EncodeReplaceSafe (reopened when replaced, re-attached when not)
    return TRUE;
}

// feature 105: TRUE when 'wPath' (wide, \\?\ form) is the file this window shows (its decoder
// keeps it open). The file system's identity decides (salsamefile.h); where it has no ids, equal
// metadata or the same name count as "maybe" - and a maybe is treated as yes: the decoder is
// let go and taken back afterwards, which costs nothing (feature 111: also for the other windows).
BOOL CRendererWindow::IsShownFile(const WCHAR* wPath)
{
    if (FileName == NULL || FileName[0] == '<' || PVHandle == NULL)
        return FALSE;
    WCHAR* wShown = SplU8ToWExtAlloc(FileName);
    if (wShown == NULL)
        return FALSE;
    BOOL same = _wcsicmp(wShown, wPath) == 0;
    if (!same)
    {
        CSalFileIdentity a, b;
        if (SalGetFileIdentityW(wShown, FALSE, &a) && SalGetFileIdentityW(wPath, FALSE, &b))
        {
            int m = SalFileIdMatch(a, b);
            same = m == simEqual || (m == simUnknown && SalFileMetaEqual(a, b));
        }
    }
    free(wShown);
    return same;
}

// feature 105: Save As writes the image into a temporary file next to the target; only the
// complete, flushed file takes the target's place (src/common/salsafereplace.h). An existing
// target is never deleted or truncated before that, so a failure at any step - a format that
// cannot be written, a folder without write access, a full disk, a target in use, Esc - leaves
// it as it was. Returns a PVC_* code; '*win32Err' the system error behind a failure (0 = none,
// the engine's text applies); '*leftAt' (UTF-8, free()) the temporary file that holds the only
// copy of the new image when the target vanished and the file could not be moved into its
// place (never deleted). Feature 111: a target shown in this or another viewer window is let go
// by every such window for the replace and taken back afterwards (EncodeReplaceSafe).
int CRendererWindow::SaveImageSafe(LPCTSTR fileName, DWORD format, SAVEAS_INFO_PTR psai, BOOL targetExists,
                                   BOOL clearReadOnly, DWORD* win32Err, char** leftAt)
{
    *win32Err = 0;
    *leftAt = NULL;
    if (!WicCanEncodeFormat(format))
        return PVC_UNSUP_OUT_PARAMS; // refused before anything is touched

    // the parameters as SaveImage computes them for the engine
    CWicEncodeParams ep;
    memset(&ep, 0, sizeof(ep));
    ep.Format = format;
    ep.Compression = psai->Compression;
    ep.Colors = psai->Colors & SAVEAS_GRAY_MASK;
    ep.ColorModel = (psai->Colors & SAVEAS_GRAY_FLAG) ? PVCM_GRAYS : PVCM_RGB;
    ep.Flags = psai->Flags & (PVSF_INVERT | PVSF_ROTATE90 | PVSF_FLIP_HOR | PVSF_FLIP_VERT);
    ep.JPEGQuality = G.Save.JPEGQuality;
    ep.JPEGSubsampling = G.Save.JPEGSubsampling;
    ep.CommentU8 = psai->Comment;

    WCHAR* wTarget = SplU8ToWExtAlloc(fileName);
    if (wTarget == NULL)
    {
        *win32Err = ERROR_INVALID_NAME;
        return PVC_WRITING_ERROR;
    }
    WCHAR* wLeftAt = NULL;
    int code = EncodeReplaceSafe(wTarget, &ep, targetExists, clearReadOnly, win32Err, &wLeftAt);
    if (wLeftAt != NULL) // named in the target's folder as the user typed it (UTF-8)
    {
        const WCHAR* tmpName = wcsrchr(wLeftAt, L'\\');
        char* tmpNameU8 = SplWToU8Alloc(tmpName != NULL ? tmpName + 1 : wLeftAt);
        if (tmpNameU8 != NULL)
        {
            const char* slash = strrchr(fileName, '\\');
            size_t dirLen = slash != NULL ? (size_t)(slash - fileName) + 1 : 0;
            size_t size = dirLen + strlen(tmpNameU8) + 1;
            *leftAt = (char*)malloc(size);
            if (*leftAt != NULL)
            {
                memcpy(*leftAt, fileName, dirLen);
                strcpy_s(*leftAt + dirLen, size - dirLen, tmpNameU8);
            }
            free(tmpNameU8);
        }
        free(wLeftAt);
    }
    free(wTarget);
    return code;
}

// feature 111 (from 105's SaveImageSafe): encodes the shown image with 'ep' (mirror of the view
// added here) into a temporary file next to 'wTarget' (\\?\ form) and replaces the target with it.
// A target shown in this or another viewer window is let go by every such window just before the
// replace and taken back after it: opened again when replaced, re-attached (no reload) when not.
// Returns a PVC_* code; '*win32Err' as SaveImageSafe; '*wLeftAt' (free()) the temporary file that
// holds the only copy of the new image when the target vanished meanwhile (never deleted).
int CRendererWindow::EncodeReplaceSafe(const WCHAR* wTarget, CWicEncodeParams* ep, BOOL targetExists,
                                       BOOL clearReadOnly, DWORD* win32Err, WCHAR** wLeftAt)
{
    *win32Err = 0;
    *wLeftAt = NULL;
    // what the window shows mirrored is saved mirrored (the window mirrors only when drawing)
    if (fMirrorHor)
        ep->Flags ^= PVSF_FLIP_HOR;
    if (fMirrorVert)
        ep->Flags ^= PVSF_FLIP_VERT;
    ep->HorDPI = (ep->Flags & PVSF_ROTATE90) ? pvii.VerDPI : pvii.HorDPI;
    ep->VerDPI = (ep->Flags & PVSF_ROTATE90) ? pvii.HorDPI : pvii.VerDPI;

    WCHAR* wTemp = NULL;
    HANDLE hTemp = INVALID_HANDLE_VALUE;
    DWORD err = 0;
    if (!SalCreateTempNextToW(wTarget, L"pv", &wTemp, &hTemp, &err))
    {
        // no file can be created in the target's folder (no write access, ...): nothing touched
        *win32Err = err;
        return PVC_WRITING_ERROR;
    }

    // refresh the window so it does not look messy during longer saves after the SaveAs dialog
    UpdateWindow(Viewer->HWindow);
    HCURSOR hOldCur = SetCursor(LoadCursor(NULL, IDC_WAIT));
    CALL_STACK_MESSAGE6("EncodeReplaceSafe: %ux%ux%u, %u, %u", pvii.Width, pvii.Height, ep->Colors, ep->Format, ep->Flags);
    sProgBarInfo pbi;
    Viewer->InitProgressBar();
    pbi.pViewer = Viewer;
    pbi.lastCheckTicks = pbi.lastUpdateTicks = GetTickCount();
    // feature 111 (review S1): the progress hook dispatches sent messages - while the encoder reads this
    // image, another window's release request is refused (else a reopen would free the image under it)
    ImageBusy++;
    int code = WicEncodeImageToFile(PVHandle, pvii.CurrentImage, hTemp, ep, SaveProgressProcedure, &pbi, &err);
    ImageBusy--;
    Viewer->KillProgressBar();
    SetCursor(hOldCur);
    if (code == PVC_OK && !FlushFileBuffers(hTemp)) // complete on the disk before it replaces anything
    {
        err = GetLastError();
        code = PVC_WRITING_ERROR;
    }
    if (!CloseHandle(hTemp) && code == PVC_OK)
    {
        err = GetLastError();
        code = PVC_WRITING_ERROR;
    }

    BOOL keepTemp = FALSE; // the temporary file holds the only copy of the new image
    if (code == PVC_OK)
    {
        // the decoder of a shown image keeps its file open without FILE_SHARE_DELETE: replacing it
        // would fail with "in use" (32) - every window showing the target lets it go (feature 111:
        // also the OTHER viewer windows; before, a second window showing the file blocked the save)
        CShownFileRelease rel;
        rel.Own = FALSE;
        rel.OthersCount = 0;
        rel.Op = 0;
        if (targetExists)
            ReleaseShownFile(wTarget, TRUE, &rel);
        BOOL replaced = FALSE;
        switch (SalReplaceWithTempW(wTarget, wTemp, targetExists, clearReadOnly, &err))
        {
        case srrDone:
            replaced = TRUE;
            break;

        case srrLeftAtTemp: // the target is gone, the only copy of the new image is the temporary file
            code = PVC_WRITING_ERROR;
            keepTemp = TRUE;
            *wLeftAt = _wcsdup(wTemp);
            TRACE_E("EncodeReplaceSafe: the new image stayed in the temporary file, error " << err);
            break;

        default: // srrFailedKept, srrFailedBothGone: the target as it was (or already gone by others)
            code = PVC_WRITING_ERROR;
            break;
        }
        // replaced: the windows open the file again; not: the same file is taken back without a
        // reload (feature 111 - 105 reopened it, losing the view's zoom and mirror after a failure)
        RetakeShownFile(&rel, replaced ? sfaChanged : sfaSame, NULL);
    }
    if (code != PVC_OK && !keepTemp && !DeleteFileW(wTemp)) // never delete the only copy of the image
        TRACE_E("EncodeReplaceSafe: cannot delete the temporary file, error " << GetLastError());
    if (code != PVC_OK)
        *win32Err = code == PVC_CANCELED ? 0 : err;
    free(wTemp);
    return code;
}

// saves the image into the file 'fileName' using format 'format' (PVF_xxx)
// returns the PVSaveImage function's return value
int CRendererWindow::SaveImage(LPCTSTR fileName, DWORD format, SAVEAS_INFO_PTR psai)
{
    PVSaveImageInfo sii;
    sProgBarInfo pbi;

    memset(&sii, 0, sizeof(PVSaveImageInfo));
    sii.cbSize = sizeof(PVSaveImageInfo);
    sii.Format = format;
    sii.ColorModel = pvii.ColorModel == PVCM_CMYK ? PVCM_RGB : pvii.ColorModel;
    // psai is NULL when saving wallpaper
    sii.Colors = psai ? (psai->Colors & SAVEAS_GRAY_MASK) : pvii.Colors;
    if (psai)
    {
        if (psai->Colors & SAVEAS_GRAY_FLAG)
        {
            sii.ColorModel = PVCM_GRAYS;
        }
        else if (sii.Colors > 256)
        {
            // must be reset to RGB when saving originally Grayscale image as Hi/TrueColor
            sii.ColorModel = PVCM_RGB;
        }
    }
    sii.Compression = psai ? psai->Compression : PVCS_DEFAULT;
    sii.Flags = psai ? (psai->Flags & (PVSF_INVERT | PVSF_ROTATE90 | PVSF_FLIP_HOR | PVSF_FLIP_VERT)) : 0;
    // Flip DPI if rotating
    sii.HorDPI = (sii.Flags & PVSF_ROTATE90) ? pvii.VerDPI : pvii.HorDPI;
    sii.VerDPI = (sii.Flags & PVSF_ROTATE90) ? pvii.HorDPI : pvii.VerDPI;
#if 0
  if (PVW32DLL.PVIsOutCombSupported(sii.Format, PVCS_DEFAULT, sii.Colors, sii.ColorModel) == -1) {
     // the target format does not support the source bit depth with any compression scheme
     // we must perform some bit-depth conversion
     int i;
     for (i = 0; i < 6; i++) {
        switch (sii.Colors) { // we try to upgrade bit depth
           case 2: sii.Colors = 16; break;
           case PV_COLOR_HC15: sii.Colors = PV_COLOR_HC16; break;
           case PV_COLOR_HC16: sii.Colors = PV_COLOR_TC24; break;
           case PV_COLOR_TC24: sii.Colors = PV_COLOR_TC32; break;
           case PV_COLOR_TC32: sii.Colors = 256; break; // some formats are 8bit only
           default: if ((sii.Colors >= 3) && (sii.Colors <= 16)) sii.Colors = 256;
             else if ((sii.Colors > 16) && (sii.Colors <= 256)) sii.Colors = PV_COLOR_HC15;
        }
        if (PVW32DLL.PVIsOutCombSupported(sii.Format, PVCS_DEFAULT, sii.Colors, sii.ColorModel) != -1) {
           break; // found one!!
        }
     }
  }
#endif
    if (fMirrorHor)
    {
        // Patch: PVW32Cnv.dll will mirror the image in memory
        sii.Flags ^= PVSF_FLIP_HOR;
        fMirrorHor = FALSE;
        PVW32DLL.PVSetStretchParameters(PVHandle, XStretchedRange,
                                        YStretchedRange * (1 - 2 * fMirrorVert), COLORONCOLOR);
    }
    if (fMirrorVert)
    {
        sii.Flags ^= PVSF_FLIP_VERT;
    }
    if (sii.Format == PVF_GIF)
    {
        sii.Flags |= G.Save.Flags & (PVSF_GIF89 | PVSF_INTERLACE);
    }
    if (sii.Format == PVF_JPG)
    {
        sii.Misc.JPEG.Quality = G.Save.JPEGQuality;
        // 0 means 2x1:1:1        = here 0 means 1:1:1
        sii.Misc.JPEG.SubSampling = !G.Save.JPEGSubsampling;
    }
    if (sii.Format == PVF_TIFF)
    {
        sii.Flags |= G.Save.Flags & PVSF_DO_NOT_STRIP;
        sii.Misc.TIFF.StripSize = G.Save.TIFFStripSize;
        sii.Misc.TIFF.JPEGQuality = G.Save.JPEGQuality;
        // 0 means 2x1:1:1        = here 0 means 1:1:1
        sii.Misc.TIFF.JPEGSubSampling = !G.Save.JPEGSubsampling;
    }
    sii.Transp.Flags = PVTF_ORIGINAL; // Preserve transparency
    if (psai && psai->Comment[0])
    {
        sii.Comment = psai->Comment;
        // we save terminating zero only in TIFFs
        sii.CommentSize = (int)strlen(sii.Comment) + (sii.Format == PVF_TIFF ? 1 : 0);
    }

    // refresh the window so it does not look messy during longer saves after the SaveAs dialog
    UpdateWindow(Viewer->HWindow);
    HCURSOR hOldCur = SetCursor(LoadCursor(NULL, IDC_WAIT));
    CALL_STACK_MESSAGE6("Save pars: %ux%ux%u, %u, %u", pvii.Width, pvii.Height, sii.Colors, sii.Format, sii.Flags);

    Viewer->InitProgressBar();
    pbi.pViewer = Viewer;
    pbi.lastCheckTicks = pbi.lastUpdateTicks = GetTickCount();
#ifdef _UNICODE
    char fileNameA[_MAX_PATH];

    WideCharToMultiByte(CP_ACP, 0, fileName, -1, fileNameA, sizeof(fileNameA), NULL, NULL);
    fileNameA[sizeof(fileNameA) - 1] = 0;
    int saveRet = PVW32DLL.PVSaveImage(PVHandle, fileNameA, &sii, SaveProgressProcedure, &pbi, pvii.CurrentImage);
#else
    int saveRet = PVW32DLL.PVSaveImage(PVHandle, fileName, &sii, SaveProgressProcedure, &pbi, pvii.CurrentImage);
#endif
    Viewer->KillProgressBar();
    SetCursor(hOldCur);

    return saveRet;
}
