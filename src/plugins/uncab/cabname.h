// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// cabname.h (feature 381)
//
// How the UnCAB plug-in reads the stored bytes of a cabinet entry name.
// Header-only, so saltests checks the rule without the plug-in.
//
// A cabinet stores a name either in the local code page or - when the entry's
// attributes carry _A_NAME_IS_UTF - in UTF-8. A Windows file name may hold an
// unpaired UTF-16 surrogate; written as UTF-8 it becomes the 3-byte WTF-8 form,
// which a strict UTF-8 test rejects. Such a name is accepted byte for byte (the
// program's names are WTF-8 since feature 066; like the core, a pair written as
// two 3-byte surrogate sequences is read as that pair - SplIsWtf8); bytes that are
// not even that are refused when flagged, never guessed into another name.
//

#include "../shared/splunicode.h" // SplIsWtf8

// _A_NAME_IS_UTF of the SDK's fdi.h (uncab.cpp asserts they are equal)
#define CABNAME_A_NAME_IS_UTF 0x80

enum CCabNameRead
{
    CABNAME_UTF8,     // the bytes are the UTF-8 (WTF-8) name - take them verbatim
    CABNAME_CODEPAGE, // the bytes are in the local code page - convert
    CABNAME_REFUSE,   // flagged UTF-8 but malformed - refuse the name
};

// 'attribs' = the entry's attributes, or -1 where FDI does not report them
// (fdintPARTIAL_FILE): the encoding is then guessed - valid WTF-8 is taken as
// UTF-8, anything else as the code page
inline CCabNameRead CabNameReadAs(const char* name, int attribs)
{
    BOOL wtf8 = SplIsWtf8(name);
    if (attribs < 0)
        return wtf8 ? CABNAME_UTF8 : CABNAME_CODEPAGE;
    if ((attribs & CABNAME_A_NAME_IS_UTF) == 0)
        return CABNAME_CODEPAGE;
    return wtf8 ? CABNAME_UTF8 : CABNAME_REFUSE;
}
