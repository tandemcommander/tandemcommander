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

// Is 'name' shown next to 'remote'? Not when there is no name, or when the name is
// the path (case ignored, as the file system compares) - it says nothing the path
// does not.
inline BOOL SalNetDriveNameShown(const WCHAR* name, const WCHAR* remote)
{
    if (name == NULL || name[0] == 0)
        return FALSE;
    if (remote == NULL || remote[0] == 0)
        return TRUE;
    return CompareStringOrdinal(name, -1, remote, -1, TRUE) != CSTR_EQUAL;
}

// The text shown for a mapped drive: "Name (\\server\share\path)", or the path
// alone when the name is not shown (SalNetDriveNameShown). With
// 'doubleAmpersands' every '&' is written as "&&" (the menu draws the column with
// prefix processing; the tooltip does not). Returns the number of units needed
// INCLUDING the terminator; the text is written only when 'out' has room for all
// of it, otherwise 'out' is left empty (when it has room for anything) - never cut.
inline int SalNetDriveText(const WCHAR* name, const WCHAR* remote, BOOL doubleAmpersands,
                           WCHAR* out, int outSize)
{
    if (remote == NULL)
        remote = L"";
    BOOL useName = SalNetDriveNameShown(name, remote);
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

// The number of leading units of 'name' whose UTF-8 (WTF-8) form fits into 'maxBytes' bytes,
// ending on a whole character - a surrogate pair is never split (a lone surrogate counts as
// the three bytes WTF-8 gives it). Used where a text has a hard byte limit (the tooltip
// buffer): the NAME is shortened there, the path never is.
inline int SalNetDriveFitU8(const WCHAR* name, int maxBytes)
{
    int units = 0;
    int bytes = 0;
    while (name != NULL && name[units] != 0)
    {
        WCHAR c = name[units];
        int n = 3;
        int w = 1;
        if (c < 0x80)
            n = 1;
        else if (c < 0x800)
            n = 2;
        else if (c >= 0xD800 && c <= 0xDBFF && name[units + 1] >= 0xDC00 && name[units + 1] <= 0xDFFF)
        {
            n = 4;
            w = 2;
        }
        if (bytes + n > maxBytes)
            break;
        bytes += n;
        units += w;
    }
    return units;
}

// The UTF-8 (WTF-8) length in bytes of 'text', counted as SalNetDriveFitU8 counts.
inline int SalNetDriveU8Len(const WCHAR* text)
{
    int bytes = 0;
    for (int i = 0; text != NULL && text[i] != 0; i++)
    {
        WCHAR c = text[i];
        if (c < 0x80)
            bytes += 1;
        else if (c < 0x800)
            bytes += 2;
        else if (c >= 0xD800 && c <= 0xDBFF && text[i + 1] >= 0xDC00 && text[i + 1] <= 0xDFFF)
        {
            bytes += 4;
            i++;
        }
        else
            bytes += 3;
    }
    return bytes;
}

// The tooltip has a hard byte limit; its text (SalNetDriveText without '&'
// doubling) must keep the path whole, so only the NAME is shortened - to a
// whole-character prefix followed by an ellipsis (U+2026, three bytes). Returns
//   -1  the text fits 'maxBytes' as it is, or the name is not shown (nothing to
//       shorten: a path alone that does not fit is cut by the caller's copy)
//   -2  even an empty name with the ellipsis does not leave room for the path
//   >=0 the number of leading units of 'name' to keep before the ellipsis
inline int SalNetDriveNameUnitsForLimit(const WCHAR* name, const WCHAR* remote, int maxBytes)
{
    if (!SalNetDriveNameShown(name, remote))
        return -1;
    int remoteBytes = remote == NULL ? 0 : SalNetDriveU8Len(remote);
    int pathPart = remoteBytes == 0 ? 0 : 2 + remoteBytes + 1; // " (" + path + ")"
    if (SalNetDriveU8Len(name) + pathPart <= maxBytes)
        return -1;
    int forName = maxBytes - pathPart - 3;
    if (forName < 0)
        return -2;
    return SalNetDriveFitU8(name, forName);
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
