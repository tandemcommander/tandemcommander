// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salftpsrvenc.h
//
// FTP client: in which encoding does a name go to a server (FTPU8NameToServer in
// src/plugins/ftp/ftputils.cpp)? Header-only, pure - the plug-in includes it and
// saltests checks it (feature 288).
//
// Feature 224 sent a non-ASCII name in the ANSI code page only when a listing (or a
// "257" reply) had given that very text in the code page, remembered in one set for
// the whole program: a new name (a created folder, a rename's new name, an uploaded
// file, a typed path) went in UTF-8 also to a server whose listings showed it speaks
// the code page - it stored a garbled name; and a name seen in the code page on one
// server went in the code page to another (a UTF-8 server: "550 No such file").
//
// Now each server - its host (ASCII case ignored), port and user (anonymous = none,
// the identity of the upload listing cache) - has its own evidence and its own names:
//   - UTF-8 evidence: a listing field with non-ASCII bytes that is UTF-8 (WTF-8, see
//     salftplisting.h). A "257" path is never UTF-8 evidence - it may echo the bytes
//     the client sent;
//   - code-page evidence: a listing field or a "257" path read in the code page.
// The plug-in sends no FEAT, so a listing is the only evidence (FEAT UTF8 would be a
// new command to the server - the maintainer's decision).
//
//*****************************************************************************

enum
{
    SALFTPENC_UNKNOWN, // nothing seen yet
    SALFTPENC_UTF8,    // only UTF-8 names seen
    SALFTPENC_LEGACY,  // only code-page names seen
    SALFTPENC_MIXED,   // both (a byte-transparent server holding both kinds)
};

inline int SalFtpServerEncState(BOOL sawUtf8, BOOL sawCodePage)
{
    if (sawUtf8)
        return sawCodePage ? SALFTPENC_MIXED : SALFTPENC_UTF8;
    return sawCodePage ? SALFTPENC_LEGACY : SALFTPENC_UNKNOWN;
}

// TRUE when a non-ASCII name goes to the server in the code page: it is (or holds as a
// component or a leading part) a text this server gave in the code page, or the server
// speaks only the code page; an unknown or mixed server gets a new name in UTF-8 (224's
// policy). The caller still sends UTF-8 when the code page cannot hold the name.
inline BOOL SalFtpNameGoesInCodePage(int state, BOOL isCodePageNameOfServer)
{
    return isCodePageNameOfServer || state == SALFTPENC_LEGACY;
}

// the user of a server: NULL, "" and "anonymous" are one user (the operations store the
// anonymous user by its name, the upload listing cache by NULL); otherwise byte for byte
inline BOOL SalFtpSameServerUser(const char* a, const char* b)
{
    if (a != NULL && (a[0] == 0 || strcmp(a, "anonymous") == 0))
        a = NULL;
    if (b != NULL && (b[0] == 0 || strcmp(b, "anonymous") == 0))
        b = NULL;
    if (a == NULL || b == NULL)
        return a == b;
    return strcmp(a, b) == 0;
}

// the host of a server: equal without regard to ASCII case (a byte >= 0x80 is compared as
// it is); NULL is never a host
inline BOOL SalFtpSameServerHost(const char* a, const char* b)
{
    if (a == NULL || b == NULL)
        return FALSE;
    for (;; a++, b++)
    {
        unsigned char ca = (unsigned char)*a;
        unsigned char cb = (unsigned char)*b;
        if (ca >= 'A' && ca <= 'Z')
            ca += 'a' - 'A';
        if (cb >= 'A' && cb <= 'Z')
            cb += 'a' - 'A';
        if (ca != cb)
            return FALSE;
        if (ca == 0)
            return TRUE;
    }
}

inline BOOL SalFtpSameServer(const char* hostA, unsigned short portA, const char* userA,
                             const char* hostB, unsigned short portB, const char* userB)
{
    return portA == portB && SalFtpSameServerHost(hostA, hostB) && SalFtpSameServerUser(userA, userB);
}
