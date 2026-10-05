// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "lib/pvw32dll.h"

// Path to focus, used by menu File/Focus
extern TCHAR Focus_Path[MAX_PATH];

// Used by SaveAs dlg to get the current path in the source(=active) panel
extern HWND ghSaveAsWindow;

// internal color holder that also contains a flag
typedef DWORD SALCOLOR;

// SALCOLOR flags
#define SCF_DEFAULT 0x01 // ignore the color component and use the default value

#define GetCOLORREF(rgbf) ((COLORREF)rgbf & 0x00ffffff)
#define RGBF(r, g, b, f) ((COLORREF)(((BYTE)(r) | ((WORD)((BYTE)(g)) << 8)) | (((DWORD)(BYTE)(b)) << 16) | (((DWORD)(BYTE)(f)) << 24)))
#define GetFValue(rgbf) ((BYTE)((rgbf) >> 24))

// Comment size when saving
#define SAVEAS_MAX_COMMENT_SIZE 64
// feature 105: the comment field holds SAVEAS_MAX_COMMENT_SIZE - 1 UTF-16 units; kept as UTF-8
// (up to 3 bytes per unit)
#define SAVEAS_MAX_COMMENT_BYTES (3 * SAVEAS_MAX_COMMENT_SIZE)

inline void SetRGBPart(SALCOLOR* salColor, COLORREF rgb)
{
    *salColor = rgb & 0x00ffffff | (((DWORD)(BYTE)((BYTE)((*salColor) >> 24))) << 24);
}

// Renderer colors
enum ViewerColorsEnum
{
    vceBackground,    // color for workspace in window-renderer
    vceTransparent,   // color for transparent background in window-renderer
    vceFSBackground,  // color for workspace in full screen mode
    vceFSTransparent, // color for transparent background in full screen mode
    vceCount
};

// Active tool in the renderer window
typedef enum eTool
{
    RT_HAND,
    RT_ZOOM,
    RT_SELECT,
    RT_PIPETTE
} eTool;

typedef enum eZoomType
{
    eZoomGeneral = 0,
    eShrinkToFit = 1, // alias Zoom whole
    eShrinkToWidth,
    eZoomOriginal, // alias 1:1
    eZoomFullScreen
} eZoomType;

// Local settings for this file save
// The global settings kept in Registry are in G.Save
typedef struct _gen_saveas_info
{
    DWORD Compression;
    DWORD Colors;
    DWORD PrevInputColors;
    DWORD Rotation;
    DWORD Flip;
    DWORD Flags;
    char Comment[SAVEAS_MAX_COMMENT_BYTES]; // UTF-8 (feature 105)
    LPPVImageInfo pvii;
    // feature 104: the Save As dialog is the Unicode one, so its lpstrFilter is UTF-16; the hook
    // reads the code-page filter list (the extensions of the formats) from here
    LPCTSTR FilterA;
} SAVEAS_INFO, *SAVEAS_INFO_PTR;

// feature 111: an operation on the file a viewer shows (rename, delete, Save As over it) first lets
// every PictView window showing that file release it - the WIC decoder keeps it open without
// FILE_SHARE_DELETE - and afterwards each of them takes it back (render1.cpp)
enum CShownFileAfter
{
    sfaSame,    // the content is the same (renamed, or the operation failed or was declined): take the
                // file back without a reload - zoom, mirror and rotation stay
    sfaChanged, // the file was rewritten (Save As over it): open it again (the zoom stays)
    sfaGone,    // the file was deleted: the image stays in memory, titled <Deleted>
    sfaUnknown, // no word from the operation (the window's timer): take the file back if it is the
                // same file with the same content, else open it again
};

struct CShownFileRelease
{
    BOOL Own;        // this window let its decoder go
    HWND Others[64]; // other viewer windows that let theirs go
    int OthersCount;
    int Op; // the operation (render1.cpp ShownFileOps) - active from the release until the retake
};

// the data of WM_USER_RELEASEFILE: the operation and the file (\\?\ form)
struct CShownFileRequest
{
    int Op;
    WCHAR Path[1]; // as long as needed
};

// the data of WM_USER_RETAKEFILE: the operation, what happened, the new name (UTF-8; "" = unchanged)
struct CShownFileRetake
{
    int Op;
    int After;       // CShownFileAfter
    char NewName[1]; // as long as needed
};

struct CSalFileIdentity; // salsamefile.h

// feature 111: "Unable to save the image." with the UTF-8 reason 'detailU8', as UTF-8 (saveas.cpp)
void FormatSaveErrorU8(char* out, int outSize, const char* detailU8);

BOOL IsCageValid(const RECT* r); // returns TRUE if r->left != 0x80000000
void InvalidateCage(RECT* r);    // sets r->left = 0x80000000 (the cage is invalid and will not be shown)

//****************************************************************************
//
// CRendererWindow
//

class CViewerWindow;
class CPrintDlg;
struct CWicEncodeParams; // wicengine.h

class CRendererWindow : public CWindow
{
public:
    CViewerWindow* Viewer;

    // variables for PVW32
    LPPVHandle PVHandle; // image handle
    LPPVImageSequence PVSequence, PVCurImgInSeq;
    BOOL ImageLoaded;
    BOOL DoNotAttempToLoad;
    BOOL Canceled;
    DWORD OldMousePos;
    HCURSOR HOldCursor;
    LPTSTR FileName;
    __int64 ZoomFactor;
    eZoomType ZoomType;
    BOOL Capturing;
    eTool CurrTool;
    BOOL HiddenCursor;       // relevant in FullScreen, TRUE when the cursor faded after a timeout
    BOOL CanHideCursor;      // TRUE = the cursor may be hidden (FALSE e.g. while opening Save As so the cursor stays visible)
    DWORD LastMoveTickCount; // tick count at the last mouse movement
    RECT ClientRect;

protected:
    PVImageInfo pvii;
    char* Comment;
    int XStart, YStart, XStartLoading, YStartLoading;
    int XStretchedRange, YStretchedRange;
    int XRange, YRange;
    int ZoomIndex;
    int PageWidth, PageHeight;
    BOOL Loading;
    HDC LoadingDC;
    BOOL fMirrorHor, fMirrorVert;
    HWND PipWindow;
    TCHAR toolTipText[68];
    HBRUSH HAreaBrush;
    // SelectRect is in absolute image coordinates and is unaffected by zoom or scroll
    RECT SelectRect;    // selected area; left = 0x8000000 if no selection (in image coordinates)
    POINT LButtonDown;  // client-window coordinates where the user pressed LBUTTON (to detect drag start)
    RECT TmpCageRect;   // cage currently being dragged (zoom || select); in image coordinates; left/top = anchor; right/bottom = cursor
    POINT CageAnchor;   // cage origin (the point opposite to CageCursor) in image coordinates
    POINT CageCursor;   // see CageAnchor
    BOOL BeginDragDrop; // TRUE if drag&drop has not started yet (we are in the safe zone)
    BOOL ShiftKeyDown;  // remember the pressed SHIFT key
    BOOL bDrawCageRect;
    BOOL bEatSBTextOnce; // Don't update SB texts once to keep information displayed for a while
    int inWMSizeCnt;

    int EnumFilesSourceUID;    // source UID for enumerating files in the viewer
    int EnumFilesCurrentIndex; // index of the current file in the viewer within the source

    // feature 111: the decoder let the shown file go for an operation on it; only that image - still
    // detached, under the path that was asked for or another one - is taken back (review B1: a
    // window that moved to another file meanwhile was given the old file's name or <Deleted>)
    BOOL FileReleased;
    LPPVHandle ReleasedHandle;    // the image that let go
    BOOL ReleasedSamePath;        // the request named the window's own path (not a hard link / alias)
    CSalFileIdentity* ReleasedId; // the file at the release (id, size, times; NULL = unknown)
    int ReleasedOp;               // the operation that asked
    int ImageBusy;                // > 0: the image is being encoded or printed - not let go (review S1)

    BOOL SavedZoomParams;
    eZoomType SavedZoomType;
    __int64 SavedZoomFactor;
    int SavedXScrollPos;
    int SavedYScrollPos;

    int BrushOrg;
    BOOL ScrollTimerIsRunning;

    // the print dialog is allocated because it carries the configured parameters
    // for printer, paper orientation, etc.; if the user prints twice in a row,
    // these settings remain preserved
    CPrintDlg* pPrintDlg;

public:
    CRendererWindow(int enumFilesSourceUID, int enumFilesCurrentIndex);
    ~CRendererWindow();

    BOOL OnFileOpen(LPCTSTR defaultDirectory); // set 'defaultDirectory' to NULL for current dir
    BOOL OnFileSaveAs(LPCTSTR pInitDir);
    BOOL SaveImage(LPCTSTR name, DWORD format, SAVEAS_INFO_PTR psai);
    // feature 105: Save As - the image into a temporary file next to the target, which replaces the
    // target only when complete (saveas.cpp)
    int SaveImageSafe(LPCTSTR fileName, DWORD format, SAVEAS_INFO_PTR psai, BOOL targetExists,
                      BOOL clearReadOnly, DWORD* win32Err, char** leftAt);
    // feature 111: the encode-into-a-temporary-file-and-replace step of SaveImageSafe, also used by
    // the wallpaper commands (render2.cpp); 'ep' gets the view's mirror and the DPI here
    int EncodeReplaceSafe(const WCHAR* wTarget, CWicEncodeParams* ep, BOOL targetExists,
                          BOOL clearReadOnly, DWORD* win32Err, WCHAR** wLeftAt);
    BOOL IsShownFile(const WCHAR* wPath);
    // feature 111: before an operation on 'wPath' (\\?\ form): this window (if 'own') and every
    // other viewer window showing that file let it go; after it: RetakeShownFile
    void ReleaseShownFile(const WCHAR* wPath, BOOL own, CShownFileRelease* rel);
    void RetakeShownFile(CShownFileRelease* rel, CShownFileAfter after, const char* newNameU8);
    // feature 111: the two halves for this window (also the WM_USER_RELEASEFILE / _RETAKEFILE handlers)
    LRESULT OnReleaseFileRequest(const WCHAR* wPath, int op, BOOL own);
    void OnRetakeFile(int op, CShownFileAfter after, const char* newNameU8, BOOL saver);
    void OnRetakeTimer();
    BOOL TakeBackIfSame(const char* nameU8); // re-attach when 'nameU8' is the released file, unchanged
    BOOL ReopenKeepingView(BOOL keepMirror);
    void DropReleasedState();
    // feature 111: a window that opens another image no longer holds a released one
    void ForgetRelease()
    {
        if (FileReleased)
            DropReleasedState();
    }
    // feature 111: 'pvii' as the source file holds it (colors, color model, bit depth) - for the
    // title and Image Information; the engine's rows stay 32-bit
    void GetSourceImageInfo(PVImageInfo* out);
    int OpenFile(LPCTSTR name, int ShowCmd, HBITMAP hBmp);
    int HScroll(int ScrollRequest, int ThumbPos);
    int VScroll(int ScrollRequest, int ThumbPos);
    void WMSize(void);
    void ZoomTo(int zoomPercent);
    void ZoomIn(void);
    void ZoomOut(void);

    void SetTitle(void);

    BOOL IsCanceled(void) { return Canceled; };

    void CancelCapture();

    BOOL PageAvailable(BOOL next);

    // feature 111: the wallpaper image (render2.cpp)
    int SaveWallpaperFile(WCHAR** path, DWORD* err);

protected:
    virtual LRESULT WindowProc(UINT uMsg, WPARAM wParam, LPARAM lParam);
    LRESULT OnPaint();
    LRESULT OnCommand(WPARAM wParam, LPARAM lParam, BOOL* closingViewer);

    void SimplifyImageSequence(HDC dc);
    void PaintImageSequence(PAINTSTRUCT* ps, HDC dc, BOOL bTopLeft);

    void DetermineZoomIndex(void);
    void AdjustZoomFactor(void);

    void ScreenCapture();
    void SetAsWallpaper(WORD command);

    PVCODE InitiatePageLoad(void);
    void TryEnterHandToolMode(void);
    void ShutdownTool(void);

    void SelectTool(eTool tool);

    void OnContextMenu(const POINT* p);
    BOOL OnSetCursor(DWORD lParam);

    void OnDelete(BOOL toRecycle);
    void OnCopyTo();

    BOOL RenameFileInternal(LPCTSTR oldPath, LPCTSTR oldName, TCHAR (&newName)[3 * MAX_PATH], BOOL* tryAgain);

    void FreeComment(void);
    void DuplicateComment(void);

    PVCODE GetHistogramData(LPDWORD luminosity, LPDWORD red, LPDWORD green, LPDWORD blue, LPDWORD rgb);

    bool GetRGBAtCursor(int x, int y, RGBQUAD* pRGB, int* pIndex);

    void UpdatePipetteTooltip();
    void UpdateInfos();

    void ClientToPicture(POINT* p); // converts client-area window coordinates to image coordinates
    void PictureToClient(POINT* p); // converts image coordinates to client-area window coordinates

    void AutoScroll(); // tracks the cursor relative to the client area; if it is outside, scroll the window

    void DrawCageRect(HDC hDC, const RECT* cageRect);

    void ZoomOnTheSpot(LPARAM dwMousePos, BOOL bZoomIn);

    friend class CViewerWindow;
    friend void FillTypeFmt(HWND hDlg, OPENFILENAME* lpOFN, BOOL bUpdCompressions,
                            BOOL bUpdBitDepths, BOOL onlyEnable);
};
