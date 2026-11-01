// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salwsl.h (feature 374)
//
// The Change Drive menu (Alt+F1 / Alt+F2) and the drive bar offer the WSL
// distributions of the current user ("Linux - Ubuntu" -> \\wsl.localhost\Ubuntu).
// The list is read from the registry only (CDrivesList, drivelst.cpp); the pure
// decisions are here so that saltests checks them:
//
//   SalWslDistroUsableW    can a registered name form a path (else it is left
//                          out - never cut or changed)
//   SalWslDistroPathU8     "\\wsl.localhost\<name>" - refused when it does not
//                          fit, never cut
//   SalWslPathOnDistroU8   is a panel path on that distribution
//                          (\\wsl.localhost\<name> or \\wsl$\<name>, deeper
//                          folders included) - its item is the current one
//   SalWslItemTextAlloc    "<label> - <name>", '&' doubled for a menu
//   SalWslFingerprintAdd / SalWslFingerprintFold
//                          a 24-bit fingerprint of the sorted names; the drive
//                          bars are rebuilt when it changes
//
//*****************************************************************************

#include "salnameorder.h"

// the longest distribution name taken (characters); WSL itself allows far less
#define SAL_WSL_NAME_MAX 255

// the server of the WSL file systems (Windows 11) and the older alias
#define SAL_WSL_SERVER_U8 "\\\\wsl.localhost\\"
#define SAL_WSL_SERVER_OLD_U8 "\\\\wsl$\\"

// FNV-1a start value of SalWslFingerprintAdd
#define SAL_WSL_FINGERPRINT_START 2166136261u

// Can the registered distribution name 'name' (wide, as the registry holds it) form the path
// \\wsl.localhost\<name>? Not when it is NULL or empty, longer than SAL_WSL_NAME_MAX characters,
// "." or "..", or holds a character no path component may hold (\ / : * ? " < > |) or a control
// character (< 0x20).
inline BOOL SalWslDistroUsableW(const WCHAR* name)
{
    if (name == NULL || name[0] == 0)
        return FALSE;
    int len = 0;
    for (const WCHAR* s = name; *s != 0; s++)
    {
        if (++len > SAL_WSL_NAME_MAX)
            return FALSE;
        WCHAR c = *s;
        if (c < 0x20 || c == L'\\' || c == L'/' || c == L':' || c == L'*' || c == L'?' ||
            c == L'"' || c == L'<' || c == L'>' || c == L'|')
        {
            return FALSE;
        }
    }
    if (name[0] == L'.' && (name[1] == 0 || name[1] == L'.' && name[2] == 0))
        return FALSE;
    return TRUE;
}

// Writes "\\wsl.localhost\<name>" (UTF-8) to 'buf' of 'bufSize' bytes. FALSE (and an empty
// 'buf' when bufSize > 0) when 'name' is NULL / empty or the path with its terminator does not
// fit - the path is never cut.
inline BOOL SalWslDistroPathU8(const char* name, char* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return FALSE;
    buf[0] = 0;
    if (name == NULL || name[0] == 0)
        return FALSE;
    size_t serverLen = strlen(SAL_WSL_SERVER_U8);
    size_t nameLen = strlen(name);
    if (serverLen + nameLen + 1 > (size_t)bufSize)
        return FALSE;
    memcpy(buf, SAL_WSL_SERVER_U8, serverLen);
    memcpy(buf + serverLen, name, nameLen + 1);
    return TRUE;
}

namespace SalWslDetail
{
    // does 'path' start with 'prefix' (ASCII, case ignored)? returns the length of the prefix or 0
    inline int AsciiPrefixCI(const char* path, const char* prefix)
    {
        int i = 0;
        for (; prefix[i] != 0; i++)
        {
            BYTE a = (BYTE)path[i];
            BYTE b = (BYTE)prefix[i];
            if (a >= 'A' && a <= 'Z')
                a = (BYTE)(a - 'A' + 'a');
            if (b >= 'A' && b <= 'Z')
                b = (BYTE)(b - 'A' + 'a');
            if (a != b) // also stops at the end of 'path' (0 != b)
                return 0;
        }
        return i;
    }
} // namespace SalWslDetail

// Is the panel path 'path' (UTF-8) on the distribution 'name' (UTF-8)? TRUE for
// \\wsl.localhost\<name> and \\wsl$\<name> (the server's ASCII case ignored), alone or followed
// by '\' (a deeper folder); the name compares as the file system compares names (case ignored).
inline BOOL SalWslPathOnDistroU8(const char* path, const char* name)
{
    if (path == NULL || name == NULL || name[0] == 0)
        return FALSE;
    int skip = SalWslDetail::AsciiPrefixCI(path, SAL_WSL_SERVER_U8);
    if (skip == 0)
        skip = SalWslDetail::AsciiPrefixCI(path, SAL_WSL_SERVER_OLD_U8);
    if (skip == 0)
        return FALSE;
    const char* part = path + skip;
    const char* end = part;
    while (*end != 0 && *end != '\\')
        end++;
    if (end == part)
        return FALSE;
    return SalNameOrderEqualCI(part, (int)(end - part), name, -1);
}

// "<label> - <name>" in a new heap buffer (free() it); with 'doubleAmp' every '&' of the name is
// doubled (a menu item text, where '&' marks the hot key; the label is a resource text and is
// taken as it is). NULL when out of memory or an argument is NULL.
inline char* SalWslItemTextAlloc(const char* label, const char* name, BOOL doubleAmp)
{
    if (label == NULL || name == NULL)
        return NULL;
    size_t amps = 0;
    if (doubleAmp)
    {
        for (const char* s = name; *s != 0; s++)
        {
            if (*s == '&')
                amps++;
        }
    }
    size_t labelLen = strlen(label);
    size_t size = labelLen + 3 + strlen(name) + amps + 1;
    char* text = (char*)malloc(size);
    if (text == NULL)
        return NULL;
    char* d = text;
    memcpy(d, label, labelLen);
    d += labelLen;
    memcpy(d, " - ", 3);
    d += 3;
    for (const char* s = name; *s != 0; s++)
    {
        *d++ = *s;
        if (doubleAmp && *s == '&')
            *d++ = '&';
    }
    *d = 0;
    return text;
}

// adds the name 'name' (UTF-8, followed by an implicit 0 byte) to the FNV-1a hash 'h'
// (start: SAL_WSL_FINGERPRINT_START)
inline DWORD SalWslFingerprintAdd(DWORD h, const char* name)
{
    if (name != NULL)
    {
        for (const char* s = name; *s != 0; s++)
        {
            h ^= (BYTE)*s;
            h *= 16777619u;
        }
    }
    h *= 16777619u; // the terminator (0 ^ h = h), so "ab","c" differs from "a","bc"
    return h;
}

// folds the hash to 24 bits (the drive bars keep it in bits 8-31 of their cloud storages mask)
inline DWORD SalWslFingerprintFold(DWORD h)
{
    return (h ^ (h >> 24)) & 0x00FFFFFFu;
}
