// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// viewer.h - the mdview viewer window (WebView2 host).

#pragma once

#include "render.h"
#include "htmlgen.h"
#include <string>

class CTcWebHost;

class CViewerWindow : public CWindow
{
public:
    HANDLE Lock;     // signaled once the (possibly temp) source file may be released
    char* Name;      // full UTF-8 path (heap; may exceed MAX_PATH) or NULL
    CTcWebHost* Web; // the shared WebView2 rendering surface (src/common/webhost/)

    HMENU HSchemeMenu; // the "Color Scheme" submenu (for radio/checkmark updates)

    HBRUSH BgBrush; // scheme docBg fill for WM_ERASEBKGND - the shared winliblt
                    // class brush is white and would flash before WebView2 paints

    const MdTheme* Theme;
    MdHtmlResult Html;        // current generated document (served by the host)
    std::wstring DecodedText; // decoded source (UTF-16); kept for re-render/find
    std::wstring FilePathW;   // display path (no \\?\)
    std::wstring DocDir;      // directory of the file (image resolution)
    MdEncoding Encoding;
    wchar_t FindText[256];
    int FindIndex;      // current match for find next/prev
    int DocVersion;     // bumped whenever Html is regenerated; Navigate(DocVersion, ...)
                        // makes that a fresh URL (full reload with the new marks),
                        // while a fragment at the SAME version is a same-document
                        // scroll. Owned here since feature 081 -- the shared host
                        // takes the version from its caller.
    bool RemoteAllowed; // per-document remote-image consent (D2)
    bool RenderPending; // set before the controller is ready
    bool SourceMode;    // "View Source" (Ctrl+U): raw text instead of rendered
    bool DarkMenus;     // IsDarkThemeActive() snapshot at creation; owner-drawn
                        // dark menu when set (036 convention: reopen adopts)

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
    void RefreshSchemeChecks();
    const MdTheme* EffectiveTheme();
    void RebuildHtml();                                               // (re)generate Html only
    void ShowDocument(const std::wstring& fragment = std::wstring()); // serve + navigate
    void Regenerate(const std::wstring& fragment = std::wstring());   // RebuildHtml + ShowDocument
    void RenderDocument();
    void SetZoom(int pct);
    void SelectScheme(int idx);
    void CycleScheme(int dir);
    void DoFind(BOOL forward, BOOL prompt);
    void ActivateLink(const std::wstring& uri);
    void UpdateTitle();
    void EngineFailed();
};
