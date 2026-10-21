// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// saluncserver.h (feature 125)
//
// A UNC path that names a server and no share ("\\server", "\\server\") used to
// end in "A share name is missing in the path specified" unless a Network
// plug-in was loaded (GitHub issue #5). Without such a plug-in the core now
// reads the server's shares and lets the user pick one (CFilesWindow::
// PickServerShare). The decisions of that route are here, pure, so that
// saltests checks them:
//
//   SalUncServerOfPath    is the path "server only", and which server
//   SalUncShareOffered    which share types are offered (folders only)
//   SalUncShareHidden     hidden by the '$' convention / a special share
//   SalUncShareCompare    visible before hidden, then the file system's order
//   SalUncBuildSharePath  "\\server\share" - refused when it does not fit,
//                         never cut (CLAUDE.md: a path or name is never cut)
//   SalUncMenuText        a share name as a menu item text ('&' doubled)
//   SalUncShareRootServerPath  (feature 284) is the path a share's root, and
//                         "\\server\" of it - the way up from "\\server\share"
//                         (`..`, Backspace, Go to root) offers the same list
//
// Names are UTF-8 (WTF-8), as everywhere in the core. Header-only.
//
//*****************************************************************************

#include "salnameorder.h"

// share types of lmshare.h (repeated: saltests does not include lm.h)
#define SALUNC_STYPE_DISKTREE 0x00000000
#define SALUNC_STYPE_MASK 0x000000FF
#define SALUNC_STYPE_SPECIAL 0x80000000

// TRUE when 'path' is "\\server" or "\\server\" (after the normalisation the
// path change does: backslashes only, no doubled ones behind the prefix);
// 'server' then holds the server name without backslashes. FALSE for "\\",
// "\\.\..." and "\\?\..." (devices, not servers), for a path with a share
// part, and for a server name that does not fit into 'serverSize' bytes.
inline BOOL SalUncServerOfPath(const char* path, char* server, int serverSize)
{
    if (server != NULL && serverSize > 0)
        server[0] = 0;
    if (path == NULL || path[0] != '\\' || path[1] != '\\')
        return FALSE;
    const char* s = path + 2;
    const char* e = s;
    while (*e != 0 && *e != '\\')
        e++;
    if (e == s)
        return FALSE; // "\\" or "\\\..."
    if (*e == '\\' && e[1] != 0)
        return FALSE; // something follows the server: a share part
    int len = (int)(e - s);
    if (len == 1 && (*s == '.' || *s == '?'))
        return FALSE; // "\\.\" and "\\?\" are device prefixes
    if (server == NULL || len + 1 > serverSize)
        return FALSE;
    memcpy(server, s, len);
    server[len] = 0;
    return TRUE;
}

// Folder shares only: printers, devices and IPC are not places a panel can show.
inline BOOL SalUncShareOffered(DWORD type)
{
    return (type & SALUNC_STYPE_MASK) == SALUNC_STYPE_DISKTREE;
}

// A share name a path can hold: not empty, no backslash and no slash (both are
// separators for the path code), not "." or ".." (the path code would resolve
// them away). Windows servers never report such a name; one from a foreign
// server ("a/b") is left out of the list rather than offered and then opened
// as "\\server\a\b".
inline BOOL SalUncShareNameUsable(const char* name)
{
    return name != NULL && name[0] != 0 && strchr(name, '\\') == NULL && strchr(name, '/') == NULL &&
           strcmp(name, ".") != 0 && strcmp(name, "..") != 0;
}

// Hidden: a special (administrative) share or a name ending with '$'.
inline BOOL SalUncShareHidden(const char* name, DWORD type)
{
    if ((type & SALUNC_STYPE_SPECIAL) != 0)
        return TRUE;
    size_t len = name != NULL ? strlen(name) : 0;
    return len > 0 && name[len - 1] == '$';
}

// The order of the offered list: visible shares first, hidden ones after them,
// inside a group the file system's name order (rule 092).
inline int SalUncShareCompare(const char* nameA, BOOL hiddenA, const char* nameB, BOOL hiddenB)
{
    if ((hiddenA != FALSE) != (hiddenB != FALSE))
        return hiddenA ? 1 : -1;
    return SalNameOrderCompareCI(nameA, -1, nameB, -1);
}

// "\\server\share" into 'buf'. FALSE (and an empty 'buf') when a part is
// missing, when a part holds a backslash or a slash (the path code reads both
// as a separator, so "a/b" would open another place than the one offered), or
// when the result does not fit - the caller refuses the path then; it is
// never shortened.
inline BOOL SalUncBuildSharePath(const char* server, const char* share, char* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return FALSE;
    buf[0] = 0;
    if (server == NULL || share == NULL || server[0] == 0 || share[0] == 0 ||
        strchr(server, '\\') != NULL || strchr(share, '\\') != NULL ||
        strchr(server, '/') != NULL || strchr(share, '/') != NULL)
        return FALSE;
    size_t serverLen = strlen(server);
    size_t shareLen = strlen(share);
    if (2 + serverLen + 1 + shareLen + 1 > (size_t)bufSize)
        return FALSE;
    char* d = buf;
    *d++ = '\\';
    *d++ = '\\';
    memcpy(d, server, serverLen);
    d += serverLen;
    *d++ = '\\';
    memcpy(d, share, shareLen + 1);
    return TRUE;
}

// Feature 284: TRUE when 'path' is the root of a share - "\\server\share" or
// "\\server\share\" (backslashes only, as the panel's paths are) with a server
// that is not a device prefix ("\\.\", "\\?\"), a share part that is not
// empty and nothing after it; 'serverPath' then holds "\\server\", the path
// whose change offers the server's shares (feature 125). FALSE and an empty
// 'serverPath' otherwise, also when the result does not fit into
// 'serverPathSize' bytes - refused, never cut.
inline BOOL SalUncShareRootServerPath(const char* path, char* serverPath, int serverPathSize)
{
    if (serverPath == NULL || serverPathSize <= 0)
        return FALSE;
    serverPath[0] = 0;
    if (path == NULL || path[0] != '\\' || path[1] != '\\')
        return FALSE;
    const char* server = path + 2;
    const char* e = server;
    while (*e != 0 && *e != '\\')
        e++;
    int serverLen = (int)(e - server);
    if (serverLen == 0 || *e != '\\')
        return FALSE; // "\\", "\\\..." or no share part at all ("\\server")
    if (serverLen == 1 && (*server == '.' || *server == '?'))
        return FALSE; // "\\.\" and "\\?\" are device prefixes
    const char* share = e + 1;
    const char* s = share;
    while (*s != 0 && *s != '\\')
        s++;
    if (s == share)
        return FALSE; // "\\server\" or "\\server\\...": no share name
    if (*s == '\\' && s[1] != 0)
        return FALSE; // something follows the share: not its root
    if (2 + serverLen + 1 + 1 > serverPathSize)
        return FALSE;
    serverPath[0] = '\\';
    serverPath[1] = '\\';
    memcpy(serverPath + 2, server, serverLen);
    serverPath[2 + serverLen] = '\\';
    serverPath[2 + serverLen + 1] = 0;
    return TRUE;
}

// A share name as the text of a menu item: every '&' doubled (a single one
// marks the item's access key). FALSE when the text does not fit - the caller
// then leaves the item out rather than showing a cut name.
inline BOOL SalUncMenuText(const char* name, char* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return FALSE;
    buf[0] = 0;
    if (name == NULL)
        return FALSE;
    int n = 0;
    for (const char* s = name; *s != 0; s++)
    {
        int need = *s == '&' ? 2 : 1;
        if (n + need + 1 > bufSize)
        {
            buf[0] = 0;
            return FALSE;
        }
        buf[n++] = *s;
        if (*s == '&')
            buf[n++] = '&';
    }
    buf[n] = 0;
    return TRUE;
}
