// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

// stdafx.h : include file for standard system include files,
// or project specific include files that are used frequently, but
// are changed infrequently
//

#pragma once

#ifndef OPENSAL_VERSION // version built for Salamander distribution will not be backward compatible with version 5.0 (unnecessary complication)
#define SALSDK_COMPATIBLE_WITH_VER 103
#define REQUIRE_COMPATIBLE_SAL_VERSION "This plugin requires Tandem Commander 0.1.0 or later."
#endif // OPENSAL_VERSION

//#define TIMINGTEST

#define SALAMANDER
//#define TRACE_ENABLE
#define WM_APP_ICONLOADED (WM_APP + 1)
#define WM_APP_DIRPOPULATED (WM_APP + 2)   //wParam = 0; lParam = CZRoot
#define WM_APP_LOGUPDATED (WM_APP + 3)     //wParam = count; lParam = logger
#define WM_APP_CLOSEABANDONED (WM_APP + 4) // feature 143: Release() gave up the close it asked for
#define DISKMAP_CLOSE_FROM_RELEASE 0x143   // feature 143: wParam of the WM_CLOSE Release() posts

#define WIN32_LEAN_AND_MEAN // exclude rarely-used stuff from Windows headers
// Windows Header Files:
#include <windows.h>
#include <CommDlg.h>
#include <ShellAPI.h>
#include <shlobj.h>
#include <Windowsx.h> // helper macros

// C RunTime Header Files
#include <malloc.h>
#include <tchar.h>

// CRT diagnostics and utility headers
#include <crtdbg.h>
#include <limits.h>
#include <process.h>
#include <commctrl.h>
#include <ostream>
#include <stdio.h>
#include <time.h>

// Salamander headers
#include "versinfo.rh2"

#include "spl_com.h"
//#include "spl_arc.h"
#include "spl_base.h"
#include "spl_gen.h"
//#include "spl_fs.h"
#include "spl_menu.h"
//#include "spl_thum.h"
//#include "spl_view.h"
#include "spl_vers.h"
#include "spl_gui.h"

#include "splunicode.h" // UTF-8 <-> UTF-16 helpers (plugin interface 104)

#include "dbg.h"
#include "auxtools.h"
//#include "mhandles.h"

//#include "DiskMapPlugin.rh"
//#include "arraylt.h"
//#include "winliblt.h"
//#include "dialogs.h"
//#include "demoplug.h"
//#include "demoplug.rh"

// TODO: reference additional headers your program requires here

#ifndef ARRAYSIZE
#define RTL_NUMBER_OF_V1(A) (sizeof(A) / sizeof((A)[0]))
#define RTL_NUMBER_OF_V2(A) RTL_NUMBER_OF_V1(A)
#define ARRAYSIZE(A) RTL_NUMBER_OF_V2(A)
#endif // ARRAYSIZE

#include "../DiskMap/Resources/DiskMap.rh2"
