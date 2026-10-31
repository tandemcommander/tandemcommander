// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salrenamekey.h
//
// The key of the in-place rename (feature 346): Shift+F6 opens the Quick Rename
// edit over the focused item's name, as in Total Commander (F2 keeps the Rename
// dialog). The panel recognises the key after the plug-in hot keys; IsSalHotKey
// reserves the key for new bindings and IsSalHotKeyKeptAtLoad keeps a stored one
// (not erased - it never ran from the key, CPlugins::QueryHotKey looks F6 up as U).
// Header-only, no globals; saltests checks it.
//
//*****************************************************************************

#include <windows.h>
#include <commctrl.h>

// TRUE for the key that opens the in-place rename: F6 with Shift only
inline BOOL SalIsRenameInPlaceKey(WPARAM vk, BOOL ctrl, BOOL shift, BOOL alt)
{
    return vk == VK_F6 && shift && !ctrl && !alt;
}

// the same key in the hot-key form of the plug-in menu items (LOBYTE virtual key,
// HIBYTE HOTKEYF_* modifiers; HOTKEYF_EXT does not matter)
inline BOOL SalIsRenameInPlaceHotKey(WORD hotKey)
{
    BYTE mods = (BYTE)(HIBYTE(hotKey) & (HOTKEYF_CONTROL | HOTKEYF_SHIFT | HOTKEYF_ALT));
    return LOBYTE(hotKey) == VK_F6 && mods == HOTKEYF_SHIFT;
}
