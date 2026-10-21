// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// saldrivetext.h (feature 289)
//
// The type name of folders, a removable drive's name and a CD label reached the
// panel, the Change Drive menu and the drive bar tooltip from the code-page
// shell / volume calls, which give '?' for every character the code page
// cannot express. They are now read from the wide calls and kept as UTF-8; the
// pure parts of that are here, so that saltests checks them:
//
//   SAL_DRIVE_TEXT_U8_MAX     bytes that hold any shell display name or volume
//                             label as UTF-8 (+ terminator) - nothing is cut
//   SAL_FOLDER_TYPE_U8_MAX    the same for a shell type name (szTypeName[80])
//   SalDriveNameTrimLetterSuffixW
//                             "USB stick (E:)" -> "USB stick": the drive menu
//                             shows the letter in its own column
//
// Header-only.
//
//*****************************************************************************

// One UTF-16 unit is at most 3 bytes of UTF-8 (a surrogate pair: 2 units, 4
// bytes). SHFILEINFOW::szDisplayName and the label buffer of
// GetVolumeInformationW hold at most MAX_PATH units with the terminator.
#define SAL_DRIVE_TEXT_U8_MAX (3 * MAX_PATH + 1)
// SHFILEINFOW::szTypeName holds at most 80 units with the terminator.
#define SAL_FOLDER_TYPE_U8_MAX (3 * 80 + 1)

// Cuts a drive's display name at its last '(' together with the spaces before
// it - the rule GetDisplayNameFromSystem has always applied to the code-page
// text, now on the wide text (unchanged: a name without '(' stays as it is, a
// '(' at the start leaves an empty name). NULL is ignored.
inline void SalDriveNameTrimLetterSuffixW(WCHAR* name)
{
    if (name == NULL)
        return;
    WCHAR* s = wcsrchr(name, L'(');
    if (s != NULL)
    {
        while (s > name && *(s - 1) == L' ')
            s--;
        *s = 0;
    }
}
