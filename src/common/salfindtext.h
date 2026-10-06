// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salfindtext.h (feature 121)
//
// The texts of the Find Files window built from a path.
//
// The "Look in" field held MAX_PATH bytes (feature 101 record): the panel's path
// was copied into it with a silent cut at 259 bytes (about 130 accented
// characters), possibly inside a UTF-8 character, and a typed or chosen path got
// the same cut on its way back - Find then searched ANOTHER folder (the cut
// prefix) or none. The field now holds any path the program can
// (SAL_MAX_PATH_UTF8); these helpers never cut a path:
//
//   SalFindLookInFromPath - the panel's path as the field's text: every ';' is
//                           doubled (the field's escape for a ';' inside a path,
//                           ';' alone separates paths); FALSE and "" when the
//                           result does not fit - never a cut path
//   SalFindComposeItemName - the display name of a saved Find option,
//                           "<named>" <in> "<look in>", cut to the name's buffer
//                           at a whole UTF-8 character (a display name; the
//                           option keeps its whole texts)
//
// Header-only and pure: saltests.
//
//*****************************************************************************

#include <stddef.h>
#include <string.h>

inline bool SalFindLookInFromPath(const char* path, char* buf, size_t bufSize)
{
    if (buf == NULL || bufSize == 0)
        return false;
    buf[0] = 0;
    if (path == NULL)
        return true;
    size_t d = 0;
    for (const char* s = path; *s != 0; s++)
    {
        size_t need = (*s == ';') ? 2 : 1;
        if (d + need >= bufSize) // the terminator must fit too
        {
            buf[0] = 0;
            return false;
        }
        if (*s == ';')
            buf[d++] = ';';
        buf[d++] = *s;
    }
    buf[d] = 0;
    return true;
}

// drops a trailing incomplete UTF-8 sequence (the core's SalU8TrimIncompleteTail, header-only)
inline void SalFindTrimTornTail(char* buf)
{
    if (buf == NULL)
        return;
    size_t len = strlen(buf);
    size_t i = len;
    while (i > 0 && ((unsigned char)buf[i - 1] & 0xC0) == 0x80)
        i--;
    if (i > 0)
    {
        unsigned char lead = (unsigned char)buf[i - 1];
        if (lead >= 0xC0)
        {
            size_t seqLen = lead >= 0xF0 ? 4 : (lead >= 0xE0 ? 3 : 2);
            if (len - (i - 1) < seqLen)
                buf[i - 1] = 0;
        }
    }
}

inline void SalFindComposeItemName(char* dst, size_t dstSize, const char* named, const char* in,
                                   const char* lookIn)
{
    if (dst == NULL || dstSize == 0)
        return;
    const char* parts[7] = {"\"", named != NULL ? named : "", "\" ", in != NULL ? in : "", " \"",
                            lookIn != NULL ? lookIn : "", "\""};
    size_t d = 0;
    bool cut = false;
    for (int p = 0; p < 7 && !cut; p++)
    {
        for (const char* s = parts[p]; *s != 0; s++)
        {
            if (d + 1 >= dstSize)
            {
                cut = true;
                break;
            }
            dst[d++] = *s;
        }
    }
    dst[d] = 0;
    if (cut)
        SalFindTrimTornTail(dst);
}
