// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salpackname.h
//
// Pure rule of feature 317: the Pack dialog's archive name keeps the leading
// spaces of a relative name (' report.zip' is no longer packed into
// 'report.zip'). A name whose last part is only spaces and dots (' ..', ' .')
// then reaches the packer as that part - before 317 it was trimmed to '..' or
// '.' and meant a folder, so no archive was made; the packers write through
// \\?\ paths and would now create a file literally named ' ..'. Such a name is
// refused. Header-only, no globals; saltests checks it.
//
//   SalPackNameIsOnlyDotsAndSpaces  the last part of a full archive name is
//                                   made of spaces and dots only
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

// TRUE when the part of 'fullName' after its last '\' (the whole name when there is none) is not
// empty and holds only ' ' and '.' characters - a name no Windows file system keeps as typed (the
// trailing spaces and dots are trimmed); FALSE otherwise, also for NULL or an empty last part
inline BOOL SalPackNameIsOnlyDotsAndSpaces(const char* fullName)
{
    if (fullName == NULL)
        return FALSE;
    const char* last = strrchr(fullName, '\\');
    last = (last != NULL) ? last + 1 : fullName;
    if (*last == 0)
        return FALSE;
    for (const char* s = last; *s != 0; s++)
    {
        if (*s != ' ' && *s != '.')
            return FALSE;
    }
    return TRUE;
}
