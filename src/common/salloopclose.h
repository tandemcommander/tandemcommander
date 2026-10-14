// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salloopclose.h
//
// A close request for a window whose thread may be inside one of its own
// loops - the pure part (feature 143). Header-only, no globals; saltests
// checks it. The Disk Map plug-in uses it for its map window.
//
// A modal or menu loop on a window's thread dispatches a posted WM_CLOSE; if
// the window's procedure lets DefWindowProc destroy the window there, the code
// that opened the loop runs on into objects the window's WM_DESTROY freed
// (measured in 0.1.10: Disk Map crashed on exit with its context menu or a
// shell command's confirmation open). The window counts what it is inside of
// and asks this module what a close request means:
//
//   no loop          - close now (as before)
//   inside a loop    - the close is PENDING; a popup menu is ended (no command),
//                      the window's own boxes are cancelled - but not while a
//                      shell command runs: the shell's windows are never
//                      answered for the user
//   last loop left   - a pending close is carried out now (once)
//   request given up - the pending close is dropped: the window stays
//
// The window also withdraws its "closes unattended" declaration (interface 107)
// while it is inside a loop: SalLoopEnter / SalLoopLeave report the first
// entry and the last exit.
//
// Contract: specs/143-diskmap-release-guard/contracts/close-in-loop.md
//
//*****************************************************************************

#include <windows.h>

enum CSalLoopKind
{
    slkMenu,   // a popup menu (TrackPopupMenu[Ex])
    slkOwnBox, // a box or dialog of the window's own code (About, a confirmation)
    slkShell   // a shell command (IContextMenu::InvokeCommand) with whatever it shows
};

struct CSalLoopCloseState
{
    int Menus;
    int OwnBoxes;
    int ShellCommands;
    // a close is pending - asked by the plug-in's Release() (it may give the request up again) or by
    // anything else: the window's own close routes, the person, the system (never given up)
    BOOL ClosePendingRelease;
    BOOL ClosePendingOther;
};

inline void SalLoopInit(CSalLoopCloseState* s)
{
    s->Menus = 0;
    s->OwnBoxes = 0;
    s->ShellCommands = 0;
    s->ClosePendingRelease = FALSE;
    s->ClosePendingOther = FALSE;
}

inline BOOL SalLoopClosePending(const CSalLoopCloseState* s)
{
    return s->ClosePendingRelease || s->ClosePendingOther;
}

inline BOOL SalLoopInside(const CSalLoopCloseState* s)
{
    return s->Menus > 0 || s->OwnBoxes > 0 || s->ShellCommands > 0;
}

// counts a loop of 'kind'; TRUE when it is the window's first open loop (the
// caller withdraws its unattended-close declaration then)
inline BOOL SalLoopEnter(CSalLoopCloseState* s, CSalLoopKind kind)
{
    BOOL first = !SalLoopInside(s);
    switch (kind)
    {
    case slkMenu:
        s->Menus++;
        break;
    case slkOwnBox:
        s->OwnBoxes++;
        break;
    default:
        s->ShellCommands++;
        break;
    }
    return first;
}

struct CSalLoopLeave
{
    BOOL Last;      // no loop is open any more
    BOOL CloseNow;  // Last and a close was pending: carry it out (post WM_CLOSE) - reported once
    BOOL Redeclare; // Last and no close pending: the declaration may come back
};

inline CSalLoopLeave SalLoopLeave(CSalLoopCloseState* s, CSalLoopKind kind)
{
    CSalLoopLeave r = {FALSE, FALSE, FALSE};
    if (!SalLoopInside(s))
        return r; // unbalanced leave: nothing was open, nothing to report
    int* n = kind == slkMenu ? &s->Menus : kind == slkOwnBox ? &s->OwnBoxes
                                                             : &s->ShellCommands;
    if (*n > 0)
        (*n)--;
    if (!SalLoopInside(s))
    {
        r.Last = TRUE;
        r.CloseNow = SalLoopClosePending(s);
        r.Redeclare = !r.CloseNow;
        s->ClosePendingRelease = FALSE; // the posted WM_CLOSE carries it now
        s->ClosePendingOther = FALSE;
    }
    return r;
}

struct CSalLoopClose
{
    BOOL CloseNow;       // no loop: close (destroy) as before
    BOOL EndMenu;        // end the open popup menu without a command
    BOOL CancelOwnBoxes; // cancel the window's own open boxes
};

// the request that made a close pending was given up by its sender (the plug-in's Release() did not
// get the window closed in time and returned FALSE: the core then asks "force?" or abandons an
// installer's close) - the window stays when its loop ends, unless a close asked for by anything
// else is pending too (the person closed the window meanwhile: review of 143); TRUE when the
// window stays because of it
inline BOOL SalLoopCloseAbandon(CSalLoopCloseState* s)
{
    BOOL was = s->ClosePendingRelease;
    s->ClosePendingRelease = FALSE;
    return was && !s->ClosePendingOther;
}

// a close request (WM_CLOSE) arrived; 'fromRelease': asked by the plug-in's Release()
inline CSalLoopClose SalLoopCloseRequest(CSalLoopCloseState* s, BOOL fromRelease)
{
    CSalLoopClose r = {FALSE, FALSE, FALSE};
    if (!SalLoopInside(s))
    {
        r.CloseNow = TRUE;
        return r;
    }
    if (fromRelease)
        s->ClosePendingRelease = TRUE;
    else
        s->ClosePendingOther = TRUE;
    r.EndMenu = s->Menus > 0;
    r.CancelOwnBoxes = s->OwnBoxes > 0 && s->ShellCommands == 0;
    return r;
}
