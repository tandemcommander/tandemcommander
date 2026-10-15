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
// Header-only; needs <windows.h>; checked by saltests.
//
//*****************************************************************************

inline DWORD SalShortNameClashError(DWORD stepErr)
{
    if (stepErr == ERROR_SUCCESS || stepErr == ERROR_FILE_EXISTS || stepErr == ERROR_ALREADY_EXISTS)
        return ERROR_ACCESS_DENIED;
    return stepErr;
}
