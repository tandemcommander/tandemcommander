// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "dbg.h"

#include "isoimage.h"

#include "uniso.h"
#include "uniso.rh"
#include "uniso.rh2"
#include "lang\lang.rh"

#define CCD_ROW_LEN 1024

struct TextRow
{
    char* Row;
    char *Id, *Value;

    TextRow(char* row)
    {
        Row = new char[strlen(row) + 1];
        strcpy(Row, row);

        Id = strtok(Row, "=");
        Value = strtok(NULL, "\n");
    }

    ~TextRow()
    {
        delete[] Row;
    }
};

enum ECCDType
{
    ccdNone,
    ccdHeader,
    ccdDisc,
    ccdSession,
    ccdEntry,
    ccdTrack
};

struct TextSection
{
    TIndirectArray<TextRow> Rows;
    ECCDType Type;

    TextSection(ECCDType type) : Rows(10, 5, dtDelete)
    {
        Type = type;
    }

    void Add(char* row)
    {
        Rows.Add(new TextRow(row));
    }
};

struct CCDSession
{
    int PreGapMode;
    int PreGapSubC;

    CCDSession(int preGapMode, int preGapSubC)
    {
        PreGapMode = preGapMode;
        PreGapSubC = preGapSubC;
    }
};

struct CCDTrack
{
    int Mode;
    int Index;

    CCDTrack(int mode, int index)
    {
        Mode = mode;
        Index = index;
    }
};

struct CCDEntry
{
    int Session; // feature 352: the whole value (a BYTE made 257 session 1); checked before use
    DWORD Point;
    DWORD PLBA;
    BYTE ADR;

    CCDEntry(int session, DWORD point, DWORD plba, BYTE adr)
    {
        Session = session;
        Point = point;
        PLBA = plba;
        ADR = adr;
    }
};

struct CCD
{
    TIndirectArray<CCDTrack> TrackArray;
    TIndirectArray<CCDEntry> EntryArray;
    TIndirectArray<CCDSession> SessionArray;
    BOOL DisplayMissingCCDWarning;
    // feature 352: the .ccd exists and was refused (IDS_CCD_BAD_FORMAT) - the image is then detected
    // without it and its listing marked incomplete; a missing .ccd is not refused
    BOOL Refused;

    CCD() : TrackArray(10, 5, dtDelete), EntryArray(100, 10, dtDelete), SessionArray(5, 2, dtDelete)
    {
        DisplayMissingCCDWarning = TRUE;
        Refused = FALSE;
    }
};

//

static BOOL
processHeaderSection(TextSection* section)
{
    CALL_STACK_MESSAGE1("processHeaderSection()");

    int i;
    for (i = 0; i < section->Rows.Count; i++)
    {
        //    TextRow *row = section->Rows[i];
        if (section->Rows[i]->Id != NULL && strcmp(section->Rows[i]->Id, "Version") == 0) // feature 352: "=" has no name
        {
        }
    }

    return TRUE;
}

static BOOL
processDiscSection(TextSection* section, CCD* ccd)
{
    CALL_STACK_MESSAGE1("processDiscSection(, )");

    int tocEntries, sessions;

    int i;
    for (i = 0; i < section->Rows.Count; i++)
    {
        if (section->Rows[i]->Id == NULL || section->Rows[i]->Value == NULL) // feature 352: "=" / "Sessions="
            continue;
        if (strcmp(section->Rows[i]->Id, "TocEntries") == 0)
        {
            sscanf(section->Rows[i]->Value, "%d", &tocEntries);
        }
        else if (strcmp(section->Rows[i]->Id, "Sessions") == 0)
        {
            sscanf(section->Rows[i]->Value, "%d", &sessions);
        }
    }

    return TRUE;
}

static BOOL
processTrackSection(TextSection* section, CCD* ccd)
{
    CALL_STACK_MESSAGE1("processTrackSection(, )");

    // feature 352: a row counts only when its value parses, each needed row once (salisotrack.h) - a row
    // repeated while another was missing, or MODE=x, left a field uninitialised
    int mode = 0, index = 0;
    CSalIsoCcdFields fields;

    int i;
    for (i = 0; i < section->Rows.Count; i++)
    {
        const char* id = section->Rows[i]->Id;
        if (id == NULL) // a row with no name ("=...")
            continue;
        if (strcmp(id, "MODE") == 0)
            fields.Row(1, SalIsoCcdReadInt(section->Rows[i]->Value, false, mode));
        else if (strncmp(id, "INDEX 1", 7) == 0)
            fields.Row(2, SalIsoCcdReadInt(section->Rows[i]->Value, false, index));
    }

    if (fields.Complete(1 | 2))
    {
        ccd->TrackArray.Add(new CCDTrack(mode, index));
        return TRUE;
    }
    else
        return FALSE;
}

static BOOL
processEntrySection(TextSection* section, CCD* ccd)
{
    CALL_STACK_MESSAGE1("processEntrySection(, )");

    // feature 352: each needed row once and parsed (see processTrackSection)
    int session = 0, point = 0, plba = 0, adr = 0;
    CSalIsoCcdFields fields;

    int i;
    for (i = 0; i < section->Rows.Count; i++)
    {
        const char* id = section->Rows[i]->Id;
        if (id == NULL)
            continue;
        if (strcmp(id, "Session") == 0)
            fields.Row(1, SalIsoCcdReadInt(section->Rows[i]->Value, false, session));
        else if (strcmp(id, "Point") == 0)
            fields.Row(2, SalIsoCcdReadInt(section->Rows[i]->Value, true, point));
        else if (strcmp(id, "PLBA") == 0)
            fields.Row(4, SalIsoCcdReadInt(section->Rows[i]->Value, false, plba));
        else if (strcmp(id, "ADR") == 0)
            fields.Row(8, SalIsoCcdReadInt(section->Rows[i]->Value, true, adr));
    }

    if (fields.Complete(1 | 2 | 4 | 8))
    {
        ccd->EntryArray.Add(new CCDEntry(session, (DWORD)point, (DWORD)plba, (BYTE)adr));
        return TRUE;
    }
    else
        return FALSE;
}

static BOOL
processSessionSection(TextSection* section, CCD* ccd)
{
    CALL_STACK_MESSAGE1("processSessionSection(, )");

    // feature 352: each needed row once and parsed (see processTrackSection)
    int preGapMode = 0, preGapSubC = 0;
    CSalIsoCcdFields fields;

    int i;
    for (i = 0; i < section->Rows.Count; i++)
    {
        const char* id = section->Rows[i]->Id;
        if (id == NULL)
            continue;
        if (strcmp(id, "PreGapMode") == 0)
            fields.Row(1, SalIsoCcdReadInt(section->Rows[i]->Value, false, preGapMode));
        else if (strcmp(id, "PreGapSubC") == 0)
            fields.Row(2, SalIsoCcdReadInt(section->Rows[i]->Value, false, preGapSubC));
    }

    if (fields.Complete(1 | 2))
    {
        ccd->SessionArray.Add(new CCDSession(preGapMode, preGapSubC));
        return TRUE;
    }
    else
        return FALSE;
}

static BOOL
processTextSection(TextSection* section, CCD* ccd)
{
    CALL_STACK_MESSAGE1("processTextSection(, )");

    if (section == NULL)
        return FALSE;

    switch (section->Type)
    {
    case ccdHeader:
        return processHeaderSection(section);
    case ccdDisc:
        return processDiscSection(section, ccd);
    case ccdSession:
        return processSessionSection(section, ccd);
    case ccdEntry:
        return processEntrySection(section, ccd);
    case ccdTrack:
        return processTrackSection(section, ccd);
    } // switch

    return TRUE;
}

BOOL CISOImage::CheckForBootSectorOrMBR()
{
    BYTE buf[512];

    if (512 == ReadDataByPos(0, 512, buf))
    {
        if (((buf[0] == 0xEB) || (buf[0] == 0xE9) || (buf[0] == 0xFA)) && (buf[0x1FE] == 0x55) && (buf[0x1FF] == 0xAA))
        {
            // Looks like a Boot record or Master Boot Record
            return TRUE;
        }
    }
    return FALSE;
}

static BOOL
processCCDFile(CISOImage* pISOImage, CFile& File, const char* fileName, CCD* ccd, BOOL quiet /* = FALSE*/)
{
    CALL_STACK_MESSAGE3("processCCDFile(%s, , %d)", fileName, quiet);

    if (fileName == NULL)
        return FALSE;

    FILE* f = NULL;
    TextSection* textSection = NULL;
    TIndirectArray<TextSection> sections(100, 50, dtDelete);

    BOOL ret = TRUE;
    // 'fileName' derives from the image path: UTF-8 since interface 104 -> W CRT API
    WCHAR* wFileName = SplU8ToWExtAlloc(fileName);
    f = wFileName != NULL ? _wfopen(wFileName, L"r") : NULL;
    free(wFileName);
    if (f == NULL)
    {
        if (ccd->DisplayMissingCCDWarning)
        {
            if (!pISOImage->CheckForBootSectorOrMBR())
            {
                Warning(IDS_CCD_MISSING, quiet);
            }
            ccd->DisplayMissingCCDWarning = FALSE; // do not display the warning any more
        }
        return FALSE;
    }

    char row[CCD_ROW_LEN];
    while (fgets(row, CCD_ROW_LEN, f) != NULL)
    {
        // remove trailing \n
        char* n = strchr(row, '\n');
        if (n != NULL)
            *n = '\0';

        // skip empty rows
        if (strlen(row) == 0)
            continue;

        if (strncmp(row, "[", 1) == 0)
        {
            ECCDType type = ccdNone;
            if (strncmp(row, "[CloneCD]", 9) == 0)
                type = ccdHeader;
            else if (strncmp(row, "[Disc]", 9) == 0)
                type = ccdDisc;
            else if (strncmp(row, "[Session ", 9) == 0)
                type = ccdSession;
            else if (strncmp(row, "[Entry ", 7) == 0)
                type = ccdEntry;
            else if (strncmp(row, "[TRACK ", 7) == 0)
                type = ccdTrack;

            if (type != ccdNone)
            {
                textSection = new TextSection(type);
                if (textSection == FALSE)
                {
                    fclose(f);
                    return Error(IDS_INSUFFICIENT_MEMORY, quiet);
                }
                sections.Add(textSection);
            }
            else
                textSection = NULL;
        }
        else
        {
            if (textSection != NULL)
                textSection->Add(row);
        }
    } // while

    fclose(f);

    if (sections.Count > 0)
    {
        BOOL validCCD = TRUE;
        int i;
        for (i = 0; i < sections.Count; i++)
        {
            textSection = sections[i];
            if (!processTextSection(textSection, ccd))
            {
                validCCD = FALSE;
                break;
            }
        }

        if (validCCD)
            ret = TRUE;
        else
        {
            ccd->Refused = TRUE; // feature 352: the listing is marked (ReadSessionCCD)
            ret = Error(IDS_CCD_BAD_FORMAT, quiet);
        }
    }
    else
    {
        ccd->Refused = TRUE;
        ret = Error(IDS_CCD_BAD_FORMAT, quiet);
    }

    return ret;
}

BOOL CISOImage::ReadSessionCCD(char* fileName, BOOL quiet /* = FALSE*/)
{
    CALL_STACK_MESSAGE3("CISOImage::ReadSessionCCD(%s, %d)", fileName, quiet);

    BOOL ret = TRUE;

    // process read info
    CCD* ccd = new CCD;
    ccd->DisplayMissingCCDWarning = DisplayMissingCCDWarning;
    if (ccd == NULL)
        return Error(IDS_INSUFFICIENT_MEMORY, quiet);

    if (processCCDFile(this, *File, fileName, ccd, quiet))
    {
        // feature 352: every entry must name one of the [Session n] sections - its session indexes the
        // per-session tables below (Session=0 wrote before them, Session=200 far past them); checked
        // for all entries before anything is built, a .ccd naming another session is refused
        BOOL entriesValid = TRUE;
        int e;
        for (e = 0; e < ccd->EntryArray.Count; e++)
        {
            if (SalIsoCcdSessionIndex(ccd->EntryArray[e]->Session, ccd->SessionArray.Count) < 0)
            {
                TRACE_I("CISOImage::ReadSessionCCD(): entry " << e << " names session " << ccd->EntryArray[e]->Session
                                                              << ", the .ccd has " << ccd->SessionArray.Count);
                entriesValid = FALSE;
                break;
            }
        }

        if (entriesValid && ccd->SessionArray.Count > 0 && ccd->TrackArray.Count > 0 && ccd->EntryArray.Count > 0)
        {
            // process read ccd info
            int i;

            DWORD* pointMin = NULL;
            DWORD* pointMax = NULL;
            DWORD* extents = NULL;
            DWORD* extentsEnd = NULL;

            try
            {
                pointMin = new DWORD[ccd->SessionArray.Count];
                if (pointMin == NULL)
                    throw Error(IDS_INSUFFICIENT_MEMORY, quiet);
                pointMax = new DWORD[ccd->SessionArray.Count];
                if (pointMax == NULL)
                    throw Error(IDS_INSUFFICIENT_MEMORY, quiet);
                extents = new DWORD[ccd->SessionArray.Count];
                if (extents == NULL)
                    throw Error(IDS_INSUFFICIENT_MEMORY, quiet);
                extentsEnd = new DWORD[ccd->SessionArray.Count];
                if (extentsEnd == NULL)
                    throw Error(IDS_INSUFFICIENT_MEMORY, quiet);

                // the extent within the session is counted from zero
                // if the session contains multiple tracks, the track's extent is stored in ccdtrk->Index

                // build track info
                for (i = 0; i < ccd->TrackArray.Count; i++)
                {
                    CCDTrack* ccdtrk = ccd->TrackArray[i];

                    CISOImage::Track* track = new CISOImage::Track;
                    if (track == NULL)
                        throw Error(IDS_INSUFFICIENT_MEMORY, quiet);

                    track->SectorSize = 2048;
                    // CCD track modes; feature 351: a data track gets a data type (Open detects its file
                    // system and replaces it - the value the NRG reader gives a data track) - it kept the
                    // heap's, in Release often "unknown" (the image did not open); another mode stays
                    // unknown (the constructor's mNone / fsUnknown)
                    switch (SalIsoCcdTrackKind(ccdtrk->Mode))
                    {
                    case SAL_ISO_TRACK_AUDIO:
                        track->Mode = mNone;
                        track->FSType = fsAudio;
                        break;
                    case SAL_ISO_TRACK_DATA:
                        track->Mode = ccdtrk->Mode == 1 ? mMode1 : mMode2;
                        track->FSType = fsISO9660;
                        break;
                    }
                    track->Start = 0x00;
                    track->End = 0x00;
                    track->ExtentOffset = ccdtrk->Index; // track extent within the session
                    AddTrack(track);
                } // for

                // count tracks for each session
                int firstTrack = 0;
                for (i = 1; i < ccd->TrackArray.Count; i++)
                {
                    CCDTrack* track = ccd->TrackArray[i];
                    if (track->Index == 0)
                    {
                        AddSessionTracks(i - firstTrack);
                        firstTrack = i;
                    }
                } // for
                AddSessionTracks(ccd->TrackArray.Count - firstTrack);

                // feature 352: the session layout is trusted only when the [Session n] sections and the
                // splits above agree (a real multi-session dump with absolute INDEX 1 values has one
                // split); otherwise every loop stays within its own count and the listing is marked
                // incomplete (a whole unpack fails, the image is kept)
                if (!SalIsoCcdLayoutTrusted(ccd->SessionArray.Count, Session.Count))
                {
                    TRACE_I("CISOImage::ReadSessionCCD(): " << ccd->SessionArray.Count << " session sections, "
                                                            << Session.Count << " track splits");
                    ListingLeftOut.SetIncomplete();
                }

                // set sector format for tracks in session (feature 352: over the splits - it went over
                // the [Session n] sections and read Session[i] past the split list)
                firstTrack = 0;
                for (i = 0; i < Session.Count; i++)
                {
                    WORD sectorSize = 0x930;

                    int j;
                    for (j = 0; j < Session[i]; j++)
                    {
                        CISOImage::Track* track = Tracks[firstTrack + j];
                        track->SectorSize = sectorSize;
                        track->SectorHeaderSize = CISOImage::GetHeaderSizeFromMode(track->Mode, track->SectorSize);
                    }

                    firstTrack += Session[i];
                }

                // set ExtentOffset in sessions
                for (i = 0; i < ccd->SessionArray.Count; i++)
                {
                    pointMin[i] = 0xFFFFFFFF;
                    pointMax[i] = 0x00000000;
                    extents[i] = 0;
                    extentsEnd[i] = 0;
                }

                for (i = 0; i < ccd->EntryArray.Count; i++)
                {
                    CCDEntry* entry = ccd->EntryArray[i];
                    int session = SalIsoCcdSessionIndex(entry->Session, ccd->SessionArray.Count); // checked above
                    if (entry->ADR == 1 && entry->Point < pointMin[session])
                    {
                        pointMin[session] = entry->Point;
                        extents[session] = entry->PLBA;
                    }

                    if (entry->ADR == 1 && entry->Point > pointMax[session])
                    {
                        pointMax[session] = entry->Point;
                        extentsEnd[session] = entry->PLBA;
                    }
                }

                LONGLONG start = 0x0;
                firstTrack = 0;
                for (i = 0; i < Session.Count; i++)
                {
                    // feature 352: a split takes its offsets from its [Session n] section's row only when
                    // the .ccd has that section (it read extents[i] past the tables); none: 0 (the
                    // listing is marked above)
                    int row = SalIsoCcdSplitSection(i, ccd->SessionArray.Count);
                    DWORD extent = row >= 0 ? extents[row] : 0;
                    DWORD extentEnd = row >= 0 ? extentsEnd[row] : 0;

                    int j;
                    for (j = 0; j < Session[i]; j++)
                    {
                        CISOImage::Track* track = Tracks[firstTrack + j];
                        track->ExtentOffset += extent; // the extent is counted from zero within the session -> we want the absolute position in the image

                        DWORD endSector;
                        if (j < Session[i] - 1)
                            endSector = ccd->TrackArray[firstTrack + j + 1]->Index;
                        else
                            endSector = extentEnd - extent;

                        CCDTrack* ccdTrack = ccd->TrackArray[firstTrack + j];
                        DWORD sectorCount = endSector - ccdTrack->Index;
                        track->End = start + (track->SectorSize * sectorCount);
                        start = track->End;
                    }

                    firstTrack += Session[i];
                }

                for (i = 0; i < Tracks.Count - 1; i++)
                {
                    Tracks[i + 1]->Start = Tracks[i]->End;
                }
            }
            catch (BOOL e)
            {
                ret = e;
            }

            delete[] extents;
            delete[] extentsEnd;
            delete[] pointMin;
            delete[] pointMax;
        }
        else
        {
            ccd->Refused = TRUE;
            ret = Error(IDS_CCD_BAD_FORMAT, quiet);
        }
    }
    else
        ret = FALSE;

    // feature 352: a .ccd that exists but was refused leaves the image to the detection without it,
    // which lists the first session only - the listing is marked incomplete, so a whole unpack fails and
    // "Delete archive after unpacking" keeps the image (the box already says it could be incomplete)
    if (ccd->Refused)
        ListingLeftOut.SetIncomplete();

    DisplayMissingCCDWarning = ccd->DisplayMissingCCDWarning;
    delete ccd;

    return ret;
}
