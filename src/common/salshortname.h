// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salshortname.h
//
// Feature 203: a new file or folder whose name is only the short (8.3) name of ANOTHER entry
// ("LONGFI~1.TXT" next to "longfilename.txt") fails "it exists"; the create paths move that entry
// aside for the create and back. When that does not help (the other entry held open), the error
// reported is the failed step's own - never "it exists", which every caller takes for the target
// itself: F5 asked to overwrite the other file, a copied folder was merged into the other folder,
// an archive member replaced the other file's content. Nor success (no step reported an error):
// both become "access denied".
//
// Feature 204: an archive member's folder "LONGDI~1" unpacked next to a folder "longdirname" (whose
// short name LONGDI~1 is) went INTO longdirname - the path resolves through the short name, and a
// file there of the member's name was offered for overwriting under the member's path. Below the
// unpack's target folder, a path component found only as ANOTHER entry's short name is made a
// folder of its own (the clash moved aside, as above); the target the user typed keeps resolving.
//
// Header-only; needs <windows.h> and SalNameEqualOrdinalCI (salunicode.h); checked by saltests.
//
//*****************************************************************************

// the entry found under 'name' ('nameLen' bytes, -1 = all) has the long name 'foundLong' and the short
// name 'foundShort' (empty when none): TRUE when 'name' is only that short name - the entry is
// another one (both by the 092 rule; a name equal to the long name is the entry's own, whatever
// its short name)
inline BOOL SalNameIsOnlyShortNameOf(const char* name, int nameLen, const char* foundLong, const char* foundShort)
{
    if (foundShort == NULL || foundShort[0] == 0 || foundLong == NULL)
        return FALSE;
    return SalNameEqualOrdinalCI(name, nameLen, foundShort, -1) && !SalNameEqualOrdinalCI(name, nameLen, foundLong, -1);
}

// can 'name' ('nameLen' bytes, -1 = all; UTF-8) be a short (8.3) name at all? At most 8 characters,
// one dot, then at most 3 - a component that cannot is never looked up (an unpack of 100,000 files
// to a share did a directory search per folder of every file). No false "cannot": a character is
// counted once whatever its UTF-8 length; "." and ".." and an empty name are not short names
inline BOOL SalNameCanBeShortName(const char* name, int nameLen)
{
    if (nameLen < 0)
        nameLen = (int)strlen(name);
    if (nameLen == 0 || name[0] == '.')
        return FALSE;
    int base = 0, ext = 0, dots = 0;
    for (int i = 0; i < nameLen; i++)
    {
        unsigned char c = (unsigned char)name[i];
        if ((c & 0xC0) == 0x80)
            continue; // a continuation byte: the character is counted already
        if (c == '.')
        {
            if (++dots > 1)
                return FALSE;
        }
        else if (dots == 0)
        {
            if (++base > 8)
                return FALSE;
        }
        else if (++ext > 3)
            return FALSE;
    }
    return base > 0;
}

inline DWORD SalShortNameClashError(DWORD stepErr)
{
    if (stepErr == ERROR_SUCCESS || stepErr == ERROR_FILE_EXISTS || stepErr == ERROR_ALREADY_EXISTS)
        return ERROR_ACCESS_DENIED;
    return stepErr;
}
