// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salmaskgroup.h
//
// How CMaskGroup::PrepareMasks (src/masks.cpp) takes one mask out of a mask
// group and normalizes it (feature 298). Header-only, no globals; saltests
// checks it against the code it replaced.
//
// The group text is "mask;mask|mask": ';' separates masks, ";;" is a literal
// ';', one '|' starts the exclude part. The text is any length - up to
// MAX_GROUPMASK - 1 bytes in a CMaskGroup, unbounded when it is passed to
// PrepareMasks directly - and one mask may fill all of it. PrepareMasks used
// two MAX_PATH stack buffers, so a single mask of 260 bytes or more (a plug-in's
// thumbnail masks in the registry, a tab filter, a settings import) ran over
// the stack. Neither step below writes more than its input's length + 1 bytes,
// so storage of strlen(group text) + 1 bytes holds any mask of the group
// whole: a mask is never cut (a cut mask matches other files).
//
// Bytes are compared as unsigned char - what the core's /J gives: a UTF-8 byte
// (>= 0x80) is a mask character, never a separator or a space.
//
//*****************************************************************************

#include <string.h>

// copies the mask that starts at 's' into 'mask' (";;" -> ';') and NUL-terminates it; stops at the
// end, at a single ';', at '|' or at a byte a mask may not hold (below 32, \ / < > : "); returns
// where it stopped. 'mask' holds at least strlen(s) + 1 bytes - never more is written.
inline const char* SalMaskGroupCutMask(const char* s, char* mask)
{
    while (*s != 0 && (unsigned char)*s > 31 && *s != '\\' && *s != '/' &&
           *s != '<' && *s != '>' && *s != ':' && *s != '"')
    {
        if (*s == '|')
            break;
        if (*s == ';')
        {
            if (*(s + 1) == ';')
                s++;
            else
                break;
        }
        *mask++ = *s++;
    }
    *mask = 0;
    return s;
}

// cuts off the bytes <= ' ' at the end of 'mask' in place; returns its first byte that is not <= ' '
inline char* SalMaskGroupTrimMask(char* mask)
{
    size_t n = strlen(mask);
    while (n > 0 && (unsigned char)mask[n - 1] <= ' ')
        n--;
    mask[n] = 0;
    while (*mask != 0 && (unsigned char)*mask <= ' ')
        mask++;
    return mask;
}

// the PrepareMask normalization: leading spaces skipped, "**" -> "*", "*?" -> "?*", trailing spaces
// trimmed. 'mask' holds at least strlen(src) + 1 bytes - never more is written (each step keeps or
// drops a byte; "*?" rewrites the '*' already written and adds one byte for the '?').
inline void SalPrepareMaskU8(char* mask, const char* src)
{
    char* begMask = mask;
    char lastChar = 0;
    while (*src == ' ')
        src++;
    while (*src != 0)
    {
        if (*src == '*' && lastChar == '*')
            src++;                               // "**" -> "*"
        else if (*src == '?' && lastChar == '*') // "*?" -> "?*"
        {
            *(mask - 1) = '?';
            *mask++ = '*';
            src++;
        }
        else
            *mask++ = (lastChar = *src++);
    }
    while (mask > begMask && *(mask - 1) == ' ')
        mask--;
    *mask = 0;
}
