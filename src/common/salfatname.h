// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salfatname.h
//
// FAT directory-entry name rules for the Undelete plug-in (feature 114).
// Header-only, no globals: the plug-in includes it from its FAT parser and
// saltests checks it.
//
// Where the 0xE5 rule belongs. A FAT directory entry marks a deleted entry by
// overwriting the FIRST BYTE OF THE SHORT (8.3) NAME with 0xE5; a short name
// whose real first byte is 0xE5 (a lead byte in the Japanese OEM code page) is
// therefore stored with 0x05 instead. That is all: the rule lives in the
// 11 raw bytes of a short-name entry, in the OEM code page, and nowhere else -
// long-name (LFN) entries carry UTF-16 and are marked deleted in their own
// ordinal byte, exFAT marks deleted entries with a type bit, NTFS has no such
// byte at all. Before feature 114 the plug-in applied the rule to the UTF-8
// name it had already produced (every file system, long names included), so
// every name whose UTF-8 form begins with the byte 0xE5 - U+5000..U+5FFF, e.g.
// U+597D - was listed with '$' and restored under a garbled name.
//
// Now the FAT parser decodes the raw short name here, before any conversion:
//   byte 0 == 0xE5  -> the first character is lost; '$' stands for it (the
//                      placeholder the plug-in always showed) and the caller
//                      flags the name as damaged (the user is asked for the
//                      character when restoring)
//   byte 0 == 0x05  -> a real 0xE5 byte
//   base / extension -> trailing spaces trimmed (FAT pads with spaces), bytes
//                      decoded from the OEM code page (what the file system
//                      wrote), the NT case bits applied (0x08 base, 0x10
//                      extension lower case - A-Z only, as Windows shows them)
//
// The checksum of a short name links it to its long-name entries. For a
// deleted entry the first byte is gone, so it is reconstructed from the first
// long-name character Windows KEPT in the short name (it drops what it cannot
// put there); SalFatLostFirstByteCandidates lists the possible bytes, most
// likely first. A hash-form short name ("191D~1.TXT") cannot be linked back.
//
//*****************************************************************************

#include <windows.h>

#define SALFAT_NAME_DELETED 0xE5 // first byte of a deleted short-name entry
#define SALFAT_NAME_E5ESC 0x05   // first byte that stands for a real 0xE5
#define SALFAT_NTRES_LOWERBASE 0x08
#define SALFAT_NTRES_LOWEREXT 0x10
#define SALFAT_LOST_PLACEHOLDER L'$'

// the short-name checksum stored in every long-name entry (FAT specification)
inline BYTE SalFatShortNameChecksum(const BYTE* name11)
{
    BYTE sum = 0;
    for (int i = 0; i < 11; i++)
        sum = (BYTE)((((sum & 1) ? 0x80 : 0) + (sum >> 1) + name11[i]) & 0xFF);
    return sum;
}

namespace SalFatNameDetail
{
// upper / lower case in place, the same for every user locale (the file system's tables are not
// linguistic: CharUpperW / CharLowerW would follow e.g. the Turkish dotted / dotless i)
inline void CaseInvariant(WCHAR* s, int n, DWORD flag)
{
    if (n <= 0)
        return;
    WCHAR tmp[32];
    if (n > 32)
        return;
    if (LCMapStringEx(LOCALE_NAME_INVARIANT, flag, s, n, tmp, n, NULL, NULL, 0) == n)
        memcpy(s, tmp, n * sizeof(WCHAR));
}

// the NT case bits lower case A-Z only - what Windows shows (fastfat Fat8dot3ToString):
// a short name <C-caron>AJ.TXT with both bits set is shown as <C-caron>aj.txt (such short
// names come from Linux for a long name <c-caron>aj.txt; Windows writes a long name then)
inline void LowerAscii(WCHAR* s, int n)
{
    for (int i = 0; i < n; i++)
        if (s[i] >= L'A' && s[i] <= L'Z')
            s[i] = (WCHAR)(s[i] + (L'a' - L'A'));
}

// decodes 'n' OEM bytes into 'out' (capacity 'cap'); returns the WCHAR count (0 on failure)
inline int OemToW(const BYTE* s, int n, UINT oemCp, WCHAR* out, int cap)
{
    if (n <= 0)
        return 0;
    int r = MultiByteToWideChar(oemCp, 0, (const char*)s, n, out, cap);
    if (r <= 0) // an unusable code page: keep the bytes as Latin-1, never fail the name
    {
        if (n > cap)
            return 0;
        for (int i = 0; i < n; i++)
            out[i] = s[i];
        r = n;
    }
    return r;
}
} // namespace SalFatNameDetail

// Decodes the 11 raw bytes of a short-name directory entry into UTF-16 "BASE.EXT"
// (no dot when the extension is empty). 'ntRes' is the entry's NT byte; its case bits
// are applied only when 'applyCase' (the short name is the name shown; a short name
// shown next to a long name stays as stored). '*firstCharLost' (may be NULL) is set
// when byte 0 is the deletion marker - the result then starts with '$'.
// Returns the WCHAR count without the terminator; 0 for an empty base name (not a
// valid name) or when 'cap' is too small. 'out' is always terminated when cap > 0.
inline int SalFatShortNameToW(const BYTE* name11, BYTE ntRes, BOOL applyCase, UINT oemCp,
                              WCHAR* out, int cap, BOOL* firstCharLost)
{
    if (firstCharLost != NULL)
        *firstCharLost = FALSE;
    if (cap > 0)
        out[0] = 0;
    BYTE raw[11];
    memcpy(raw, name11, 11);
    BOOL lost = raw[0] == SALFAT_NAME_DELETED;
    if (raw[0] == SALFAT_NAME_E5ESC)
        raw[0] = SALFAT_NAME_DELETED; // the escaped real 0xE5 byte

    int baseLen = 8;
    while (baseLen > 0 && raw[baseLen - 1] == ' ')
        baseLen--;
    int extLen = 3;
    while (extLen > 0 && raw[8 + extLen - 1] == ' ')
        extLen--;
    if (baseLen == 0)
        return 0;

    WCHAR tmp[32];
    int len = 0;
    if (lost)
    {
        tmp[len++] = SALFAT_LOST_PLACEHOLDER;
        len += SalFatNameDetail::OemToW(raw + 1, baseLen - 1, oemCp, tmp + len, 16);
    }
    else
        len += SalFatNameDetail::OemToW(raw, baseLen, oemCp, tmp, 16);
    if (applyCase && (ntRes & SALFAT_NTRES_LOWERBASE) && len > 0)
        SalFatNameDetail::LowerAscii(tmp, len);
    if (extLen > 0)
    {
        tmp[len++] = L'.';
        int e = SalFatNameDetail::OemToW(raw + 8, extLen, oemCp, tmp + len, 8);
        if (applyCase && (ntRes & SALFAT_NTRES_LOWEREXT) && e > 0)
            SalFatNameDetail::LowerAscii(tmp + len, e);
        len += e;
    }
    if (len + 1 > cap)
        return 0;
    memcpy(out, tmp, len * sizeof(WCHAR));
    out[len] = 0;
    if (firstCharLost != NULL)
        *firstCharLost = lost;
    return len;
}

namespace SalFatNameDetail
{
// The byte Windows writes into a short name for the long-name character 'c' when it makes a
// short name on a FAT volume (fastfat: RtlGenerate8dot3Name with extended characters allowed;
// ReactOS dos8dot3.c): a character <= space and '.' are DROPPED; + , ; = [ ] become '_'; any
// other character is upper-cased and kept when it is ASCII or an OEM character that converts
// back to itself - otherwise it is DROPPED (not replaced). Returns FALSE for a dropped character.
inline BOOL ShortNameByte(WCHAR c, UINT oemCp, BYTE* b)
{
    if (c <= L' ' || c == L'.')
        return FALSE;
    if (c == L'+' || c == L',' || c == L';' || c == L'=' || c == L'[' || c == L']')
    {
        *b = '_';
        return TRUE;
    }
    WCHAR up = c;
    CaseInvariant(&up, 1, LCMAP_UPPERCASE);
    if (up < 0x7F)
    {
        *b = (BYTE)up;
        return TRUE;
    }
    if (up >= 0xD800 && up <= 0xDFFF)
        return FALSE; // a surrogate: never an OEM character
    char mb[8];
    int r;
    if (oemCp == CP_UTF8)
        r = WideCharToMultiByte(CP_UTF8, 0, &up, 1, mb, sizeof(mb), NULL, NULL);
    else
    {
        BOOL usedDefault = FALSE;
        r = WideCharToMultiByte(oemCp, WC_NO_BEST_FIT_CHARS, &up, 1, mb, sizeof(mb), NULL, &usedDefault);
        if (usedDefault)
            r = 0;
    }
    if (r <= 0)
        return FALSE;
    WCHAR back[4];
    if (MultiByteToWideChar(oemCp, 0, mb, r, back, 4) != 1 || back[0] != up)
        return FALSE; // does not convert back to itself
    *b = (BYTE)mb[0];
    return TRUE;
}

inline void AddCandidate(BYTE* cand, int* n, int max, BYTE b)
{
    if (*n >= max)
        return;
    for (int k = 0; k < *n; k++)
        if (cand[k] == b)
            return;
    cand[(*n)++] = b;
}
} // namespace SalFatNameDetail

// The bytes the first short-name byte of a deleted entry may have had, given the first
// 13 UTF-16 units of its long name ('lfn', 'lfnLen' units; the units of the long-name
// entry right before the short one - ordinal 1). Most likely first:
//   1. Windows (fastfat): the byte of the FIRST CHARACTER IT KEEPS (SalFatNameDetail::
//      ShortNameByte - dots, spaces and characters outside the OEM code page are dropped,
//      + , ; = [ ] become '_'); none when no character of the base name is kept: Windows
//      then writes a hash form ("191D~1.TXT" for U+597D.txt, measured with dir /x) whose
//      first byte says nothing about the long name - the long name cannot be linked back
//      and the short name is shown as damaged (the Damaged Filename dialog), as before
//   2. what the plug-in reconstructed before feature 114 (the ANSI code page with best
//      fit, CharUpperA) - kept so a long name found before is still found
//   3. '_' when the first visible character is not ASCII - the Linux vfat driver writes
//      '_' for a character it cannot put into a short name (memory cards, Android)
// A Windows candidate 0xE5 is returned as 0x05 (the stored form). Returns the count (<=
// max), duplicates removed. Every candidate is a 1/256 chance of taking an unrelated orphan
// long name (the checksum is a bijection of the first byte), so the list stays short.
inline int SalFatLostFirstByteCandidates(const WCHAR* lfn, int lfnLen, UINT oemCp, UINT acp,
                                         BYTE* cand, int max)
{
    int n = 0;
    if (max <= 0 || lfnLen <= 0)
        return 0;
    int end = 0;
    while (end < lfnLen && lfn[end] != 0)
        end++;
    if (end == 0)
        return 0;
    BOOL complete = end < lfnLen; // the whole name is in these units: its last dot is known
    int lead = 0;
    while (lead < end && lfn[lead] == L'.')
        lead++; // leading dots never separate the extension (".gitignore" -> GITIGN~1)
    int lastDot = -1;
    for (int i = lead; i < end; i++)
        if (lfn[i] == L'.')
            lastDot = i;

    // 1. Windows
    for (int i = 0; i < end; i++)
    {
        BYTE b;
        if (!SalFatNameDetail::ShortNameByte(lfn[i], oemCp, &b))
            continue;
        if (complete && lastDot >= 0 && i > lastDot)
            break; // the first kept character is in the extension: a hash-form short name
        if (b == SALFAT_NAME_DELETED)
            b = SALFAT_NAME_E5ESC;
        SalFatNameDetail::AddCandidate(cand, &n, max, b);
        break;
    }

    // 2. the reconstruction of the builds before 114, exactly: the first unit that is not a
    //    dot among the first five, the ANSI code page with best fit into ONE byte (the
    //    deletion marker stays when that fails), CharUpperA, no 0x05 escape
    {
        int j = 0;
        while (j < 4 && j < lfnLen - 1 && lfn[j] == L'.') // the old loop's result: Name1[4] at most
            j++;
        WCHAR oc = lfn[j];
        char one = (char)SALFAT_NAME_DELETED;
        WideCharToMultiByte(acp, 0, &oc, 1, &one, 1, NULL, NULL);
        SalFatNameDetail::AddCandidate(cand, &n, max, (BYTE)(UINT_PTR)CharUpperA((LPSTR)(UINT_PTR)(BYTE)one));
    }

    // 3. Linux vfat's '_'
    int v = 0;
    while (v < end && (lfn[v] == L'.' || lfn[v] == L' '))
        v++;
    if (v < end && lfn[v] >= 0x80)
        SalFatNameDetail::AddCandidate(cand, &n, max, '_');
    return n;
}
