// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <windows.h>

#include "salcloseapp.h"

// winuser.h declares these from _WIN32_WINNT 0x0600; keep the module
// compilable wherever it is included
#ifndef ENDSESSION_CLOSEAPP
#define ENDSESSION_CLOSEAPP 0x00000001
#endif
#ifndef ENDSESSION_CRITICAL
#define ENDSESSION_CRITICAL 0x40000000
#endif

BOOL SalIsCloseAppRequest(LPARAM lParam, BOOL sessionShuttingDown)
{
    if ((lParam & ENDSESSION_CLOSEAPP) == 0)
        return FALSE; // sign-out / shutdown
    if ((lParam & ENDSESSION_CRITICAL) != 0)
        return FALSE; // forced: the critical-shutdown path knows how to survive being killed
    if (sessionShuttingDown)
        return FALSE; // Windows is closing programs for servicing - a real shutdown
    return TRUE;
}

BOOL SalCloseAppWindowIsForeign(const CSalCloseAppWindow& w)
{
    if (!w.Visible || w.Kind != scawOther)
        return FALSE;
    BOOL hasCaption = (w.Style & WS_CAPTION) == WS_CAPTION;
    BOOL toolLike = (w.ExStyle & (WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE)) != 0;
    if (!hasCaption && toolLike)
        return FALSE; // a tooltip, a save-bits or IME window - not something a user works in
    return TRUE;
}

CSalCloseAppDecision SalCloseAppDecide(const CSalCloseAppSnapshot& s)
{
    if (!s.StartupFinished || s.CloseInProgress)
        return scadStartupOrClosing;
    if (s.Busy)
        return scadBusy;
    if (s.InsidePlugin)
        return scadInsidePlugin;
    if (s.FileOperations > 0)
        return scadFileOperations;
    if (s.FindSearching > 0)
        return scadFindSearching;
    if (s.ArchiveEditsPending)
        return scadArchiveEdits;
    if (s.PluginFSOpen)
        return scadPluginFS;
    if (s.Windows != NULL)
    {
        for (int i = 0; i < s.WindowCount; i++)
        {
            if (SalCloseAppWindowIsForeign(s.Windows[i]))
                return scadForeignWindow;
        }
    }
    return scadAgree;
}

const char* SalCloseAppDecisionName(CSalCloseAppDecision d)
{
    switch (d)
    {
    case scadAgree:
        return "agree";
    case scadStartupOrClosing:
        return "decline: start-up not finished or a close is already under way";
    case scadBusy:
        return "decline: busy (modal dialog, menu or command)";
    case scadInsidePlugin:
        return "decline: inside a plug-in call";
    case scadFileOperations:
        return "decline: file operations are running";
    case scadFindSearching:
        return "decline: a Find window is searching";
    case scadArchiveEdits:
        return "decline: files opened from an archive may have to be packed back";
    case scadPluginFS:
        return "decline: a plug-in file system is open";
    case scadForeignWindow:
        return "decline: a plug-in (or other unknown) window is open";
    }
    return "decline: unknown";
}

// appends 'text' to 'out' at 'pos' when it fits (terminating zero included); all or nothing
static BOOL AppendWhole(WCHAR* out, int outLen, int& pos, const WCHAR* text, int textLen)
{
    if (pos + textLen + 1 > outLen)
        return FALSE;
    for (int i = 0; i < textLen; i++)
        out[pos + i] = text[i];
    pos += textLen;
    out[pos] = 0;
    return TRUE;
}

BOOL SalRestartCommandLine(WCHAR* out, int outLen, BOOL hasTitlePrefix, const WCHAR* titlePrefix,
                           BOOL hasIconIndex, int iconIndex)
{
    if (out == NULL || outLen < 1)
        return FALSE;
    out[0] = 0;
    int pos = 0;

    if (hasTitlePrefix)
    {
        if (titlePrefix == NULL)
            titlePrefix = L""; // -t "" is an identity too: it forces "no prefix" over the configured one
        // -t "<prefix>": measure first, so that a prefix that does not fit leaves no trace
        int need = 4; // -t "
        for (const WCHAR* p = titlePrefix; *p != 0; p++)
            need += (*p == L'"') ? 2 : 1;
        need += 1; // closing quote
        if (pos + need + 1 <= outLen)
        {
            WCHAR* d = out + pos;
            *d++ = L'-';
            *d++ = L't';
            *d++ = L' ';
            *d++ = L'"';
            for (const WCHAR* p = titlePrefix; *p != 0; p++)
            {
                if (*p == L'"')
                    *d++ = L'"'; // GetCmdLine reads "" inside a quoted argument as one quote
                *d++ = *p;
            }
            *d++ = L'"';
            *d = 0;
            pos += need;
        }
    }

    if (hasIconIndex && iconIndex >= 0 && iconIndex <= 3)
    {
        WCHAR part[8];
        int n = 0;
        if (pos > 0)
            part[n++] = L' ';
        part[n++] = L'-';
        part[n++] = L'i';
        part[n++] = L' ';
        part[n++] = (WCHAR)(L'0' + iconIndex);
        AppendWhole(out, outLen, pos, part, n);
    }
    return TRUE;
}
