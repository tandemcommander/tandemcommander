// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// splshortname.h
//
// Feature 205: a local name of a download may be only the short (8.3) name of ANOTHER entry
// ("LONGFI~1.TXT" next to "longfilename.txt", "LONGDI~1" next to "longdirname") - Windows opens
// that other entry under it. The FTP plug-in took it for "the target exists" (a downloaded folder
// joined into the other folder, the other file offered for overwriting and resuming), the SFTP
// plug-in replaced the other file. "It exists" is never taken for an entry found only that way.
//
// Header-only, for plug-ins; needs splunicode.h and ../../common/salnameorder.h.
//
//*****************************************************************************

// TRUE when 'pathU8' (UTF-8 / WTF-8, any length; a trailing backslash ignored) was found only as
// the short name of an entry whose long name is another one (the 092 rule) - proven, not guessed:
// nothing found, or a folder that cannot be listed, is FALSE (the caller's old handling)
inline BOOL SplPathIsOnlyShortNameOfOther(const char* pathU8)
{
    size_t len = strlen(pathU8);
    while (len > 0 && pathU8[len - 1] == '\\')
        len--;
    const char* name = pathU8 + len;
    while (name > pathU8 && name[-1] != '\\')
        name--;
    int nameLen = (int)(pathU8 + len - name);
    if (nameLen == 0 || name[0] == '.' && (nameLen == 1 || nameLen == 2 && name[1] == '.'))
        return FALSE; // "." or ".." (a root "C:\" ends in a lookup of "C:", which finds nothing)
    char* copy = (char*)malloc(len + 1);
    if (copy == NULL)
        return FALSE;
    memcpy(copy, pathU8, len);
    copy[len] = 0;
    WCHAR* w = SplU8ToWExtAlloc(copy);
    free(copy);
    if (w == NULL)
        return FALSE;
    WIN32_FIND_DATAW fd;
    HANDLE find = FindFirstFileW(w, &fd);
    free(w);
    if (find == INVALID_HANDLE_VALUE)
        return FALSE;
    FindClose(find);
    char longU8[3 * MAX_PATH + 4];
    char shortU8[3 * 14 + 4];
    if (SplWToU8(fd.cFileName, longU8, sizeof(longU8)) == 0 || fd.cAlternateFileName[0] == 0 ||
        SplWToU8(fd.cAlternateFileName, shortU8, sizeof(shortU8)) == 0)
        return FALSE;
    return SalNameOrderEqualCI(name, nameLen, shortU8, -1) && !SalNameOrderEqualCI(name, nameLen, longU8, -1);
}
