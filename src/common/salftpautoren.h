// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salftpautoren.h
//
// FTP client, automatic rename of an uploaded file or directory ("name (2).txt",
// FTPGenerateNewName in src/plugins/ftp/ftputils.cpp): the steps that shorten the
// name (feature 141). Header-only, pure - the plug-in includes it and saltests
// checks it.
//
// The generator shortened at a BYTE position; with a multi-byte letter there,
// half of it stayed (in front of " (2)", or at the end of the name). The cut is
// moved back to the start of the character it falls into.
//
// Text that is not UTF-8 (a name in a code page) is never shortened more than
// before by more than 3 bytes and never to nothing: the cut moves only when one
// of the 3 bytes in front of it is a UTF-8 lead byte whose sequence reaches over
// the cut. A run of bytes 0x80-0xBF without such a lead byte keeps the plain
// byte cut. (SplU8WholePrefixLen of splunicode.h steps back without a bound - it
// is for text known to be UTF-8.)
//
//*****************************************************************************

// How many of the first 'bytes' bytes of 's' are kept so that a UTF-8 character is not cut
// in half: 'bytes', or up to 3 less. 's' must hold at least 'bytes' bytes and a terminator.
inline int SalFtpWholePrefixLen(const char* s, int bytes)
{
    if (s == NULL || bytes <= 0)
        return 0;
    if (((unsigned char)s[bytes] & 0xC0) != 0x80)
        return bytes; // the first byte left out starts a character (or ends the text)
    for (int back = 1; back <= 3 && back <= bytes; back++)
    {
        unsigned char b = (unsigned char)s[bytes - back];
        if ((b & 0xC0) == 0x80)
            continue; // another continuation byte: look further back
        if (b >= 0xC0)
        {
            int seqLen = b >= 0xF0 ? 4 : (b >= 0xE0 ? 3 : 2);
            if (seqLen > back)
                return bytes - back; // this character reaches over the cut: it goes whole
        }
        break; // ASCII, or a sequence that ended before the cut: not UTF-8 here
    }
    return bytes; // the plain byte cut
}

// 'name' holds a name part of 'nameLen' bytes (followed by the extension's dot or the
// terminator) and at least 'cut' bytes must go from its end. Returns how many bytes to
// remove so that the rest does not end in half a character: 'cut', or up to 3 more, and
// 'nameLen' when nothing of the name part would be left (the caller then shortens
// elsewhere).
inline int SalFtpCutBeforeExt(const char* name, int nameLen, int cut)
{
    if (name == NULL || nameLen <= 0 || cut <= 0)
        return 0;
    if (cut >= nameLen)
        return nameLen;
    return nameLen - SalFtpWholePrefixLen(name, nameLen - cut);
}
