// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salftproot.h
//
// How the root ("//user@host:port") of a path the FTP plug-in is told changed
// relates to the root of one of its connections (feature 410). Until 410 a
// change was matched to a panel, and to the plug-in's cached listings, only
// when the host was the one typed: a change made through "localhost" left a
// panel at "127.0.0.1" (the same server) showing the old listing. Feature 341
// decided that a client cannot tell names of one server from two servers - two
// names with the same user and port are maybe the same server.
//
//   SAL_FTP_ROOT_SAME        same user, same port, the same host name
//   SAL_FTP_ROOT_OTHER_HOST  same user, same port, another host name
//                            (maybe the same server: refresh, drop caches)
//   SAL_FTP_ROOT_OTHER       another user or another port (unchanged:
//                            not matched)
//
// The user is compared case-sensitively (UNIX accounts); no user and
// "anonymous" are the same user. The port is compared as text, as the root
// carries it; no port and "21" are the same port. The host comparison stays
// the caller's (the plug-in's StrICmp) and comes in as 'hostsEqual'.
//
// Header-only and pure (no globals): the FTP plug-in cannot be linked into
// saltests, this rule can.
//
//*****************************************************************************

#include <string.h> // strcmp

#define SAL_FTP_ROOT_OTHER 0
#define SAL_FTP_ROOT_SAME 1
#define SAL_FTP_ROOT_OTHER_HOST 2

// TRUE when two users of FTP roots are the same account: NULL and "anonymous"
// mean the anonymous user; any other name compares case-sensitively.
inline bool SalFtpSameUser(const char* user1, const char* user2)
{
    if (user1 != NULL && strcmp(user1, "anonymous") == 0)
        user1 = NULL;
    if (user2 != NULL && strcmp(user2, "anonymous") == 0)
        user2 = NULL;
    if (user1 == NULL || user2 == NULL)
        return user1 == user2;
    return strcmp(user1, user2) == 0;
}

// TRUE when two port texts of FTP roots name the same port: NULL means the
// standard port "21"; otherwise the texts compare exactly.
inline bool SalFtpSamePortText(const char* port1, const char* port2)
{
    if (port1 == NULL)
        port1 = "21";
    if (port2 == NULL)
        port2 = "21";
    return strcmp(port1, port2) == 0;
}

// The relation of two FTP roots (SAL_FTP_ROOT_*), the hosts already compared
// by the caller.
inline int SalFtpRootMatchOf(const char* user1, const char* port1, const char* user2, const char* port2,
                             bool hostsEqual)
{
    if (!SalFtpSameUser(user1, user2) || !SalFtpSamePortText(port1, port2))
        return SAL_FTP_ROOT_OTHER;
    return hostsEqual ? SAL_FTP_ROOT_SAME : SAL_FTP_ROOT_OTHER_HOST;
}
