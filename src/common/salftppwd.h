// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salftppwd.h
//
// FTP client, reading the path out of a "257" reply (PWD, MKD - the working
// folder; FTPGetDirectoryFromReply in src/plugins/ftp/ftputils.cpp). Header-only,
// pure - the plug-in includes it and saltests checks it (feature 277).
//
// The path is never cut: a path that does not fit the caller's buffer is
// refused. The German AIX form was cut at the buffer's size and taken as the
// working folder - an ancestor of the folder the server was in (measured: after a
// reconnect the client went to the cut path and downloaded the ancestor's file
// under the deep folder's name). The quoted form was refused one byte early: a
// path that fills the buffer exactly (300 bytes of FTP_MAX_PATH) was refused.
//
// Forms (as before 277):
//   RFC 959:     257<sp>"<path>"<sp><commentary>      ("" inside = one ")
//   VxWorks:     257 Current directory is "mars:"     (the first " starts it)
//   German AIX:  257 '/a/b' ist das aktuelle Verzeichnis.
//                (a ' before any "; the path ends at the last ', with no " after
//                it; otherwise the quoted form from the first " on)
// Only the bytes [reply, reply + replySize) are read (the AIX form searched up to
// the terminator before 277 - the same result for a reply that ends there).
//
//*****************************************************************************

#define SALFTPPWD_OK 1       // the path is in dirBuf (terminated)
#define SALFTPPWD_SYNTAX 0   // no path in the reply (dirBuf = "")
#define SALFTPPWD_TOOLONG -1 // the path does not fit dirBuf (dirBuf = "")

// the path of the "257" reply 'reply' ('replySize' bytes, the code included) into 'dirBuf'
// ('dirBufSize' bytes, a path of up to dirBufSize - 1 bytes fits); the bytes are copied as the
// server sent them (its encoding)
inline int SalFtpPathFromPwdReply(const char* reply, int replySize, char* dirBuf, int dirBufSize)
{
    if (dirBuf == NULL || dirBufSize <= 0)
        return SALFTPPWD_TOOLONG;
    dirBuf[0] = 0;
    if (reply == NULL || replySize <= 4)
        return SALFTPPWD_SYNTAX;
    const char* end = reply + replySize;
    const char* s = reply + 4;
    while (s < end && *s != '"' && *s != '\'')
        s++;
    if (s < end && *s == '\'') // German AIX?
    {
        const char* lastQuote = NULL;
        const char* t;
        for (t = s + 1; t < end; t++)
        {
            if (*t == '\'')
                lastQuote = t;
        }
        BOOL dquoteAfter = FALSE;
        if (lastQuote != NULL)
        {
            for (t = lastQuote; t < end; t++)
            {
                if (*t == '"')
                {
                    dquoteAfter = TRUE;
                    break;
                }
            }
        }
        if (lastQuote != NULL && !dquoteAfter)
        {
            int len = (int)(lastQuote - (s + 1));
            if (len >= dirBufSize)
                return SALFTPPWD_TOOLONG;
            memcpy(dirBuf, s + 1, len);
            dirBuf[len] = 0;
            return SALFTPPWD_OK;
        }
        while (s < end && *s != '"')
            s++;
    }
    if (s < end && *s == '"')
    {
        int d = 0;
        while (++s < end)
        {
            if (*s == '"')
            {
                if (s + 1 < end && *(s + 1) == '"')
                    s++; // '""' = '"' (escape sequence)
                else
                {
                    dirBuf[d] = 0; // the end of the path
                    return SALFTPPWD_OK;
                }
            }
            if (d >= dirBufSize - 1) // one more byte to store and no room for it
            {
                dirBuf[0] = 0;
                return SALFTPPWD_TOOLONG;
            }
            dirBuf[d++] = *s;
        }
        dirBuf[0] = 0; // the quote is never closed
    }
    return SALFTPPWD_SYNTAX;
}
