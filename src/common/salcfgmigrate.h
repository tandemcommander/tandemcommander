// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// The version-free configuration root: pure decision (feature 343)
//
// Up to 0.1.10 the configuration lived under "Software\Tandem Commander\0.1",
// a key named after the version line. Since feature 343 it lives under
// "Software\Tandem Commander\Settings"; at start, before anything reads a
// setting, MigrateConfigurationRoot (mainwnd2.cpp) copies the old tree once
// (raw copy into a side key, compared, then renamed - all or nothing) and
// never writes or deletes the old key.
//
// SalCfgMigrateDecide - what the start does, from what is in the registry.
// A root "has a configuration" when its "Configuration" subkey exists (the
// upstream rule of FindLatestConfiguration: the bare key may hold only
// AutoImportConfig or leftovers). A key that exists but cannot be read
// (access denied, no resources) is "unreadable" - never "absent": a check
// that decides what may be deleted or replaced fails closed (098).
//
//   NewHasConfig || NewUnreadable                       -> scmaUseNew
//   AlreadyMoved                                        -> scmaFresh
//   LegacyUnreadable                                    -> scmaUseLegacy
//   LegacyHasConfig || LegacyBackupExists               -> scmaMigrate
//   otherwise                                           -> scmaFresh
//
// AlreadyMoved: the parent key records that a move has happened. A new root
// missing after that is the user's reset (deleted, or "Remove Configuration"
// on a damaged one) - the old copy is never brought back.
//
// Header-only; checked by saltests (contract
// specs/343-semver-settings-root/contracts/config-root-migration.md).
//

enum CSalCfgMigrateAction
{
    scmaUseNew,    // the new root holds a configuration (or cannot be read): use it, copy and delete nothing
    scmaMigrate,   // only the old root (or its crash-time backup) holds one: copy it
    scmaFresh,     // no configuration to move: a fresh start under the new root
    scmaUseLegacy, // the old root cannot be read: run on it as 0.1.x would, copy and delete nothing
};

struct CSalCfgMigrateState
{
    BOOL NewHasConfig;       // Settings\Configuration exists
    BOOL NewUnreadable;      // Settings or Settings\Configuration exists but cannot be opened
    BOOL LegacyHasConfig;    // 0.1\Configuration exists
    BOOL LegacyBackupExists; // 0.1.backup.63A7CD13 exists
    BOOL LegacyUnreadable;   // 0.1, 0.1\Configuration or the backup exists but cannot be opened
    BOOL AlreadyMoved;       // the parent key records a finished move
};

inline CSalCfgMigrateAction SalCfgMigrateDecide(const CSalCfgMigrateState& s)
{
    if (s.NewHasConfig || s.NewUnreadable)
        return scmaUseNew;
    if (s.AlreadyMoved)
        return scmaFresh;
    if (s.LegacyUnreadable)
        return scmaUseLegacy;
    if (s.LegacyHasConfig || s.LegacyBackupExists)
        return scmaMigrate;
    return scmaFresh;
}
