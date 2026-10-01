// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salarcmig.h
//
// Archiver configuration migration to configuration version 106 - the pure
// decisions (feature 084-archiver-cleanup, contract
// specs/084-archiver-cleanup/contracts/config-migration-106.md).
//
// 0.1.8 knew twelve external archivers; 084 keeps 7-Zip (archiver index 0, new)
// and RAR (index 1, unchanged). Stored entries that refer to a removed archiver
// - through its "$(...Executable)" variable - are removed whether or not the
// user edited them (clarification Q4); entries calling a program by their own
// path are kept untouched. The functions here decide; src/packers.cpp applies
// the decisions to the loaded configuration. All strings are UTF-8.
//

// archiver indices after 084 (== PACK7ZIPINDEX, PACKRARINDEX in src/pack.h)
#define SALARCMIG_7ZIP 0
#define SALARCMIG_RAR 1

// TRUE when 'text' contains "$(<v>)" for one of the twelve variables of the
// removed archivers (case-insensitive, like the variable expansion itself)
BOOL SalArcMigUsesRemovedVariable(const char* text);

// TRUE when 'args' is exactly one of the former floppy-volume ("1.44MB
// volumes") default argument strings
BOOL SalArcMigIsFloppyArgs(const char* args);

enum ESalArcMigEntry
{
    sameKeep,       // leave the entry exactly as it is
    sameDelete,     // remove it
    sameRarDefault, // the untouched 0.1.8 default RAR packer: becomes the new default
};

// a custom packer (external entries only; a plug-in entry is always kept)
ESalArcMigEntry SalArcMigPacker(BOOL external, const char* execCopy, const char* argsCopy,
                                const char* execMove, const char* argsMove);

// a custom unpacker (external entries only); the untouched 0.1.8 default RAR
// unpacker is removed too - RAR is unpacked by the 7zip plug-in
ESalArcMigEntry SalArcMigUnpacker(BOOL external, const char* execExtract, const char* argsExtract);

// an "Archive Association" record: TRUE = keep it (with the new values in
// *newUnpacker, *newPacker, *newUsePacker), FALSE = delete it. Plug-in indices
// (< 0) are kept; old external index 1 (RAR) stays 1; every other old external
// index is a removed archiver - as the unpacker it deletes the record, as the
// packer it only switches packing off.
BOOL SalArcMigAssociation(int oldUnpacker, int oldPacker, BOOL oldUsePacker,
                          int* newUnpacker, int* newPacker, BOOL* newUsePacker);

// TRUE when the ';'-separated extension list 'list' contains 'ext' (as a whole
// item, case-insensitive ASCII; '#' items match literally)
BOOL SalArcMigListHasExt(const char* list, const char* ext);
