// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salcpfit.h
//
// Pure rule of feature 248: a display text (not a name, not a path) handed to
// a code-page sink of a fixed size - e.g. a plug-in's column name
// (CColumn::Name, drawn by the core with the A functions). Header-only, no
// globals, usable from plug-ins; saltests checks it.
//
//   SalWToCodePageWhole  wide text -> code page, no best-fit, shortened at a
//                        whole character when it does not fit
//
//*****************************************************************************

#include <windows.h>
#include <wchar.h>

// The wide text 'w' in 'codePage' (CP_ACP: the system's code page) into 'buf' of 'bufSize'
// bytes with the terminator. No best-fit: a character outside the code page becomes the code
// page's default character, never a different-looking letter. A text that does not fit is
// shortened at a whole character - never half a surrogate pair, never half a double-byte
// character; a high surrogate torn off its pair at the end of 'w' (an earlier cut) is dropped.
// Returns the bytes written without the terminator: 0 for an empty text or when not even one
// character fits ('buf' is then empty); -1 when 'buf' is NULL or 'bufSize' <= 0.
inline int SalWToCodePageWhole(const wchar_t* w, char* buf, int bufSize, UINT codePage = CP_ACP)
{
    if (buf == NULL || bufSize <= 0)
        return -1;
    buf[0] = 0;
    if (w == NULL || bufSize < 2) // a size of 0 would make WideCharToMultiByte return the needed size
        return 0;
    int len = (int)wcslen(w);
    if (len > 0 && IS_HIGH_SURROGATE(w[len - 1]))
        len--;
    UINT cp = codePage == CP_ACP ? GetACP() : (codePage == CP_OEMCP ? GetOEMCP() : codePage);
    // the "UTF-8 system code page" setting (and the few code pages that reject the flag)
    DWORD flags = (cp == CP_UTF8 || cp == CP_UTF7) ? 0 : WC_NO_BEST_FIT_CHARS;
    while (len > 0)
    {
        int n = WideCharToMultiByte(cp, flags, w, len, buf, bufSize - 1, NULL, NULL);
        if (n > 0)
        {
            buf[n] = 0;
            return n;
        }
        DWORD err = GetLastError();
        if (err == ERROR_INVALID_FLAGS && flags != 0)
        {
            flags = 0;
            continue;
        }
        if (err != ERROR_INSUFFICIENT_BUFFER)
            break;
        // one whole character less: a surrogate pair goes as a pair
        len -= (len >= 2 && IS_LOW_SURROGATE(w[len - 1]) && IS_HIGH_SURROGATE(w[len - 2])) ? 2 : 1;
    }
    buf[0] = 0;
    return 0;
}
