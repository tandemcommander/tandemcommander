// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salftpsrvpath.h
//
// FTP client: "is it the same server path?" and "is it the path or one of its
// ancestors?" (feature 385). Header-only, pure - the FTP plug-in includes it
// (FTPIsPrefixOfServerPath, ftputils.cpp) and saltests checks it.
//
// On a case-insensitive server (Windows, NetWare, OS/2, VMS, MVS, IBM z/VM,
// Tandem, AS/400 path types) the plug-in compared paths with the code-page
// byte fold (CharLowerA per byte) over UTF-8 bytes: on code page 1250 the
// folders "C-caron" and "G-circumflex" were one folder (the upload listing
// cache answered for the other one: an upload stored over an existing file
// without the overwrite question) and "C-caron" / "c-caron" were two. Now the
// two paths are walked separator by separator and name by name; each name is
// compared by the file system's rule of feature 092 (SalNameOrderEqualCI,
// salnameorder.h). Byte counts are never compared across the two paths: case
// pairs can differ in UTF-8 length (U+0250 / U+2C6F). The trailing-separator,
// root and boundary rules of each path type are the old ones; for ASCII-only
// paths every answer is the old one (saltests checks it against a copy of the
// old function).
//
//*****************************************************************************

#include "salnameorder.h"

enum ESalFtpSrvPathKind
{
    sfspkCaseSensitive, // Unix and unknown types: '/' separated, bytes compared exactly
    sfspkVms,           // OpenVMS: "DEV:[DIR.SUB]"; '.', '[' and ']' unless escaped by '^'
    sfspkMvs,           // MVS: "'USER.DIR'"; '.' and '\''
    sfspkSlashes,       // Windows, NetWare, OS/2: '/' and '\\' are one separator
    sfspkDotted,        // IBM z/VM, Tandem: '.'
    sfspkAs400,         // AS/400: '/'
};

// = FTPIsVMSEscapeSequence (ftputils.cpp): an odd number of '^' right before 'c' (counted back to
// 'beginning') makes 'c' an escaped character
inline BOOL SalFtpVmsEscaped(const char* beginning, const char* c)
{
    const char* t = c;
    while (--t >= beginning && *t == '^')
        ;
    return (((c - t) - 1) & 1) != 0;
}

namespace SalFtpSrvPathDetail
{
// is s[i] a separator of the path kind? ('s' = the whole path, for the VMS escapes)
inline BOOL IsSep(ESalFtpSrvPathKind kind, const char* s, int i)
{
    char c = s[i];
    switch (kind)
    {
    case sfspkVms:
        return (c == '.' || c == '[' || c == ']') && !SalFtpVmsEscaped(s, s + i);
    case sfspkMvs:
        return c == '.' || c == '\'';
    case sfspkSlashes:
        return c == '/' || c == '\\';
    case sfspkDotted:
        return c == '.';
    default: // sfspkAs400, sfspkCaseSensitive
        return c == '/';
    }
}

// Walks 'a' (la bytes) and 'b' (lb bytes) together: a separator of 'a' must meet the same separator
// of 'b' (sfspkSlashes: either of the two), a name of 'a' (the bytes up to the next separator or
// the end) the same name of 'b' by SalNameOrderEqualCI. Stops at the end of 'a' or at the first
// difference - at a separator or at the start of the names that differ; *ia / *ib = where.
inline void Walk(ESalFtpSrvPathKind kind, const char* a, int la, const char* b, int lb, int* ia, int* ib)
{
    int i = 0;
    int j = 0;
    while (i < la)
    {
        if (IsSep(kind, a, i))
        {
            if (j < lb && IsSep(kind, b, j) && (kind == sfspkSlashes || a[i] == b[j]))
            {
                i++;
                j++;
                continue;
            }
            break;
        }
        if (j >= lb || IsSep(kind, b, j))
            break;
        int ea = i;
        while (ea < la && !IsSep(kind, a, ea))
            ea++;
        int eb = j;
        while (eb < lb && !IsSep(kind, b, eb))
            eb++;
        if (!SalNameOrderEqualCI(a + i, ea - i, b + j, eb - j))
            break;
        i = ea;
        j = eb;
    }
    *ia = i;
    *ib = j;
}
} // namespace SalFtpSrvPathDetail

// Is 'prefix' the same server path as 'path' (mustBeSame TRUE), or the same path or one of its
// ancestors (mustBeSame FALSE)? 'kind' = the server path type (see ESalFtpSrvPathKind).
inline BOOL SalFtpServerPathIsPrefix(ESalFtpSrvPathKind kind, const char* prefix, const char* path, BOOL mustBeSame)
{
    using namespace SalFtpSrvPathDetail;
    switch (kind)
    {
    case sfspkVms:
    {
        int l1 = (int)strlen(prefix);
        int l2 = (int)strlen(path);
        if (l1 > 1 && prefix[l1 - 1] == ']' && !SalFtpVmsEscaped(prefix, prefix + (l1 - 1)))
        {
            l1--;
            if (prefix[l1 - 1] == '.' && !SalFtpVmsEscaped(prefix, prefix + (l1 - 1)))
                l1--;
            if (l1 >= 7 && strncmp(prefix + l1 - 7, "[000000", 7) == 0 &&
                !SalFtpVmsEscaped(prefix, prefix + (l1 - 7)))
            {
                l1 -= 6;
            }
        }
        if (l2 > 1 && path[l2 - 1] == ']' && !SalFtpVmsEscaped(path, path + (l2 - 1)))
        {
            l2--;
            if (path[l2 - 1] == '.' && !SalFtpVmsEscaped(path, path + (l2 - 1)))
                l2--;
            if (l2 >= 7 && strncmp(path + l2 - 7, "[000000", 7) == 0 &&
                !SalFtpVmsEscaped(path, path + (l2 - 7)))
            {
                l2 -= 6;
            }
        }
        int i, j;
        Walk(kind, prefix, l1, path, l2, &i, &j);
        return i == l1 && (j == l2 || !mustBeSame && j < l2) &&
               (j == l2 ||
                l1 > 0 && prefix[l1 - 1] == '[' && !SalFtpVmsEscaped(prefix, prefix + (l1 - 1)) ||
                (path[j] == '.' || path[j] == ']') && !SalFtpVmsEscaped(path, path + j));
    }

    case sfspkMvs:
    {
        int l1 = (int)strlen(prefix);
        int l2 = (int)strlen(path);
        if (l1 > 1 && prefix[l1 - 1] == '\'')
        {
            l1--;
            if (prefix[l1 - 1] == '.')
                l1--;
        }
        if (l2 > 1 && path[l2 - 1] == '\'')
        {
            l2--;
            if (path[l2 - 1] == '.')
                l2--;
        }
        int i, j;
        Walk(kind, prefix, l1, path, l2, &i, &j);
        return i == l1 && (j == l2 || !mustBeSame && j < l2) &&
               (j == l2 || path[j] == '.' || path[j] == '\'');
    }

    case sfspkSlashes:
    case sfspkAs400:
    {
        int i, j;
        Walk(kind, prefix, (int)strlen(prefix), path, (int)strlen(path), &i, &j);
        const char* s1 = prefix + i;
        const char* s2 = path + j;
        if (*s1 == '/' || kind == sfspkSlashes && *s1 == '\\')
            s1++;
        if (*s2 == '/' || kind == sfspkSlashes && *s2 == '\\')
            s2++;
        return *s1 == 0 && *s2 == 0 ||
               !mustBeSame && *s1 == 0 && s2 > path &&
                   (*(s2 - 1) == '/' || kind == sfspkSlashes && *(s2 - 1) == '\\');
    }

    case sfspkDotted:
    {
        int l1 = (int)strlen(prefix);
        int l2 = (int)strlen(path);
        if (l1 > 1 && prefix[l1 - 1] == '.')
            l1--;
        if (l2 > 1 && path[l2 - 1] == '.')
            l2--;
        int i, j;
        Walk(kind, prefix, l1, path, l2, &i, &j);
        return i == l1 && (j == l2 || !mustBeSame && j < l2) && (j == l2 || path[j] == '.');
    }

    default: // sfspkCaseSensitive: unchanged byte rule
    {
        int l1 = (int)strlen(prefix);
        int l2 = (int)strlen(path);
        if (l1 > 0 && prefix[l1 - 1] == '/')
            l1--;
        if (l2 > 0 && path[l2 - 1] == '/')
            l2--;
        return (l1 == l2 || !mustBeSame && l1 < l2) && strncmp(prefix, path, l1) == 0 &&
               (l1 == l2 || path[l1] == '/');
    }
    }
}
