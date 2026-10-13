// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salmaskname.h
//
// The name an operation mask makes of a file name ("a.b.c.d" + "*.*.old" =
// "a.b.c.d.old") - and whether the buffer held it (feature 141).
// Header-only, no globals; saltests checks it. The core's MaskName
// (src/masks.cpp) is a wrapper of it.
//
// The routine used to stop silently at the end of the buffer (and with a NULL
// mask it was lstrcpyn), so the callers went on with a CUT name: another file's
// name, or half a character. A Windows name holds 255 UTF-16 units = up to 765
// bytes of UTF-8, the callers' buffers were 2 * MAX_PATH (519 bytes).
//
//   SalMaskNameU8        the whole result, or FALSE and an EMPTY buffer
//   SalMaskNameLegacyU8  the historical contract (the plug-in interface's
//                        MaskName): what fits, cut at a byte; tells the cut
//
// The algorithm is the old one, byte for byte, for ASCII names and masks. What
// changed for other text: '?' takes one whole UTF-8 character of the name (it
// took one byte - half a letter), and a literal character of the mask is copied
// whole and replaces one whole character of the name (each BYTE of the mask
// used to skip one BYTE of the name). Bytes that do not form a sequence (text
// that is not UTF-8) are single characters, as before.
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

// the longest name a Windows file system stores, in UTF-16 units
#define SAL_NAME_MAX_UTF16_UNITS 255

namespace SalMaskNameDetail
{
// bytes of the character at 's' (*s != 0): a lead byte with all its continuation bytes,
// otherwise 1 (ASCII, a stray byte, a sequence cut by the end of the text)
inline int CharLen(const char* s)
{
    unsigned char b = (unsigned char)s[0];
    int len = b >= 0xF8 ? 1 : (b >= 0xF0 ? 4 : (b >= 0xE0 ? 3 : (b >= 0xC0 ? 2 : 1)));
    for (int i = 1; i < len; i++)
        if (((unsigned char)s[i] & 0xC0) != 0x80)
            return 1;
    return len;
}

// writes what fits (at most bufSize - 1 bytes + terminator, trailing dots removed) and
// returns the length of the WHOLE result; 'bufSize' > 0, 'mask' != NULL
inline int Build(char* buffer, int bufSize, const char* name, const char* mask)
{
    // the first dot in the mask separates two operational parts: the first for the name,
    // the second for the extension (example: "a.b.c.d" + "*.*.old": "a.b.c" + "*" = "a.b.c";
    // "d" + "*.old" = "d.old" -> the result is the combination "a.b.c.d.old")
    int ignPoints = 0; // dots of the name that belong to its first part
    const char* n = name;
    while (*n != 0)
        if (*n++ == '.')
            ignPoints++;
    const char* s = mask;
    while (*s != 0)
        if (*s++ == '.')
        {
            ignPoints--;
            break; // only one dot of the mask is meaningful (name.ext)
        }
    if (ignPoints < 0)
        ignPoints = 0;

    n = name;
    char* d = buffer;
    char* endBuf = buffer + bufSize - 1;
    int total = 0;     // bytes of the whole result so far
    int trailDots = 0; // how many of them are dots at its end
    // one byte of the result: stored while there is room, always counted
#define SALMASKNAME_PUT(ch) \
    do \
    { \
        char putCh = (ch); \
        if (d < endBuf) \
            *d++ = putCh; \
        total++; \
        trailDots = putCh == '.' ? trailDots + 1 : 0; \
    } while (0)

    s = mask;
    while (*s != 0)
    {
        switch (*s)
        {
        case '*': // the rest of the current part of the name (up to the "ignPoints+1"-th dot)
        {
            while (*n != 0)
            {
                if (*n == '.')
                {
                    if (ignPoints > 0)
                        ignPoints--; // this dot belongs to the part
                    else
                        break;
                }
                SALMASKNAME_PUT(*n++);
            }
            s++;
            break;
        }

        case '?': // one character, unless the current part of the name has ended
        {
            if (*n != 0)
            {
                if (*n == '.')
                {
                    if (ignPoints > 0)
                    {
                        ignPoints--;
                        SALMASKNAME_PUT(*n++);
                    }
                }
                else
                {
                    for (int k = CharLen(n); k > 0; k--) // the whole character
                        SALMASKNAME_PUT(*n++);
                }
            }
            s++;
            break;
        }

        case '.': // end of the current part (go to the next part of the name)
        {
            SALMASKNAME_PUT('.');
            while (*n != 0)
            {
                if (*n == '.')
                {
                    if (ignPoints > 0)
                        ignPoints--;
                    else
                        break;
                }
                n++;
            }
            if (*n == '.')
                n++;
            s++;
            break;
        }

        default: // a literal character: copied whole, replaces one character of the name
        {
            for (int k = CharLen(s); k > 0; k--)
                SALMASKNAME_PUT(*s++);
            if (*n != 0)
            {
                if (*n != '.')
                    n += CharLen(n);
                else
                {
                    if (ignPoints > 0)
                    {
                        ignPoints--;
                        n++; // a dot inside the part is replaced as well
                    }
                }
            }
            break;
        }
        }
    }
#undef SALMASKNAME_PUT
    while (--d >= buffer && *d == '.')
        ; // the result never ends with a dot
    *++d = 0;
    return total - trailDots;
}
} // namespace SalMaskNameDetail

// The historical contract: 'buffer' receives the result, CUT AT A BYTE when it does not fit
// (with a NULL mask: the name, as lstrcpyn copied it). Returns 'buffer', NULL for a NULL
// 'buffer' or 'name' or 'bufSize' <= 0. 'cut' (may be NULL) receives TRUE when the result is
// not the whole one. For the plug-in interface only; new code calls SalMaskNameU8.
inline char* SalMaskNameLegacyU8(char* buffer, int bufSize, const char* name, const char* mask, BOOL* cut)
{
    if (cut != NULL)
        *cut = FALSE;
    if (buffer == NULL || bufSize <= 0 || name == NULL)
        return NULL;
    size_t need;
    if (mask == NULL) // the name as it is (no dots are removed)
    {
        need = strlen(name);
        size_t copy = need < (size_t)(bufSize - 1) ? need : (size_t)(bufSize - 1);
        memcpy(buffer, name, copy);
        buffer[copy] = 0;
    }
    else
        need = (size_t)SalMaskNameDetail::Build(buffer, bufSize, name, mask);
    if (cut != NULL)
        *cut = need > (size_t)(bufSize - 1);
    return buffer;
}

// 'name' through 'mask' (NULL = the name as it is) into 'buffer' of 'bufSize' bytes.
// TRUE: the buffer holds the whole result. FALSE: it did not fit (or an argument is
// missing) and the buffer holds an EMPTY string - never a cut name.
inline BOOL SalMaskNameU8(char* buffer, int bufSize, const char* name, const char* mask)
{
    BOOL cut = FALSE;
    if (SalMaskNameLegacyU8(buffer, bufSize, name, mask, &cut) == NULL)
    {
        if (buffer != NULL && bufSize > 0)
            buffer[0] = 0;
        return FALSE;
    }
    if (cut)
        buffer[0] = 0;
    return !cut;
}

// UTF-16 units the UTF-8 (WTF-8) text takes: one per character, two for a 4-byte
// sequence; a byte that is not part of a sequence counts as one
inline int SalNameUtf16UnitsU8(const char* name)
{
    int units = 0;
    if (name != NULL)
    {
        while (*name != 0)
        {
            int len = SalMaskNameDetail::CharLen(name);
            units += len == 4 ? 2 : 1;
            name += len;
        }
    }
    return units;
}

// TRUE when no Windows file system can store 'name' (one path component): more than 255
// UTF-16 units. The operation then says "name too long" instead of a system error.
inline BOOL SalNameTooLongForFileSystemU8(const char* name)
{
    return SalNameUtf16UnitsU8(name) > SAL_NAME_MAX_UTF16_UNITS;
}
