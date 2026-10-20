// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// viewer.h - the codeview viewer window: a WebView2 host with a native status
// bar below it (spec FR-022; the page stays text-only so Select All yields
// exactly the file's content).

#pragma once

#include <string>
#include <vector>
#include "intake.h"

class CTcWebHost;

class CViewerWindow : public CWindow
{
public:
    HANDLE Lock;     // signaled once the (possibly temp) source file may be released
    char* Name;      // full UTF-8 path (heap; may exceed MAX_PATH) or NULL
    CTcWebHost* Web; // the shared, locked-down rendering surface

    HWND HStatus;     // native status bar (STATIC)
    HFONT HStatusFont; // status-bar font (NONCLIENTMETRICS lfStatusFont); owned
    int StatusHeight; // derived from the font at creation (DPI-correct)
    HBRUSH BgBrush;  // scheme background for WM_ERASEBKGND - the shared WinLib
                     // class brush is white and would flash before the page paints

    HMENU HSchemeMenu;
    HMENU HEncodingMenu;

    CvIntake Intake;
    const std::string* TextPtr; // stable address handed to the interceptor
    int ForcedEncoding; // -1 = detect

    // feature 262: the product's conversion tables (EnumConversionTables), read
    // once per window; the pointers stay valid for the program's life. The menu
    // list keeps the separators (NULL name); TableNames / TableBytes hold the
    // tables only - a "table index" is a position in them.
    std::vector<const char*> TableMenuNames;
    std::vector<const char*> TableNames;
    std::vector<const char*> TableBytes;
    BOOL TablesLoaded;
    int ForcedTable; // a chosen table (with ForcedEncoding == cvEncAnsi), or -1
    int TableUsed;   // the table the shown text was decoded with, or -1
    int DocVersion;     // bumped whenever the served text changes

    wchar_t FindText[256];
    BOOL FindCase;
    BOOL FindWholeWord;
    int FindCurrent, FindTotal;

    // Zoom is PER WINDOW; g_zoom is only the persisted starting value. Sharing
    // one live value made a second window report the first window's percentage
    // in its title and status bar over text it was not rendering at.
    int Zoom;
    int CaretLine, CaretCol;
    BOOL PageReady;   // the page reported "ready": messages may be sent
    BOOL DarkMenus;   // IsDarkThemeActive() snapshot at creation (036 convention)

    int EnumFilesSourceUID;
    int EnumFilesCurrentIndex;

public:
    CViewerWindow(int enumFilesSourceUID, int enumFilesCurrentIndex);
    ~CViewerWindow();

    HANDLE GetLock();
    void OpenFile(const char* name, BOOL setLock = TRUE);

protected:
    virtual LRESULT WindowProc(UINT uMsg, WPARAM wParam, LPARAM lParam);

    void BuildMenu();
    void RefreshChecks();
    void LayoutChildren();
    void ApplyScheme(BOOL rebuildBrush);
    void SelectScheme(int idx);
    void CycleScheme(int dir);
    void SelectEncoding(int encoding, int table = -1);
    void CycleEncoding(int dir);
    void LoadCodeTables();
    int TableCount() const { return (int)TableNames.size(); }
    const char* TableAt(int table) const;
    int RememberedTable() const;
    void SendInit(BOOL swap);
    void DoFind(BOOL prompt, int dir);
    void DoGotoLine();
    void SetZoom(int pct);
    void UpdateTitle();
    void UpdateStatus();
    void ShowContextMenu(int x, int y, BOOL hasSelection);
    void CopyToClipboard(const std::wstring& text);
    void CopyWholeDocument();
    void OnPageMessage(const std::wstring& json);
    void NextFile(int dir);
    void EngineFailed();
    void ShowBlockedNotice(const char* text, const char* nameUtf8 = NULL);
};
