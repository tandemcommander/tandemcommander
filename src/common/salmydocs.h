// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salmydocs.h (feature 386)
//
// GetMyDocumentsOrDesktopPath (shellib.cpp) read the Documents folder into a
// 520-byte buffer and copied it into the caller's buffer with lstrcpyn - a
// Documents folder whose UTF-8 path needs more than the caller's 260 bytes
// (fewer than 260 UTF-16 units, e.g. 90 CJK letters) was cut at a whole
// character and the Documents drive opened the folder named like the prefix.
// The choice is made here now: the whole path or refused.
//
//   SalDocumentsOrDesktopToU8   the Documents (else the Desktop) folder ->
//                               UTF-8 (WTF-8), whole or refused
//
// Header-only; needs SalWToU8 (salunicode.h).
//
//*****************************************************************************

enum
{
    SAL_DOCS_NONE = 0,     // neither folder has a file-system path
    SAL_DOCS_OK = 1,       // 'path' holds the whole chosen path
    SAL_DOCS_TOO_LONG = 2, // the chosen path does not fit 'pathSize' bytes
};

// 'docsW' / 'desktopW': the folders as the shell reports them, NULL or "" = no
// file-system path. Documents is chosen when it has a path, the Desktop only
// when Documents has none - a Documents path that does not fit is refused, not
// replaced by the Desktop (another folder than the one asked for). The UTF-8
// size is measured before anything is written: SAL_DOCS_OK only when the whole
// path fits 'pathSize' bytes with the terminator. 'path' is emptied whenever the
// result is not SAL_DOCS_OK (and pathSize > 0) - never a prefix.
inline int SalDocumentsOrDesktopToU8(const WCHAR* docsW, const WCHAR* desktopW, char* path, int pathSize)
{
    if (path != NULL && pathSize > 0)
        path[0] = 0;
    const WCHAR* chosen = docsW != NULL && docsW[0] != 0 ? docsW : desktopW;
    if (chosen == NULL || chosen[0] == 0)
        return SAL_DOCS_NONE;
    if (path == NULL || pathSize <= 0)
        return SAL_DOCS_TOO_LONG;
    int need = SalWToU8(chosen, -1, NULL, 0); // bytes with the terminator, WTF-8 for a lone surrogate
    if (need <= 0 || need > pathSize || SalWToU8(chosen, -1, path, pathSize) != need)
    {
        path[0] = 0;
        return SAL_DOCS_TOO_LONG;
    }
    return SAL_DOCS_OK;
}
