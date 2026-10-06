// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salftpsecret.h
//
// The FTP plug-in's secret fields - the password, the account (ACCT), the
// proxy password and the anonymous password - and the rule by which its
// dialogs take a field's text (feature 116).
//
// A secret field accepts SAL_FTP_SECRET_MAX_CHARS UTF-16 units, as it always
// did. Its text travels as UTF-8 (WTF-8 for a lone surrogate), and one UTF-16
// unit needs at most 3 bytes there (a character of the BMP or a lone surrogate:
// 3; a surrogate pair: 4 bytes for 2 units). A buffer of SAL_FTP_SECRET_BUF
// bytes therefore holds ANY text the field accepts - no secret can be "too long"
// or cut. Until feature 116 the buffers held 101 bytes, so a password of 51 or
// more two-byte letters (Czech) was re-read through the code page (0.1.8) or
// refused (feature 104).
//
// Header-only and without globals: the FTP plug-in cannot be linked into
// saltests, these rules can. Needs the plug-ins' WTF-8 converters
// (splunicode.h), which is what the dialogs use to show a stored value.
//
//*****************************************************************************

#include "../plugins/shared/splunicode.h"

// UTF-16 units a secret field accepts (EM_LIMITTEXT) - unchanged since Open Salamander
#define SAL_FTP_SECRET_MAX_CHARS 100
// the most bytes one UTF-16 unit needs in UTF-8 / WTF-8
#define SAL_FTP_UTF8_MAX_BYTES_PER_UNIT 3
// bytes (terminator included) that hold the UTF-8 form of any text a secret field accepts
#define SAL_FTP_SECRET_BUF (SAL_FTP_SECRET_MAX_CHARS * SAL_FTP_UTF8_MAX_BYTES_PER_UNIT + 1)

// The largest number of bytes the UTF-8 (WTF-8) form of 'units' UTF-16 units can need, the
// terminator not counted.
inline int SalFtpWorstUtf8Bytes(int units)
{
    return units <= 0 ? 0 : units * SAL_FTP_UTF8_MAX_BYTES_PER_UNIT;
}

// TRUE when the field's text 'fieldText' is exactly the text the stored value 'stored' is shown
// as - the dialog then keeps the STORED BYTES instead of reading the field.
//
// A dialog shows a stored value as UTF-8 (WTF-8) when it is that, and otherwise through the code
// page 'codePage' (CTransferInfo::EditLine: SplU8ToWAlloc, else WM_SETTEXT A - CP_ACP). Reading
// the field gives UTF-8, so for a value that is not UTF-8 reading would change the bytes: a
// password that 0.1.8 or earlier saved in code-page bytes (its fallback for a text over 100 UTF-8
// bytes) is shown correctly, but the field reads back as other bytes - and the server's account
// was made with the old ones. For a UTF-8 value keeping and reading give the same bytes.
//
// The rule compares texts, not the edit's "modified" flag: a text put into the field by another
// program (an accessibility or password tool sends WM_SETTEXT, which clears that flag) is taken
// whenever it differs from what was shown. An EMPTY stored value never matches: an empty field is
// read (the same empty value), and the dialogs empty a field to delete a value.
inline bool SalFtpFieldShowsStored(const char* stored, const WCHAR* fieldText, UINT codePage)
{
    if (stored == NULL || stored[0] == 0 || fieldText == NULL)
        return false;
    bool same = false;
    WCHAR* shown = SplU8ToWAlloc(stored);
    if (shown != NULL)
    {
        same = wcscmp(shown, fieldText) == 0;
        SecureZeroMemory(shown, wcslen(shown) * sizeof(WCHAR));
        free(shown);
        return same;
    }
    int len = MultiByteToWideChar(codePage, 0, stored, -1, NULL, 0);
    if (len <= 0)
        return false;
    shown = (WCHAR*)malloc((size_t)len * sizeof(WCHAR));
    if (shown == NULL)
        return false;
    if (MultiByteToWideChar(codePage, 0, stored, -1, shown, len) == len)
        same = wcscmp(shown, fieldText) == 0;
    SecureZeroMemory(shown, (size_t)len * sizeof(WCHAR));
    free(shown);
    return same;
}

// Feature 121: a login typed into a path (ftp://user:password@host/path) whose parts do not fit
// the plug-in's buffers is refused, never cut. 'userPart' is the text after "ftp:" that the plug-in
// copies into 'userPartBufSize' bytes before splitting it; 'user', 'host' and 'password' are the
// parts split from that copy (NULL = absent) and the sizes their buffers (terminator included).
// lstrcpyn cut them - inside a UTF-8 character too: a cut user name or host is ANOTHER account or
// server (and the password went there), a cut user part could end inside the password.
inline bool SalFtpTypedLoginTooLong(const char* userPart, size_t userPartBufSize,
                                    const char* user, size_t userBufSize,
                                    const char* host, size_t hostBufSize,
                                    const char* password, size_t passwordBufSize)
{
    if (userPart != NULL && strlen(userPart) >= userPartBufSize)
        return true;
    if (user != NULL && strlen(user) >= userBufSize)
        return true;
    if (host != NULL && strlen(host) >= hostBufSize)
        return true;
    if (password != NULL && strlen(password) >= passwordBufSize)
        return true;
    return false;
}
