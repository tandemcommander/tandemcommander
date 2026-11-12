// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// saldesktop.h (feature 425, GitHub #31)
//
// The drive menu's "Desktop" was the Folders plug-in's virtual fld: view (the
// shell namespace's Desktop), and inside fld: a real folder (Documents, a
// drive) stayed virtual, without the operations of a disk panel. Now the core
// has a Desktop drive item that opens the Desktop folder as a disk path, and
// the plug-in opens a file-system folder as a disk path. The decisions:
//
//   SalDesktopFolderUsable      the Desktop path names an existing directory
//   SalShellFolderOpensAsDisk   a shell item entered in fld: opens as a disk path
//
// (the Desktop path itself is converted whole or refused by SalDesktopPathToU8,
// salmydocs.h). Header-only, no dependency: the core and the Folders plug-in
// include it.
//
//*****************************************************************************

#define SAL_DESKTOP_INVALID_ATTRS 0xFFFFFFFFUL // INVALID_FILE_ATTRIBUTES
#define SAL_DESKTOP_ATTR_DIRECTORY 0x10UL      // FILE_ATTRIBUTE_DIRECTORY

// 'attrs' = GetFileAttributes of a path: true only for an existing directory.
inline bool SalDesktopFolderUsable(unsigned long attrs)
{
    return attrs != SAL_DESKTOP_INVALID_ATTRS && (attrs & SAL_DESKTOP_ATTR_DIRECTORY) != 0;
}

// The Desktop path, already found accessible by the program's check of a path (which reconnects a
// network drive, offers a login for a share and reports a missing path itself - review 1, SHOULD 2),
// names something that is not a folder: a message, never the parent the change of a disk path would
// fall back to. Attributes that cannot be read (access denied) are left to the change of the path.
inline bool SalDesktopPathIsNotFolder(unsigned long attrs)
{
    return attrs != SAL_DESKTOP_INVALID_ATTRS && (attrs & SAL_DESKTOP_ATTR_DIRECTORY) == 0;
}

// ASCII case-insensitive equality of 'n' bytes (the names compared here are ASCII)
inline bool SalDesktopAsciiEqualCI(const char* a, const char* b, int n)
{
    for (int i = 0; i < n; i++)
    {
        char x = a[i], y = b[i];
        if (x >= 'A' && x <= 'Z')
            x = (char)(x - 'A' + 'a');
        if (y >= 'A' && y <= 'Z')
            y = (char)(y - 'A' + 'a');
        if (x != y)
            return false;
    }
    return true;
}

// The path (UTF-8, '\' or '/' separators) has a component that is a recycle bin's storage folder
// ($Recycle.Bin, or RECYCLER / RECYCLED of old Windows versions): deleted items live there under
// internal names ($R..., $I...) - a disk panel's operations on them would break their restore.
inline bool SalPathHasRecycleBinPart(const char* path)
{
    static const char* const names[] = {"$Recycle.Bin", "RECYCLER", "RECYCLED"};
    if (path == 0)
        return false;
    const char* s = path;
    while (*s != 0)
    {
        const char* e = s;
        while (*e != 0 && *e != '\\' && *e != '/')
            e++;
        int len = (int)(e - s);
        for (int i = 0; i < (int)(sizeof(names) / sizeof(names[0])); i++)
        {
            int nlen = 0;
            while (names[i][nlen] != 0)
                nlen++;
            if (len == nlen && SalDesktopAsciiEqualCI(s, names[i], len))
                return true;
        }
        s = *e != 0 ? e + 1 : e;
    }
    return false;
}

// A shell item entered inside fld: opens as a disk path only when it is a folder of the shell
// (SFGAO_FOLDER), lives in the file system (SFGAO_FILESYSTEM), the shell gave its file-system path
// ('havePath') and that path is an existing directory ('pathAttrs' = GetFileAttributes of it), and
// it is not an item of the Recycle Bin ('inRecycleBin' = the current fld: folder is the Recycle Bin or
// inside it, or the path has a recycle bin component - review 1, SHOULD 1: a deleted folder is a
// file-system folder in C:\$Recycle.Bin\<SID>\$R...), and it is not a folder shortcut: an item with
// SFGAO_LINK ('isLink') opens as a disk path only when its directory is a reparse point (a junction or
// a directory symbolic link - review 3: the file system follows them itself); a folder shortcut, e.g. a
// network location of This PC, is a plain directory holding target.lnk and desktop.ini - its path is
// that directory, not the target fld: follows (review 2). Everything else stays in fld:, as before:
// virtual places (This PC, Control Panel, Network - no SFGAO_FILESYSTEM or no path), the Recycle Bin's
// items, folder shortcuts, and shell folders whose path is a file (a zip archive, a .lnk to a folder).
#define SAL_DESKTOP_ATTR_REPARSE_POINT 0x400UL // FILE_ATTRIBUTE_REPARSE_POINT
inline bool SalShellFolderOpensAsDisk(bool isFolder, bool isFileSystem, bool isLink, bool havePath,
                                      unsigned long pathAttrs, bool inRecycleBin)
{
    if (!isFolder || !isFileSystem || !havePath || inRecycleBin || !SalDesktopFolderUsable(pathAttrs))
        return false;
    return !isLink || (pathAttrs & SAL_DESKTOP_ATTR_REPARSE_POINT) != 0;
}
