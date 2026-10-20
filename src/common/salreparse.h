// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salreparse.h
//
// Feature 197: is a directory with FILE_ATTRIBUTE_REPARSE_POINT deleted as a LINK (only the link
// removed) or emptied like a folder? The delete script took it for a link only when its
// destination could be read - which failed for a path of about 780 characters or more - and then
// descended into the junction: the files of its TARGET were deleted.
//
// The rule (fail closed): a link when the destination was read (a volume mount point, junction,
// symbolic link), when the tag cannot be read, or when the tag is a name surrogate (another link
// kind - the link's own delete refuses a tag it does not know, so nothing is deleted through it).
// Only a readable tag that is not a name surrogate (a cloud placeholder, feature 062 C3) - or no
// tag at all - is a plain directory.
//
// Feature 253: what Change Attributes does with a directory link's own entry (below).
//
// Header-only; needs <windows.h>; checked by saltests.
//
//*****************************************************************************

inline BOOL SalDeleteAsDirLinkDecision(BOOL destinationRead, BOOL tagRead, DWORD tag)
{
    if (destinationRead)
        return TRUE;
    if (!tagRead)
        return TRUE; // cannot tell: never emptied through what may be a link
    return tag != 0 && (tag & 0x20000000) != 0; // IsReparseTagNameSurrogate
}

// feature 253: Change Attributes on a directory link's own entry (213 stopped the walk into it)
// opened the link without FILE_FLAG_OPEN_REPARSE_POINT - the TARGET folder was compressed,
// uncompressed and re-timed. A folder listed with the reparse bit that the Delete rule above takes
// for a link ('deleteAsDirLink', asked only when both bits are set) is a directory link:
inline BOOL SalAttrsEntryIsDirLink(DWORD listedAttr, BOOL deleteAsDirLink)
{
    return (listedAttr & FILE_ATTRIBUTE_DIRECTORY) != 0 && (listedAttr & FILE_ATTRIBUTE_REPARSE_POINT) != 0 &&
           deleteAsDirLink;
}

// the CreateFile flags that reach the entry itself: a folder needs FILE_FLAG_BACKUP_SEMANTICS, a
// directory link also FILE_FLAG_OPEN_REPARSE_POINT (its compression and times are its own, measured)
inline DWORD SalAttrsOpenFlags(BOOL isDir, BOOL isDirLink)
{
    if (!isDir)
        return 0;
    return FILE_FLAG_BACKUP_SEMANTICS | (isDirLink ? FILE_FLAG_OPEN_REPARSE_POINT : 0);
}

// EncryptFile / DecryptFile take a path and follow a link - a directory link's encryption is
// refused when it would change ('wantedAttr' = the requested attributes); a link whose state
// already matches the request has nothing to change
inline BOOL SalAttrsLinkRefusesEncryption(BOOL isDirLink, BOOL changeEncryption, DWORD listedAttr, DWORD wantedAttr)
{
    return isDirLink && changeEncryption && ((listedAttr ^ wantedAttr) & FILE_ATTRIBUTE_ENCRYPTED) != 0;
}

// feature 219: a link's stored name in the Win32 long form ("\\?\C:\x", "\\?\UNC\srv\share") or the
// NT form ("\??\C:\x", "\??\UNC\srv\share") as the path it names - the panel refused "\\?\C:\x".
// Returns a pointer into 's' (for UNC one character of 's' is overwritten: "\\srv\share"), or 's'
// itself when the name is another form (a volume, "\\?\GLOBALROOT", a relative name) or when a
// component ends with '.' or ' ' - the long form keeps such a name, the plain path would name
// another folder (Win32 trims them).
inline WCHAR* SalReparseNameAsPath(WCHAR* s)
{
    if (s == NULL)
        return s;
    BOOL longForm = s[0] == L'\\' && (s[1] == L'\\' || s[1] == L'?') && s[2] == L'?' && s[3] == L'\\';
    if (!longForm)
        return s;
    WCHAR* rest = NULL;
    BOOL unc = FALSE;
    if ((s[4] == L'U' || s[4] == L'u') && (s[5] == L'N' || s[5] == L'n') && (s[6] == L'C' || s[6] == L'c') &&
        s[7] == L'\\' && s[8] != 0)
    {
        rest = s + 8;
        unc = TRUE;
    }
    else if (s[4] != 0 && s[5] == L':' && s[6] == L'\\')
        rest = s + 4;
    if (rest == NULL)
        return s;
    for (const WCHAR* p = rest; *p != 0; p++) // a component ending with '.' or ' ': kept long
    {
        if ((*p == L'.' || *p == L' ') && (p[1] == 0 || p[1] == L'\\'))
            return s;
    }
    if (unc)
    {
        s[6] = L'\\'; // "\\?\UNC\srv" -> "\\srv" (s[7] is the second backslash)
        return s + 6;
    }
    return rest;
}
