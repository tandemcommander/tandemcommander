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
// AutoImportConfig or leftovers).
//
//   NewHasConfig                                        -> scmaUseNew
//   !NewHasConfig && (LegacyHasConfig || LegacyBackup)  -> scmaMigrate
//   otherwise                                           -> scmaFresh
//
// Header-only; checked by saltests (contract
// specs/343-semver-settings-root/contracts/config-root-migration.md).
//

enum CSalCfgMigrateAction
{
    scmaUseNew,  // the new root holds a configuration: use it, copy nothing
    scmaMigrate, // only the old root (or its crash-time backup) holds one: copy it
    scmaFresh,   // no configuration anywhere: a fresh start under the new root
};

struct CSalCfgMigrateState
{
    BOOL NewHasConfig;       // Settings\Configuration exists
    BOOL LegacyHasConfig;    // 0.1\Configuration exists
    BOOL LegacyBackupExists; // 0.1.backup.63A7CD13 exists
};

inline CSalCfgMigrateAction SalCfgMigrateDecide(const CSalCfgMigrateState& s)
{
    if (s.NewHasConfig)
        return scmaUseNew;
    if (s.LegacyHasConfig || s.LegacyBackupExists)
        return scmaMigrate;
    return scmaFresh;
}
