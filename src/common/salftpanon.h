// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salftpanon.h
//
// The e-mail address the FTP plug-in sends as the password of an anonymous
// login when the user never set one (feature 090, privacy defect F9 of
// feature 083). Anonymous FTP servers conventionally ask for an e-mail address
// there, so something is sent; until this feature it was
// "name@someserver.com" - an address at an ordinary registrable domain, i.e. a
// third party's. The placeholder now uses example.com, which RFC 2606 reserves
// for documentation and which can never be anybody's mailbox.
//
// Header-only and pure (no globals): the FTP plug-in cannot be linked into
// saltests, this rule can.
//
//*****************************************************************************

#include <stddef.h> // NULL

#define SAL_FTP_ANONYMOUS_DEFAULT "anonymous@example.com"
// the placeholder of every version up to 0.1.8; kept only to recognise it in a stored configuration
#define SAL_FTP_ANONYMOUS_OLD_DEFAULT "name@someserver.com"

// What a value read from the stored configuration becomes: the old placeholder
// (compared without case - nobody typed that as their own address) turns into
// the new one; every other value, including an empty one, is the user's and is
// returned unchanged. Never returns NULL ('stored' NULL counts as "not stored").
inline const char* SalFtpAnonymousOnLoad(const char* stored)
{
    if (stored == NULL)
        return SAL_FTP_ANONYMOUS_DEFAULT;
    const char* a = stored;
    const char* b = SAL_FTP_ANONYMOUS_OLD_DEFAULT;
    while (*a != 0 && *b != 0)
    {
        char ca = (*a >= 'A' && *a <= 'Z') ? (char)(*a - 'A' + 'a') : *a;
        if (ca != *b) // the old placeholder is all lower case
            return stored;
        a++;
        b++;
    }
    return (*a == 0 && *b == 0) ? SAL_FTP_ANONYMOUS_DEFAULT : stored;
}
