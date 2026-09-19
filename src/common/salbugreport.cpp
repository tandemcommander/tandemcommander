// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <windows.h>

#include "salbugreport.h"

// writes 'value' as exactly 'digits' decimal digits (zero-padded); FALSE when it does not fit
static BOOL WriteFixedDigits(WCHAR*& p, unsigned value, int digits)
{
    unsigned limit = 1;
    for (int i = 0; i < digits; i++)
        limit *= 10;
    if (value >= limit)
        return FALSE;
    for (int i = digits - 1; i >= 0; i--)
    {
        p[i] = (WCHAR)(L'0' + value % 10);
        value /= 10;
    }
    p += digits;
    return TRUE;
}

BOOL SalFormatBugReportName(WCHAR* out, int outLen, const char* shortVersion, const SYSTEMTIME& t, int suffix)
{
    if (out != NULL && outLen > 0)
        out[0] = 0;
    if (out == NULL || outLen <= 0 || shortVersion == NULL || shortVersion[0] == 0)
        return FALSE;
    if (suffix < 0 || suffix > 99)
        return FALSE;

    // validate the version tag and measure it
    int verLen = 0;
    for (const char* s = shortVersion; *s != 0; s++, verLen++)
    {
        char c = *s;
        BOOL ok = (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
        if (!ok)
            return FALSE;
    }

    // "TC" + version + "-YYYYMMDD" + "-HHMMSS" + ["-n" | "-nn"] + ".TXT" + NUL
    int suffixLen = suffix == 0 ? 0 : (suffix < 10 ? 2 : 3);
    int needed = 2 + verLen + 9 + 7 + suffixLen + 4 + 1;
    if (needed > outLen)
        return FALSE;

    WCHAR* p = out;
    *p++ = L'T';
    *p++ = L'C';
    for (const char* s = shortVersion; *s != 0; s++)
    {
        char c = *s;
        if (c >= 'a' && c <= 'z')
            c = (char)(c - 'a' + 'A');
        *p++ = (WCHAR)(unsigned char)c;
    }
    *p++ = L'-';
    if (!WriteFixedDigits(p, t.wYear, 4) || !WriteFixedDigits(p, t.wMonth, 2) || !WriteFixedDigits(p, t.wDay, 2))
    {
        out[0] = 0;
        return FALSE;
    }
    *p++ = L'-';
    if (!WriteFixedDigits(p, t.wHour, 2) || !WriteFixedDigits(p, t.wMinute, 2) || !WriteFixedDigits(p, t.wSecond, 2))
    {
        out[0] = 0;
        return FALSE;
    }
    if (suffix > 0)
    {
        *p++ = L'-';
        if (suffix >= 10)
            *p++ = (WCHAR)(L'0' + suffix / 10);
        *p++ = (WCHAR)(L'0' + suffix % 10);
    }
    *p++ = L'.';
    *p++ = L'T';
    *p++ = L'X';
    *p++ = L'T';
    *p = 0;
    return TRUE;
}
