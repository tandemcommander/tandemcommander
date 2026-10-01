// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salarcname.h
//
// Names taken from an archive, made safe (feature 087), and the archive-format
// signatures the 7zip plugin recognises.
//
// An archive stores whatever names its author wrote: "..\..\Windows\x.dll",
// "C:\Users\x", "\\server\share\x", "file.txt:hidden" (an NTFS alternate data
// stream), "CON", names ending in a dot. Joined to a target folder as they are,
// such names write outside the folder or into streams. Until feature 087 the
// 7zip plugin did exactly that (extract.cpp: target + name through
// SalPathAppend). Every name the plugin shows or extracts now goes through
// SalArcCleanItemPath first.
//
// Header-only on purpose (as salrandom.h, feature 086): plugins cannot compile
// a shared .cpp from src/common with their precompiled header. Pure: no
// globals. Text is UTF-8; every byte >= 0x80 is copied unchanged, so a
// multi-byte character is never split or altered.
//
// Contract: specs/087-7zip-2603-rar/contracts/item-names.md
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

namespace SalArcNameDetail
{

inline bool IsSep(char c) { return c == '\\' || c == '/'; }

inline char Lower(char c) { return (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c; }

inline bool EqualNoCase(const char* a, int aLen, const char* b)
{
    int bLen = (int)strlen(b);
    if (aLen != bLen)
        return false;
    for (int i = 0; i < aLen; i++)
        if (Lower(a[i]) != Lower(b[i]))
            return false;
    return true;
}

// CON, PRN, AUX, NUL, CONIN$, CONOUT$, COM0-9, LPT0-9 and COM/LPT with a
// superscript digit (U+00B9, U+00B2, U+00B3) - also "con.txt" and "con .txt":
// Windows takes the part before the first dot, without trailing spaces
inline bool IsReservedDeviceName(const char* comp, int len)
{
    int stem = 0;
    while (stem < len && comp[stem] != '.')
        stem++;
    while (stem > 0 && comp[stem - 1] == ' ')
        stem--;
    static const char* const names[] = {"con", "prn", "aux", "nul", "conin$", "conout$"};
    for (const char* n : names)
        if (EqualNoCase(comp, stem, n))
            return true;
    if (stem >= 4 && (EqualNoCase(comp, 3, "com") || EqualNoCase(comp, 3, "lpt")))
    {
        if (stem == 4 && comp[3] >= '0' && comp[3] <= '9')
            return true;
        unsigned char c1 = (unsigned char)comp[3];
        unsigned char c2 = stem == 5 ? (unsigned char)comp[4] : 0;
        if (stem == 5 && c1 == 0xC2 && (c2 == 0xB9 || c2 == 0xB2 || c2 == 0xB3))
            return true;
    }
    return false;
}

} // namespace SalArcNameDetail

// N1: 'in' (UTF-8, as stored in the archive) -> 'out', a relative path of clean
// components separated by '\'. Drive, UNC/device prefixes and leading
// separators are removed; empty, "." and ".." components are dropped (never
// climb); in each component ':', '<', '>', '"', '|', '?', '*' and control
// characters become '_', trailing dots/spaces become '_', a reserved device
// name gets a '_' prefix. An empty result becomes "_". Returns FALSE (and an
// empty 'out') only when 'outSize' is too small. Idempotent.
inline BOOL SalArcCleanItemPath(const char* in, char* out, int outSize)
{
    using namespace SalArcNameDetail;
    if (out == NULL || outSize <= 0)
        return FALSE;
    out[0] = 0;
    if (in == NULL)
        in = "";

    const char* p = in;
    // UNC / device prefixes: \\?\, \\.\, \\server\share\ (also with '/')
    if (IsSep(p[0]) && IsSep(p[1]))
    {
        p += 2;
        if ((p[0] == '?' || p[0] == '.') && IsSep(p[1]))
        {
            p += 2; // \\?\C:\x -> C:\x (the drive is removed below), \\?\UNC\srv\sh -> UNC\srv\sh
            if (EqualNoCase(p, 3, "unc") && IsSep(p[3]))
            {
                p += 4;
                for (int skip = 0; skip < 2 && *p != 0; skip++) // server, share
                {
                    while (*p != 0 && !IsSep(*p))
                        p++;
                    while (IsSep(*p))
                        p++;
                }
            }
        }
        else
        {
            for (int skip = 0; skip < 2 && *p != 0; skip++) // server, share
            {
                while (*p != 0 && !IsSep(*p))
                    p++;
                while (IsSep(*p))
                    p++;
            }
        }
    }
    // a drive ("C:", "C:\..."); "C:x" or "x::$DATA" is not taken for one - its
    // ':' becomes '_' below, which is just as safe and keeps the name
    if (((p[0] >= 'A' && p[0] <= 'Z') || (p[0] >= 'a' && p[0] <= 'z')) && p[1] == ':' &&
        (p[2] == 0 || IsSep(p[2])))
        p += 2;

    int w = 0;
    while (*p != 0)
    {
        while (IsSep(*p))
            p++;
        if (*p == 0)
            break;
        const char* comp = p;
        while (*p != 0 && !IsSep(*p))
            p++;
        int len = (int)(p - comp);
        if (len == 1 && comp[0] == '.' || len == 2 && comp[0] == '.' && comp[1] == '.')
            continue; // ".", ".." - dropped

        bool reserved = IsReservedDeviceName(comp, len);
        // the component's length after cleaning: optional '_' prefix
        int need = (w > 0 ? 1 : 0) + (reserved ? 1 : 0) + len;
        if (w + need + 1 > outSize)
        {
            out[0] = 0;
            return FALSE;
        }
        if (w > 0)
            out[w++] = '\\';
        if (reserved)
            out[w++] = '_';
        int start = w;
        for (int i = 0; i < len; i++)
        {
            unsigned char c = (unsigned char)comp[i];
            if (c < 0x20 || c == ':' || c == '<' || c == '>' || c == '"' || c == '|' || c == '?' || c == '*')
                out[w++] = '_';
            else
                out[w++] = (char)c;
        }
        // trailing dots and spaces: Windows would strip them (two names could
        // merge, a name could vanish) - replace them instead
        for (int i = w - 1; i >= start && (out[i] == '.' || out[i] == ' '); i--)
            out[i] = '_';
    }
    if (w == 0)
    {
        if (outSize < 2)
            return FALSE;
        out[w++] = '_';
    }
    out[w] = 0;
    return TRUE;
}

// N2: the archive format by signature (at least 8 bytes of 'head' are read
// when available): 1 = 7z, 2 = RAR 1.5-4, 3 = RAR5, 0 = unknown.
#define SALARC_FORMAT_UNKNOWN 0
#define SALARC_FORMAT_7Z 1
#define SALARC_FORMAT_RAR 2
#define SALARC_FORMAT_RAR5 3

inline int SalArcDetectFormat(const BYTE* head, int headLen)
{
    static const BYTE sig7z[] = {0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C};
    static const BYTE sigRar[] = {0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00};
    static const BYTE sigRar5[] = {0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00};
    if (head == NULL)
        return SALARC_FORMAT_UNKNOWN;
    if (headLen >= (int)sizeof(sig7z) && memcmp(head, sig7z, sizeof(sig7z)) == 0)
        return SALARC_FORMAT_7Z;
    if (headLen >= (int)sizeof(sigRar5) && memcmp(head, sigRar5, sizeof(sigRar5)) == 0)
        return SALARC_FORMAT_RAR5;
    if (headLen >= (int)sizeof(sigRar) && memcmp(head, sigRar, sizeof(sigRar)) == 0)
        return SALARC_FORMAT_RAR;
    return SALARC_FORMAT_UNKNOWN;
}
