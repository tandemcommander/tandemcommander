// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salcopyname.h
//
// The name Paste gives a copy in the folder of its source, in the style of
// Windows Explorer since Vista: "name - Copy.ext", "name - Copy (2).ext", ...
// (feature 259). Header-only, no globals; saltests checks it; the core's
// CFilesWindow::BuildScriptMain2 (fileswn6.cpp) asks it for attempt 1, 2, ...
// until a name is free.
//
// The candidate used to be assembled in a 260-byte window and dropped when it
// reached 260 bytes - the copy then went to its source and the user read
// "Cannot copy a file to itself." (also for a valid name: 84 CJK letters +
// ".txt" are 256 bytes, the copy name 95 UTF-16 units). Now it is built whole
// and judged by the file systems' limit, 255 UTF-16 units; a name over it is
// SAL_COPYNAME_TOOLONG, never a cut name.
//
// The rule, unchanged (a port of the old code):
//   ext   the last '.' and what follows, for a file only; an extension holding
//         a space is no extension
//   num   the first "(digits)" of the name ("()" counts)
//   attempt 1, or no num:  base + hyphenCopy [+ " (attempt)"] + ext
//   attempt >= 2 with num: num becomes "(attempt)"; hyphenCopy goes before ext
//         (num before ext), after the part before ext (num inside ext), or at
//         the end (no ext)
// The caller stops at the first TOOLONG: a later attempt is not shorter, except
// when the name's own number has leading zeros ("x (001).txt" -> "x (2) - Copy.txt")
// - such a name is then refused although a later attempt might fit (as before).
//
//*****************************************************************************

#include <windows.h>
#include <stdio.h>
#include <string.h>

#include "salmaskname.h" // SalNameTooLongForFileSystemU8

#define SAL_COPYNAME_OK 0
#define SAL_COPYNAME_TOOLONG 1 // more than 255 UTF-16 units, or does not fit 'out'

namespace SalCopyNameDetail
{
    // appends 'len' bytes of 'src'; FALSE when 'out' cannot hold them with the terminator
    inline BOOL Put(char* out, int outSize, int* pos, const char* src, int len)
    {
        if (len < 0 || *pos + len >= outSize)
            return FALSE;
        memcpy(out + *pos, src, len);
        *pos += len;
        out[*pos] = 0;
        return TRUE;
    }
} // namespace SalCopyNameDetail

// Writes the 'attempt'-th copy name (1, 2, ...) of 'name' (UTF-8, one component) into 'out'
// ('outSize' bytes); 'isDir': folders have no extension; 'hyphenCopy': " - " + the localized
// word "Copy" (UTF-8). Returns SAL_COPYNAME_OK, or SAL_COPYNAME_TOOLONG with 'out' empty.
inline int SalMakeCopyNameU8(const char* name, BOOL isDir, const char* hyphenCopy, int attempt,
                             char* out, int outSize)
{
    using SalCopyNameDetail::Put;
    if (out == NULL || outSize <= 0)
        return SAL_COPYNAME_TOOLONG;
    out[0] = 0;
    if (name == NULL || hyphenCopy == NULL || attempt < 1)
        return SAL_COPYNAME_TOOLONG;

    const char* nameEnd = name + strlen(name);
    const char* ext = isDir ? NULL : strrchr(name, '.'); // directories have no extensions (Vista behavior)
    if (ext != NULL && strchr(ext, ' ') != NULL)
        ext = NULL; // an extension with a space isn't an extension (Vista behavior)
    const char* numBeg = name;
    const char* numEnd = NULL;
    while (1) // the first "(number)"
    {
        while (*numBeg != 0 && *numBeg != '(')
            numBeg++;
        if (*numBeg == '(')
        {
            numEnd = numBeg + 1;
            while (*numEnd >= '0' && *numEnd <= '9')
                numEnd++;
            if (*numEnd != ')')
                numBeg = numEnd;
            else
            {
                numEnd++;
                break; // "(number)" found
            }
        }
        else
        {
            numBeg = NULL;
            break; // "(number)" not present
        }
    }

    int hyphenLen = (int)strlen(hyphenCopy);
    char number[24];
    int pos = 0;
    BOOL ok;
    if (attempt > 1 && numBeg != NULL)
    {
        sprintf(number, "(%d)", attempt);
        int numberLen = (int)strlen(number);
        if (ext != NULL)
        {
            if (numBeg < ext)
                ok = Put(out, outSize, &pos, name, (int)(numBeg - name)) &&
                     Put(out, outSize, &pos, number, numberLen) &&
                     Put(out, outSize, &pos, numEnd, (int)(ext - numEnd)) &&
                     Put(out, outSize, &pos, hyphenCopy, hyphenLen) &&
                     Put(out, outSize, &pos, ext, (int)(nameEnd - ext));
            else
                ok = Put(out, outSize, &pos, name, (int)(ext - name)) &&
                     Put(out, outSize, &pos, hyphenCopy, hyphenLen) &&
                     Put(out, outSize, &pos, ext, (int)(numBeg - ext)) &&
                     Put(out, outSize, &pos, number, numberLen) &&
                     Put(out, outSize, &pos, numEnd, (int)(nameEnd - numEnd));
        }
        else
            ok = Put(out, outSize, &pos, name, (int)(numBeg - name)) &&
                 Put(out, outSize, &pos, number, numberLen) &&
                 Put(out, outSize, &pos, numEnd, (int)(nameEnd - numEnd)) &&
                 Put(out, outSize, &pos, hyphenCopy, hyphenLen);
    }
    else
    {
        const char* baseEnd = ext != NULL ? ext : nameEnd;
        ok = Put(out, outSize, &pos, name, (int)(baseEnd - name)) &&
             Put(out, outSize, &pos, hyphenCopy, hyphenLen);
        if (ok && attempt > 1)
        {
            sprintf(number, " (%d)", attempt);
            ok = Put(out, outSize, &pos, number, (int)strlen(number));
        }
        if (ok && ext != NULL)
            ok = Put(out, outSize, &pos, ext, (int)(nameEnd - ext));
    }
    if (!ok || SalNameTooLongForFileSystemU8(out))
    {
        out[0] = 0;
        return SAL_COPYNAME_TOOLONG;
    }
    return SAL_COPYNAME_OK;
}
