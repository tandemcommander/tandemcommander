// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salclipcheck.h
//
// The idle clipboard check of the main window (feature 375). Every activation
// of the program asks the next idle to find out whether Paste, Paste Shortcuts
// and the paste of a path are available. While another program kept the
// clipboard open, the text query retried OpenClipboard ten times with
// Sleep(10) and blocked the window ~150 ms on every activation. The idle check
// now tries once; a busy clipboard is looked at again a little later, a
// bounded number of times. This header decides when.
// Header-only, no globals; saltests checks it.
//
//*****************************************************************************

#include <windows.h>

#define SAL_CLIPCHECK_RETRY_MS 500  // a busy clipboard is looked at again after this delay
#define SAL_CLIPCHECK_MAX_RETRIES 10 // at most this many looks after one trigger (5 s)

// After an idle clipboard check: the delay [ms] of the next look, 0 = none.
// 'busy' - the check could not open the clipboard (another program keeps it open);
// 'wasRetry' - the check was requested by a previous look (not by an activation, a menu,
// a dialog, a paste, ...); '*retries' - the looks of the current series (updated).
// A free clipboard ends the series; any other trigger starts a new one.
inline UINT SalClipCheckNextLook(BOOL busy, BOOL wasRetry, int* retries)
{
    if (!wasRetry || !busy)
        *retries = 0;
    if (!busy)
        return 0;
    if (*retries >= SAL_CLIPCHECK_MAX_RETRIES)
        return 0;
    (*retries)++;
    return SAL_CLIPCHECK_RETRY_MS;
}
