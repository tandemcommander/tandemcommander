// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// The start-up import of a configuration file: pure rule (feature 263)
//
// SalRegKeyIsInsideRoot - the import of config.reg (installation folder,
// %APPDATA%\Tandem Commander, -C) wrote and deleted every key the file named,
// also keys of other programs and HKEY_CLASSES_ROOT. Now every key line and
// every delete line must name the program's own root or a key below it.
// 'name' is the key name after the root key of the line ("Software\X" of
// "[HKEY_CURRENT_USER\Software\X]"), 'root' the allowed root
// ("Software\Tandem Commander\0.1"). Inside = equal to 'root' or 'root'
// followed by '\'; compared ASCII case-insensitively as the registry does
// (the root is ASCII); other bytes compare exactly, so a name the registry
// might fold onto the root through a non-ASCII letter is outside (fail
// closed). An empty or NULL name or root is outside.
//
// Header-only; needs <windows.h>; checked by saltests (contract
// specs/263-import-foreign-reg-keys/contracts/import-root-rule.md).
//

inline BOOL SalRegKeyIsInsideRoot(const char* name, const char* root)
{
    if (name == NULL || root == NULL || *root == 0 || *name == 0)
        return FALSE;
    const char* n = name;
    const char* r = root;
    while (*r != 0)
    {
        char a = *n;
        char b = *r;
        if (a >= 'A' && a <= 'Z')
            a = (char)(a + ('a' - 'A'));
        if (b >= 'A' && b <= 'Z')
            b = (char)(b + ('a' - 'A'));
        if (a == 0 || a != b)
            return FALSE;
        n++;
        r++;
    }
    return *n == 0 || *n == '\\';
}
