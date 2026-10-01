// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

// Archiver configuration migration to version 106 - the pure decisions
// (feature 084), see salarcmig.h. The data below is frozen from tag v0.1.8
// (src/packers.cpp, src/pack3.cpp; specs/084-archiver-cleanup/fix-log.md T007).

#include "precomp.h"

#include <windows.h>

#include "salarcmig.h"

namespace
{

// the variables of the ten archivers removed in feature 084 (two of them had a
// second variable: PKZIP 2.04g its PKUNZIP, and there were DOS and Win32 RAR)
const char* const RemovedVariables[] = {
    "Jar32bitExecutable", "Jar16bitExecutable", "Rar16bitExecutable", "Arj32bitExecutable",
    "Arj16bitExecutable", "Ace32bitExecutable", "Ace16bitExecutable", "Lha16bitExecutable",
    "UC216bitExecutable", "Zip32bitExecutable", "Zip16bitExecutable", "Unzip16bitExecutable",
};

// every "1.44MB volumes" argument string of the 0.1.8 default custom packers;
// the RAR ones use the kept $(Rar32bitExecutable), so the variable rule alone
// would not remove them; the "-scol"-less RAR pair is what configurations older
// than the RAR 5 conversion still had
const char* const FloppyArgs[] = {
    "a -v1440 \"$(ArchiveFullName)\" !\"$(ListFullName)\"",
    "m -v1440 \"$(ArchiveFullName)\" !\"$(ListFullName)\"",
    "a -scol -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
    "m -scol -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
    "a -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
    "m -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
    "a -pav1440 $(ArchiveDOSFullName) !$(ListDOSFullName)",
    "m -pav1440 $(ArchiveDOSFullName) !$(ListDOSFullName)",
    "a -v1440 $(ArchiveDOSFullName) !$(ListDOSFullName)",
    "m -v1440 $(ArchiveDOSFullName) !$(ListDOSFullName)",
    "a -v1440 $(ArchiveDOSFullName) @$(ListDOSFullName)",
    "m -v1440 $(ArchiveDOSFullName) @$(ListDOSFullName)",
    "a -pav1440 \"$(ArchiveFullName)\" !\"$(ListFullName)\"",
    "m -pav1440 \"$(ArchiveFullName)\" !\"$(ListFullName)\"",
};

// the 0.1.8 default RAR packer and unpacker (and their pre-RAR-5 form)
const char* const RarVariable = "$(Rar32bitExecutable)";
const char* const RarDefaultCopy[] = {
    "a -scol \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
    "a \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
};
const char* const RarDefaultMove[] = {
    "m -scol \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
    "m \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
};
const char* const RarDefaultExtract[] = {
    "x -scol \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
    "x \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
};

char Lower(char c)
{
    return c >= 'A' && c <= 'Z' ? (char)(c - 'A' + 'a') : c;
}

// case-insensitive (ASCII) equality of a[0..len) and the terminated b
BOOL EqualsNoCase(const char* a, int len, const char* b)
{
    int i;
    for (i = 0; i < len; i++)
    {
        if (b[i] == 0 || Lower(a[i]) != Lower(b[i]))
            return FALSE;
    }
    return b[len] == 0;
}

BOOL EqualsNoCase(const char* a, const char* b)
{
    return a != NULL && b != NULL && EqualsNoCase(a, lstrlenA(a), b);
}

BOOL InList(const char* text, const char* const* list, int count)
{
    if (text == NULL)
        return FALSE;
    int i;
    for (i = 0; i < count; i++)
    {
        if (lstrcmpA(text, list[i]) == 0)
            return TRUE;
    }
    return FALSE;
}

} // namespace

BOOL SalArcMigUsesRemovedVariable(const char* text)
{
    if (text == NULL)
        return FALSE;
    const char* s;
    for (s = text; *s != 0; s++)
    {
        if (s[0] != '$' || s[1] != '(')
            continue;
        const char* name = s + 2;
        const char* end = name;
        while (*end != 0 && *end != ')')
            end++;
        if (*end != ')')
            return FALSE; // unterminated - nothing more to find
        int len = (int)(end - name);
        int i;
        for (i = 0; i < _countof(RemovedVariables); i++)
        {
            if (EqualsNoCase(name, len, RemovedVariables[i]))
                return TRUE;
        }
        s = end;
    }
    return FALSE;
}

BOOL SalArcMigIsFloppyArgs(const char* args)
{
    return InList(args, FloppyArgs, _countof(FloppyArgs));
}

ESalArcMigEntry SalArcMigPacker(BOOL external, const char* execCopy, const char* argsCopy,
                                const char* execMove, const char* argsMove)
{
    if (!external)
        return sameKeep;
    if (SalArcMigUsesRemovedVariable(execCopy) || SalArcMigUsesRemovedVariable(argsCopy) ||
        SalArcMigUsesRemovedVariable(execMove) || SalArcMigUsesRemovedVariable(argsMove) ||
        SalArcMigIsFloppyArgs(argsCopy) || SalArcMigIsFloppyArgs(argsMove))
    {
        return sameDelete;
    }
    // the untouched default RAR packer of 0.1.8: copy and move commands both as shipped
    int i;
    for (i = 0; i < _countof(RarDefaultCopy); i++)
    {
        if (EqualsNoCase(execCopy, RarVariable) && EqualsNoCase(execMove, RarVariable) &&
            argsCopy != NULL && lstrcmpA(argsCopy, RarDefaultCopy[i]) == 0 &&
            argsMove != NULL && lstrcmpA(argsMove, RarDefaultMove[i]) == 0)
        {
            return sameRarDefault;
        }
    }
    return sameKeep;
}

ESalArcMigEntry SalArcMigUnpacker(BOOL external, const char* execExtract, const char* argsExtract)
{
    if (!external)
        return sameKeep;
    if (SalArcMigUsesRemovedVariable(execExtract) || SalArcMigUsesRemovedVariable(argsExtract))
        return sameDelete;
    if (EqualsNoCase(execExtract, RarVariable) &&
        InList(argsExtract, RarDefaultExtract, _countof(RarDefaultExtract)))
    {
        return sameDelete; // the default RAR unpacker - RAR is unpacked by the 7zip plug-in now
    }
    return sameKeep;
}

BOOL SalArcMigAssociation(int oldUnpacker, int oldPacker, BOOL oldUsePacker,
                          int* newUnpacker, int* newPacker, BOOL* newUsePacker)
{
    // the unpacker: a plug-in stays, RAR stays index 1, anything else was removed
    if (oldUnpacker >= 0 && oldUnpacker != SALARCMIG_RAR)
        return FALSE;
    *newUnpacker = oldUnpacker;
    *newPacker = oldPacker;
    *newUsePacker = oldUsePacker;
    if (oldUsePacker && oldPacker >= 0 && oldPacker != SALARCMIG_RAR)
    {
        *newUsePacker = FALSE; // the packer was a removed archiver - packing is off
        *newPacker = -1;
    }
    return TRUE;
}

BOOL SalArcMigListHasExt(const char* list, const char* ext)
{
    if (list == NULL || ext == NULL || ext[0] == 0)
        return FALSE;
    const char* s = list;
    while (*s != 0)
    {
        const char* e = s;
        while (*e != 0 && *e != ';')
            e++;
        if (EqualsNoCase(s, (int)(e - s), ext))
            return TRUE;
        s = *e == ';' ? e + 1 : e;
    }
    return FALSE;
}
