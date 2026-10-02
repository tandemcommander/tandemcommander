// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salplugver.h
//
// What the core gives a plug-in depending on the interface version the
// plug-in was built for - the pure rules (feature 088). Header-only, no
// globals, testable in saltests.
//
// Contract: specs/088-plugin-interface-107/contracts/plugin-api-v107.md
//
//*****************************************************************************

// interface version from which GetNextFileNameForViewer /
// GetPreviousFileNameForViewer are documented with a SAL_MAX_PATH_UTF8 buffer;
// the headers of 104-106 said "at least MAX_PATH"
#define SAL_PLUGINVER_LONG_VIEWER_NAMES 107

// B3: may a full file name of 'nameLen' bytes (without the terminator) be
// written into the buffer of a plug-in built for 'builtForVersion'? A plug-in
// built for an older interface was promised MAX_PATH bytes, so only a name
// that fits them with its terminator; an unknown version (<= 0) is treated
// as old.
inline BOOL SalViewerNameFitsPlugin(int builtForVersion, size_t nameLen)
{
    return builtForVersion >= SAL_PLUGINVER_LONG_VIEWER_NAMES || nameLen < MAX_PATH;
}

// feature 097: interface version from which spl_arc.h documents the archive
// file name handed to an archiver plug-in as "up to SAL_MAX_PATH_UTF8 - 1
// bytes"; a plug-in built for an older interface may hold it in MAX_PATH bytes
#define SAL_PLUGINVER_LONG_ARCHIVE_NAMES 107

// 'builtForVersion' value for an archive handled by an external archiver (a
// console program that gets the name on its command line): never a long name
#define SAL_ARCHIVE_HANDLER_EXTERNAL (-1000)

// May the full name of an archive file, 'nameLen' bytes long (without the
// terminator), be handed to its handler? 'builtForVersion' is the interface
// version of the plug-in that handles the archive, or
// SAL_ARCHIVE_HANDLER_EXTERNAL. A name under MAX_PATH bytes always fits; a
// longer one only a plug-in built for interface 107 or later, and only while
// it fits the program's own path buffers (SAL_MAX_PATH_UTF8 bytes with the
// terminator). An unknown version (<= 0) is treated as old.
inline BOOL SalArchiveNameFitsHandler(int builtForVersion, size_t nameLen)
{
    if (nameLen < MAX_PATH)
        return TRUE;
    return builtForVersion >= SAL_PLUGINVER_LONG_ARCHIVE_NAMES && nameLen < (size_t)(3 * 32767 + 1);
}
