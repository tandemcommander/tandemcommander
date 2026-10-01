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
