// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salpackvol.h
//
// Feature 119: the volumes a multi-volume pack created, and what a failed or
// cancelled pack may delete.
//
// A multi-volume ZIP pack writes name.z01, name.z02, ... one after another.
// Before 119 a failure at volume n (a refusal, a full disk, Cancel, a read
// error) deleted only volume n - volumes 1..n-1 stayed behind, a set that
// cannot be opened. Now every volume this operation created (CREATE_NEW, or
// CREATE_ALWAYS after the user confirmed overwriting it - its old content is
// gone at that moment) is recorded with the file system's identity read from
// the open handle, and a failure deletes the recorded volumes - each only if
// the name still holds the file this operation created (never another file
// that took the name meanwhile; when that cannot be told - a server without
// file ids - the volume is kept unless its creation time and size still match).
// On removable media the earlier volumes are on other disks and one name exists
// on every disk: only the most recent volume is considered, under the same
// identity rule (the disk in the drive may be another one). Once the archive is
// complete (the last volume renamed) nothing is deleted any more - a Move's
// source clean-up comes after that point, and its failure must never cost the
// archive.
//
// Header-only, no globals: the ZIP plug-in cannot compile a shared .cpp file
// (its sources find precomp.h beside themselves), and saltests checks it.
// Contract: specs/119-packing-leftovers/spec.md.
//
//*****************************************************************************

#include <windows.h>
#include <stdlib.h>
#include <string.h>

#include "salsamefile.h"

// one volume this operation created: its UTF-8 name, its identity read from the handle that
// created it (CSalFileIdentity, salsamefile.h) and - once the volume was closed - its size on disk
struct CSalPackCreatedFile
{
    char* Name;
    CSalFileIdentity Id;
    BOOL SizeKnown;
    ULONGLONG Size;
};

// The volumes created by one pack operation, in creation order. Not copyable.
class CSalPackCreatedFiles
{
public:
    CSalPackCreatedFiles() : Items(NULL), Count(0), Capacity(0) {}
    ~CSalPackCreatedFiles()
    {
        Clear();
        free(Items);
    }

    // FALSE on low memory (nothing recorded); the caller must then not keep the file
    BOOL Add(const char* nameU8, const CSalFileIdentity& id)
    {
        if (nameU8 == NULL)
            return FALSE;
        if (Count == Capacity)
        {
            int cap = Capacity == 0 ? 8 : Capacity * 2;
            CSalPackCreatedFile* n = (CSalPackCreatedFile*)realloc(Items, cap * sizeof(CSalPackCreatedFile));
            if (n == NULL)
                return FALSE;
            Items = n;
            Capacity = cap;
        }
        size_t len = strlen(nameU8);
        char* copy = (char*)malloc(len + 1);
        if (copy == NULL)
            return FALSE;
        memcpy(copy, nameU8, len + 1);
        Items[Count].Name = copy;
        Items[Count].Id = id;
        Items[Count].SizeKnown = FALSE;
        Items[Count].Size = 0;
        Count++;
        return TRUE;
    }

    // the most recent volume was written and closed with 'size' bytes on disk
    void SetLastSize(ULONGLONG size)
    {
        if (Count > 0)
        {
            Items[Count - 1].SizeKnown = TRUE;
            Items[Count - 1].Size = size;
        }
    }

    int GetCount() const { return Count; }
    const char* GetName(int i) const { return Items[i].Name; }
    const CSalFileIdentity& GetId(int i) const { return Items[i].Id; }
    BOOL GetSizeKnown(int i) const { return Items[i].SizeKnown; }
    ULONGLONG GetSize(int i) const { return Items[i].Size; }

    void Clear()
    {
        for (int i = 0; i < Count; i++)
            free(Items[i].Name);
        Count = 0;
    }

private:
    CSalPackCreatedFiles(const CSalPackCreatedFiles&);
    CSalPackCreatedFiles& operator=(const CSalPackCreatedFiles&);

    CSalPackCreatedFile* Items;
    int Count;
    int Capacity;
};

// What a multi-volume pack that ends without a complete archive deletes.
enum
{
    salPackVolDeleteNone,    // the archive is complete (or nothing was created): nothing
    salPackVolDeleteCurrent, // removable media: the most recent volume only, if it is still the one this
                             // operation created and still holds its name (the disk may have been changed)
    salPackVolDeleteAll,     // a fixed disk: every volume this operation created
};

// 'failed': the operation ends with an error or a cancel; 'outputComplete': the archive was
// finished (the last volume written and renamed) - from here on a failure (a Move's source
// clean-up) never deletes the archive; 'removable': the volumes go to removable media, one disk
// after another.
inline int SalPackVolCleanupScope(BOOL failed, BOOL outputComplete, BOOL removable)
{
    if (!failed || outputComplete)
        return salPackVolDeleteNone;
    return removable ? salPackVolDeleteCurrent : salPackVolDeleteAll;
}

// May the recorded volume 'created' (with its size on disk when 'sizeKnown') be deleted now that
// its name holds 'now' (read with linkItself TRUE - DeleteFile deletes a link itself)? Keep it
// whenever unsure. 'nowExists' FALSE: there is nothing to delete. The same id: yes - unless both
// creation times are known and differ. Another id (another file took the name, another disk):
// never. No usable ids on one side (a server without file ids, or the identity could not be read
// when the volume was created): only a file (not a folder, not a link) whose creation time is
// known, equal to the recorded one, and whose size equals the size this operation wrote (when
// known); otherwise kept - another process may have replaced the volume during a long pack
// (code review SF1; the first version deleted by name). Tunnelling can give a file that replaced
// a name within seconds the old creation time - the size is the second witness.
inline BOOL SalPackCreatedMayDelete(const CSalFileIdentity& created, BOOL sizeKnown, ULONGLONG size,
                                    BOOL nowExists, const CSalFileIdentity& now)
{
    if (!nowExists || !created.Valid || !now.Valid)
        return FALSE;
    ULONGLONG ca = ((ULONGLONG)created.CTime.dwHighDateTime << 32) | created.CTime.dwLowDateTime;
    ULONGLONG cb = ((ULONGLONG)now.CTime.dwHighDateTime << 32) | now.CTime.dwLowDateTime;
    int ids = SalFileIdMatch(created, now);
    if (ids == simEqual)
        return ca == 0 || cb == 0 || ca == cb;
    if (ids == simDifferent)
        return FALSE;
    if ((now.Attr & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) != 0)
        return FALSE;
    if (ca == 0 || ca != cb)
        return FALSE;
    return !sizeKnown || now.Size == size;
}

// Multi-volume pack with "WinZip names" on a fixed disk: the volumes are name.z01, name.z02, ...
// and the last one is renamed to the archive's own name at the end - a rename that never
// replaces. When that name already exists (the core asked "Add or Overwrite?" and the answer was
// Add, or the question is switched off) the set used to end with name.z0N and the old file
// silently kept its name. TRUE: refuse before anything is created (the plug-in's existing text
// "Archive of the same file name already exists. The multi-volume archives can be created only
// like a new archive."). Removable media: the rename happens on the last disk, not on the one in
// the drive now - not decided here (the rename's own failure is reported). A self-extractor and
// numbered names (name01.zip, ...) are never renamed.
inline BOOL SalMultiVolFinalNameTaken(BOOL selfExtract, BOOL seqNames, BOOL winZipNames, BOOL removable,
                                      BOOL archiveNameExists)
{
    return !selfExtract && seqNames && winZipNames && !removable && archiveNameExists;
}
