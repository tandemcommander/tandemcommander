// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salunpackdefault.h
//
// Pure rules of feature 315: a default the Unpack dialog (Alt+F9) offers - the
// other panel's path, that path + the archive's name as a subfolder, a plug-in's
// unpack mask - and the archive panel's path an empty target becomes, is copied
// into the caller's buffer whole or not at all, never cut (a path cut at 259
// bytes is another folder; the files were unpacked into it). Header-only, no
// globals; saltests checks it.
//
//   SalUnpackDefaultCopy       a text, whole, or the buffer empty
//   SalUnpackDefaultAddSubdir  buffer + '\' + name, whole, or the name alone
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

// 'text' whole into 'buf' (TRUE), or 'buf' empty (FALSE) when it does not fit 'size' bytes with its
// terminator; NULL 'text': 'buf' empty, FALSE; NULL 'buf' or 'size' <= 0: FALSE
inline BOOL SalUnpackDefaultCopy(const char* text, char* buf, int size)
{
    if (buf == NULL || size <= 0)
        return FALSE;
    buf[0] = 0;
    if (text == NULL)
        return FALSE;
    size_t len = strlen(text);
    if (len >= (size_t)size)
        return FALSE;
    memcpy(buf, text, len + 1);
    return TRUE;
}

// 'buf' + '\' + the first 'nameLen' bytes of 'name' - no '\' when 'buf' is empty (a relative name)
// or already ends with one - whole (TRUE); when the result does not fit 'size' bytes with its
// terminator (FALSE), the path is left out and 'buf' holds the name alone - a subfolder next to the
// archive, what an empty entry gets - or is empty when even the name does not fit; never the path
// without its subfolder. 'nameLen' <= 0: nothing to append, 'buf' unchanged (TRUE). NULL arguments
// or 'size' <= 0: FALSE, 'buf' unchanged.
inline BOOL SalUnpackDefaultAddSubdir(char* buf, int size, const char* name, int nameLen)
{
    if (buf == NULL || name == NULL || size <= 0)
        return FALSE;
    if (nameLen <= 0)
        return TRUE;
    size_t l = strlen(buf);
    size_t sep = (l > 0 && buf[l - 1] != '\\') ? 1 : 0;
    if (l + sep + (size_t)nameLen >= (size_t)size)
    {
        if ((size_t)nameLen < (size_t)size)
        {
            memcpy(buf, name, (size_t)nameLen);
            buf[nameLen] = 0;
        }
        else
            buf[0] = 0;
        return FALSE;
    }
    if (sep)
        buf[l++] = '\\';
    memcpy(buf + l, name, (size_t)nameLen);
    buf[l + nameLen] = 0;
    return TRUE;
}
