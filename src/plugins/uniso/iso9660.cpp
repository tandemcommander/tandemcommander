// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "dbg.h"

#include "uniso.h"
#include "isoimage.h"
#include "iso9660.h"

#include "uniso.rh"
#include "uniso.rh2"
#include "lang\lang.rh"

#include <memory> // feature 328

#define SECTOR_SIZE 0x800

// feature 328: one name buffer of ListDirectoryRe (the size its names always had)
static const int NAME_BUF = 2 * MAX_PATH + 1;

#define FATTR_HIDDEN 1
#define FATTR_DIRECTORY 2

#define ISO_SEPARATOR1 '.'
#define ISO_SEPARATOR2 ';'

#define SWAPDWORD(d) \
    ((((d) & 0x000000FF) << 24) | \
     (((d) & 0x0000FF00) << 8) | \
     (((d) & 0x00FF0000) >> 8) | \
     (((d) & 0xFF000000) >> 24))

// ****************************************************************************
//
// CISO9660
//

CISO9660::CDirectoryRecord::CDirectoryRecord()
{
    ZeroMemory(RecordingDateAndTime, sizeof(RecordingDateAndTime));
}

CISO9660::CISO9660(CISOImage* image, DWORD extent) : CUnISOFSAbstract(image)
{
    Ext = extNone;
    SuspVolume = FALSE;
    SuspSkip = 0;
    FitCheck = FALSE;
    FitRefused = FALSE;
    FitIsoNames = FALSE;
    FitCount = 0;
    FitListed = 0;
    Decide = FALSE;
    Visited = NULL;
    VisitedLog = NULL;
    ExtentOffset = extent;

    BootRecordInfo = NULL;
}

CISO9660::~CISO9660()
{
    delete BootRecordInfo;
}

BOOL CISO9660::Open(BOOL quiet)
{
    CALL_STACK_MESSAGE2("CISO9660::Open(%d)", quiet);

    BOOL ret = TRUE;
    DWORD block = 0x10;
    BYTE sector[SECTOR_SIZE];
    BOOL terminate = FALSE;

    // detecting CD-ROM Volume Descriptor Set
    BOOL isoDescriptors = FALSE;
    // Read the VolumeDescriptor (2k) until we find it, but only up to to 1MB
    while (!terminate)
    {
        // Try to read a block
        if (Image->ReadBlock(block, SECTOR_SIZE, sector) != SECTOR_SIZE)
        {
            // Something went wrong, probably EOF?
            Error(IDS_ERROR_READING_SECTOR, quiet, block);
            ret = FALSE;
            break;
        }

        if (strncmp((char*)(sector + 1), "CD001", 5) == 0)
        {
            switch (sector[0])
            {
            case 0x00:
                ReadBootRecord(sector, quiet);
                break;

            case 0x01: // primary volume descriptor
                memcpy(&PVD, sector, SECTOR_SIZE);
                break;

            case 0x02: // suplementary/enhanced volume descriptor
                memcpy(&SVD, sector, SECTOR_SIZE);

                // Joliet has FileStructureVersion = 1
                if (SVD.FileStructureVersion == 1)
                    Ext = extJoliet;
                // Patera 2009.02.03: The following check seems correct and not the above one...
                // Raptor provided "Pantera Safari.ISO" with corruped FileStructureVersion
                if ((SVD.EscapeSequences[0] == 0x25) && (SVD.EscapeSequences[1] == 0x2F) && ((SVD.EscapeSequences[2] == 0x40) || (SVD.EscapeSequences[2] == 0x43) || (SVD.EscapeSequences[2] == 0x45)))
                    Ext = extJoliet;
                break;

            case 0xff: // terminator
                terminate = TRUE;
                break;
            } // switch
        } // if

        block++;

        if (block > 128)
        {
            // Just to make sure we don't read in a too big file, stop after 128 sectors.
            ret = FALSE;
            break;
        }
    } // while

    if (ret)
    {
        if (Ext == extJoliet)
            FillDirectoryRecord(Root, SVD.DirectoryRecordForRootDirectory);
        else
        {
            FillDirectoryRecord(Root, PVD.DirectoryRecordForRootDirectory);

            // feature 326: a volume that uses SUSP carries the SP entry in the root's first record
            // ('.'); Rock Ridge 1.12 (xorriso) writes no RR entry, so the records are read as Rock
            // Ridge by this. The block ListDirectoryRe reads first; a failed read: no SUSP (the
            // listing reports it)
            DWORD rootBlock = (DWORD)Root.LocationOfExtent - ExtentOffset + Root.ExtendedAttributeRecordLength;
            BYTE rootSector[SECTOR_SIZE];
            BYTE lenSkp = 0;
            if (Root.LocationOfExtent >= ExtentOffset && Root.DataLength > 0 &&
                Image->ReadBlock(rootBlock, SECTOR_SIZE, rootSector) == SECTOR_SIZE &&
                SalSuspRootHasSp(rootSector, min((DWORD)SECTOR_SIZE, Root.DataLength), &lenSkp))
            {
                SuspVolume = TRUE;
                SuspSkip = lenSkp;
            }
        }
    }

    return ret;
}

void CISO9660::FillDirectoryRecord(CDirectoryRecord& dr, BYTE bytes[])
{
#define CpyN(Var, Ofs, N) \
    memcpy(&(dr.##Var), bytes + Ofs, N);

    CpyN(LengthOfDirectoryRecord, 0, 1);
    CpyN(ExtendedAttributeRecordLength, 1, 1);
    CpyN(LocationOfExtent, 2, 4);
    CpyN(LocationOfExtentA, 6, 4);
    CpyN(DataLength, 10, 4);
    CpyN(DataLengthA, 14, 4);
    CpyN(RecordingDateAndTime, 18, 7);
    CpyN(FileFlags, 25, 1);
    CpyN(VolumeSequenceNumber, 28, 2);

    CpyN(LengthOfFileIdentifier, 32, 1);
#undef CpyN
}

void CISO9660::FillPathTableRecord(CPathTableRecord& record, BYTE bytes[])
{
#define CpyN(Var, Ofs, N) \
    memcpy(&(record.##Var), bytes + Ofs, N);

    CpyN(LengthOfDirectoryIdentifier, 0, 1);
    CpyN(ExtendedAttributeRecordLength, 1, 1);
    CpyN(LocationOfExtent, 2, 4);
    CpyN(ParentDirectoryNumber, 6, 2);
#undef CpyN
}

#define ROTATE(a) ((((a) & 0xffff) >> 8) | (((a) & 0xff) << 8))

//
// feature 326: TRUE when the name is the Rock Ridge one (no ISO 9660 version suffix to remove)
BOOL CISO9660::ExtractExtFileName(char* fileName, const char* src, CDirectoryRecord& dr)
{
    // processing extensions
    const char* srcSU = src + dr.LengthOfFileIdentifier;
    // feature 223: the record ends at its start + its length ('src' is its start + 33)
    const char* srcEnd = src + (dr.LengthOfDirectoryRecord - 33);
    int len = dr.LengthOfDirectoryRecord - 34;

    if (dr.LengthOfFileIdentifier % 2 == 0)
    {
        srcSU++;
    }

    // check whether there is any extension in the 'system use area'
    if (srcSU + sizeof(CRRExtHeader) <= srcEnd && (Ext != extJoliet)) // feature 223: a whole header
    {
        EExt ext = extNone;

        CRRExtHeader rrHeader;

        // feature 326: a record whose first entry is RR is Rock Ridge (as before); on a volume whose
        // root carries SP every record is (Rock Ridge 1.12 - xorriso - writes no RR), its entries
        // starting after the SP entry's LEN_SKP
        size_t rrStart = 0;
        if (SalSuspRockRidgeStart((const unsigned char*)srcSU, (size_t)(srcEnd - srcSU), SuspVolume != FALSE,
                                  SuspSkip, &rrStart))
        {
            ext = extRockRidge; // this is a RockRidge entry
            srcSU += rrStart;
        }

        char extFileName[2 * MAX_PATH + 1];
        ZeroMemory(extFileName, sizeof(extFileName));

        switch (ext)
        {
        case extRockRidge:
        {
            BOOL bNM = FALSE;
            BOOL nmContinues = FALSE; // the last NM part said the name goes on
            BOOL broken = FALSE;

            // feature 223: the lengths come from the image - a length under 5 made the copy
            // unbounded (and 0 looped forever), the NM parts were appended past 'extFileName';
            // such an entry ends the parsing and the plain ISO 9660 name is used. A name that goes
            // on in a continuation area (CE - a Rock Ridge name longer than the record holds) is
            // read from there too: it was cut (a file of a 200-letter name extracted under 146)
            const char* area = srcSU;
            const char* areaEnd = srcEnd;
            BYTE ceSector[SECTOR_SIZE];
            for (int hop = 0;; hop++)
            {
                BOOL ce = FALSE;
                DWORD ceBlock = 0, ceOffset = 0, ceLen = 0;
                while (area + sizeof(rrHeader) <= areaEnd)
                {
                    memcpy(&rrHeader, area, sizeof(rrHeader));
                    if (rrHeader.Length < sizeof(rrHeader) || area + rrHeader.Length > areaEnd)
                    {
                        broken = TRUE;
                        break;
                    }

                    if (strncmp((char*)rrHeader.Signature, "ST", 2) == 0)
                        break; // the terminator: what follows is not an entry

                    if (strncmp((char*)rrHeader.Signature, "NM", 2) == 0)
                    {
                        size_t part = rrHeader.Length >= 5 ? (size_t)(rrHeader.Length - 5) : 0;
                        size_t have = strlen(extFileName);
                        if (rrHeader.Length < 5 || have + part >= sizeof(extFileName))
                        {
                            broken = TRUE;
                            break;
                        }
                        bNM = TRUE;
                        nmContinues = (((const BYTE*)area)[4] & 0x01) != 0; // NM flags: CONTINUE
                        memcpy(extFileName + have, area + 5, part);
                        extFileName[have + part] = 0;
                    }
                    else if (strncmp((char*)rrHeader.Signature, "CE", 2) == 0 && rrHeader.Length >= 28)
                    { // the continuation area: block, offset, length (both-endian - the first four bytes)
                        ce = TRUE;
                        memcpy(&ceBlock, area + 4, 4);
                        memcpy(&ceOffset, area + 12, 4);
                        memcpy(&ceLen, area + 20, 4);
                    }

                    area += rrHeader.Length;
                } // while
                if (broken || !ce || hop >= 8 || (bNM && !nmContinues)) // a whole name: no other entry is needed
                    break;
                // the continuation area lies in one sector here (as the image tools write it)
                if (ceOffset >= SECTOR_SIZE || ceLen == 0 || ceLen > SECTOR_SIZE - ceOffset ||
                    ceBlock < ExtentOffset ||
                    Image->ReadBlock(ceBlock - ExtentOffset, SECTOR_SIZE, ceSector) != SECTOR_SIZE)
                {
                    broken = TRUE;
                    break;
                }
                area = (const char*)ceSector + ceOffset;
                areaEnd = area + ceLen;
            }
            if (broken || nmContinues) // never a cut name: the plain ISO 9660 name then
                bNM = FALSE;

            if (bNM)
            {
                strcpy(fileName, extFileName);
                return TRUE;
            }
        }
        break;

        default:
            break;
        } // switch
    }

    if (Ext == extJoliet)
    {
        // feature 322: 'src' is the name ConvJolietName() already made - UTF-8, terminated. A letter
        // of U+0800 and above takes 3 bytes there but 2 in the UCS-2 identifier, so the copy limited
        // to the identifier's length cut names of mostly CJK letters (the extension, part of a
        // letter). The whole name fits 'fileName' (ExtractFileName's 2 * MAX_PATH + 1 bytes): a
        // 255-byte identifier holds at most 127 units, at most 381 UTF-8 bytes.
        lstrcpyn(fileName, src, 2 * MAX_PATH + 1);
        return FALSE;
    }
    lstrcpyn(fileName, src, dr.LengthOfFileIdentifier + 1);
    return FALSE;
}

// the ISO 9660 version suffix of a file name removed: "NAME.EXT;1" -> "NAME.EXT", "NAME.;1" -> "NAME";
// feature 327 (review): also the separator of an image without version numbers ("NAME." -> "NAME") -
// the safe-name rule would turn that dot into '_' (salsusp.h SalIsoRemoveVersion)
static void RemoveIsoVersion(char* name)
{
    SalIsoRemoveVersion(name);
}

//
// Extracts the file name from 'src'
// used for file names in ISO levels 1, 2, and 3
// feature 326: TRUE when it is the Rock Ridge name
//
BOOL CISO9660::ExtractFileName(char* fileName, const char* src, CISO9660::CDirectoryRecord& dr)
{
    char tmpFileName[2 * MAX_PATH + 1];
    ZeroMemory(tmpFileName, sizeof(tmpFileName));

    // feature 326: a Rock Ridge name is the file's whole name - a ';' in it is part of the name, not
    // the ISO 9660 version suffix (a file 'a;b.txt' was listed as 'a')
    BOOL rockRidge = ExtractExtFileName(tmpFileName, src, dr);

    // iso filename
    if (!rockRidge)
        RemoveIsoVersion(tmpFileName);

    strcpy(fileName, tmpFileName);
    return rockRidge;
}

// feature 326: the name as it is listed - made UTF-8 (EnsureU8Name) and, when it is a Rock Ridge
// name, made safe for Windows ("..\x" was written outside the target folder, "12:30.txt" into a
// stream). The cleaning runs on the UTF-8 name (review 2): on the raw bytes of a legacy code page it
// changed letters - a Shift-JIS second byte 0x5C is not a backslash ("\x83\x5C" is one letter). A
// name the cleaning cannot hold: the plain ISO 9660 name of the record ('src', its raw identifier).
// Feature 327: an ISO 9660 identifier or a Joliet name is made safe the same way (MakeSafeName) - an
// image can store "..\x", "12:30.txt", "con.txt" or "x." there just as well
void CISO9660::MakeListedName(char* name, int size, BOOL rockRidge, const char* src, CDirectoryRecord& dr,
                              BOOL file)
{
    EnsureU8Name(name, size);
    if (rockRidge && SalSuspCleanRockRidgeName(name, (size_t)size))
        return;
    if (rockRidge)
    {
        MakeIsoName(name, size, src, dr, file);
        return;
    }
    MakeSafeName(name, size);
}

// feature 328: the ISO 9660 name of a record ('src' = its raw identifier) as it is listed - what
// MakeListedName gives a record without a Rock Ridge name
void CISO9660::MakeIsoName(char* name, int size, const char* src, CDirectoryRecord& dr, BOOL file)
{
    ZeroMemory(name, size);
    lstrcpyn(name, src, min(size, (int)dr.LengthOfFileIdentifier + 1));
    if (file)
        RemoveIsoVersion(name);
    EnsureU8Name(name, size);
    MakeSafeName(name, size);
}

#define READ_SIZE 4096

// format boundary (interface 104): Joliet names are UCS-2 big-endian; byte-swap them
// and emit UTF-8 directly - the interface wants UTF-8, and going through the ANSI code
// page (as this used to) silently destroyed every character outside it.
void CISO9660::ConvJolietName(char* dest, const char* src, int nLen)
{
    char tmp[2 * MAX_PATH];
    ZeroMemory(&tmp, sizeof(tmp));

    if (nLen > (int)sizeof(tmp) - 2)
        nLen = (int)sizeof(tmp) - 2; // a Joliet identifier never gets this long
    memcpy(tmp, src, nLen);

    WCHAR* uname = (WCHAR*)tmp;
    int i;
    for (i = 0; i < (nLen / 2); i++)
        uname[i] = (WORD)ROTATE(uname[i]);
    uname[nLen / 2] = 0;

    char final[2 * MAX_PATH];
    ZeroMemory(&final, sizeof(final));
    if (SplWToU8(uname, final, sizeof(final)) == 0)
    {
        // lone surrogates and the like: fall back to a lossy but valid UTF-8 form
        WideCharToMultiByte(CP_UTF8, 0, uname, -1, final, sizeof(final) - 1, 0, 0);
    }
    final[sizeof(final) - 1] = 0;

    strcpy(dest, final);
}

int CISO9660::AddFileDir(const char* path, char* fileName, CDirectoryRecord& dr,
                         CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData)
{
    // feature 326 (review): the panel listing's own rule (sallistingname.h, CSalamanderDirectory::
    // AddFile / AddDir) - the fit check pass adds nothing, it only asks whether the entry would be
    // taken; feature 328: and counts it - taken, and fitting (SalIsoEntryFits: the core's operations
    // reach it from the image's root); a count walk descends into every folder the listing takes
    size_t pathLen = path != NULL ? strlen(path) : 0;
    size_t nameLen = strlen(fileName);
    BOOL isDir = (dr.FileFlags & FATTR_DIRECTORY) != 0;
    bool fits = isDir ? SalListingAcceptsDirU8(path, pathLen, nameLen)
                      : SalListingAcceptsFileU8(path, pathLen, fileName, nameLen);
    if (FitCheck)
    {
        if (SalIsoEntryFits(isDir != FALSE, path, pathLen, fileName, nameLen))
            FitCount++;
        else
            FitRefused = TRUE;
        if (fits)
            FitListed++;
        return fits ? ADD_LISTED : ADD_LEFT_OUT;
    }
    // feature 328: an entry the listing refuses is left out alone and reported (ListArchive) - it
    // cleared the whole listing and showed "Error", the walk then descended no later folder
    if (!fits)
    {
        Image->ListingLeftOut.Add(path, fileName);
        return ADD_LEFT_OUT;
    }

    CFileData fd;

    memset(&fd, 0, sizeof(CFileData));
    fd.Name = SalamanderGeneral->DupStr(fileName);
    if (fd.Name == NULL)
    {
        Error(IDS_INSUFFICIENT_MEMORY);
        return ADD_FAILED;
    } // if

    fd.NameLen = strlen(fd.Name);
    char* s = strrchr(fd.Name, '.');
    if (s != NULL)
        fd.Ext = s + 1; // ".cvspass" is extension in Windows
    else
        fd.Ext = fd.Name + fd.NameLen;

    CISOImage::CFilePos* filePos = new CISOImage::CFilePos;
    if (!filePos)
    {
        free(fd.Name);
        Error(IDS_INSUFFICIENT_MEMORY);
        return ADD_FAILED;
    }

    filePos->Extent = (DWORD)dr.LocationOfExtent;
    filePos->Type = FS_TYPE_ISO9660;

    char u[1204];
    sprintf(u, "CISO9960::AddFileDir(): name: %s, Extent: 0x%X", fileName, dr.LocationOfExtent);
    TRACE_I(u);

    fd.PluginData = (DWORD_PTR)filePos;

    // set date & time
    if (memcmp(&dr.RecordingDateAndTime, "\x00\x00\x00\x00\x00\x00\x00",
               sizeof(dr.RecordingDateAndTime)) != 0)
    {
        ISODateTimeToFileTime(dr.RecordingDateAndTime, &fd.LastWrite);
    }
    else
        fd.LastWrite = Image->GetLastWrite();

    fd.DosName = NULL;

    fd.Attr = FILE_ATTRIBUTE_READONLY; // Everything is read-only by default
    fd.Hidden = 0;
    fd.IsOffline = 0;
    if (dr.FileFlags & FATTR_HIDDEN)
    {
        fd.Attr |= FILE_ATTRIBUTE_HIDDEN;
        fd.Hidden = 1;
    }

    if (dr.FileFlags & FATTR_DIRECTORY)
    {
        fd.Size = CQuadWord(0, 0);
        fd.Attr |= FILE_ATTRIBUTE_DIRECTORY;
        fd.IsLink = 0;

        if (!SortByExtDirsAsFiles)
            fd.Ext = fd.Name + fd.NameLen; // directories do not have an extension

        if (dir && !dir->AddDir(path, fd, pluginData))
        {
            // feature 328: refused although the rule took it (out of memory) - the listing is kept,
            // only marked incomplete (a whole unpack fails)
            free(fd.Name);
            delete filePos;
            Image->ListingLeftOut.SetIncomplete();
            Error(IDS_ERROR);
            return ADD_LEFT_OUT;
        }
    }
    else
    {
        fd.Size = CQuadWord(dr.DataLength, 0);

        // file
        fd.IsLink = SalamanderGeneral->IsFileLink(fd.Ext);
        if (dir && !dir->AddFile(path, fd, pluginData))
        {
            free(fd.Name); // feature 328: as for a folder above
            delete filePos;
            Image->ListingLeftOut.SetIncomplete();
            Error(IDS_ERROR);
            return ADD_LEFT_OUT;
        }
    }

    return ADD_LISTED;
}

char* CISO9660::PickDirName(char* path, CDirectoryRecord& dr, char* rrName, char* isoName, BOOL& below)
{
    below = Decide;
    if (rrName == NULL)
        return isoName; // Joliet, plain ISO 9660: the record's one name
    if (FitCheck)
        return FitIsoNames ? isoName : rrName; // a count walk: fixed names
    size_t pathLen = strlen(path);
    BOOL keepRr = TRUE;
    if (Decide)
    {
        // feature 328 (salisonamefit.h): the Rock Ridge name when it is not longer (no count walk - review
        // 2: a deep chain of short names walked its subtree once per level), when the whole subtree fits
        // with Rock Ridge names (it then leaves the decision mode), or when it leaves no fewer entries
        // fitting and no fewer listed than the ISO 9660 name - counted with ISO 9660 names below
        size_t rrLen = strlen(rrName), isoLen = strlen(isoName);
        if (rrLen > isoLen)
        {
            size_t fitRr = 0, listedRr = 0, fitIso = 0, listedIso = 0;
            BOOL refused = FALSE;
            CountUnder(path, dr, rrName, FALSE, &fitRr, &listedRr, &refused);
            BOOL fits = !refused;
            keepRr = fits;
            if (!keepRr)
            {
                CountUnder(path, dr, rrName, TRUE, &fitRr, &listedRr, NULL);
                CountUnder(path, dr, isoName, TRUE, &fitIso, &listedIso, NULL);
                keepRr = SalIsoFolderKeepsRockRidge(false, rrLen, isoLen, fitRr, fitIso, listedRr, listedIso);
            }
            below = !fits;
        }
    }
    // the chosen Rock Ridge name refused by the listing: the ISO 9660 name when the listing takes it
    if (keepRr && !SalListingAcceptsDirU8(path, pathLen, strlen(rrName)) &&
        SalListingAcceptsDirU8(path, pathLen, strlen(isoName)))
    {
        keepRr = FALSE;
    }
    return keepRr ? rrName : isoName;
}

void CISO9660::CountUnder(char* path, CDirectoryRecord& dr, const char* name, BOOL isoNames, size_t* fit,
                          size_t* listed, BOOL* refused)
{
    size_t pathLen = strlen(path);
    size_t nameLen = strlen(name);
    BOOL folderFits = SalIsoEntryFits(true, path, pathLen, name, nameLen);
    *fit = 0;
    *listed = 0;
    if (refused != NULL)
        *refused = !folderFits;
    if (!SalListingAcceptsDirU8(path, pathLen, nameLen))
        return;
    // a count walk of the subtree (nothing added, errors quiet); the modes of the walk it is part of kept
    BOOL saveFitCheck = FitCheck, saveFitRefused = FitRefused, saveFitIsoNames = FitIsoNames, saveDecide = Decide;
    size_t saveFitCount = FitCount, saveFitListed = FitListed;
    FitCheck = TRUE;
    FitRefused = FALSE;
    FitIsoNames = isoNames;
    FitCount = 0;
    FitListed = 0;
    Decide = FALSE;
    // the directories the walk it is part of met already stay empty here too; the count walk marks its
    // own in the same set and takes them out afterwards (review 2: a copy of the set per count walk was
    // quadratic - 20,000 Rock Ridge folders at a root)
    std::vector<DWORD> countLog;
    std::vector<DWORD>* saveLog = VisitedLog;
    VisitedLog = &countLog;
    // the folder part and the name are accepted (at most MAX_PATH - 5 bytes each): the walk's
    // 4 * MAX_PATH + 2 byte buffer holds both
    path[pathLen] = '\\';
    memcpy(path + pathLen + 1, name, nameLen + 1);
    CPluginDataInterfaceAbstract* noData = NULL;
    ListDirectoryRe(path, &dr, NULL, noData);
    path[pathLen] = '\0';
    VisitedLog = saveLog;
    if (Visited != NULL)
        for (size_t i = 0; i < countLog.size(); i++)
            Visited->erase(countLog[i]);
    *fit = (folderFits ? 1 : 0) + FitCount;
    *listed = 1 + FitListed;
    if (refused != NULL && FitRefused)
        *refused = TRUE;
    FitCheck = saveFitCheck;
    FitRefused = saveFitRefused;
    FitIsoNames = saveFitIsoNames;
    FitCount = saveFitCount;
    FitListed = saveFitListed;
    Decide = saveDecide;
}

char* CISO9660::GetBootRecordTypeStr(EBootRecordType type)
{
    CALL_STACK_MESSAGE1("CISO9660::GetBootRecordTypeStr()");

    static char buffer[8];

    ZeroMemory(buffer, 8);
    buffer[0] = '-';

    switch (type)
    {
    case biNoEmul:
        strcat(buffer, "noemul");
        break;
    case bi120:
        strcat(buffer, "1.2");
        break;
    case bi144:
        strcat(buffer, "1.44");
        break;
    case bi288:
        strcat(buffer, "2.88");
        break;
    case biHDD:
        strcat(buffer, "hdd");
        break;
    } // switch

    return buffer;
}

BOOL CISO9660::AddBootRecord(char* path, int session,
                             CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData)
{
    // add boot image file
    if (BootRecordInfo != NULL)
    {

        CDirectoryRecord dr;
        ZeroMemory(&dr, sizeof(dr));

        // set up the virtual directory record
        dr.FileFlags = 0;
        dr.LocationOfExtent = BootRecordInfo->LoadRBA;
        //    dr.RecordingDateAndTime = ;
        dr.DataLength = BootRecordInfo->Length;

        char fileName[MAX_PATH];
        if (session == -1)
        {
            session = 1;
            sprintf(fileName, "s%02d-bootdisk%s.ima", session, GetBootRecordTypeStr(BootRecordInfo->Type));
            if (!AddFileDir("\\", fileName, dr, dir, pluginData))
                return FALSE;
            strcat(path, "Session 01");
        }
        else
        {
            sprintf(fileName, "s%02d-bootdisk%s.ima", session, GetBootRecordTypeStr(BootRecordInfo->Type));
            if (!AddFileDir("\\", fileName, dr, dir, pluginData))
                return FALSE;
        }
    }

    return TRUE;
}

BOOL CISO9660::ListDirectory(char* path, int session,
                             CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData)
{
    CALL_STACK_MESSAGE3("CISO9660::ListDirectory(%s, %d, , )", path, session);

    AddBootRecord(path, session, dir, pluginData);

    // feature 326 (review): a volume walks its tree with the listing's rule (FitCheck) first - Rock
    // Ridge names are longer than the ISO 9660 ones, a deep tree of them can pass the folder part the
    // panel takes. Feature 328: every non-Joliet volume (genisoimage's RR records were read again after
    // 326 turned SP off: "Error", folders lost); when something is refused, the listing decides each
    // Rock Ridge folder's name (Decide, salisonamefit.h) instead of listing the whole volume under its
    // ISO 9660 names, and leaves out (and reports) what fits under no name
    Decide = FALSE;
    if (Ext != extJoliet)
    {
        size_t pathSize = 4 * MAX_PATH + 2; // CISOImage::ListImage's buffer: the walk appends in place
        size_t used = strlen(path);
        char* fitPath = used < pathSize ? (char*)malloc(pathSize) : NULL;
        if (fitPath == NULL)
            Decide = TRUE; // cannot check: decide (the same listing, more walks)
        else
        {
            memcpy(fitPath, path, used + 1);
            FitCheck = TRUE;
            FitRefused = FALSE;
            FitIsoNames = FALSE;
            FitCount = 0;
            FitListed = 0;
            std::set<DWORD> fitVisited;
            Visited = &fitVisited;
            CPluginDataInterfaceAbstract* noData = NULL;
            ListDirectoryRe(fitPath, &Root, NULL, noData);
            Visited = NULL;
            FitCheck = FALSE;
            free(fitPath);
            if (FitRefused)
            {
                TRACE_I("CISO9660::ListDirectory(): names that do not fit the listing - the Rock Ridge folder names decided");
                Decide = TRUE;
            }
        }
    }
    std::set<DWORD> visited; // feature 328 (review): each directory walked once
    Visited = &visited;
    BOOL ret = ListDirectoryRe(path, &Root, dir, pluginData) != ERR_TERMINATE;
    Visited = NULL;
    Decide = FALSE;
    return ret;
}

//
int CISO9660::ListDirectoryRe(char* path, CDirectoryRecord* root,
                              CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData)
{
    if (root == NULL)
        return ERR_TERMINATE;

    DWORD block = (DWORD)root->LocationOfExtent - ExtentOffset + root->ExtendedAttributeRecordLength;
    int size = root->DataLength;

    if (block == 0 || size == 0)
        return ERR_TERMINATE;

    // feature 328 (review): a directory is walked once per walk - in a crafted image whose folders
    // point back to an ancestor (or to one directory twice) the walk never ended: the old "Error" at
    // the first refused entry stopped every later descent, a left-out entry no longer does. A
    // directory met again is listed as an empty folder
    if (Visited != NULL)
    {
        bool added = false;
        try
        {
            if (!Visited->insert(block).second)
                return ERR_OK;
            added = true;
            if (VisitedLog != NULL) // a count walk: CountUnder takes its directories out again
                VisitedLog->push_back(block);
        }
        catch (...)
        {
            if (added)
                Visited->erase(block);
            Error(IDS_INSUFFICIENT_MEMORY, FitCheck);
            return ERR_TERMINATE;
        }
    }

    char* data = new char[size];
    if (data == NULL)
    {
        Error(IDS_INSUFFICIENT_MEMORY, FitCheck);
        return ERR_TERMINATE;
    }

    if (Image->ReadBlock(block, size, data) != (DWORD)size)
    {
        delete[] data;
        Error(IDS_ERROR_LISTING_IMAGE, FitCheck, block);
        // if reading the sector with the root fails
        return (block == (DWORD)Root.LocationOfExtent - ExtentOffset) ? ERR_CONTINUE : ERR_TERMINATE;
    }

    // feature 328: a record's names - the listed one and a Rock Ridge record's ISO 9660 one - on the
    // heap (the walk recurses once per folder level, count walks inside it)
    std::unique_ptr<char, decltype(&free)> nameBuf((char*)malloc(2 * NAME_BUF), &free);
    if (!nameBuf)
    {
        delete[] data;
        Error(IDS_INSUFFICIENT_MEMORY, FitCheck);
        return ERR_TERMINATE;
    }
    char* names = nameBuf.get();

    int ret = ERR_OK;
    int offset = 0;
    while (offset < size - 0x21 && ret != ERR_TERMINATE)
    {
        while (!data[offset] && offset < size - 0x21)
            offset++;

        if (offset >= size - 0x21)
            break;

        //
        CDirectoryRecord dirRecord;

        FillDirectoryRecord(dirRecord, (BYTE*)(data + offset));

        // Safety check
        if ((dirRecord.LocationOfExtent != SWAPDWORD(dirRecord.LocationOfExtentA)) || (dirRecord.DataLength != SWAPDWORD(dirRecord.DataLengthA)))
        {
            delete[] data; // feature 223: it was left allocated
            Error(IDS_ERROR_LISTING_IMAGE, FitCheck, block);
            return ERR_TERMINATE;
        }
        // feature 223: the record and its name lie inside the data read (its lengths come from the
        // image; the name and the system use area were read past the buffer)
        if (dirRecord.LengthOfDirectoryRecord < 34 || offset + dirRecord.LengthOfDirectoryRecord > size ||
            33 + dirRecord.LengthOfFileIdentifier > dirRecord.LengthOfDirectoryRecord)
        {
            delete[] data;
            Error(IDS_ERROR_LISTING_IMAGE, FitCheck, block);
            return ERR_TERMINATE;
        }

        if (dirRecord.FileFlags & FATTR_DIRECTORY)
        {
            // feature 328: the folder's name (the Rock Ridge or the ISO 9660 one, PickDirName), and a
            // folder the listing refuses is left out alone - it ended this directory ("Error")
            char* listedName = NULL;
            BOOL below = Decide;
            if (Ext == extJoliet)
            {
                if (dirRecord.LengthOfFileIdentifier > 1)
                {
                    char dirName[2 * MAX_PATH];
                    ZeroMemory(&dirName, sizeof(dirName));
                    ConvJolietName(dirName, (data + offset + 33), dirRecord.LengthOfFileIdentifier);
                    MakeSafeName(dirName, sizeof(dirName)); // feature 327: listed and descended with
                    memcpy(names, dirName, sizeof(dirName));
                    listedName = names;
                } // if
            }
            else
            {
                char firstChar = data[offset + 33];
                if (firstChar != 0x00 && firstChar != 0x01)
                {
                    char* extFileName = names;
                    ZeroMemory(extFileName, NAME_BUF);
                    BOOL rockRidge = ExtractExtFileName(extFileName, (data + offset + 33), dirRecord);
                    // format boundary (interface 104): plain ISO9660 (and Rock Ridge)
                    // identifiers are raw bytes with no encoding tag -> make them UTF-8;
                    // feature 326: a Rock Ridge name then made safe; feature 327: every name
                    MakeListedName(extFileName, NAME_BUF, rockRidge, (data + offset + 33), dirRecord, FALSE);
                    char* isoName = names + NAME_BUF;
                    if (rockRidge) // feature 328: its ISO 9660 name too
                        MakeIsoName(isoName, NAME_BUF, (data + offset + 33), dirRecord, FALSE);
                    listedName = rockRidge ? PickDirName(path, dirRecord, extFileName, isoName, below)
                                           : extFileName;
                } // if
            }     // if
            if (listedName != NULL)
            {
                int added = AddFileDir(path, listedName, dirRecord, dir, pluginData);
                if (added == ADD_LISTED)
                {
                    int pathLen = (int)strlen(path);
                    strcat(path, "\\");
                    strcat(path, listedName);
                    // descend only when everything is OK
                    if (ret == ERR_OK)
                    {
                        BOOL decide = Decide;
                        Decide = below;
                        ret = ListDirectoryRe(path, &dirRecord, dir, pluginData);
                        Decide = decide;
                        // if we surface with a termination error, keep processing as much as possible
                        if (ret == ERR_TERMINATE)
                            ret = ERR_CONTINUE;
                    }
                    path[pathLen] = '\0';
                }
                else if (added == ADD_FAILED)
                    ret = ERR_TERMINATE;
            }
        }
        else
        {
            char* fileName = names;
            ZeroMemory(fileName, NAME_BUF);

            char* src = (data + offset + 33);
            if (Ext == extJoliet)
            {
                ConvJolietName(fileName, src, dirRecord.LengthOfFileIdentifier);
                src = fileName;
            }

            BOOL rockRidge = ExtractFileName(fileName, src, dirRecord);
            // format boundary (interface 104): plain ISO9660 (and Rock Ridge) identifiers
            // are raw bytes with no encoding tag -> make them UTF-8. A no-op for Joliet,
            // which ConvJolietName() already turned into UTF-8 above. Feature 326: a Rock
            // Ridge name then made safe (never Joliet: 'src' is the raw identifier then);
            // feature 327: every other name too
            MakeListedName(fileName, NAME_BUF, rockRidge, src, dirRecord, TRUE);

            // feature 328: a Rock Ridge file the listing refuses goes under its ISO 9660 name when the
            // listing takes that (a count walk lists fixed names); refused under both: left out alone
            char* listedName = fileName;
            if (rockRidge)
            {
                char* isoName = names + NAME_BUF;
                MakeIsoName(isoName, NAME_BUF, src, dirRecord, TRUE);
                if (FitCheck)
                    listedName = FitIsoNames ? isoName : fileName;
                else if (SalIsoPickFileName(path, strlen(path), fileName, isoName) == SAL_ISO_NAME_ISO9660)
                    listedName = isoName;
            }
            if (AddFileDir(path, listedName, dirRecord, dir, pluginData) == ADD_FAILED)
                ret = ERR_TERMINATE;
        } // if

        offset += dirRecord.LengthOfDirectoryRecord;
    } // while

    delete[] data;

    return ret;
}

int CISO9660::UnpackFile(CSalamanderForOperationsAbstract* salamander, const char* srcPath, const char* path, const char* nameInArc,
                         const CFileData* fileData, DWORD& silent, BOOL& toSkip)
{
    CALL_STACK_MESSAGE6("CISO9660::UnpackFile( , %s, %s, %s, , %u, %d)", srcPath, path, nameInArc, silent, toSkip);

    ///
    // the target path is UTF-8 and may be long (interface 104) -> heap buffer
    CU8PathBuf name;
    if (!name.IsOk())
    {
        Error(IDS_INSUFFICIENT_MEMORY);
        return UNPACK_ERROR;
    }
    lstrcpyn(name, path, U8_MAX_PATH);
    if (!AppendSafeName(name, fileData->Name, U8_MAX_PATH)) // feature 327: made safe again
    {
        Error(IDS_ERR_TOO_LONG_NAME);
        return UNPACK_ERROR;
    }

    char fileInfo[100];
    FILETIME ft = fileData->LastWrite;
    GetInfo(fileInfo, &ft, fileData->Size);

    DWORD attrs = fileData->Attr;

    HANDLE hFile = SalamanderSafeFile->SafeFileCreate(name, GENERIC_WRITE, FILE_SHARE_READ, attrs, FALSE,
                                                      SalamanderGeneral->GetMainWindowHWND(), nameInArc, fileInfo,
                                                      &silent, TRUE, &toSkip, NULL, 0, NULL, NULL);
    CBufferedFile file(hFile, GENERIC_WRITE);
    // set file time
    file.SetFileTime(&ft, &ft, &ft);

    // the overall operation can continue further: skip only
    if (toSkip)
        return UNPACK_ERROR;

    // the overall operation cannot continue any further: cancel
    if (hFile == INVALID_HANDLE_VALUE)
        return UNPACK_CANCEL;

    ///

    BOOL bFileComplete = TRUE;

    BOOL ret = UNPACK_OK;
    CISOImage::CFilePos* fp = (CISOImage::CFilePos*)fileData->PluginData;
    DWORD block = fp->Extent - ExtentOffset;
    CQuadWord remain = fileData->Size;
    DWORD sectorUserSize = 0x800;
    DWORD nbytes = sectorUserSize;
    BYTE* buffer = new BYTE[sectorUserSize];
    if (!buffer)
    {
        Error(IDS_INSUFFICIENT_MEMORY);
        return UNPACK_CANCEL;
    }
    /*
  char u[1024];
  sprintf(u, "CISO9660::UnpackFile(): opening Extent: %x, Size: %d", block, remain);
  TRACE_I(u);
*/
    while (remain.Value > 0)
    {
        if (remain.Value < nbytes)
            nbytes = remain.LoDWord; // !!! the buffer size must not exceed DWORD

        if (!Image->ReadBlock(block, sectorUserSize, buffer))
        {
            if (silent == 0)
            {
                char error[1024];
                sprintf(error, LoadStr(IDS_ERROR_READING_SECTOR), block);
                int userAction = SalamanderGeneral->DialogError(SalamanderGeneral->GetMsgBoxParent(), BUTTONS_SKIPCANCEL,
                                                                fileData->Name, error, LoadStr(IDS_READERROR));

                switch (userAction)
                {
                case DIALOG_CANCEL:
                    ret = UNPACK_CANCEL;
                    break;
                case DIALOG_SKIP:
                    ret = UNPACK_ERROR;
                    break;
                case DIALOG_SKIPALL:
                    ret = UNPACK_ERROR;
                    silent = 1;
                    break;
                }
            }

            bFileComplete = FALSE;
            break;
        }

        block++;

        if (!salamander->ProgressAddSize(nbytes, TRUE)) // delayedPaint==TRUE, so we do not slow things down
        {
            salamander->ProgressDialogAddText(LoadStr(IDS_CANCELING_OPERATION), FALSE);
            salamander->ProgressEnableCancel(FALSE);

            ret = UNPACK_CANCEL;
            bFileComplete = FALSE;
            break; // action interrupted
        }

        ULONG written;
        if (!file.Write(buffer, nbytes, &written, name, NULL))
        {
            // Error message was already displayed by SafeWriteFile()
            ret = UNPACK_CANCEL;
            bFileComplete = FALSE;
            break;
        }
        remain.Value -= nbytes;
    } // while

    delete[] buffer;

    //  sprintf(u, "CISOImage::UnpackFile(): ret: %d, bFileComplete: %d", ret, bFileComplete);
    //  TRACE_I(u);

    if (!file.Close(name, NULL))
    {
        // Flushing cache may fail
        ret = UNPACK_CANCEL;
        bFileComplete = FALSE;
    }

    if (!bFileComplete)
    {
        // because it was created with the read-only attribute, we must clear
        // the R attribute so the file can be deleted
        attrs &= ~FILE_ATTRIBUTE_READONLY;
        if (!SetFileAttributesU8(name, attrs))
            Error(LoadStrU8(IDS_CANT_SET_ATTRS), GetLastError());

        // the user cancelled the operation
        // delete the incomplete file afterwards
        if (!DeleteFileU8(name))
            Error(LoadStrU8(IDS_CANT_DELETE_TEMP_FILE), GetLastError());
    }
    else
        SetFileAttrs(name, attrs);

    return ret;
}

BOOL CISO9660::DumpInfo(FILE* outStream)
{
    char* s;

    CALL_STACK_MESSAGE1("CISO9660::DumpInfo()");

    // display info from the PVD
    s = ViewerStrNcpy((char*)PVD.SystemIdentifier, 32);
    if (*s)
        fprintf(outStream, "    System Identifier:        %s\n", s);
    s = ViewerStrNcpy((char*)PVD.VolumeIdentifier, 32);
    if (*s)
        fprintf(outStream, "    Volume:                   %s\n", s);
    s = ViewerStrNcpy((char*)PVD.VolumeSetIdentifier, 128);
    if (*s)
        fprintf(outStream, "    Volume Set:               %s\n", s);
    s = ViewerStrNcpy((char*)PVD.PublisherIdentifier, 128);
    if (*s)
        fprintf(outStream, "    Publisher:                %s\n", s);
    s = ViewerStrNcpy((char*)PVD.DataPreparerIdentifier, 128);
    if (*s)
        fprintf(outStream, "    Data Preparer:            %s\n", s);
    s = ViewerStrNcpy((char*)PVD.ApplicationIdentifier, 128);
    if (*s)
        fprintf(outStream, "    Application:              %s\n", s);
    s = ViewerStrNcpy((char*)PVD.CopyrightFileIdentifier, 37);
    if (*s)
        fprintf(outStream, "    Copyright File:           %s\n", s);
    s = ViewerStrNcpy((char*)PVD.AbstractFileIdentifier, 37);
    if (*s)
        fprintf(outStream, "    Abstract File:            %s\n", s);
    s = ViewerStrNcpy((char*)PVD.BibliographicFileIdentifier, 37);
    if (*s)
        fprintf(outStream, "    Bibliographic File:       %s\n", s);

    //  fprintf(outStream, "\n");

    SYSTEMTIME st;
    ISODateTimeStrToSystemTime(PVD.VolumeCreationDateAndTime, &st);
    if (st.wYear != 0)
        fprintf(outStream, "    Volume Creation Date:     %s\n", ViewerPrintSystemTime(&st));

    ISODateTimeStrToSystemTime(PVD.VolumeModificationDateAndTime, &st);
    if (st.wYear != 0)
        fprintf(outStream, "    Volume Modification Date: %s\n", ViewerPrintSystemTime(&st));

    ISODateTimeStrToSystemTime(PVD.VolumeExpirationDateAndTime, &st);
    if (st.wYear != 0)
        fprintf(outStream, "    Volume Expiration Date:   %s\n", ViewerPrintSystemTime(&st));

    ISODateTimeStrToSystemTime(PVD.VolumeEffectiveDateAndTime, &st);
    if (st.wYear != 0)
        fprintf(outStream, "    Volume Effective Date:    %s\n", ViewerPrintSystemTime(&st));

    return TRUE;
}

BOOL CISO9660::ReadBootRecord(BYTE* data, BOOL quiet)
{
    CALL_STACK_MESSAGE2("CISO9660::ReadBootRecord(, %d)", quiet);

    memcpy(&BR, data, sizeof(BR));

    BOOL result = FALSE;

    if (!Options.BootImageAsFile)
        return FALSE;

    // check for El Torito specification
    if (memcmp(BR.BootSystemIdentifier + 0, "EL TORITO SPECIFICATION", 23) == 0)
    {
        DWORD sector = 0;
        memcpy(&sector, data + 0x47, sizeof(DWORD));

        BYTE* catalog = new BYTE[SECTOR_SIZE];
        if (catalog == NULL)
        {
            return Error(IDS_INSUFFICIENT_MEMORY, quiet);
        }

        if (Image->ReadBlock(sector - ExtentOffset, SECTOR_SIZE, catalog) == SECTOR_SIZE)
        {
            result = ReadElTorito(catalog, SECTOR_SIZE, quiet);
        }
        else
        {
            result = Error(IDS_ERROR_READING_SECTOR, FALSE, sector - ExtentOffset);
        }

        delete[] catalog;
    }

    // and finally
    return result;
}
