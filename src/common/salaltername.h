// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salaltername.h
//
// Feature 169: the letter case of a UTF-8 (WTF-8) file name - the rule behind
// AlterFileName (salamdr2.cpp): the panel's name format option, Change Case
// (which renames files on disk) and CSalamanderGeneral::AlterFileName for the
// plug-ins. Header-only, checked by saltests.
//
// Before: every byte went through the code page's LowerCase / UpperCase tables
// (CharLowerA per byte) - the bytes of a UTF-8 letter were folded one by one
// into another sequence: Change Case of "SARKA.TXT" with S-caron, A-acute
// failed with "(123) the file name is incorrect" (invalid UTF-8), and with
// other letters the folded bytes can spell a different valid name.
//
// Now a letter is mapped as a whole (Unicode, the invariant mapping of
// LCMapStringEx - the culture-independent one a file system name needs) and
// only when its mapped form has the same UTF-8 length: the name keeps its byte
// length, so the callers' buffers (sized for the source) and the positions of
// the name / extension split stay exact. A letter whose case pair has another
// length (dotted / dotless i, a few historic letters) is left as it is; an
// invalid byte, a lone surrogate of WTF-8 and characters without case are
// copied unchanged.
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

namespace salaltername_detail
{
    // the length of the UTF-8 sequence at s (2-4), 1 when it is not a well-formed one
    inline int SeqLen(const unsigned char* s)
    {
        int n = s[0] >= 0xF0 && s[0] <= 0xF4 ? 4 : s[0] >= 0xE0               ? 3
                                               : s[0] >= 0xC2 && s[0] <= 0xDF ? 2
                                                                              : 1;
        if (s[0] >= 0xF5)
            return 1;
        for (int i = 1; i < n; i++)
            if ((s[i] & 0xC0) != 0x80)
                return 1;
        return n;
    }

    inline int Encode(unsigned cp, char* out)
    {
        if (cp < 0x80)
        {
            out[0] = (char)cp;
            return 1;
        }
        if (cp < 0x800)
        {
            out[0] = (char)(0xC0 | (cp >> 6));
            out[1] = (char)(0x80 | (cp & 0x3F));
            return 2;
        }
        if (cp < 0x10000)
        {
            out[0] = (char)(0xE0 | (cp >> 12));
            out[1] = (char)(0x80 | ((cp >> 6) & 0x3F));
            out[2] = (char)(0x80 | (cp & 0x3F));
            return 3;
        }
        out[0] = (char)(0xF0 | (cp >> 18));
        out[1] = (char)(0x80 | ((cp >> 12) & 0x3F));
        out[2] = (char)(0x80 | ((cp >> 6) & 0x3F));
        out[3] = (char)(0x80 | (cp & 0x3F));
        return 4;
    }
} // namespace salaltername_detail

// Writes to dst the character at src in upper (or lower) case, in exactly as many
// bytes as it has at src; returns that count (1-4).
inline int SalU8CaseChar(const char* src, char* dst, bool upper)
{
    using namespace salaltername_detail;
    const unsigned char* s = (const unsigned char*)src;
    if (s[0] < 0x80)
    {
        char c = src[0];
        if (upper && c >= 'a' && c <= 'z')
            c = (char)(c - 'a' + 'A');
        else if (!upper && c >= 'A' && c <= 'Z')
            c = (char)(c - 'A' + 'a');
        dst[0] = c;
        return 1;
    }
    int n = SeqLen(s);
    memcpy(dst, src, n); // unchanged unless a same-length mapping exists
    if (n == 1)
        return 1;
    unsigned cp = n == 2   ? ((s[0] & 0x1Fu) << 6) | (s[1] & 0x3Fu)
                  : n == 3 ? ((s[0] & 0x0Fu) << 12) | ((s[1] & 0x3Fu) << 6) | (s[2] & 0x3Fu)
                           : ((s[0] & 0x07u) << 18) | ((s[1] & 0x3Fu) << 12) | ((s[2] & 0x3Fu) << 6) | (s[3] & 0x3Fu);
    if ((n == 3 && cp < 0x800) || (n == 4 && (cp < 0x10000 || cp > 0x10FFFF)) || (cp >= 0xD800 && cp <= 0xDFFF))
        return n; // an overlong form or a WTF-8 surrogate: no case
    WCHAR w[2];
    int wn = 1;
    if (cp >= 0x10000)
    {
        w[0] = (WCHAR)(0xD800 + ((cp - 0x10000) >> 10));
        w[1] = (WCHAR)(0xDC00 + ((cp - 0x10000) & 0x3FF));
        wn = 2;
    }
    else
        w[0] = (WCHAR)cp;
    WCHAR m[4];
    int mn = LCMapStringEx(LOCALE_NAME_INVARIANT, upper ? LCMAP_UPPERCASE : LCMAP_LOWERCASE, w, wn, m, 4, NULL, NULL, 0);
    if (mn != wn)
        return n;
    unsigned mc = wn == 2 ? (((unsigned)(m[0] - 0xD800) << 10) | (unsigned)(m[1] - 0xDC00)) + 0x10000 : m[0];
    if (wn == 2 && (m[0] < 0xD800 || m[0] > 0xDBFF || m[1] < 0xDC00 || m[1] > 0xDFFF))
        return n;
    if (wn == 1 && mc >= 0xD800 && mc <= 0xDFFF)
        return n;
    char enc[4];
    if (Encode(mc, enc) == n)
        memcpy(dst, enc, n);
    return n;
}

// AlterFileName (salamdr2.cpp, the format numbers there): tgtName receives exactly
// strlen(filename) bytes + the terminator. With change == 1 the '.' of the
// extension in filename is overwritten for the time of the call (as before).
inline void SalAlterFileNameU8(char* tgtName, char* filename, int filenameLen, int format, int change, BOOL dir)
{
    if (format == 6)
        format = dir ? 3 : 2; // VC display style
    if (format == 7 && change != 0)
        format = (change == 1) ? 1 : 2; // convert to mixed/lower case

    char* ext = NULL; // points past the last dot or is NULL (no extension)
    if (change != 0 && format != 5 && format != 7)
    {
        char* s = filename;
        while (*s != 0) // the last dot (the extension); '.' is never part of a UTF-8 sequence
            if (*s++ == '.')
                ext = s;
        if (change == 1) // only the name
        {
            if (ext != NULL)
                *(ext - 1) = 0;
        }
        else // only the extension
        {
            if (ext == NULL || *ext == 0)
            {
                strcpy(tgtName, filename);
                return;
            }
            memmove(tgtName, filename, ext - filename);
            tgtName += ext - filename;
            filename = ext;
        }
    }

    switch (format)
    {
    case 5: // explorer style: an all-capital 8.3 (ASCII) name -> capitalized words
    {
        char* s = filename;
        int c = 8;
        while (c-- && *s != 0 && (unsigned char)*s < 0x80 && !(*s >= 'a' && *s <= 'z') && *s != '.')
            s++; // name
        if (*s == '.')
            s++;
        else if (*s != 0)
        {
            strcpy(tgtName, filename);
            break;
        }
        c = 3;
        while (c-- && *s != 0 && *s != '.' && (unsigned char)*s < 0x80 && !(*s >= 'a' && *s <= 'z'))
            s++; // ext
        if (*s != 0)
        {
            strcpy(tgtName, filename);
            break;
        }
        bool capital = true;
        char* tgt = tgtName;
        char* name = filename;
        while (*name != 0)
        {
            char first = *name;
            int n = SalU8CaseChar(name, tgt, capital);
            tgt += n;
            name += n;
            if (!capital)
            {
                if (first == ' ')
                    capital = true;
            }
            else if (first != ' ')
                capital = false;
        }
        *tgt = 0;
        break;
    }

    case 1: // capitalize (after a space and after a dot)
    {
        bool capital = true;
        char* tgt = tgtName;
        char* name = filename;
        while (*name != 0)
        {
            char first = *name;
            int n = SalU8CaseChar(name, tgt, capital);
            tgt += n;
            name += n;
            if (!capital)
            {
                if (first == ' ' || first == '.')
                    capital = true;
            }
            else if (first != ' ')
                capital = false;
        }
        *tgt = 0;
        break;
    }

    case 2: // lower case
    case 3: // upper case
    {
        char* tgt = tgtName;
        char* name = filename;
        while (*name != 0)
        {
            int n = SalU8CaseChar(name, tgt, format == 3);
            tgt += n;
            name += n;
        }
        *tgt = 0;
        break;
    }

    case 7: // name mixed case, extension lower case
    {
        char* s = filename;
        while (*s != 0)
            if (*s++ == '.')
                ext = s;
        if (ext == NULL)
            ext = s;

        bool capital = true;
        char* tgt = tgtName;
        char* name = filename;
        while (name < ext) // name mixed case
        {
            char first = *name;
            int n = SalU8CaseChar(name, tgt, capital);
            tgt += n;
            name += n;
            if (!capital)
            {
                if (first == ' ')
                    capital = true;
            }
            else if (first != ' ')
                capital = false;
        }
        while (*name != 0) // extension lower case
        {
            int n = SalU8CaseChar(name, tgt, false);
            tgt += n;
            name += n;
        }
        *tgt = 0;
        break;
    }

    default:
    {
        if (filenameLen == -1)
            strcpy(tgtName, filename);
        else
            memcpy(tgtName, filename, filenameLen + 1);
        break;
    }
    }

    if (change == 1 && format != 5 && format != 7) // change only the name
    {
        if (ext != NULL)
        {
            *--ext = '.';                            // restore '.' in the name
            strcpy(tgtName + (ext - filename), ext); // append the extension
        }
    }
}
