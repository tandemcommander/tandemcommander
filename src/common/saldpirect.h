// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// saldpirect.h
//
// Maps a rectangle between two coordinate spaces of one monitor (feature 424,
// GitHub #29). The program is system DPI aware; the WebView2 viewer windows
// run per-monitor v2 aware. A rectangle the core computed (system
// coordinates) is moved into the viewer's coordinates through the monitor
// that holds it: 'from' is that monitor's rectangle as a system-aware thread
// sees it, 'to' the same monitor as a per-monitor thread sees it. The point's
// place relative to the monitor is kept, sizes scale by the monitor's ratio.
//
// Header-only, no globals; saltests checks it (TestDpiRect424); the shared
// WebView2 host (src/common/webhost/webhost.cpp) uses it.
//
//*****************************************************************************

#include <windows.h>

// Rounds a * num / den to the nearest integer, halves away from zero; den > 0.
inline long long SalDpiScaleRound(long long a, long long num, long long den)
{
    long long p = a * num;
    return p >= 0 ? (p + den / 2) / den : -((-p + den / 2) / den);
}

// 'r' mapped from monitor rectangle 'from' to monitor rectangle 'to'. When
// either monitor rectangle is empty the mapping is unknown and 'r' is returned
// unchanged (refuse to guess). Equal rectangles give 'r' itself (an unchanged
// display scaling changes nothing).
inline RECT SalDpiMapRect(const RECT& r, const RECT& from, const RECT& to)
{
    long long fw = (long long)from.right - from.left, fh = (long long)from.bottom - from.top;
    long long tw = (long long)to.right - to.left, th = (long long)to.bottom - to.top;
    if (fw <= 0 || fh <= 0 || tw <= 0 || th <= 0)
        return r;
    RECT o;
    o.left = (LONG)(to.left + SalDpiScaleRound((long long)r.left - from.left, tw, fw));
    o.top = (LONG)(to.top + SalDpiScaleRound((long long)r.top - from.top, th, fh));
    // the size is scaled on its own, so a rectangle keeps its size wherever it sits
    o.right = (LONG)(o.left + SalDpiScaleRound((long long)r.right - r.left, tw, fw));
    o.bottom = (LONG)(o.top + SalDpiScaleRound((long long)r.bottom - r.top, th, fh));
    return o;
}
