// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salarcpwd.h
//
// The two forms of a typed archive password (feature 093, contract P1 of
// specs/093-unicode-dialogs/contracts/dialog-unicode.md). Header-only, no
// globals, testable in saltests.
//
// TRUE form:   the typed text, UTF-16, unchanged.
// LEGACY form: what the 7-Zip plug-in handed to the engine up to 0.1.8 - the
//              dialog stored the text as UTF-8 in a 128-byte buffer and the
//              consumers read those bytes as text of the system code page
//              (MultiByteToWideChar(CP_ACP, 0, ...), 7-Zip's
//              MultiByteToUnicodeString, the same in 16.04 and 26.03).
//              "heslo-" U+0159 became "heslo-" U+0139 U+2122 on code page 1250.
//              Archives the plug-in created were encrypted with that form.
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

// size of the old dialog buffer in bytes, terminator included
#define SALARCPWD_OLD_BUFFER 128

// TRUE when 'typed' has no character above U+007F: the two forms are equal
inline BOOL SalArcPwdIsAscii(const wchar_t* typed)
{
    if (typed == NULL)
        return TRUE;
    for (; *typed != 0; typed++)
        if (*typed > 0x7F)
            return FALSE;
    return TRUE;
}

// Writes the legacy form of 'typed' to 'out' ('outChars' units, terminator
// included). Returns FALSE (and an empty 'out') when it does not fit or cannot
// be derived. 'codePage' is CP_ACP in the product; a test passes a fixed one.
//
// The old dialog code, step by step:
//  1. strict UTF-8 (WC_ERR_INVALID_CHARS) into the 128-byte buffer;
//  2. when that failed (more than 127 bytes, or an unpaired surrogate), the
//     field was read as code-page text instead, cut to 127 bytes;
//  3. the consumers decoded the buffer with the code page, flags 0.
inline BOOL SalArcPwdLegacy(const wchar_t* typed, wchar_t* out, int outChars, UINT codePage = CP_ACP)
{
    if (out == NULL || outChars <= 0)
        return FALSE;
    out[0] = 0;
    if (typed == NULL)
        return FALSE;
    if (typed[0] == 0)
        return TRUE;

    char bytes[SALARCPWD_OLD_BUFFER];
    BOOL ok = FALSE;
    int len = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, typed, -1, bytes, SALARCPWD_OLD_BUFFER, NULL, NULL);
    if (len <= 0)
    {
        // step 2: the code-page read (WM_GETTEXT of the narrow kind), cut to the buffer
        int need = WideCharToMultiByte(codePage, 0, typed, -1, NULL, 0, NULL, NULL);
        char* all = need > 0 ? (char*)HeapAlloc(GetProcessHeap(), 0, need) : NULL;
        if (all != NULL)
        {
            if (WideCharToMultiByte(codePage, 0, typed, -1, all, need, NULL, NULL) == need)
            {
                len = need < SALARCPWD_OLD_BUFFER ? need : SALARCPWD_OLD_BUFFER;
                memcpy(bytes, all, len);
                bytes[len - 1] = 0;
            }
            SecureZeroMemory(all, need);
            HeapFree(GetProcessHeap(), 0, all);
        }
    }
    if (len > 1)
    {
        // step 3; len - 1 bytes give at most len - 1 units
        int n = MultiByteToWideChar(codePage, 0, bytes, len - 1, out, outChars - 1);
        if (n > 0)
        {
            out[n] = 0;
            ok = TRUE;
        }
        else
        {
            SecureZeroMemory(out, outChars * sizeof(wchar_t));
            out[0] = 0;
        }
    }
    else
        ok = (len == 1); // nothing but the terminator
    SecureZeroMemory(bytes, sizeof(bytes));
    return ok;
}

// TRUE when the legacy form exists and differs from the typed text - only
// then is a second attempt with the legacy form worth making. Always FALSE
// for an ASCII password.
inline BOOL SalArcPwdHasLegacy(const wchar_t* typed, UINT codePage = CP_ACP)
{
    if (SalArcPwdIsAscii(typed))
        return FALSE;
    wchar_t legacy[SALARCPWD_OLD_BUFFER];
    BOOL differs = SalArcPwdLegacy(typed, legacy, SALARCPWD_OLD_BUFFER, codePage) && wcscmp(legacy, typed) != 0;
    SecureZeroMemory(legacy, sizeof(legacy));
    return differs;
}
