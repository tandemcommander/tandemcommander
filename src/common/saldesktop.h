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

// 'attrs' = GetFileAttributes of the Desktop path. Only an existing directory is opened: a missing
// folder (or a file of that name) gives a message - the ordinary change of a disk path would otherwise
// "shorten" the path and show its parent, another folder than the one asked for.
inline bool SalDesktopFolderUsable(unsigned long attrs)
{
    return attrs != SAL_DESKTOP_INVALID_ATTRS && (attrs & SAL_DESKTOP_ATTR_DIRECTORY) != 0;
}

// A shell item entered inside fld: opens as a disk path only when it is a folder of the shell
// (SFGAO_FOLDER), lives in the file system (SFGAO_FILESYSTEM), the shell gave its file-system path
// ('havePath') and that path is an existing directory ('pathAttrs' = GetFileAttributes of it).
// Everything else stays in fld:, as before: virtual places (This PC, Control Panel, Recycle Bin,
// Network - no SFGAO_FILESYSTEM or no path), and shell folders whose path is a file (a zip archive,
// a .lnk to a folder).
inline bool SalShellFolderOpensAsDisk(bool isFolder, bool isFileSystem, bool havePath, unsigned long pathAttrs)
{
    return isFolder && isFileSystem && havePath && SalDesktopFolderUsable(pathAttrs);
}
