// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salmoveback.h
//
// Feature 221 / 281: an entry moved aside to a temporary name ("salNNN") for an 8.3 name clash is
// moved back to its own name; a scanner or an indexer may hold it for a moment, so the move back is
// tried for about a second while the failure is a sharing / lock violation or access denied. One
// rule for the core (SalMoveFileBack) and the plug-ins that move aside themselves (PictView,
// Renamer - through SalamanderGeneral->SalMoveFile).
//
// Debug builds only: the probe seam TC_PROBE_MOVE_BACK_FAIL=<n> makes the first n move-back
// attempts of the module fail with ERROR_SHARING_VIOLATION without touching the disk
// (specs/281-moved-aside-leftovers/contracts/probe-seam.md).
//
// Header-only; needs <windows.h>; checked by saltests.
//
//*****************************************************************************

#define SAL_MOVE_BACK_RETRIES 10  // attempts after the first one
#define SAL_MOVE_BACK_WAIT_MS 100 // between two attempts

// is the failure of a move back worth another attempt (another process holds the entry)?
inline BOOL SalMoveBackRetryable(DWORD err)
{
    return err == ERROR_SHARING_VIOLATION || err == ERROR_ACCESS_DENIED || err == ERROR_LOCK_VIOLATION;
}

// the seam's count from the variable's text: 1 to 1,000,000 decimal digits only, anything else 0 (off)
inline LONG SalMoveBackSeamParse(const WCHAR* text)
{
    if (text == NULL || text[0] == 0)
        return 0;
    LONG n = 0;
    for (const WCHAR* s = text; *s != 0; s++)
    {
        if (*s < L'0' || *s > L'9')
            return 0;
        n = n * 10 + (*s - L'0');
        if (n > 1000000)
            return 0;
    }
    return n;
}

// takes one failure from the seam's count: TRUE while any is left
inline BOOL SalMoveBackSeamTake(volatile LONG* remaining)
{
    while (1)
    {
        LONG v = *remaining;
        if (v <= 0)
            return FALSE;
        if (InterlockedCompareExchange(remaining, v - 1, v) == v)
            return TRUE;
    }
}

// the move back: 'move(&err)' returns TRUE when done, else FALSE with 'err' set; 'wait(ms)' waits;
// 'seamFails()' TRUE = this attempt fails (the probe seam). Returns TRUE when moved back; else
// FALSE and '*lastErr' (if not NULL) holds the last attempt's error
template <class TMove, class TWait, class TSeam>
BOOL SalMoveBackRetryEx(TMove move, TWait wait, TSeam seamFails, DWORD* lastErr)
{
    for (int attempt = 0;; attempt++)
    {
        DWORD err = ERROR_SUCCESS;
        BOOL done = FALSE;
        if (seamFails())
            err = ERROR_SHARING_VIOLATION;
        else
            done = move(&err);
        if (done)
        {
            if (lastErr != NULL)
                *lastErr = ERROR_SUCCESS;
            return TRUE;
        }
        if (lastErr != NULL)
            *lastErr = err;
        if (attempt >= SAL_MOVE_BACK_RETRIES || !SalMoveBackRetryable(err))
            return FALSE;
        wait((DWORD)SAL_MOVE_BACK_WAIT_MS);
    }
}

#ifdef _DEBUG
// the probe seam of this module (read once)
inline BOOL SalMoveBackSeamFails()
{
    static volatile LONG remaining = -1; // -1 = not read yet
    if (remaining == -1)
    {
        WCHAR buf[16];
        DWORD len = GetEnvironmentVariableW(L"TC_PROBE_MOVE_BACK_FAIL", buf, _countof(buf));
        InterlockedCompareExchange(&remaining, len > 0 && len < _countof(buf) ? SalMoveBackSeamParse(buf) : 0, -1);
    }
    return SalMoveBackSeamTake(&remaining);
}
#endif // _DEBUG

// SalMoveBackRetryEx with Sleep and (Debug builds) the probe seam
template <class TMove>
BOOL SalMoveBackRetry(TMove move, DWORD* lastErr)
{
#ifdef _DEBUG
    return SalMoveBackRetryEx(
        move, [](DWORD ms)
        { Sleep(ms); },
        []()
        { return SalMoveBackSeamFails(); },
        lastErr);
#else
    return SalMoveBackRetryEx(
        move, [](DWORD ms)
        { Sleep(ms); },
        []()
        { return FALSE; },
        lastErr);
#endif
}
