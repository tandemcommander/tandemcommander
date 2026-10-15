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
