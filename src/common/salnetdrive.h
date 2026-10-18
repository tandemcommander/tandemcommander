// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salnetdrive.h (feature 246)
//
// A mapped network drive was shown in the Change Drive menu and the drive bar
// tooltip by its UNC path only, although Windows shows the name the user (or a
// policy) gave the drive in Explorer; and the drive bar kept the "connected"
// icon of a drive whose connection Windows reports as unavailable. The pure
// decisions of the fix are here, so that saltests checks them:
//
//   SalNetDriveNameKey        the Explorer key that holds a drive's name:
//                             HKCU\...\Explorer\MountPoints2\##server#share#path
//   SalNetDriveCleanName      a name read from that key, made safe for a menu
//   SalNetDriveText           "Name (\\server\share\path)", or the path alone
//   SalNetDriveIsDisconnected the drive's state from Windows' local answers
//
// Wide strings (the producers are WNetGetConnectionW and RegQueryValueExW; the
// caller converts the result to UTF-8). Nothing is ever cut: a result that does
// not fit is refused or its size is reported. Header-only.
//
//*****************************************************************************

// winerror.h / winnetwk.h values, repeated because saltests does not include
// winnetwk.h; drivelst.cpp ties them to the SDK with static_assert
#define SALNETDRV_ERROR_CONNECTION_UNAVAIL 1201 // ERROR_CONNECTION_UNAVAIL
#define SALNETDRV_WNGC_DISCONNECTED 1           // WNGC_DISCONNECTED

// Explorer's MountPoints2 sub-key name of a mapped network path: the leading
// "\\" becomes "##", every further '\' becomes '#', all other characters are
// copied as they are (Explorer does the same - a '#' in the path stays '#';
// measured, specs/246-network-drive-labels/analysis.md G1). Trailing
// backslashes are ignored. FALSE (and an empty 'key') for anything that is not
// "\\server\share[\path...]": NULL or empty, no "\\" prefix, the device
// prefixes "\\?\" and "\\.\", an empty server, no share, an empty component
// inside the path, or a key that does not fit 'keySize' units (refused, never
// cut).
inline BOOL SalNetDriveNameKey(const WCHAR* remote, WCHAR* key, int keySize)
{
    if (key != NULL && keySize > 0)
        key[0] = 0;
    if (remote == NULL || remote[0] != L'\\' || remote[1] != L'\\' || key == NULL || keySize <= 0)
        return FALSE;
    int len = (int)wcslen(remote);
    while (len > 2 && remote[len - 1] == L'\\') // "\\srv\share\" -> "\\srv\share"
        len--;
    const WCHAR* s = remote + 2;
    const WCHAR* end = remote + len;
    if (s >= end || *s == L'\\')
        return FALSE; // "\\" or "\\\x": no server
    if (end - s >= 2 && (s[0] == L'?' || s[0] == L'.') && s[1] == L'\\')
        return FALSE; // "\\?\..." and "\\.\..." are device prefixes, not servers
    int components = 1;
    for (const WCHAR* p = s; p < end; p++)
    {
        if (*p == L'\\')
        {
            if (p + 1 >= end || p[1] == L'\\')
                return FALSE; // an empty component ("\\srv\\x")
            components++;
        }
    }
    if (components < 2)
        return FALSE; // "\\server" - a drive maps a share, never a server alone
    int keyLen = len; // "\\" -> "##" keeps the length
    if (keyLen + 1 > keySize)
        return FALSE;
    key[0] = L'#';
    key[1] = L'#';
    for (int i = 2; i < len; i++)
        key[i] = remote[i] == L'\\' ? L'#' : remote[i];
    key[keyLen] = 0;
    return TRUE;
}

// Makes a name read from the registry safe to show in place: every control
// character (below U+0020, and U+007F) becomes a space - a tab would split the
// menu's columns, a line break the menu line - and leading and trailing spaces
// are removed. Returns the length in units; 0 = no name (NULL, empty, blank).
inline int SalNetDriveCleanName(WCHAR* name)
{
    if (name == NULL)
        return 0;
    for (WCHAR* p = name; *p != 0; p++)
    {
        if (*p < 0x20 || *p == 0x7F)
            *p = L' ';
    }
    WCHAR* b = name;
    while (*b == L' ')
        b++;
    int len = (int)wcslen(b);
    while (len > 0 && b[len - 1] == L' ')
        len--;
    if (b != name)
        memmove(name, b, len * sizeof(WCHAR));
    name[len] = 0;
    return len;
}

// The text shown for a mapped drive: "Name (\\server\share\path)", or the path
// alone when there is no name or the name is the path (case ignored, as the
// file system compares). With 'doubleAmpersands' every '&' is written as "&&"
// (the menu draws the column with prefix processing; the tooltip does not).
// Returns the number of units needed INCLUDING the terminator; the text is
// written only when 'out' has room for all of it, otherwise 'out' is left
// empty (when it has room for anything) - never cut.
inline int SalNetDriveText(const WCHAR* name, const WCHAR* remote, BOOL doubleAmpersands,
                           WCHAR* out, int outSize)
{
    if (remote == NULL)
        remote = L"";
    BOOL useName = name != NULL && name[0] != 0;
    if (useName && remote[0] != 0 &&
        CompareStringOrdinal(name, -1, remote, -1, TRUE) == CSTR_EQUAL)
    {
        useName = FALSE; // the name says nothing the path does not
    }
    const WCHAR* parts[4];
    int count = 0;
    if (useName)
    {
        parts[count++] = name;
        if (remote[0] != 0)
        {
            parts[count++] = L" (";
            parts[count++] = remote;
            parts[count++] = L")";
        }
    }
    else
        parts[count++] = remote;

    int needed = 1; // the terminator
    for (int i = 0; i < count; i++)
    {
        for (const WCHAR* p = parts[i]; *p != 0; p++)
            needed += (doubleAmpersands && *p == L'&') ? 2 : 1;
    }
    if (out == NULL || outSize < needed)
    {
        if (out != NULL && outSize > 0)
            out[0] = 0;
        return needed;
    }
    WCHAR* d = out;
    for (int i = 0; i < count; i++)
    {
        for (const WCHAR* p = parts[i]; *p != 0; p++)
        {
            *d++ = *p;
            if (doubleAmpersands && *p == L'&')
                *d++ = L'&';
        }
    }
    *d = 0;
    return needed;
}

// Is a network drive disconnected, by Windows' local answers (none of them
// contacts the server; measured, analysis.md G2)?
//   'listed'      its letter is in GetLogicalDrives()
//   'connResult'  WNetGetConnectionW("X:"): ERROR_CONNECTION_UNAVAIL = a
//                 remembered connection that is not connected
//   'conn3Result' / 'conn3State'  WNetGetConnection3W(WNGC_INFOLEVEL_DISCONNECTED)
//                 - asked only for a listed, connected drive
// A letter missing from GetLogicalDrives() was the only rule before 246. An
// unknown answer keeps "connected": the icon is information only, and picking
// the drive reconnects on access in either case.
inline BOOL SalNetDriveIsDisconnected(BOOL listed, DWORD connResult, DWORD conn3Result, DWORD conn3State)
{
    if (!listed)
        return TRUE;
    if (connResult == SALNETDRV_ERROR_CONNECTION_UNAVAIL)
        return TRUE;
    return connResult == 0 && conn3Result == 0 && conn3State == SALNETDRV_WNGC_DISCONNECTED;
}
