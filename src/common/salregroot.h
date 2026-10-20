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
// SalRegKeyIsParentOfRoot - the program's own export (CKey::Dump) writes a
// line for every key above the root too ("[HKEY_CURRENT_USER\Software]",
// "[HKEY_CURRENT_USER\Software\Tandem Commander]"), without values. Such a
// line names a strict parent of the root: 'root' starts with 'name' followed
// by '\' (same comparison as above). The importer accepts it but creates
// nothing for it, and a value under it refuses the file.
//
// Header-only; needs <windows.h>; checked by saltests (contract
// specs/263-import-foreign-reg-keys/contracts/import-root-rule.md).
//

// TRUE when 'text' starts with 'prefix' (ASCII case-insensitive); '*rest' = the rest of 'text'
inline BOOL SalRegRootStartsWithCI(const char* text, const char* prefix, const char** rest)
{
    while (*prefix != 0)
    {
        char a = *text;
        char b = *prefix;
        if (a >= 'A' && a <= 'Z')
            a = (char)(a + ('a' - 'A'));
        if (b >= 'A' && b <= 'Z')
            b = (char)(b + ('a' - 'A'));
        if (a == 0 || a != b)
            return FALSE;
        text++;
        prefix++;
    }
    *rest = text;
    return TRUE;
}

inline BOOL SalRegKeyIsInsideRoot(const char* name, const char* root)
{
    if (name == NULL || root == NULL || *root == 0 || *name == 0)
        return FALSE;
    const char* n;
    if (!SalRegRootStartsWithCI(name, root, &n))
        return FALSE;
    return *n == 0 || *n == '\\';
}

inline BOOL SalRegKeyIsParentOfRoot(const char* name, const char* root)
{
    if (name == NULL || root == NULL || *root == 0 || *name == 0)
        return FALSE;
    const char* r;
    if (!SalRegRootStartsWithCI(root, name, &r))
        return FALSE;
    return *r == '\\';
}
