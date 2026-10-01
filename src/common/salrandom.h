// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salrandom.h
//
// The product's one source of security-relevant random bytes (feature 086).
//
// Salts, encryption headers and verifier data must not be predictable. Until
// 0.1.8 both places that made them - the core's password manager and the ZIP
// plugin - used rand() seeded once with time ^ process id, so every salt was a
// function of a guessable 32-bit seed. Both now call SalGenRandom.
//
// Header-only on purpose: it is included by the core, saltests and the ZIP
// plugin, and the ZIP project cannot compile a shared .cpp from src/common (its
// sources find their precompiled header next to themselves; see
// specs/086-zip-aes-salt/research.md R2). Contract:
// specs/086-zip-aes-salt/contracts/salrandom.md
//
//*****************************************************************************

#include <windows.h>
#include <bcrypt.h>

#pragma comment(lib, "bcrypt.lib")

// Fills 'len' bytes at 'buf' from the operating system's cryptographic random
// generator (BCryptGenRandom, system-preferred RNG). 'len' == 0 -> TRUE, nothing
// written; 'len' < 0, or 'buf' NULL with 'len' > 0 -> FALSE, nothing written.
// FALSE also when the generator fails - the buffer must then not be used as
// random data. Thread-safe, no state.
inline BOOL SalGenRandom(void* buf, int len)
{
    if (len == 0)
        return TRUE;
    if (len < 0 || buf == NULL)
        return FALSE;
    return BCRYPT_SUCCESS(BCryptGenRandom(NULL, (PUCHAR)buf, (ULONG)len, BCRYPT_USE_SYSTEM_PREFERRED_RNG));
}
