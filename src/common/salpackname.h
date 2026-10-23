// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salpackname.h
//
// Pure rule of features 317 and 318: the Pack dialog's archive name reaches the
// packer as typed (317 keeps the leading spaces of a relative name), and the
// packers write through \\?\ paths, where Windows neither trims trailing dots
// and spaces nor maps a reserved device name. A last part such as 'report.',
// 'report.zip ', ' ..' (317) or 'CON.zip' would be created as a literal file
// that ordinary Windows programs cannot open, rename or delete. Such a name is
// refused, unless a file of exactly that name already exists (the caller's
// check through \\?\ - adding to it creates nothing new). Header-only, no
// globals; saltests checks it.
//
//   SalPackNameIsNotKeptAsTyped  the last part of a full archive name is not
//                                a name the file system keeps as typed
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

// ASCII upper case of 'c' (other bytes, also UTF-8 ones, unchanged)
inline char SalPackNameUpperAscii(char c)
{
    return (c >= 'a' && c <= 'z') ? (char)(c - 'a' + 'A') : c;
}

// TRUE when 'part' (one name, no '\' or '/') is a reserved device name of Windows: the part before its
// first '.' (the whole part when there is none), with its trailing spaces removed, is CON, PRN,
// AUX, NUL, COM0-COM9, LPT0-LPT9, or COM / LPT followed by a superscript one, two or three
// (UTF-8 C2 B9, C2 B2, C2 B3), in any letter case - 'NUL .zip' and 'lpt9.tar.zip' are device
// names; ' CON.zip', 'CONSOLE.zip', 'con bla.zip' and 'COM10.zip' are not
inline BOOL SalPackNameIsReservedDevice(const char* part)
{
    if (part == NULL)
        return FALSE;
    const char* end = part;
    while (*end != 0 && *end != '.')
        end++;
    while (end > part && *(end - 1) == ' ')
        end--;
    size_t len = (size_t)(end - part);
    if (len < 3 || len > 5)
        return FALSE;
    char a = SalPackNameUpperAscii(part[0]);
    char b = SalPackNameUpperAscii(part[1]);
    char c = SalPackNameUpperAscii(part[2]);
    if (len == 3)
    {
        return (a == 'C' && b == 'O' && c == 'N') || (a == 'P' && b == 'R' && c == 'N') ||
               (a == 'A' && b == 'U' && c == 'X') || (a == 'N' && b == 'U' && c == 'L');
    }
    if (!(a == 'C' && b == 'O' && c == 'M') && !(a == 'L' && b == 'P' && c == 'T'))
        return FALSE;
    if (len == 4)
        return part[3] >= '0' && part[3] <= '9';
    unsigned char s1 = (unsigned char)part[3];
    unsigned char s2 = (unsigned char)part[4];
    return s1 == 0xC2 && (s2 == 0xB9 || s2 == 0xB2 || s2 == 0xB3);
}

// TRUE when the part of 'fullName' after its last '\' or '/' (the whole name when there is none -
// the packers' path conversion turns '/' into '\') is not empty and either ends with ' ' or '.'
// (the file system would trim them - also a part of only spaces and dots, feature 317) or is a
// reserved device name (SalPackNameIsReservedDevice); FALSE otherwise, also for NULL or an empty
// last part. A trailing tab or other control character is not this rule's (the packer refuses it).
// The caller refuses such a name only when no file of exactly that name exists yet (an archive
// already named so is added to as before)
inline BOOL SalPackNameIsNotKeptAsTyped(const char* fullName)
{
    if (fullName == NULL)
        return FALSE;
    const char* last = fullName;
    for (const char* s = fullName; *s != 0; s++)
    {
        if (*s == '\\' || *s == '/')
            last = s + 1;
    }
    if (*last == 0)
        return FALSE;
    char lastChar = last[strlen(last) - 1];
    if (lastChar == ' ' || lastChar == '.')
        return TRUE;
    return SalPackNameIsReservedDevice(last);
}
