// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salmaskopt.h
//
// Which shortcut a prepared mask of a mask group may take (feature 283).
// Header-only, no globals; saltests checks it. CMaskGroup::PrepareMasks
// (src/masks.cpp) classifies every mask with it.
//
//   SAL_MASKOPT_ALL        "*" or "*.*": every name matches
//   SAL_MASKOPT_EXTENSION  "*.xxx" (no wildcard, no dot after "*."): the group
//                          compares the name's extension with "xxx" byte by
//                          byte through the code-page LowerCase table (StrICmp)
//                          and may file the mask in its extension hash table
//   SAL_MASKOPT_NONE       anything else: AgreeMask - ASCII byte matching for
//                          an ASCII name and mask, otherwise whole letters
//                          (NFC + case per UTF-16 unit)
//
// The code-page table understands ASCII only: on the UTF-8 bytes of an accented
// extension it missed the other case of a letter ("*.čtx" vs "A.ČTX") and
// confused different letters whose bytes fold together ("*.ĥ" matched "x.Ĺ" on
// CP1250 - Convert rewrote that file). So an extension with any byte >= 0x80 is
// no longer a shortcut mask: it goes to AgreeMask like every other accented
// mask. For a mask of ASCII bytes the result is the old classification, byte
// for byte (the "*" / "*.*" test stays lstrcmpA, as it was).
//
// An ASCII shortcut mask can never equal an accented extension: a UTF-8
// sequence holds a continuation byte (0x80-0xBF) and no code page folds one to
// ASCII (saltests, every ANSI code page).
//
//*****************************************************************************

#include <windows.h>

// the values equal MASK_OPTIMIZE_NONE / _ALL / _EXTENSION of src/masks.h (static_assert in masks.cpp)
#define SAL_MASKOPT_NONE 0
#define SAL_MASKOPT_ALL 1
#define SAL_MASKOPT_EXTENSION 2

// 'preparedMask': one mask after PrepareMask (spaces trimmed, "**" -> "*", "*?" -> "?*"),
// NUL-terminated; 'extendedMode': '#' is a wildcard (one digit)
inline int SalMaskOptimizeKind(const char* preparedMask, BOOL extendedMode)
{
    if (lstrcmpA(preparedMask, "*") == 0 || lstrcmpA(preparedMask, "*.*") == 0)
        return SAL_MASKOPT_ALL;
    if (preparedMask[0] != '*' || preparedMask[1] != '.' || preparedMask[2] == 0) // "*.xxxx", at least one byte
        return SAL_MASKOPT_NONE;
    const char* iter = preparedMask + 2;
    while (*iter != 0 && *iter != '*' && *iter != '?' && *iter != '.' && (!extendedMode || *iter != '#'))
    {
        if ((unsigned char)*iter >= 0x80) // not ASCII: whole letters, AgreeMask (feature 283)
            return SAL_MASKOPT_NONE;
        iter++;
    }
    return *iter == 0 ? SAL_MASKOPT_EXTENSION : SAL_MASKOPT_NONE;
}
