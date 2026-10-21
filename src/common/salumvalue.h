// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salumvalue.h
//
// Pure rules of feature 280: a value the User Menu inserts into a command (an
// item's folder or name, a panel's full path, a name to compare) is copied
// whole or not at all - never cut (a folder cut at 259 bytes right after a
// backslash is its parent: a command ran on another folder). Header-only, no
// globals; saltests checks it.
//
//   SalUMCopyWhole          a text, whole
//   SalUMPathWithBackslash  a folder with a trailing backslash, whole
//   SalUMJoinWhole          folder + '\' + name, whole (SalPathAppend's rules)
//
// Each returns FALSE and leaves 'buf' empty when the result does not fit
// 'size' bytes with its terminator (or 'buf' / the input is NULL).
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

inline BOOL SalUMCopyWhole(const char* src, char* buf, int size)
{
    if (buf == NULL || size <= 0)
        return FALSE;
    buf[0] = 0;
    if (src == NULL)
        return FALSE;
    size_t len = strlen(src);
    if (len >= (size_t)size)
        return FALSE;
    memcpy(buf, src, len + 1);
    return TRUE;
}

// 'path' with one trailing backslash ("C:\a" -> "C:\a\", "C:\" stays); an empty 'path' gives an
// empty 'buf' (TRUE)
inline BOOL SalUMPathWithBackslash(const char* path, char* buf, int size)
{
    if (!SalUMCopyWhole(path, buf, size))
        return FALSE;
    size_t len = strlen(buf);
    if (len > 0 && buf[len - 1] != '\\')
    {
        if (len + 2 > (size_t)size)
        {
            buf[0] = 0;
            return FALSE;
        }
        buf[len] = '\\';
        buf[len + 1] = 0;
    }
    return TRUE;
}

// 'path' + '\' + 'name' as SalPathAppend joins them: one leading backslash of 'name' and one
// trailing backslash of 'path' are dropped; an empty 'name' gives 'path' unchanged, an empty
// 'path' gives 'name'
inline BOOL SalUMJoinWhole(const char* path, const char* name, char* buf, int size)
{
    if (buf == NULL || size <= 0)
        return FALSE;
    buf[0] = 0;
    if (path == NULL || name == NULL)
        return FALSE;
    if (*name == '\\')
        name++;
    if (*name == 0)
        return SalUMCopyWhole(path, buf, size);
    size_t l = strlen(path);
    if (l > 0 && path[l - 1] == '\\')
        l--;
    size_t n = strlen(name);
    size_t total = (l > 0 ? l + 1 : 0) + n;
    if (total >= (size_t)size)
        return FALSE;
    char* out = buf;
    if (l > 0)
    {
        memcpy(out, path, l);
        out[l] = '\\';
        out += l + 1;
    }
    memcpy(out, name, n + 1);
    return TRUE;
}
