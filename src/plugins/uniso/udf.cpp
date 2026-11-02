// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "dbg.h"

#include "uniso.h"
#include "isoimage.h"
#include "udf.h"
#include "../../common/salisoudfvat.h"   // feature 358: the VAT rules
#include "../../common/salisoudfentry.h" // feature 361: the file entry's descriptor area
#include "../../common/salisoudfmaps.h"  // feature 378: the partition map table

// feature 400: the walk results of salisowalk.h are the plug-in's
static_assert(ERR_OK == SAL_ISO_WALK_OK && ERR_CONTINUE == SAL_ISO_WALK_CONTINUE &&
                  ERR_TERMINATE == SAL_ISO_WALK_TERMINATE,
              "salisowalk.h results");

#include "uniso.rh"
#include "uniso.rh2"
#include "lang\lang.rh"

#define MIN(a, b) ((a) < (b) ? (a) : (b))

typedef wchar_t unicode_t;

#define SECTOR_SIZE 0x800
#define INVALID_SECTOR_NUMBER -11111111 // reasonable negative number; Should not be -1 or so!!

// Maximum length of filenames allowed in UDF.
#define MAX_UDF_FILE_NAME_LEN 2048

// Flags for testing the File Identifier Descriptor
#define UDF_HIDDEN 0x01
#define UDF_DIRECTORY 0x02
#define UDF_DELETED 0x04
#define UDF_PARENT 0x08
#define UDF_METADATA 0x10

/* For direct data access, LSB first */
#define GET_BYTE(data, p) ((Uint8)data[p])
#define GET_WORD(data, p) ((Uint16)data[p] | ((Uint16)data[(p) + 1] << 8))
//#define GETN3(p) ((Uint32)data[p] | ((Uint32)data[(p) + 1] << 8) \
//		  | ((Uint32)data[(p) + 2] << 16))
#define GET_DWORD(data, p) ((Uint32)data[p] | ((Uint32)data[(p) + 1] << 8) | ((Uint32)data[(p) + 2] << 16) | ((Uint32)data[(p) + 3] << 24))
#define GET_QWORD(data, p) ((Uint64)data[p] | ((Uint64)data[(p) + 1] << 8) | ((Uint64)data[(p) + 2] << 16) | ((Uint64)data[(p) + 3] << 24) | ((Uint64)data[(p) + 4] << 32) | ((Uint64)data[(p) + 5] << 40) | ((Uint64)data[(p) + 6] << 48) | ((Uint64)data[(p) + 7] << 56))
/* This is wrong with regard to endianess */
#define GETN(data, p, n, target) memcpy(target, &data[p], n)

static void
UDFTimeStampToSystemTime(CUDF::CTimeStamp& stamp, SYSTEMTIME* st)
{
    st->wYear = stamp.Year;
    st->wMonth = stamp.Month;
    st->wDayOfWeek = 0;
    st->wDay = stamp.Day;
    st->wHour = stamp.Hour;
    st->wMinute = stamp.Minute;
    st->wSecond = stamp.Second;
    st->wMilliseconds = 0;
}

static void
UDFTimeStampToFileTime(CUDF::CTimeStamp& stamp, FILETIME* ft)
{
    SYSTEMTIME st;
    int offset;

    UDFTimeStampToSystemTime(stamp, &st);
    SystemTimeToFileTime(&st, ft);
    offset = stamp.TypeAndTimezone & 0x0FFF;
    if ((1 == (stamp.TypeAndTimezone >> 12)) && (0xFFF != offset))
    { // Valid timezone, offset in minutes
        __int64 newtime = ft->dwLowDateTime + (((__int64)ft->dwHighDateTime) << 32);

        if (offset & 0x800) // negative 12-bit number -> extend to 32-bit negative number
            offset |= 0xFFFFF000;
        newtime -= ((__int64)offset) * 60 * 1000 * 1000 * 10; // from min units to 100ns units
        ft->dwLowDateTime = (DWORD)(newtime & 0x00000000ffffffff);
        ft->dwHighDateTime = (DWORD)(newtime >> 32);
    }
}

static int
UnicodeLength(unicode_t* string)
{
    int length;
    length = 0;
    while (*string++)
        length++;

    return length;
}

static int
UnicodeUncompress(BYTE* compressed, int numberOfBytes, unicode_t* unicode)
{
    unsigned int compID;
    int returnValue, unicodeIndex, byteIndex;

    // Use 'compressed' to store current byte being read.
    compID = compressed[0];

    // First check for valid compID.
    if (compID != 8 && compID != 16)
    {
        returnValue = -1;
    }
    else
    {
        unicodeIndex = 0;
        byteIndex = 1;
        if (16 == compID)
        {
            // Make it odd number: length byte plus even number of text bytes
            numberOfBytes = ((numberOfBytes - 1) & 0xFFFE) + 1;
        }

        // Loop through all the bytes.
        while (byteIndex < numberOfBytes)
        {
            if (compID == 16)
            {
                // Move the first byte to the high bits of the unicode char.
                unicode[unicodeIndex] = compressed[byteIndex++] << 8;
            }
            else
            {
                unicode[unicodeIndex] = 0;
            }
            if (byteIndex < numberOfBytes)
            {
                // Then the next byte to the low bits.
                unicode[unicodeIndex] |= compressed[byteIndex++];
            }
            unicodeIndex++;
        }
        returnValue = unicodeIndex;
    }

    return returnValue;
}

// format boundary (interface 104): UDF stores names as OSTA-compressed Unicode; once
// uncompressed they are UTF-16, so emit UTF-8 directly - the interface wants UTF-8, and
// the previous route through the ANSI code page dropped everything outside it.
void DecodeOSTACompressed(BYTE* id, int len, char* result)
{
    unicode_t uncompressed[1024];
    int ucompChars;

    ucompChars = UnicodeUncompress(id, len, uncompressed);
    if (ucompChars < 0)
    { // Invalid string?
        *result = 0;
        return;
    }
    uncompressed[ucompChars] = 0;
    int length = MIN(ucompChars, UnicodeLength(uncompressed));
    uncompressed[length] = 0;

    char final[4 * 1024]; // UTF-8 needs up to 3 bytes per UTF-16 unit

    if (SplWToU8(uncompressed, final, sizeof(final)) == 0)
    {
        // encoding-check: allow lossy-lenient-at-intake - fallback after SplWToU8 (WTF-8, total since 089), which fails only on a too small buffer; a UDF name (length byte <= 255) always fits 'final' (255)
        // lone surrogates and the like: fall back to a lossy but valid UTF-8 form
        WideCharToMultiByte(CP_UTF8, 0, uncompressed, -1, final, sizeof(final) - 1, 0, 0);
    }
    final[sizeof(final) - 1] = 0;
    strcpy(result, final);
}

/*
static char *
DString(BYTE *ds, int count)
{
  static char buffer[256];

  BYTE len = ds[count - 1];
  UnicodeUncompress(ds, len, (unicode_t *)buffer);
  buffer[len] = '\0';
  return buffer;
}
*/

//
//

// ****************************************************************************
//
// CUDF
//

CUDF::CUDF(CISOImage* image, DWORD extent, int trackno) : CUnISOFSAbstract(image),
                                                          PartitionMaps(2, 1, dtDelete)
{
    TrackTryingToOpen = trackno;
    ExtentOffset = extent;
    PartitionMapping.Translation = NULL;
    PartitionMapping.VAT = NULL;
    PartitionMapping.Entries = 0; // feature 358: no table until a VAT is found (was left uninitialized)
    PartitionMapping.Length = 0;
    PartitionMapping.nMetadataICBs = 0;
    VatMissing = FALSE;
    MapsRefused = FALSE;
    Visited = NULL;
}

CUDF::~CUDF()
{
    delete[] PartitionMapping.VAT;
}

BOOL CUDF::ReadBlockPhys(Uint32 lbNum, size_t blocks, unsigned char* data)
{
    DWORD len = (DWORD)(blocks * SECTOR_SIZE);

    if (Image->ReadBlock(PD.Start + lbNum, len, data) != len)
        return FALSE;
    else
        return TRUE;
}

Uint32 CUDF::LogSector(Uint32 lbNum, Uint16 part)
{
    DWORD physBlock = INVALID_SECTOR_NUMBER;

    if (part >= PartitionMaps.Count)
    {
        TRACE_E("Invalid partition number");
        return lbNum;
    }

    switch (PartitionMaps[part]->Type)
    {
    case mapPhysical:
    case mapSparable:
        physBlock = lbNum - ExtentOffset;
        break;

    case mapVirtual:
        // feature 358: only through a table that was read and only its entries 0 .. Entries - 1 (a VAT not
        // found left Translation NULL - read through NULL; '<=' read one entry past the table)
        if (SalIsoUdfVatTranslates(lbNum, PartitionMapping.Entries, PartitionMapping.Translation != NULL))
            physBlock = PartitionMapping.Translation[lbNum] - ExtentOffset;
        else
            physBlock = INVALID_SECTOR_NUMBER;
        break;

    case mapMetadata:
        LONGLONG pos;
        pos = (LONGLONG)lbNum * SECTOR_SIZE;
        int i;
        for (i = 0; i < PartitionMapping.nMetadataICBs; i++)
        {
            if (pos < PartitionMapping.MetadataICBs[i].Length)
            {
                physBlock = (Uint32)(pos / SECTOR_SIZE + PartitionMapping.MetadataICBs[i].Location) - ExtentOffset;
                break;
            }
            pos -= PartitionMapping.MetadataICBs[i].Length;
            if (PartitionMapping.MetadataICBs[i].Length & (SECTOR_SIZE - 1))
            {
                TRACE_E("Metadata partition translation block is not multiple of sector size");
            }
        }
    } // switch
    /*
  char u[1024];
  sprintf(u, "CUDF::LogSector(): 0x%X -> 0x%X", lbNum, physBlock);
  TRACE_I(u);
*/
    return physBlock;
}

BOOL CUDF::ReadBlockLog(Uint32 lbNum, size_t blocks, unsigned char* data)
{
    if (lbNum == INVALID_SECTOR_NUMBER)
        return FALSE;

    DWORD len = (DWORD)(blocks * SECTOR_SIZE);
    DWORD ofs = 0;

    unsigned int i;
    for (i = 0; i < blocks; i++)
    {
        DWORD readBytes;
        if ((readBytes = Image->ReadBlock(PD.Start + lbNum, SECTOR_SIZE, data + ofs)) != SECTOR_SIZE)
            return FALSE;

        ofs += readBytes;
        lbNum++;
    } // for

    return TRUE;
}

void CUDF::ReadExtentAd(BYTE sector[], CExtentAd* extent)
{
    extent->Length = GET_DWORD(sector, 0);
    extent->Location = GET_DWORD(sector, 4);
}

void CUDF::ReadEntityID(BYTE sector[], CEntityID* entityID)
{
    entityID->Flags = GET_BYTE(sector, 0);
    GETN(sector, 1, 23, &entityID->Identifier);
    GETN(sector, 24, 8, &entityID->Suffix);
}

void CUDF::ReadAVDP(BYTE sector[], CAVDP* avdp)
{
    ReadExtentAd(sector + 16, &avdp->MVDS);
    ReadExtentAd(sector + 24, &avdp->RVDS);
}

void CUDF::ReadPD(BYTE sector[], CPD* pd)
{
    pd->Flags = GET_WORD(sector, 20);
    pd->PartitionNumber = GET_WORD(sector, 22);
    pd->Start = GET_DWORD(sector, 188);
    pd->Length = GET_DWORD(sector, 192);
}

int CUDF::ReadPartitionMap(BYTE data[])
{
    CPartitionMap* partMap = new CPartitionMap;
    partMap->MetadataFileLocation = 0; // feature 377: set below for a metadata partition map only
    partMap->HasMetadataFile = FALSE;
    CEntityID entityID;

    BYTE partType = GET_BYTE(data, 0);
    switch (partType)
    {
    case 1:
        partMap->VolumeSequenceNumber = GET_WORD(data, 2);
        partMap->PartitionNumber = GET_WORD(data, 4);
        partMap->Type = mapPhysical;
        break;

    case 2:
        partMap->VolumeSequenceNumber = GET_WORD(data, 36);
        partMap->PartitionNumber = GET_WORD(data, 38);

        ReadEntityID(data + 4, &entityID);
        if (strncmp(entityID.Identifier, "*UDF Virtual Partition", 22) == 0)
        {
            partMap->Type = mapVirtual;
        }
        else if (strncmp(entityID.Identifier, "*UDF Sparable Partition", 23) == 0)
        {
            partMap->Type = mapSparable;
        }
        else if (strncmp(entityID.Identifier, "*UDF Metadata Partition", 23) == 0)
        {
            partMap->Type = mapMetadata;

            // Parsing struct part_map_meta. Feature 377: only the metadata file's location is kept here; its
            // entry is read in ReadSupportingTables - the logical volume descriptor may precede the partition
            // descriptor (Windows' IMAPI2FS, UDF 2.50), and the read needs PD.Start
            partMap->MetadataFileLocation = GET_DWORD(data, 40) - ExtentOffset;
            partMap->HasMetadataFile = TRUE;
        }
        break;
    } // switch
    PartitionMapping.Type = partMap->Type;
    PartitionMaps.Add(partMap);

    return GET_BYTE(data, 1);
}

// returns FALSE (feature 378) when the descriptor's partition maps do not fit its sector and its map table
// (salisoudfmaps.h) - nothing is read then and no partition map is recorded; the volume is refused
BOOL CUDF::ReadLVD(BYTE sector[], CLVD* lvd)
{
    unsigned long long mapCount = 0;
    if (!SalIsoUdfLvdMapsFit(sector, SECTOR_SIZE, mapCount))
        return FALSE;

    lvd->VDSN = GET_DWORD(sector, 16);
    lvd->LogicalBlockSize = GET_DWORD(sector, 212);
    GETN(sector, 84, 128, lvd->LogicalVolumeIdentifier);

    LongAD(sector + 248, &lvd->FSD);

    // every declared map lies in [440, min(SECTOR_SIZE, 440 + map table length)) and is at least as long as the
    // bytes ReadPartitionMap takes from it: the walk ends after mapCount (at most 804) steps inside the sector
    int offset = 440;
    for (unsigned long long i = 0; i < mapCount; i++)
        offset += ReadPartitionMap(sector + offset);
    return TRUE;
}

void CUDF::ReadDescriptorTag(BYTE sector[], CDescriptorTag* tag)
{
    tag->ID = (UDF_TAG_ID)GET_WORD(sector, 0);
    tag->Version = GET_WORD(sector, 2);
    tag->Checksum = GET_BYTE(sector, 4);
    tag->Reserved = GET_BYTE(sector, 5);
    tag->SerialNumber = GET_WORD(sector, 6);
    tag->CRC = GET_WORD(sector, 8);
    tag->CRCLength = GET_WORD(sector, 10);
    tag->TagLocation = GET_DWORD(sector, 12);
}

//
// in:
//    data
//
// out:
//    ad, partition
int CUDF::ShortAD(Uint8* data, CUDF::CAD* ad, WORD partNumber)
{
    ad->Length = GET_DWORD(data, 0);
    ad->Flags = (Uint8)(ad->Length >> 30);
    ad->Length &= 0x3FFFFFFF;
    ad->Location = GET_DWORD(data, 4);
    ad->Partition = partNumber; // use number of current partition
    ad->Offset = 0;
    return 0;
}

//
// in:
//    data
//
// out:
//    ad
int CUDF::LongAD(Uint8* data, CUDF::CAD* ad)
{
    Uint32 len = GET_DWORD(data, 0);
    ad->Flags = (Uint8)(len >> 30);
    ad->Length = len & 0x3FFFFFFF;
    ad->Location = GET_DWORD(data, 4);
    ad->Partition = GET_WORD(data, 8);
    ad->Offset = 0;
    return 0;
}

//
// in:
//    data
//
// out:
//    ad
int CUDF::ExtAD(Uint8* data, CUDF::CAD* ad)
{
    ad->Length = GET_DWORD(data, 0);
    ad->Flags = (Uint8)(ad->Length >> 30);
    ad->Length &= 0x3FFFFFFF;
    ad->Location = GET_DWORD(data, 12);
    ad->Partition = GET_WORD(data, 16);
    ad->Offset = 0;
    return 0;
}

void CUDF::ReadICBTag(BYTE data[], CICBTag* icb)
{
    icb->Strategy = GET_WORD(data, 4);
    icb->StrategyParametr = GET_WORD(data, 6);
    icb->Entries = GET_WORD(data, 8);
    icb->FileType = GET_WORD(data, 11);
    icb->Flags = GET_WORD(data, 18);
    /*
  if (icb->FileType == 248)
  {
    char u[1024];
    sprintf(u, "CUDF::ReadICBTag() - %d", icb->FileType);
    TRACE_I(u);
  }
*/
}

//
// in:
//    struct file_entry or struct extfile_entry
//
// out:
//    fileType, partition, ad
//
// returns the number of descriptors stored, -1 for data embedded in the entry, or (feature 361)
// UDF_FE_REFUSED when the entry is refused (salisoudfentry.h): a reserved descriptor type (4 - 7 - the walk
// never advanced and Tandem Commander stopped answering), a descriptor area outside the sector (read past
// the buffer; the area was computed in 32 bits without a bound) or one that is not a whole number of
// descriptors; nothing is stored then. 'data' is one sector (SECTOR_SIZE bytes).
int CUDF::ReadFileEntry(Uint8* data, bool bEFE, Uint16 part, CICBTag* icbTag, CUDF::CAD* ad, int maxAds)
{
    int cnt = maxAds;

    ReadICBTag(data + 16, icbTag);

    // File Entry: 176; Extended File Entry (UDF 2.50+): 176 + 40
    unsigned int fixed = bEFE ? 176 + 40 : 176;
    Uint32 l_ea = GET_DWORD(data, fixed - 8);
    Uint32 l_ad = GET_DWORD(data, fixed - 4);
    unsigned long long first, end;
    int size;
    if (!SalIsoUdfEntryDescs(SECTOR_SIZE, bEFE, l_ea, l_ad, icbTag->Flags & 0x0007, first, end, size))
        return UDF_FE_REFUSED;

    if (size == 0)
    {
        if (first < end && maxAds > 0)
        {
            ad->Offset = (Uint16)first; // < SECTOR_SIZE: the area lies in the sector
            ad->Flags = UDF_EXT_ALLOCATED;
            ad->Length = l_ad;
            ad->Location = 0; // To be determined by the caller
            ad->Partition = part;
            return -1; // -1 tells the caller the data is inlined, but Location is not set
        }
    }
    else
    {
        for (unsigned long long p = first; p < end; p += (unsigned long long)size)
        {
            if (maxAds <= 0)
            {
                TRACE_E("UnISO: UNSUPPORTED: Not enough CAD structures");
                break;
            }
            switch (size)
            {
            case 8:
                ShortAD(&data[p], ad, part);
                break;
            case 16:
                LongAD(&data[p], ad);
                break;
            default:
                ExtAD(&data[p], ad);
                break;
            }
            ad++;
            maxAds--;
        }
    }
    cnt -= maxAds; // # of used ad entries
    if (maxAds > 0)
    {
        // Terminate the sequence
        // And also init ad for an empty file (i.e. there isn't a AD, L_AD == 0 )
        ad->Length = 0;
        ad->Flags = 0;
        ad->Location = 0; // what should we put here?
        ad->Partition = part;
    }
    return cnt;
}

// 'held' = the bytes the caller holds from 'sector' (at least the 38-byte head). Returns the identifier's padded
// length, or (feature 363) 0 when the identifier does not lie whole in those bytes (salisoudfentry.h): its L_IU /
// L_FI from the image put the name 64 KB past the walk's buffer, which was read, listed as "_" and walked on; the
// name is not decoded then.
int CUDF::ReadFileIdentifier(Uint8* sector, unsigned int held, Uint8* fileChar, char* fileName, CAD* fileICB)
{
    Uint8 fi;
    Uint16 iu;

    *fileChar = GET_BYTE(sector, 18);
    fi = GET_BYTE(sector, 19);
    LongAD(sector + 20, fileICB);
    iu = GET_WORD(sector, 36);
    unsigned long long len;
    if (!SalIsoUdfFidLength(held, 0, fi, iu, len))
    {
        fileName[0] = '\0';
        return 0;
    }
    if (fi)
        DecodeOSTACompressed(sector + 38 + iu, fi, fileName);
    else
        fileName[0] = '\0';
    return (int)len; // <= held
}

// feature 364: the folder's entry gives up to 32 descriptors (it gave one - a folder in several extents was read up
// to its first extent); the leading recorded extents are walked, and a folder whose walked bytes do not cover its
// Information Length (a later extent not recorded, descriptors continued in an allocation extent, more than 32
// extents, an extent shorter than the folder) comes back with Whole FALSE - the caller marks the listing
// incomplete (feature 330) and walks what was read (salisoudfentry.h)
int CUDF::MapICB(CUDF::CAD icb, CICBTag* icbTag, CUDFFolder* folder)
{
    static_assert(sizeof(folder->Ext) / sizeof(folder->Ext[0]) == SAL_ISO_UDF_FOLDER_MAX_EXTENTS,
                  "CUDFFolder holds SAL_ISO_UDF_FOLDER_MAX_EXTENTS descriptors");
    BYTE sector[SECTOR_SIZE];
    Uint32 lbNum = LogSector(icb.Location, icb.Partition);
    CDescriptorTag tag;

    do
    {
        if (ReadBlockLog(lbNum, 1, sector))
            ReadDescriptorTag(sector, &tag);
        else
            tag.ID = UDF_TAGID_UNKNOWN;

        if ((UDF_TAGID_FENTRY == tag.ID) || (UDF_TAGID_EXTFENTRY == tag.ID))
        {
            int n = ReadFileEntry(sector, (UDF_TAGID_EXTFENTRY == tag.ID), icb.Partition, icbTag, folder->Ext,
                                  SAL_ISO_UDF_FOLDER_MAX_EXTENTS);
            // feature 361: a refused entry cannot be read - as an unreadable one ("Bad root ICB" for the root, a
            // sub-folder listed empty and the listing incomplete, feature 330); the walk hung on a reserved type.
            // Feature 362: so is a folder entry whose first extent cannot hold its parent's identifier (L_AD 0, also
            // embedded; a first extent or embedded data under 38 bytes) - it was walked over that length (with no
            // descriptor from the terminator's unset Offset), listed empty without a mark, and a whole unpack
            // deleted the image (salisoudfentry.h). A refused entry stored nothing in 'folder' - not read.
            if (n == UDF_FE_REFUSED)
                return 0;
            int stored = n == -1 ? 1 : n; // embedded data: one piece (Flags UDF_EXT_ALLOCATED, its Offset)
            unsigned int types[SAL_ISO_UDF_FOLDER_MAX_EXTENTS];
            unsigned long long lens[SAL_ISO_UDF_FOLDER_MAX_EXTENTS];
            for (int i = 0; i < stored; i++)
            {
                types[i] = folder->Ext[i].Flags;
                lens[i] = folder->Ext[i].Length;
            }
            int walk;
            unsigned long long walkLen;
            // the Information Length lies at 56 in a File Entry and in an Extended File Entry
            bool whole = SalIsoUdfFolderExtents(types, lens, stored, SECTOR_SIZE, GET_QWORD(sector, 56), walk, walkLen);
            // feature 364: 362's rule on the first WALKED extent - a first descriptor that is not a recorded extent
            // leaves nothing to walk (it was walked over bytes that are not recorded)
            if (!SalIsoUdfFolderEntryWalkable(n, walk > 0 ? lens[0] : 0))
                return 0;
            if (-1 == n)
            {
                folder->Ext[0].Location = lbNum;
            }
            folder->Count = walk;
            folder->Length = walkLen;
            folder->Offset = folder->Ext[0].Offset;
            folder->Whole = whole ? TRUE : FALSE;
            return 1;
        }

        lbNum++;
    } while (lbNum <= icb.Location + (icb.Length - 1) / SECTOR_SIZE);

    return 0;
}

int CUDF::MapICB(CUDF::CAD icb, CFileEntry* fe)
{
    BYTE sector[SECTOR_SIZE];
    Uint32 lbNum = LogSector(icb.Location, icb.Partition);
    CDescriptorTag tag;

    do
    {
        if (ReadBlockLog(lbNum, 1, sector))
            ReadDescriptorTag(sector, &tag);
        else
            tag.ID = UDF_TAGID_UNKNOWN;

        if (UDF_TAGID_FENTRY == tag.ID)
        {
            ReadFileEntry(sector, false, fe);
            return 1;
        }
        if (UDF_TAGID_EXTFENTRY == tag.ID)
        {
            ReadFileEntry(sector, true, fe);
            return 1;
        }

        lbNum++;
    } while (lbNum <= icb.Location + (icb.Length - 1) / SECTOR_SIZE);

    return 0;
}

BOOL CUDF::Open(BOOL quiet)
{
    CALL_STACK_MESSAGE2("CUDF::Open(%d)", quiet);

    CDescriptorTag tag;

    BOOL ret = TRUE;
    DWORD block = 0x20, lastBlock = 0x200;
    BYTE sector[SECTOR_SIZE]; // (2k)
    BOOL terminate = FALSE;

    if (Image->ReadBlock(256, SECTOR_SIZE, sector) != SECTOR_SIZE)
    {
        // Something went wrong, probably EOF?
        Error(IDS_ERROR_READING_SECTOR, quiet, block);
        return FALSE;
    }
    ReadDescriptorTag(sector, &tag);
    if (UDF_TAGID_ANCHOR == tag.ID)
    {
        ReadAVDP(sector, &AVDP);
        block = AVDP.MVDS.Location - ExtentOffset;
        lastBlock = block + AVDP.MVDS.Length / SECTOR_SIZE;
    }

    // detecting UDF Volume Descriptor Set
    while (!terminate)
    {
        // Try to read a block
        if (Image->ReadBlock(block, SECTOR_SIZE, sector) != SECTOR_SIZE)
        {
            /*      // Something went wrong, probably EOF?
      if (block > 200) {
         block = 0x20; lastBlock = 0x200;
         continue;
      }*/
            Error(IDS_ERROR_READING_SECTOR, quiet, block);
            return FALSE;
        }

        ReadDescriptorTag(sector, &tag);
        // TODO: better validation test of tag struct
        if (tag.TagLocation - ExtentOffset == block)
        {
            switch (tag.ID)
            {
            case UDF_TAGID_PRI_VOL:
                // Primary Volume Descriptor
                memcpy(&PVD, sector, sizeof(PVD));
                break;

                //        case UDF_TAGID_ANCHOR: ReadAVDP(sector, &AVDP); break;
            case UDF_TAGID_PARTITION:
                ReadPD(sector, &PD);
                break;
            case UDF_TAGID_LOGVOL:
                if (!ReadLVD(sector, &LVD))
                {
                    // feature 378: partition maps that do not fit the descriptor - the volume does not open (a
                    // UDF-only track is not opened; an ISO 9660 + UDF image marks its listing, CUDFISO::Open)
                    Error(IDS_ERROR_LISTING_IMAGE, quiet, block);
                    MapsRefused = TRUE;
                    return FALSE;
                }
                break;

            case UDF_TAGID_TERM:
                // Terminating Descriptor
                terminate = TRUE;
                break;
            };
        }

        block++;

        if (block > lastBlock)
        {
            // Just to make sure we don't read in a too big file, stop after 128 sectors.
            ret = FALSE;
            break;
        }
    } // while

    if (ret)
        ret = ReadSupportingTables(quiet);

    return ret;
}

void CUDF::ReadFileEntry(BYTE sector[], bool bEFE, CFileEntry* fe)
{
    ReadICBTag(sector + 16, &fe->ICBTag);

    fe->InformationLength = GET_QWORD(sector, 56);

    if (!bEFE)
    {
        fe->L_EA = GET_DWORD(sector, 168);
        fe->L_AD = GET_DWORD(sector, 172);
        memcpy(&fe->mtime, sector + 84, sizeof(CTimeStamp));
    }
    else
    {
        fe->L_EA = GET_DWORD(sector, 208);
        fe->L_AD = GET_DWORD(sector, 212);
        memcpy(&fe->mtime, sector + 92, sizeof(CTimeStamp));
    }
}

//
// returns the length of the allocation descriptor read; -1 when it cannot be read or (feature 360) when it does
// not fit: 'avail' is the number of bytes left in the descriptors' area at 'data', 'vatLength' the table's length
// - a descriptor cut by the area's end, or data past the table (more than the file's information length), is
// not a VAT (the reader copied without a bound and wrote past the table)
int CUDF::ReadAllocDesc(BYTE data[], DWORD avail, CFileEntry* fe, BYTE* vat, DWORD vatLength, DWORD* o)
{
    CAD ad;
    int len = SalIsoUdfVatDescSize(fe->ICBTag.Flags & 0x0007);

    if (len == 0)
    {
        // data embedded in the entry: the whole area
        if (!SalIsoUdfVatDescFits(0, avail, avail) || !SalIsoUdfVatCopyFits(*o, avail, vatLength))
            return -1;
        memcpy(vat + *o, data, avail);
        *o += avail;
        return (int)avail;
    }
    if (len < 0 || !SalIsoUdfVatDescFits(0, (unsigned long long)len, avail))
        return -1; // a reserved descriptor type (ReadVAT refuses it first), or a descriptor cut by the area's end

    switch (len)
    {
    case 8:
        ShortAD(data, &ad, PD.PartitionNumber);
        break;
    case 16:
        LongAD(data, &ad);
        break;
    default:
        ExtAD(data, &ad);
        break;
    }

    if (!SalIsoUdfVatCopyFits(*o, ad.Length, vatLength))
        return -1;
    if (!Image->ReadBlock(PD.Start + ad.Location - ExtentOffset, ad.Length, vat + *o))
    {
        return -1;
    }
    *o += ad.Length;

    return len;
}

int CUDF::AddFileDir(const char* path, char* fileName, BYTE fileChar, CAD* icb,
                     CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData)
{
    // feature 329: the panel listing's own rule first (sallistingname.h, CSalamanderDirectory::AddFile /
    // AddDir) - a refused entry is left out alone and named in the report (ListArchive, 328); it showed
    // "Error", and the walk dropped the rest of the folder and descended no later folder
    size_t pathLen = path != NULL ? strlen(path) : 0;
    size_t nameLen = strlen(fileName);
    bool fits = (fileChar & UDF_DIRECTORY) ? SalListingAcceptsDirU8(path, pathLen, nameLen)
                                           : SalListingAcceptsFileU8(path, pathLen, fileName, nameLen);
    if (!fits)
    {
        Image->ListingLeftOut.Add(path, fileName);
        return ADD_LEFT_OUT;
    }

    CFileData fd;
    CISOImage::CFilePos* filePos = NULL;
    int ret = ADD_LISTED;

    memset(&fd, 0, sizeof(CFileData));
    try
    {
        fd.Name = SalamanderGeneral->DupStr(fileName);
        if (fd.Name == NULL)
        {
            Image->ListingLeftOut.SetIncomplete(); // feature 329: a whole unpack then fails
            WalkOutOfMemory(); // feature 400: no later folder descended, the walk's one box
            throw (int)ADD_FAILED;
        } // if

        fd.NameLen = strlen(fd.Name);
        char* s = strrchr(fd.Name, '.');
        if (s != NULL)
            fd.Ext = s + 1; // ".cvspass" is extension in Windows
        else
            fd.Ext = fd.Name + fd.NameLen;

        filePos = new CISOImage::CFilePos;
        if (filePos == NULL)
        {
            Image->ListingLeftOut.SetIncomplete();
            WalkOutOfMemory(); // feature 400: no later folder descended, the walk's one box
            throw (int)ADD_FAILED;
        }

        filePos->Type = FS_TYPE_UDF;
        // ExtentOffset is added to help detect which track the file is in
        filePos->Extent = icb->Location + ExtentOffset;
        filePos->Partition = icb->Partition;

        /*
    char u[1024];
    sprintf(u, "CUDF::AddFileDir(): opening Extent: %x", icb->Location);
    TRACE_I(u);
*/

        fd.PluginData = (DWORD_PTR)filePos;

        fd.DosName = NULL;

        fd.Attr = FILE_ATTRIBUTE_READONLY; // everything is read-only by default
        fd.Hidden = 0;
        fd.IsOffline = 0;

        if (fileChar & UDF_HIDDEN)
        {
            fd.Attr |= FILE_ATTRIBUTE_HIDDEN;
            fd.Hidden = 1;
        }

        if (fileChar & UDF_DIRECTORY)
        {
            fd.Size = CQuadWord(0, 0);
            fd.Attr |= FILE_ATTRIBUTE_DIRECTORY;
            fd.IsLink = 0;

            UDFTimeStampToFileTime(PVD.RecordingDateandTime, &fd.LastWrite);

            if (!SortByExtDirsAsFiles)
                fd.Ext = fd.Name + fd.NameLen; // directories do not have an extension

            if (dir && !dir->AddDir(path, fd, pluginData))
            {
                // feature 329: refused although the rule took it (out of memory) - the listing is kept,
                // only marked incomplete (a whole unpack fails), as CISO9660 (328)
                Image->ListingLeftOut.SetIncomplete();
                Error(IDS_ERROR);
                throw (int)ADD_LEFT_OUT;
            }
        }
        else
        {
            CFileEntry fe;
            if (!MapICB(*icb, &fe))
                throw (int)ADD_FAILED; // a read error: the directory ends, as before

            fd.Size.Value = fe.InformationLength;
            UDFTimeStampToFileTime(fe.mtime, &fd.LastWrite);

            // file
            fd.IsLink = SalamanderGeneral->IsFileLink(fd.Ext);
            if (dir && !dir->AddFile(path, fd, pluginData))
            {
                Image->ListingLeftOut.SetIncomplete(); // feature 329: as for a folder above
                Error(IDS_ERROR);
                throw (int)ADD_LEFT_OUT;
            }
        }
    }
    catch (int e)
    {
        if (fd.Name != NULL)
            SalamanderGeneral->Free(fd.Name); // feature 329: the listing did not take it (it leaked)
        delete filePos;

        ret = e;
    }

    return ret;
}

BOOL CUDF::ListDirectory(char* path, int session, CSalamanderDirectoryAbstract* dir,
                         CPluginDataInterfaceAbstract*& pluginData)
{
    CALL_STACK_MESSAGE3("CUDF::ListDirectory(%s, %d, , )", path, session);

    Uint8 sector[SECTOR_SIZE];
    CAD rootICB;
    /*
  char u[1024];
  sprintf(u, "CUDF::ListDirectory()");
  TRACE_I(u);
*/
    CDescriptorTag tag;
    // find root ICB
    Uint32 lbNum = LogSector(LVD.FSD.Location, LVD.FSD.Partition);
    // This while should no longer be needed since we use LVD.FSD
    do
    {
        if (!ReadBlockLog(lbNum, 1, sector))
        {
            Image->ListingLeftOut.SetIncomplete(); // feature 330: a whole unpack then fails
            Error(IDS_ERROR_LISTING_IMAGE, FALSE, lbNum);
            return ERR_TERMINATE;
        }

        ReadDescriptorTag(sector, &tag);
        if (UDF_TAGID_FSD == tag.ID)
        { // File Set Descriptor
            LongAD(sector + 400, &rootICB);
            break;
        }

        lbNum++;
    } while (lbNum < PD.Length);

    // feature 330: the root folder cannot be found or read - nothing of this UDF volume is listed (in a
    // UDF + ISO 9660 hybrid the other part is), so the listing is incomplete and a whole unpack fails
    // ("Delete archive after unpacking" deleted the image)

    // Sanity checks.
    if (UDF_TAGID_FSD != tag.ID)
    {
        Image->ListingLeftOut.SetIncomplete();
        return Error(IDS_UDF_INVALID_TAG_ID);
    }

    // Find root dir
    CUDFFolder root;
    CICBTag icbTag;

    if (!MapICB(rootICB, &icbTag, &root) || icbTag.FileType != 4) // Root dir should be dir
    {
        Image->ListingLeftOut.SetIncomplete();
        return Error(IDS_UDF_BAD_ROOT_ICB);
    }
    // feature 364: a root read short of its Information Length - its readable part is listed, the listing is
    // incomplete (it was listed cut without a mark and a whole unpack deleted the image)
    if (!root.Whole)
        Image->ListingLeftOut.SetIncomplete();

    // feature 400: a fresh walk; each folder walked once (the root marked first)
    Walk = SalIsoWalk();
    std::set<unsigned long long> visited;
    Visited = &visited;
    VisitFolder(rootICB);
    int walked = ScanDir(root, path, dir, pluginData);
    Visited = NULL;
    // feature 330: a folder that could not be read (a read error, an invalid tag, a file entry that
    // cannot be read) ends its walk (feature 400: later folders are still descended), and its result
    // reaches the top as ERR_CONTINUE / ERR_TERMINATE - the listing is incomplete, so a whole unpack
    // fails and "Delete archive after unpacking" keeps the image (it was deleted)
    if (walked != ERR_OK)
        Image->ListingLeftOut.SetIncomplete();
    return walked != ERR_TERMINATE;
}

// feature 364: the walk's two-block window - the folder's blocks 'block' and 'block' + 1 (counted from the first
// extent's first block; embedded data: the entry's block) read through the folder's extents into 'window'
// (2 * SECTOR_SIZE bytes). Both in one extent, or past the last one: one two-block read as before feature 364 (a
// folder in one extent makes the same reads); the second block in the next extent: two one-block reads - an
// identifier crossing the extents' boundary is read from both. 'lbNum' = the first block's physical number (for
// the error message).
BOOL CUDF::ReadFolderWindow(const CUDFFolder& folder, Uint32 block, Uint8* window, Uint32& lbNum)
{
    unsigned long long lens[SAL_ISO_UDF_FOLDER_MAX_EXTENTS];
    for (int i = 0; i < folder.Count; i++)
        lens[i] = folder.Ext[i].Length;
    int e0, e1;
    unsigned long long b0, b1;
    if (!SalIsoUdfFolderSector(lens, folder.Count, SECTOR_SIZE, block, e0, b0) ||
        !SalIsoUdfFolderSector(lens, folder.Count, SECTOR_SIZE, (unsigned long long)block + 1, e1, b1))
    {
        lbNum = 0;
        return FALSE;
    }
    lbNum = LogSector(folder.Ext[e0].Location, folder.Ext[e0].Partition) + (Uint32)b0;
    if (e0 == e1)
        return ReadBlockPhys(lbNum, 2, window);
    return ReadBlockPhys(lbNum, 1, window) &&
           ReadBlockPhys(LogSector(folder.Ext[e1].Location, folder.Ext[e1].Partition) + (Uint32)b1, 1,
                         window + SECTOR_SIZE);
}

// feature 400: out of memory in the walk - no later folder is descended (as every failure did before), the
// walk's one box
void CUDF::WalkOutOfMemory()
{
    Walk.Stopped = true;
    Error(IDS_INSUFFICIENT_MEMORY, SalIsoWalkBoxQuiet(Walk, false));
}

// feature 400: the walk meets the folder whose file entry 'icb' names - 1 the first time, 0 met again in this
// walk (not descended: listed empty, not marked - CISO9660's rule, 328), -1 out of memory
int CUDF::VisitFolder(const CAD& icb)
{
    if (Visited == NULL)
        return 1;
    try
    {
        return Visited->insert(((unsigned long long)icb.Partition << 32) | icb.Location).second ? 1 : 0;
    }
    catch (...)
    {
        WalkOutOfMemory();
        return -1;
    }
}

int CUDF::ScanDir(const CUDFFolder& folder, char* path,
                  CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData)
{
    char fileName[MAX_UDF_FILE_NAME_LEN + 1];
    Uint8 directory[2 * SECTOR_SIZE];
    Uint32 lbNum;
    Uint8 fileChar;
    unsigned int p;

    // Scan dir for ICB of file
    // feature 364: through every walked extent (the first extent's blocks only before)
    Uint32 block = 0; // the window's first block in the folder
    if (!ReadFolderWindow(folder, block, directory, lbNum))
    {
        Error(IDS_ERROR_LISTING_IMAGE, SalIsoWalkBoxQuiet(Walk, false), lbNum); // feature 400: once
        // if we are reading from the root (lbNum == 2), return ERR_CONTINUE so we can descend into an empty image
        // we try to behave consistently from the user's point of view
        // TODO: better detection of whether the sector being read is the root
        return lbNum == 2 ? ERR_CONTINUE : ERR_TERMINATE;
    }

    int ret = ERR_OK;
    CDescriptorTag tag;
    p = folder.Offset;
    unsigned long long end = folder.Offset + folder.Length; // the walk's end in window positions
    while (p < end && ret != ERR_TERMINATE)
    {
        if (p > SECTOR_SIZE)
        {
            ++block;
            p -= SECTOR_SIZE;
            end -= SECTOR_SIZE;
            if (!ReadFolderWindow(folder, block, directory, lbNum))
            {
                Error(IDS_ERROR_LISTING_IMAGE, SalIsoWalkBoxQuiet(Walk, false), lbNum); // feature 400: once
                return ERR_TERMINATE;
            }
        } // if

        ReadDescriptorTag(directory + p, &tag);
        if (UDF_TAGID_FID == tag.ID)
        {
            CAD icb;
            // p <= SECTOR_SIZE: the 38-byte head lies in the buffer; feature 363: an identifier that does not lie
            // whole in it is refused like an invalid tag - the walk ends, the listing is incomplete (feature 330)
            int fidLen = ReadFileIdentifier(directory + p, (unsigned int)(sizeof(directory) - p), &fileChar, fileName, &icb);
            if (fidLen == 0)
            {
                Error(IDS_UDF_INVALID_TAG_ID, SalIsoWalkBoxQuiet(Walk, false)); // feature 400: once
                return ERR_CONTINUE;
            }
            p += fidLen;

            if (!(fileChar & UDF_PARENT))
            {
                MakeSafeName(fileName, sizeof(fileName)); // feature 327: listed and descended with
                int added = AddFileDir(path, fileName, fileChar, &icb, dir, pluginData);
                if (added == ADD_FAILED)
                    return ERR_TERMINATE;

                // feature 329: a left-out entry is skipped alone - a left-out folder is not descended
                if (added == ADD_LISTED && (fileChar & UDF_DIRECTORY))
                {
                    char newPath[4 * MAX_PATH + 2]; // feature 222: path + a name of up to 3 * MAX_PATH bytes
                    ZeroMemory(newPath, sizeof(newPath));
                    strcpy(newPath, path);
                    strcat(newPath, "\\");
                    strcat(newPath, fileName);

                    // feature 400: descended also after a folder that could not be read ("descend when
                    // everything is OK" listed every later folder empty) - only out of memory stops the walk;
                    // a failure below keeps this directory incomplete; a folder met again in this walk is
                    // listed empty (a crafted image: a folder inside itself)
                    int visit = SalIsoWalkDescends(Walk) ? VisitFolder(icb) : 0;
                    if (visit < 0)
                        ret = SalIsoWalkAfterChild(ret, ERR_TERMINATE);
                    else if (visit > 0)
                    {
                        CUDFFolder sub;
                        CICBTag icbTag;
                        if (MapICB(icb, &icbTag, &sub))
                        {
                            // feature 364: a sub-folder read short of its Information Length - as the root
                            if (!sub.Whole)
                                Image->ListingLeftOut.SetIncomplete();
                            ret = SalIsoWalkAfterChild(ret, ScanDir(sub, newPath, dir, pluginData));
                        }
                        else
                        {
                            // feature 330: the folder's file entry cannot be read - it was listed empty without
                            // a word; its contents are missing, so a whole unpack fails
                            Image->ListingLeftOut.SetIncomplete();
                        }
                    }
                }
            }
        }
        else
        {
            Error(IDS_UDF_INVALID_TAG_ID, SalIsoWalkBoxQuiet(Walk, false)); // feature 400: once
            return ERR_CONTINUE;
        } // if
    } // while

    return ret;
}

int CUDF::UnpackFile(CSalamanderForOperationsAbstract* salamander, const char* srcPath, const char* path,
                     const char* nameInArc, const CFileData* fileData, DWORD& silent, BOOL& toSkip)
{
    CALL_STACK_MESSAGE7("CUDF::UnpackFile( , %s, %s, %s, %p, %u, %d)", srcPath, path, nameInArc, fileData, silent, toSkip);

    // TODO: extraction according to allocation strategy 4096
    // if the file is a sequence of allocation descriptors, we cannot extract it because we would need to track
    // where the allocation descriptors point and use the correct blocks (we have no image to test on,
    // so it is not implemented, maybe someday)

    if (fileData == NULL)
        return UNPACK_ERROR;

    BOOL ret = UNPACK_OK;
    BYTE* sector = NULL;
    BYTE* fileEntry = NULL;
    try
    {
        fileEntry = new BYTE[SECTOR_SIZE];
        if (!fileEntry)
        {
            Error(IDS_INSUFFICIENT_MEMORY, silent == 1);
            throw UNPACK_CANCEL;
        }

        CISOImage::CFilePos* fp = (CISOImage::CFilePos*)fileData->PluginData;
        // read File Entry
        CDescriptorTag tag;
        DWORD extent = fp->Extent - ExtentOffset; // ExtentOffset was added to detect track #
        DWORD lbNum = LogSector(extent, fp->Partition);
        /*
    char u[1024];
    sprintf(u, "CUDF::UnpackFile(): Extent: 0x%X, lbNum: 0x%X", fp->Extent, lbNum);
    TRACE_I(u);
*/
        if (!ReadBlockLog(lbNum, 1, fileEntry))
        {
            delete[] fileEntry;
            Error(IDS_ERROR_READING_SECTOR, silent == 1, lbNum);
            throw UNPACK_ERROR;
        }
        ReadDescriptorTag(fileEntry, &tag);

        if ((UDF_TAGID_FENTRY != tag.ID) && (UDF_TAGID_EXTFENTRY != tag.ID))
        {
            delete[] fileEntry;
            Error(IDS_UDF_INVALID_TAG_ID, silent == 1);
            throw UNPACK_ERROR;
        }

        CICBTag icbTag;
        CAD icbs[32]; // Each ICB can describe at most 1GB-1B
        // -> 9 ICB's should be enough for a DVD9, but we are paranoic

        int nicbs = ReadFileEntry(fileEntry, UDF_TAGID_EXTFENTRY == tag.ID, fp->Partition, &icbTag, icbs, sizeof(icbs) / sizeof(CAD));

        // No longer needed
        delete[] fileEntry;
        fileEntry = NULL;

        // feature 361: a refused entry (a reserved descriptor type hung the walk, a descriptor area past the
        // sector was read past the buffer) - the file is not extracted, the unpack fails (the image is kept)
        if (nicbs == UDF_FE_REFUSED)
        {
            Error(IDS_UDF_ICB_AND_FILESIZE_MISMATCH, silent == 1, fileData->Name);
            throw UNPACK_ERROR;
        }

        // Verify that the icbs describe as many bytes as needed by the file
        ULONGLONG acc = 0;
        if (-1 == nicbs)
        {
            // File data is inlined in file entry
            nicbs = 1;
            icbs[0].Location = lbNum;
        }
        int i;
        for (i = 0; i < nicbs; i++)
        {
            if (UDF_EXT_ALLOCATED != icbs[i].Flags)
                continue;
            acc += icbs[i].Length;
        }
        if (acc != fileData->Size.Value)
        {
            Error(IDS_UDF_ICB_AND_FILESIZE_MISMATCH, silent == 1, fileData->Name);
            throw UNPACK_ERROR;
        }

        if (icbTag.Strategy != 4)
        {
            Error(IDS_UDF_UNKNOWN_ALLOCATION_STRATEGY, silent == 1, icbTag.Strategy);
            throw UNPACK_ERROR;
        }

        // unpack file
        sector = new BYTE[SECTOR_SIZE];
        if (!sector)
        {
            Error(IDS_INSUFFICIENT_MEMORY, silent == 1);
            throw UNPACK_CANCEL;
        }

        // the target path is UTF-8 and may be long (interface 104) -> heap buffer
        CU8PathBuf name;
        if (!name.IsOk())
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            throw UNPACK_ERROR;
        }
        lstrcpyn(name, path, U8_MAX_PATH);
        if (!AppendSafeName(name, fileData->Name, U8_MAX_PATH)) // feature 327: made safe again
        {
            Error(IDS_ERR_TOO_LONG_NAME, silent == 1);
            throw UNPACK_ERROR;
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
            throw UNPACK_ERROR;

        // the overall operation cannot continue any further: cancel
        if (hFile == INVALID_HANDLE_VALUE)
            throw UNPACK_CANCEL;

        BOOL bFileComplete = TRUE;

        // Loop over all ICB's
        CAD* picb = icbs;
        for (; (nicbs-- > 0) && bFileComplete; picb++)
        {
            if (UDF_EXT_ALLOCATED != picb->Flags)
                continue; // Skip unused blocks

            // ICB & data can be located in different tracks
            BYTE track = Image->GetTrackFromExtent(picb->Location);
            DWORD extentOfs = Image->GetTrack(track)->ExtentOffset;

            // it is necessary to open the track we will read from (setting the track parameters)
            if (!Image->OpenTrack(track))
            {
                Error(IDS_CANT_OPEN_TRACK, silent == 1, track);
                throw UNPACK_ERROR;
            }

            DWORD block = picb->Location - extentOfs; // use the extent from the track where the file is stored
            DWORD remain = picb->Length;

            /*
      char u[1024];
      sprintf(u, "CUDF::UnpackFile(): opening Extent: 0x%X", block);
      TRACE_I(u);
*/

            DWORD nbytes = SECTOR_SIZE;
            while (remain > 0)
            {
                if (remain < nbytes)
                    nbytes = remain;

                if (!ReadBlockPhys(block, 1, sector))
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

                if (!salamander->ProgressAddSize(nbytes, TRUE)) // delayedPaint==TRUE, to make things faster
                {
                    salamander->ProgressDialogAddText(LoadStr(IDS_CANCELING_OPERATION), FALSE);
                    salamander->ProgressEnableCancel(FALSE);

                    ret = UNPACK_CANCEL;
                    bFileComplete = FALSE;
                    break; // action interrupted
                }

                ULONG written;
                // picb->Offset is nonzero only for small (less than a sector) files inlined within File Entry
                if (!file.Write(sector + picb->Offset, nbytes, &written, name, NULL))
                {
                    // Error message was already displayed by SafeWriteFile()
                    ret = UNPACK_CANCEL;
                    bFileComplete = FALSE;
                    break;
                }
                remain -= nbytes;
                block++;
            } // while (remain > 0)
        } // while over all ICB's

        //    sprintf(u, "CISOImage::UnpackFile(): ret: %d, bFileComplete: %d", ret, bFileComplete);
        //    TRACE_I(u);

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
                Error(LoadStrU8(IDS_CANT_SET_ATTRS), GetLastError(), silent == 1);

            // the user cancelled the operation
            // delete the incomplete file afterwards
            if (!DeleteFileU8(name))
                Error(LoadStrU8(IDS_CANT_DELETE_TEMP_FILE), GetLastError(), silent == 1);
        }
        else
            SetFileAttrs(name, attrs, silent == 1);

        // feature 338: a read error met without a box (after Skip all) left 'ret' at UNPACK_OK
        ret = SalIsoFileUnpackResult(ret, bFileComplete);
    }
    catch (int e)
    {
        ret = e;
    }

    delete[] sector;

    return ret;
}

BOOL CUDF::DumpInfo(FILE* outStream)
{
    CALL_STACK_MESSAGE1("CUDF::DumpInfo( )");

    char buffer[1024], *s; // DecodeOSTACompressed() now emits UTF-8 (up to 3 bytes/char)

    // display info from the PVD
    DecodeOSTACompressed((BYTE*)PVD.VolumeIdentifier, 32, buffer);
    fprintf(outStream, "    Volume:             %s\n", buffer);
    DecodeOSTACompressed((BYTE*)PVD.VolumeSetIdentifier, 128, buffer);
    fprintf(outStream, "    Volume Set:         %s\n", buffer);
    s = ViewerStrNcpy((char*)PVD.ApplicationIdentifier.Identifier, 23);
    if (*s)
        fprintf(outStream, "    Application:        %s\n", s);
    s = ViewerStrNcpy((char*)PVD.ImplementationIdentifier.Identifier, 23);
    if (*s)
        fprintf(outStream, "    Implementation:     %s\n", s);
    //  fprintf(outStream, "\n");

    SYSTEMTIME st;
    UDFTimeStampToSystemTime(PVD.RecordingDateandTime, &st);
    if (st.wYear != 0)
        fprintf(outStream, "    Recording Date:     %s\n", ViewerPrintSystemTime(&st));

    return TRUE;
}

int CUDF::ReadVAT(BYTE fileEntry[], bool bEFE, BYTE** vat, DWORD* vatLength, BOOL quiet)
{
    CALL_STACK_MESSAGE1("CUDF::ReadVAT(, , , )");

    CFileEntry fe;
    ReadFileEntry(fileEntry, bEFE, &fe);

    Uint16 entries = fe.ICBTag.Entries;
    Uint16 strategy = fe.ICBTag.Strategy;
    Uint32 dataLength = fe.L_AD;
    Uint8 addrType = fe.ICBTag.Flags & 0x03;

    Uint32 directEntries, indirectEntries;
    switch (strategy)
    {
    case 0:
    case 1:
    case 2:
    case 3:
        Error(IDS_UDF_UNKNOWN_ALLOCATION_STRATEGY, quiet, strategy);
        return ERR_TERMINATE;

    case 4:
        directEntries = dataLength;
        indirectEntries = 0;
        break;

    case 4096:
        directEntries = fe.ICBTag.StrategyParametr;
        indirectEntries = 1;
        Error(IDS_UDF_UNKNOWN_ALLOCATION_STRATEGY, quiet, strategy);
        return ERR_TERMINATE;

    default:
        Error(IDS_UDF_UNKNOWN_ALLOCATION_STRATEGY, quiet, strategy);
        return ERR_TERMINATE;
    } // switch

    // feature 360: the table's length is the file's information length, never cut to 32 bits; the descriptors'
    // area lies in the 2048-byte sector (the reader took it in 32 bits without a bound); a reserved descriptor
    // type has no descriptor to read - otherwise this entry is not a VAT (the search goes on, feature 358)
    unsigned long length;
    unsigned long long areaFirst, areaEnd;
    if (!SalIsoUdfVatTableLength(fe.InformationLength, length) ||
        !SalIsoUdfVatDescArea(SECTOR_SIZE, bEFE, fe.L_EA, fe.L_AD, areaFirst, areaEnd) ||
        SalIsoUdfVatDescSize(fe.ICBTag.Flags & 0x0007) < 0)
    {
        return ERR_CONTINUE;
    }

    *vatLength = length;
    *vat = new BYTE[length];
    if (*vat == NULL)
    {
        Error(IDS_INSUFFICIENT_MEMORY, quiet);
        return ERR_TERMINATE;
    }

    DWORD offset = (DWORD)areaFirst, end = (DWORD)areaEnd;

    DWORD o = 0;
    while (offset < end)
    {
        int ret = ReadAllocDesc(fileEntry + offset, end - offset, &fe, *vat, length, &o);

        if (ret < 0)
        {
            delete[] *vat;
            *vat = NULL;
            return ERR_CONTINUE;
        }
        offset += ret;
    }

    return ERR_OK;
}

int CUDF::CheckForVAT(BYTE sector[], bool bEFE, CPartitionMapping* pm, BOOL quiet)
{
    CALL_STACK_MESSAGE1("CUDF::CheckForVAT(, , )");

    CICBTag icbTag;
    DWORD vatLen;
    BYTE* vat = NULL;
    int ret;

    ReadICBTag(sector + 16, &icbTag);
    if (icbTag.FileType == 248)
    {
        // VAT in UDF 2.00+
        CFileEntry fe;
        ReadFileEntry(sector, bEFE, &fe);
        if ((ret = ReadVAT(sector, bEFE, &vat, &vatLen, quiet)) != ERR_OK)
            return ret;

        // decode VAT header
        // feature 358: the header length comes from the table - a table too short to hold it, or a header
        // longer than the file (the count wrapped and Translation pointed past the table), is not a VAT
        unsigned long long entries;
        if (vatLen < 2 || !SalIsoUdfVat200Entries(fe.InformationLength, GET_WORD(vat, 0), vatLen, entries))
        {
            delete[] vat;
            return ERR_CONTINUE;
        }
        WORD l_hd = GET_WORD(vat, 0);

        pm->Entries = entries; // definition: (InformationLength - l_hd) / 4
        pm->Length = vatLen;
        pm->Translation = (DWORD*)(vat + l_hd);
        pm->VAT = vat;
    }
    else if (icbTag.FileType == 0)
    {
        if ((ret = ReadVAT(sector, bEFE, &vat, &vatLen, quiet)) != ERR_OK)
            return ret;

        // check the old UDF 1.50 VAT
        Uint32 entries = (vatLen - 36) / 4; // definition

        if (entries * 4 >= vatLen)
        {
            delete[] vat;
            return ERR_CONTINUE;
        }

        CEntityID entityID;
        ReadEntityID(vat + (entries * 4), &entityID);
        if (strncmp(entityID.Identifier, "*UDF Virtual Alloc Tbl", 22) != 0)
        {
            delete[] vat;
            return ERR_CONTINUE;
        }

        // VAT in UDF 1.50
        pm->Entries = entries;
        pm->Length = vatLen;
        pm->Translation = (DWORD*)vat;
        pm->VAT = vat;
    }
    else
        return ERR_CONTINUE;

    return ERR_OK;
}

BOOL CUDF::ReadSupportingTables(BOOL quiet)
{
    CALL_STACK_MESSAGE1("CUDF::ReadSupportingTables( )");

    DWORD vatLoc, lastVatLoc;
    bool fallbackTaken;
    BYTE sector[SECTOR_SIZE];
    CDescriptorTag tag;
    BOOL ret = TRUE;
    int vatRet;

    int i;
    for (i = 0; i < PartitionMaps.Count; i++)
    {
        switch (PartitionMaps[i]->Type)
        {
        case mapPhysical:
            break;

        case mapVirtual:
            vatLoc = PD.Length - ExtentOffset;
            /*
        {
        char u[1024];
        sprintf(u, "CUDF::ReadSupportingTables(): vatLoc: 0x%X", vatLoc);
        TRACE_I(u);
        }
*/
            lastVatLoc = vatLoc + 7;
            vatLoc -= 7;

            vatRet = ERR_CONTINUE;
            fallbackTaken = false;
            do
            {
                if (!ReadBlockPhys(vatLoc, 1, sector))
                {
                    LONGLONG size;

                    size = Image->GetCurrentTrackEnd(TrackTryingToOpen);
                    if (size != 0xFFFFFFFFFFFFFFFF && size >= 0)
                    {
                        // feature 359: the track's last sectors are searched once, without a wrapped window
                        // (a failed read there used to set the same window again for ever)
                        unsigned long long first, last;
                        if (SalIsoUdfVatFallback((unsigned long long)size / SECTOR_SIZE, PD.Start, ExtentOffset,
                                                 vatLoc, fallbackTaken, first, last))
                        {
                            fallbackTaken = true;
                            vatLoc = (DWORD)first;
                            lastVatLoc = (DWORD)last;
                            continue;
                        }
                    }

                    VatMissing = TRUE; // feature 358: see udf.h
                    return Error(IDS_UDF_ERROR_READING_VAT, quiet, vatLoc);
                }

                ReadDescriptorTag(sector, &tag);
                if ((UDF_TAGID_FENTRY == tag.ID) || (UDF_TAGID_EXTFENTRY == tag.ID))
                {
                    vatRet = CheckForVAT(sector, UDF_TAGID_EXTFENTRY == tag.ID, &PartitionMapping, quiet);
                    if (vatRet == ERR_OK)
                        ret = TRUE;
                    if (vatRet == ERR_TERMINATE)
                        break;
                }
                vatLoc++;
            } while (vatLoc < lastVatLoc && vatRet == ERR_CONTINUE);

            // feature 358: without its VAT no block of the volume can be found - the volume does not open
            // (as when the VAT sector cannot be read above), so the track or UDF part counts as not opened
            // and the listing is marked; it used to open without a table and LogSector read through NULL
            if (vatRet != ERR_OK)
            {
                VatMissing = TRUE;
                if (vatRet == ERR_CONTINUE)
                    Error(IDS_UDF_MISSING_VAT, quiet);
                return FALSE; // ERR_TERMINATE: the callee showed its message
            }
            break;

        case mapSparable:
            break;

        case mapMetadata:
        {
            // feature 377: read here, after the whole descriptor sequence (it was read while the logical volume
            // descriptor was parsed - before a partition descriptor that follows it, from PD.Start not yet set)
            Uint32 location = PartitionMaps[i]->MetadataFileLocation;
            CICBTag icbTag;

            if (!PartitionMaps[i]->HasMetadataFile)
                break; // an unrecognised map whose (unset) Type happens to read as mapMetadata: nothing read, as before

            if (!ReadBlockLog(location, 1, sector))
            {
                Error(IDS_ERROR_READING_SECTOR, false, location);
                break;
            }
            ReadDescriptorTag(sector, &tag);
            if ((UDF_TAGID_EXTFENTRY == tag.ID) || (UDF_TAGID_FENTRY == tag.ID))
            {
                // It is assumed that there is no more than 1 Metadata partition present
                int n = ReadFileEntry(sector, UDF_TAGID_EXTFENTRY == tag.ID, 0 /*??*/, &icbTag,
                                      PartitionMapping.MetadataICBs, sizeof(PartitionMapping.MetadataICBs) / sizeof(PartitionMapping.MetadataICBs[0]));
                // feature 361: a refused entry leaves no metadata extents (the walk hung on a reserved type)
                PartitionMapping.nMetadataICBs = n == UDF_FE_REFUSED ? 0 : n;
            }
            break;
        }
        } // switch
    } // loop over all partitions

    return ret;
}
