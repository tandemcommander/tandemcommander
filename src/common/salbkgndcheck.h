// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salbkgndcheck.h
//
// The background path check of a panel (feature 372). Switching back to the
// program with a network folder in a panel (a WSL folder \\wsl.localhost\...
// above all) checked the folder on the UI thread, and every refresh of a
// monitored folder whose change notification failed (9P has none) slept 400 ms
// and listed the folder a second time to notice a folder being deleted. Both
// now ask a worker thread whether the folder is still accessible; the panel
// acts on the answer only while it still shows that folder.
// Header-only, no globals; saltests checks it.
//
//*****************************************************************************

#include <windows.h>

// what asked for a background check (bits; a request while one runs adds its bit)
#define SAL_BKCHK_ACTIVATE 0x01 // the program was activated (the old synchronous CheckPath of Activate)
#define SAL_BKCHK_VERIFY 0x02   // 400 ms after a refresh of a folder without automatic refresh

// a running check older than this is taken as hung (a dead network redirector): a new request
// abandons it and starts a new worker (the old code blocked the window but recovered; a hung
// worker must not swallow every later activation of the panel)
#define SAL_BKCHK_ABANDON_MS 10000

// TRUE when a new request must not wait for the running check of the panel: it checks another
// folder than the panel shows now, or it has run for SAL_BKCHK_ABANDON_MS or longer
inline BOOL SalBkgndCheckAbandon(DWORD runningForMs, BOOL samePath)
{
    return !samePath || runningForMs >= SAL_BKCHK_ABANDON_MS;
}

// what the panel does with a finished check
enum CSalBkgndCheckAction
{
    sbcaNone,      // nothing (not wanted, or a verified folder that is still accessible)
    sbcaRefreshEx, // post WM_USER_REFRESH_DIR_EX - the activation's refresh, as before
    sbcaRefresh,   // post WM_USER_REFRESH_DIR - the folder is not accessible; the refresh leaves it
    sbcaRestart,   // the panel shows another folder now: check the current one again
};

// TRUE when the activation checks the panel's folder in the background instead of on the UI
// thread: a disk or archive panel on a network folder (drive type remote - UNC paths, mapped
// network drives, \\wsl.localhost\..., \\wsl$\...). Local folders keep the synchronous check.
inline BOOL SalBkgndCheckRoute(BOOL isDiskOrArchive, BOOL isNetwork)
{
    return isDiskOrArchive && isNetwork;
}

// TRUE when a refresh that listed the folder must verify it again 400 ms later: the folder is
// monitored but its automatic refresh failed (the condition of the old Sleep(400) + second listing)
inline BOOL SalNeedsAutoRefreshVerify(BOOL isRefresh, BOOL listed, BOOL monitorChanges, BOOL automaticRefresh)
{
    return isRefresh && listed && monitorChanges && !automaticRefresh;
}

// the action for a finished check: 'wanted' = the SAL_BKCHK_* bits asked for since it started,
// 'samePath' = the panel still shows the checked folder (same panel type, same path by the file
// system's rule), 'valid' = the folder is accessible
inline CSalBkgndCheckAction SalBkgndCheckAction(int wanted, BOOL samePath, BOOL valid)
{
    if ((wanted & (SAL_BKCHK_ACTIVATE | SAL_BKCHK_VERIFY)) == 0)
        return sbcaNone;
    if (!samePath)
        return sbcaRestart;
    if (!valid)
        return sbcaRefresh;
    return (wanted & SAL_BKCHK_ACTIVATE) ? sbcaRefreshEx : sbcaNone;
}
