// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salftplisting.h
//
// FTP client, reading a server's listing (FTPListingFieldToU8 in
// src/plugins/ftp/ftputils.cpp): is a field's text kept as the UTF-8 name, or
// read in the ANSI code page (a legacy server, feature 224)? Header-only, pure -
// the plug-in includes it and saltests checks it (feature 269).
//
// The test was the strict Windows UTF-8 conversion, which refuses the WTF-8 form
// of an unpaired UTF-16 surrogate (ED A0 80 .. ED BF BF): a name NTFS allows, the
// program's encoding of it (feature 066), and the bytes the plug-in sends for it
// (FTPU8NameToServer). A byte-transparent UTF-8 server listed it back, the whole
// name was read in the code page ("a" U+D800 ".txt" -> "a" + 3 other letters
// ".txt" in cp1250) - another name shown and downloaded, and the upload's "target
// exists?" check never found it (the server's file overwritten without asking).
//
// The rule accepts exactly what the plug-ins' WTF-8 reader (SplU8ToW of
// splunicode.h) accepts: strict UTF-8 whose 3-byte sequences may also encode a
// surrogate. The field is not NUL-terminated; a NUL byte inside counts as a
// character, as it did for the strict conversion with a length.
//
//*****************************************************************************

// TRUE when the 'len' bytes at 's' are ASCII or WTF-8 (an empty field is)
inline BOOL SalFtpListingFieldIsU8(const char* s, int len)
{
    if (s == NULL || len <= 0)
        return TRUE;
    const unsigned char* b = (const unsigned char*)s;
    int i = 0;
    while (i < len)
    {
        unsigned char c = b[i];
        if (c < 0x80)
        {
            i++;
            continue;
        }
        int seq;
        DWORD cp;
        if (c >= 0xC2 && c <= 0xDF)
        {
            seq = 2;
            cp = c & 0x1F;
        }
        else if (c >= 0xE0 && c <= 0xEF)
        {
            seq = 3;
            cp = c & 0x0F;
        }
        else if (c >= 0xF0 && c <= 0xF4)
        {
            seq = 4;
            cp = c & 0x07;
        }
        else
            return FALSE; // a stray continuation byte, C0 / C1 (overlong) or F5..FF
        if (seq > len - i)
            return FALSE; // a sequence cut by the end of the field
        for (int k = 1; k < seq; k++)
        {
            unsigned char t = b[i + k];
            if (t < 0x80 || t > 0xBF)
                return FALSE;
            cp = (cp << 6) | (t & 0x3F);
        }
        // minimal and in range as in strict UTF-8; the only extension is that a 3-byte
        // sequence may encode a surrogate (D800..DFFF)
        if ((seq == 3 && cp < 0x800) || (seq == 4 && (cp < 0x10000 || cp > 0x10FFFF)))
            return FALSE;
        i += seq;
    }
    return TRUE;
}
