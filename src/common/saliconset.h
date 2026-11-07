// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// The toolbar icon sets (feature 416)
//
// Two sets draw the toolbar, menu, drive-bar and file-list icons: "Fluent 2"
// (the default, built on Microsoft Fluent UI System Icons, MIT) and "Classic"
// (the look of 0.2.0 and earlier). The configuration stores the choice as the
// value "Toolbar Icon Set"; a missing or unknown value means Fluent 2, also
// after an upgrade (the maintainer's decision, backlog item
// fluent-icon-set-with-switch-in-appearance).
//
// Files (contract: specs/416-fluent-icon-set/contracts/icon-set-files.md):
//   Fluent 2  iconsets\fluent\<Name>.svg,  iconsets\fluent\dark\<Name>.svg
//   Classic   toolbars\<Name>.svg,         toolbars\dark\<Name>.svg
// beside the program. A dark variant is read only in the Dark theme and used
// verbatim when it parses into at least one shape; otherwise the standard file
// with the automatic dark adaptation (feature 029); otherwise nothing is drawn
// and the cell keeps what lies below it - never an empty button (029's promise).
//
// Pure rules here (saltests TestIconSet416); the drawing is in svg.cpp,
// toolbar4.cpp and salamdr1.cpp.
//

#define SAL_ICONSET_FLUENT 0  // the default
#define SAL_ICONSET_CLASSIC 1 // the look of 0.2.0
#define SAL_ICONSET_COUNT 2

// The set from the stored value: 'read' = the value exists as a DWORD and was read.
inline int SalIconSetFromStored(bool read, unsigned long value)
{
    return (read && value == SAL_ICONSET_CLASSIC) ? SAL_ICONSET_CLASSIC : SAL_ICONSET_FLUENT;
}

// Any int (a corrupted configuration in memory) mapped onto a valid set.
inline int SalIconSetNormalize(int set)
{
    return set == SAL_ICONSET_CLASSIC ? SAL_ICONSET_CLASSIC : SAL_ICONSET_FLUENT;
}

// The set's folder relative to the program's folder, with a trailing backslash.
inline const char* SalIconSetFolder(int set, bool dark)
{
    if (SalIconSetNormalize(set) == SAL_ICONSET_CLASSIC)
        return dark ? "toolbars\\dark\\" : "toolbars\\";
    return dark ? "iconsets\\fluent\\dark\\" : "iconsets\\fluent\\";
}

// A file name of the set: non-empty, no folder part, no drive, no wildcard.
inline bool SalIconSetNameValid(const char* name)
{
    if (name == 0 || *name == 0)
        return false;
    for (const char* s = name; *s != 0; s++)
        if (*s == '\\' || *s == '/' || *s == ':' || *s == '*' || *s == '?' || *s == '"' || *s == '<' || *s == '>' || *s == '|')
            return false;
    return !(name[0] == '.' && (name[1] == 0 || (name[1] == '.' && name[2] == 0)));
}

// <dir><folder of the set><name>.svg into buf (size bytes). 'dir' is the program's folder
// (UTF-8, a trailing backslash is added when missing). Returns false and leaves buf empty
// when the name is not valid or the path does not fit - a path is never cut (CLAUDE.md).
inline bool SalIconSetBuildPath(char* buf, size_t size, const char* dir, int set, bool dark, const char* name)
{
    if (buf == 0 || size == 0)
        return false;
    buf[0] = 0;
    if (dir == 0 || *dir == 0 || !SalIconSetNameValid(name))
        return false;
    const char* parts[5];
    int n = 0;
    parts[n++] = dir;
    size_t dirLen = 0;
    while (dir[dirLen] != 0)
        dirLen++;
    if (dir[dirLen - 1] != '\\' && dir[dirLen - 1] != '/')
        parts[n++] = "\\";
    parts[n++] = SalIconSetFolder(set, dark);
    parts[n++] = name;
    parts[n++] = ".svg";
    size_t len = 0;
    for (int i = 0; i < n; i++)
        for (const char* s = parts[i]; *s != 0; s++)
        {
            if (len + 1 >= size)
            {
                buf[0] = 0;
                return false;
            }
            buf[len++] = *s;
        }
    buf[len] = 0;
    return true;
}

// The Fluent 2 name of toolbar button 'tbbe' (the TBBE_* index of ToolBarButtons[] in
// toolbar4.cpp - append-only, so the numbers are stable) whose Classic name is
// 'classicName'; NULL = no image. Fluent 2 differs from the Classic table in:
//   - Zoom Panel (73) has no image; the 0.2.0 table carries "SharedDirectories" on that row
//     and nothing on Shared Directories (74) - fixed here, kept in Classic (pixel-identical);
//   - the Change Drive slots (36, 51) get a default image (the live drive icon covers it);
//   - the 9 system-folder buttons, which Classic draws with Windows shell icons.
inline const char* SalIconSetFluentButtonName(int tbbe, const char* classicName)
{
    switch (tbbe)
    {
    case 36: // TBBE_CHANGE_DRIVE_L
    case 51: // TBBE_CHANGE_DRIVE_R
        return "ChangeDrive";
    case 43: return "OpenActiveFolder"; // TBBE_OPEN_ACTIVE
    case 44: return "OpenDesktop";      // TBBE_OPEN_DESKTOP
    case 45: return "OpenComputer";     // TBBE_OPEN_MYCOMP
    case 46: return "OpenControlPanel"; // TBBE_OPEN_CONTROL
    case 47: return "OpenPrinters";     // TBBE_OPEN_PRINTERS
    case 48: return "OpenNetwork";      // TBBE_OPEN_NETWORK
    case 49: return "OpenRecycleBin";   // TBBE_OPEN_RECYCLE
    case 50: return "OpenFonts";        // TBBE_OPEN_FONTS
    case 97: return "OpenDocuments";    // TBBE_OPEN_MYDOC
    case 73: return 0;                  // TBBE_ZOOM_PANEL: no image
    case 74: return "SharedDirectories"; // TBBE_SHARES
    }
    return classicName;
}

// The Fluent 2 drive icon for a drive type (the DRIVE_* values of GetDriveType:
// 2 removable, 3 fixed, 4 remote, 5 CD-ROM, 6 RAM disk); 'systemDrive' = the fixed drive
// holding Windows. Anything else (unknown, no root) draws as a fixed drive, as Classic does.
inline const char* SalIconSetFluentDriveName(unsigned int driveType, bool accessible, bool systemDrive)
{
    switch (driveType)
    {
    case 2: return "DriveRemovable";
    case 4: return accessible ? "DriveNetwork" : "DriveNetworkDisconnected";
    case 5: return "DriveCD";
    case 6: return "DriveRam";
    case 3: return systemDrive ? "DriveSystem" : "DriveFixed";
    }
    return "DriveFixed";
}

#define SAL_ICONSET_NAME_UPDIR "UpDir"             // the ".." symbol of the file list
#define SAL_ICONSET_NAME_DOCUMENTS "OpenDocuments" // Documents on the drive bar / Change Drive menu
#define SAL_ICONSET_NAME_NETWORK "OpenNetwork"     // Network on the drive bar / Change Drive menu

// Which file draws an icon: the dark variant (Dark theme, parsed with shapes) verbatim, else
// the standard file (adapted in Dark), else nothing (the cell keeps what lies below it).
#define SAL_ICONSRC_NONE 0
#define SAL_ICONSRC_DARK 1
#define SAL_ICONSRC_STANDARD 2
inline int SalIconSetChooseSource(bool darkActive, bool darkUsable, bool standardUsable)
{
    if (darkActive && darkUsable)
        return SAL_ICONSRC_DARK;
    return standardUsable ? SAL_ICONSRC_STANDARD : SAL_ICONSRC_NONE;
}

// The 10 buttons of the preview strips on the Appearance page (TBBE_* indexes): Back,
// Parent Directory, Create Directory, Find, Views, Refresh, Copy, Delete, Select, Pack.
#define SAL_ICONSET_PREVIEW_COUNT 10
inline int SalIconSetPreviewButton(int i)
{
    static const int buttons[SAL_ICONSET_PREVIEW_COUNT] = {14, 11, 2, 3, 4, 16, 21, 23, 37, 41};
    return (i >= 0 && i < SAL_ICONSET_PREVIEW_COUNT) ? buttons[i] : -1;
}
