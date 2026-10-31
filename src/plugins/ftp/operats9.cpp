// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later
// CommentsTranslationProject: TRANSLATED

#include "precomp.h"

#include "../../common/salnameorder.h"      // feature 277: the file system's name rule (the opened-file lock)
#include "../../common/salftpupname.h"      // feature 303: an upload's name that differs from a listed one only in case
#include "../../common/salftpmkdirreport.h" // feature 323: only the last component of a created path is new

#ifdef _DEBUG
int CUploadListingsOnServer::FoundPathIndexesInCache = 0; // how many searched paths the cache has caught
int CUploadListingsOnServer::FoundPathIndexesTotal = 0;   // total number of searched paths
#endif

//
// ****************************************************************************
// CUploadListingCache
//

CUploadChangeStamp::~CUploadChangeStamp()
{
    if (User != NULL)
        SalamanderGeneral->Free(User);
    if (Host != NULL)
        SalamanderGeneral->Free(Host);
}

CUploadListingCache::CUploadListingCache() : ListingsOnServer(5, 5), ChangeStamps(5, 5)
{
    ChangeStampsLost = FALSE;
    HANDLES(InitializeCriticalSection(&UploadLstCacheCritSect));
}

CUploadListingCache::~CUploadListingCache()
{
    HANDLES(DeleteCriticalSection(&UploadLstCacheCritSect));
}

BOOL CUploadListingCache::AddOrUpdateListing(const char* user, const char* host, unsigned short port,
                                             const char* path, CFTPServerPathType pathType,
                                             const char* pathListing, int pathListingLen,
                                             const CFTPDate& pathListingDate, DWORD listingStartTime,
                                             BOOL onlyUpdate, const char* welcomeReply,
                                             const char* systReply, const char* suggestedListingServerType)
{
    if (host == NULL)
    {
        TRACE_E("Unexpected situation in CUploadListingCache::AddOrUpdateListing()!");
        return FALSE;
    }
    BOOL ret = TRUE;
    if (user != NULL && strcmp(user, FTP_ANONYMOUS) == 0)
        user = NULL;
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    if (ChangedUnderOtherName(user, host, port, listingStartTime))
    { // feature 341 (review 2): the panel was not refreshed by that change - its listing is not
        // trusted; the upload lists the path itself
        HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
        return TRUE;
    }
    CUploadListingsOnServer* foundServer = FindServer(user, host, port, NULL);
    if (foundServer == NULL && !onlyUpdate) // the cache does not contain any path from this server yet; create an entry for the server
    {
        foundServer = new CUploadListingsOnServer(user, host, port);
        if (foundServer != NULL && foundServer->IsGood())
        {
            ListingsOnServer.Add(foundServer);
            if (!ListingsOnServer.IsGood())
            {
                ListingsOnServer.ResetState();
                delete foundServer;
                foundServer = NULL;
                ret = FALSE;
            }
        }
        else
        {
            if (foundServer != NULL)
            {
                delete foundServer;
                foundServer = NULL;
            }
            else
                TRACE_E(LOW_MEMORY);
            ret = FALSE;
        }
    }

    if (foundServer != NULL)
    {
        ret = foundServer->AddOrUpdateListing(path, pathType, pathListing, pathListingLen,
                                              pathListingDate, listingStartTime, onlyUpdate,
                                              welcomeReply, systReply, suggestedListingServerType);
    }
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
    return ret;
}

void CUploadListingCache::RemoveServer(const char* user, const char* host, unsigned short port)
{
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    int index;
    if (FindServer(user, host, port, &index) != NULL)
        ListingsOnServer.Delete(index);
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
}

void CUploadListingCache::RemoveNotAccessibleListings(const char* user, const char* host, unsigned short port)
{
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    CUploadListingsOnServer* foundServer = FindServer(user, host, port, NULL);
    if (foundServer != NULL)
        foundServer->RemoveNotAccessibleListings();
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
}

BOOL CUploadListingCache::SameIdentity(const char* entryUser, const char* entryHost, unsigned short entryPort,
                                       const char* user, const char* host, unsigned short port)
{
    if (entryUser != NULL && strcmp(entryUser, FTP_ANONYMOUS) == 0)
        entryUser = NULL;
    if (user != NULL && strcmp(user, FTP_ANONYMOUS) == 0)
        user = NULL;
    return entryPort == port && SalamanderGeneral->StrICmp(entryHost, host) == 0 &&
           (entryUser == NULL && user == NULL ||
            user != NULL && entryUser != NULL && strcmp(entryUser, user) == 0);
}

CUploadListingsOnServer*
CUploadListingCache::FindServer(const char* user, const char* host, unsigned short port, int* index)
{
    if (index != NULL)
        *index = -1;
    if (host == NULL)
    {
        TRACE_E("Unexpected situation in CUploadListingCache::FindServer()!");
        return FALSE;
    }
    int i;
    for (i = 0; i < ListingsOnServer.Count; i++)
    {
        CUploadListingsOnServer* server = ListingsOnServer[i];
        if (SameIdentity(server->User, server->Host, server->Port, user, host, port)) // server found
        {
            if (index != NULL)
                *index = i;
            return server;
        }
    }
    return NULL;
}

void CUploadListingCache::InvalidateOtherNamesOfServer(const char* user, const char* host, unsigned short port,
                                                       CUploadListingsOnServer* exact)
{
    if (host == NULL)
        return;
    if (user != NULL && strcmp(user, FTP_ANONYMOUS) == 0)
        user = NULL;
    StampChange(user, host, port); // review 2: also for a panel listing taken later (AddOrUpdateListing)
    // whether two connections reach one server and see the same folders cannot be told from the
    // client: neither equal nor different addresses prove it (a server answers on several
    // addresses - 127.0.0.1 and 127.0.0.2, its LAN and public address; a proxy hides the server's
    // address; review of 341), two accounts may share their folders (a shared home, "anonymous" and
    // a named account of a public folder) and two ports may reach one server (a forwarded port;
    // feature 345) - so every other connection is taken as maybe the same server
    int i;
    for (i = 0; i < ListingsOnServer.Count; i++)
    {
        CUploadListingsOnServer* server = ListingsOnServer[i];
        if (server != exact) // 'exact' is the only entry of this connection (FindServer)
            server->InvalidateAllListings();
    }
}

void CUploadListingCache::StampChange(const char* user, const char* host, unsigned short port)
{
    if (user != NULL && strcmp(user, FTP_ANONYMOUS) == 0)
        user = NULL;
    DWORD now = IncListingCounter();
    int i;
    for (i = 0; i < ChangeStamps.Count; i++)
    {
        CUploadChangeStamp* stamp = ChangeStamps[i];
        if (SameIdentity(stamp->User, stamp->Host, stamp->Port, user, host, port))
        {
            stamp->Time = now;
            return;
        }
    }
    if (ChangeStampsLost)
        return;
    if (ChangeStamps.Count >= 1000) // a bound: a session does not change that many servers
    {
        ChangeStampsLost = TRUE; // from now on every panel listing is refused (fails closed)
        return;
    }
    CUploadChangeStamp* stamp = new CUploadChangeStamp;
    if (stamp != NULL)
    {
        stamp->Host = SalamanderGeneral->DupStr(host);
        stamp->User = user != NULL ? SalamanderGeneral->DupStr(user) : NULL;
        stamp->Port = port;
        stamp->Time = now;
        if (stamp->Host != NULL && (user == NULL || stamp->User != NULL))
        {
            ChangeStamps.Add(stamp);
            if (ChangeStamps.IsGood())
                return;
            ChangeStamps.ResetState();
        }
        delete stamp;
    }
    TRACE_E(LOW_MEMORY);
    ChangeStampsLost = TRUE; // fails closed
}

BOOL CUploadListingCache::ChangedUnderOtherName(const char* user, const char* host, unsigned short port,
                                                DWORD listingStartTime)
{
    if (ChangeStampsLost)
        return TRUE;
    if (user != NULL && strcmp(user, FTP_ANONYMOUS) == 0)
        user = NULL;
    int i;
    for (i = 0; i < ChangeStamps.Count; i++)
    {
        CUploadChangeStamp* stamp = ChangeStamps[i];
        // changed after the listing started, under another connection (another host name, user or
        // port - feature 345): the panel was not refreshed by it
        if (stamp->Time > listingStartTime && !SameIdentity(stamp->User, stamp->Host, stamp->Port, user, host, port))
        {
            return TRUE;
        }
    }
    return FALSE;
}

void CUploadListingCache::ReportCreateDirs(const char* user, const char* host, unsigned short port,
                                           const char* workPath, CFTPServerPathType pathType, const char* newDirs,
                                           BOOL unknownResult)
{
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    CUploadListingsOnServer* server = FindServer(user, host, port, NULL);
    if (server != NULL)
        server->ReportCreateDirs(workPath, pathType, newDirs, unknownResult);
    InvalidateOtherNamesOfServer(user, host, port, server); // feature 341
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
}

void CUploadListingCache::ReportRename(const char* user, const char* host, unsigned short port,
                                       const char* workPath, CFTPServerPathType pathType,
                                       const char* fromName, const char* newName, BOOL unknownResult)
{
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    CUploadListingsOnServer* server = FindServer(user, host, port, NULL);
    if (server != NULL)
        server->ReportRename(workPath, pathType, fromName, newName, unknownResult);
    InvalidateOtherNamesOfServer(user, host, port, server); // feature 341
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
}

void CUploadListingCache::ReportDelete(const char* user, const char* host, unsigned short port,
                                       const char* workPath, CFTPServerPathType pathType, const char* name,
                                       BOOL unknownResult)
{
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    CUploadListingsOnServer* server = FindServer(user, host, port, NULL);
    if (server != NULL)
        server->ReportDelete(workPath, pathType, name, unknownResult);
    InvalidateOtherNamesOfServer(user, host, port, server); // feature 341
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
}

void CUploadListingCache::ReportStoreFile(const char* user, const char* host, unsigned short port,
                                          const char* workPath, CFTPServerPathType pathType, const char* name)
{
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    CUploadListingsOnServer* server = FindServer(user, host, port, NULL);
    if (server != NULL)
        server->ReportStoreFile(workPath, pathType, name);
    InvalidateOtherNamesOfServer(user, host, port, server); // feature 341
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
}

void CUploadListingCache::ReportFileUploaded(const char* user, const char* host, unsigned short port,
                                             const char* workPath, CFTPServerPathType pathType, const char* name,
                                             const CQuadWord& fileSize, BOOL unknownResult)
{
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    CUploadListingsOnServer* server = FindServer(user, host, port, NULL);
    if (server != NULL)
        server->ReportFileUploaded(workPath, pathType, name, fileSize, unknownResult);
    InvalidateOtherNamesOfServer(user, host, port, server); // feature 341
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
}

void CUploadListingCache::ReportUnknownChange(const char* user, const char* host, unsigned short port,
                                              const char* workPath, CFTPServerPathType pathType)
{
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    CUploadListingsOnServer* server = FindServer(user, host, port, NULL);
    if (server != NULL)
        server->ReportUnknownChange(workPath, pathType);
    InvalidateOtherNamesOfServer(user, host, port, server); // feature 341
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
}

void CUploadListingCache::InvalidatePathListing(const char* user, const char* host, unsigned short port,
                                                const char* path, CFTPServerPathType pathType)
{
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    CUploadListingsOnServer* server = FindServer(user, host, port, NULL);
    if (server != NULL)
        server->InvalidatePathListing(path, pathType);
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
}

BOOL CUploadListingCache::IsListingFromPanel(const char* user, const char* host, unsigned short port,
                                             const char* path, CFTPServerPathType pathType)
{
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    CUploadListingsOnServer* server = FindServer(user, host, port, NULL);
    BOOL ret = FALSE;
    if (server != NULL)
        ret = server->IsListingFromPanel(path, pathType);
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
    return ret;
}

BOOL CUploadListingCache::GetListing(const char* user, const char* host, unsigned short port,
                                     const char* path, CFTPServerPathType pathType, int workerMsg,
                                     int workerUID, BOOL* listingInProgress, BOOL* notAccessible,
                                     BOOL* getListing, const char* name, CUploadListingItem** existingItem,
                                     BOOL* nameExists, BOOL caseOnlyCounts)
{
    BOOL ret = TRUE;
    *listingInProgress = FALSE;
    *notAccessible = FALSE;
    *getListing = FALSE;
    if (existingItem != NULL)
        *existingItem = NULL;
    if (nameExists != NULL)
        *nameExists = FALSE;
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    CUploadListingsOnServer* server = FindServer(user, host, port, NULL);
    if (server == NULL) // the cache does not contain any path from this server yet; create an entry for the server
    {
        server = new CUploadListingsOnServer(user, host, port);
        if (server != NULL && server->IsGood())
        {
            ListingsOnServer.Add(server);
            if (!ListingsOnServer.IsGood())
            {
                ListingsOnServer.ResetState();
                delete server;
                server = NULL;
                ret = FALSE;
            }
        }
        else
        {
            if (server != NULL)
            {
                delete server;
                server = NULL;
            }
            else
                TRACE_E(LOW_MEMORY);
            ret = FALSE;
        }
    }
    if (server != NULL)
    {
        ret = server->GetListing(path, pathType, workerMsg, workerUID, listingInProgress,
                                 notAccessible, getListing, name, existingItem, nameExists, caseOnlyCounts);
    }
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
    return ret;
}

void CUploadListingCache::ListingFailed(const char* user, const char* host, unsigned short port,
                                        const char* path, CFTPServerPathType pathType,
                                        BOOL listingIsNotAccessible,
                                        CUploadWaitingWorker** uploadFirstWaitingWorker,
                                        BOOL* listingOKErrorIgnored)
{
    if (listingOKErrorIgnored != NULL)
        *listingOKErrorIgnored = FALSE;
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    CUploadListingsOnServer* server = FindServer(user, host, port, NULL);
    if (server != NULL)
    {
        server->ListingFailed(path, pathType, listingIsNotAccessible,
                              uploadFirstWaitingWorker, listingOKErrorIgnored);
    }
    else
        TRACE_E("CUploadListingCache::ListingFailed(): server not found!");
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
}

BOOL CUploadListingCache::ListingFinished(const char* user, const char* host, unsigned short port,
                                          const char* path, CFTPServerPathType pathType,
                                          const char* pathListing, int pathListingLen,
                                          const CFTPDate& pathListingDate, const char* welcomeReply,
                                          const char* systReply, const char* suggestedListingServerType)
{
    BOOL ret = TRUE;
    HANDLES(EnterCriticalSection(&UploadLstCacheCritSect));
    CUploadListingsOnServer* server = FindServer(user, host, port, NULL);
    if (server != NULL)
    {
        ret = server->ListingFinished(path, pathType, pathListing, pathListingLen,
                                      pathListingDate, welcomeReply, systReply,
                                      suggestedListingServerType);
    }
    else
        TRACE_E("CUploadListingCache::ListingFinished(): server not found!");
    HANDLES(LeaveCriticalSection(&UploadLstCacheCritSect));
    return ret;
}

//
// ****************************************************************************
// CUploadListingsOnServer
//

CUploadListingsOnServer::CUploadListingsOnServer(const char* user, const char* host,
                                                 unsigned short port) : Listing(50, 100)
{
    BOOL err = host == NULL;
    Host = SalamanderGeneral->DupStr(host);
    if (user != NULL && strcmp(user, FTP_ANONYMOUS) == 0)
        user = NULL;
    User = SalamanderGeneral->DupStr(user); // if it is NULL, it remains NULL
    Port = port;

    // if there is an error, release and null the data
    if (err)
    {
        if (User != NULL)
            free(User);
        if (Host != NULL)
            free(Host);
        User = Host = NULL;
    }
    memset(FoundPathIndexes, -1, sizeof(FoundPathIndexes));
}

CUploadListingsOnServer::~CUploadListingsOnServer()
{
    int i;
    for (i = 0; i < Listing.Count; i++)
    {
        CUploadListingState state = Listing[i]->ListingState;
        if (state != ulsReady && state != ulsNotAccessible)
            TRACE_E("CUploadListingsOnServer::~CUploadListingsOnServer(): listing in forbidden state (in progress): " << state);
    }
    if (User != NULL)
        SalamanderGeneral->Free(User);
    if (Host != NULL)
        SalamanderGeneral->Free(Host);
}

BOOL CUploadListingsOnServer::AddOrUpdateListing(const char* path, CFTPServerPathType pathType,
                                                 const char* pathListing, int pathListingLen,
                                                 const CFTPDate& pathListingDate,
                                                 DWORD listingStartTime, BOOL onlyUpdate,
                                                 const char* welcomeReply, const char* systReply,
                                                 const char* suggestedListingServerType)
{
    // feature 288: the names of the listing are evidence of this server (FTPGetServerEnc enters
    // only its own SRW lock - allowed inside UploadLstCacheCritSect)
    CFTPListingServerScope listingServer(FTPGetServerEnc(Host, Port, User));
    BOOL ret = TRUE;
    int index;
    if (FindPath(path, pathType, index)) // the path is already in the cache
    {
        CUploadPathListing* listing = Listing[index];
        DWORD listingTime;
        if (listing->ListingState == ulsInProgress)
            listingTime = listing->ListingStartTime; // the changes are currently only in the queue, so they can also be used on a listing older than LatestChangeTime
        else
            listingTime = max(listing->LatestChangeTime, listing->ListingStartTime);
        if (listingTime < listingStartTime) // if this is a newer listing, perform an update
        {
            listing->ClearListingItems();
            if (listing->ParseListing(pathListing, pathListingLen, pathListingDate, pathType,
                                      welcomeReply, systReply, suggestedListingServerType, NULL))
            {
                if (listing->ListingState == ulsInProgress)
                {
                    CUploadListingChange* change = listing->FirstChange;
                    while (change != NULL)
                    {
                        if (change->ChangeTime > listingStartTime) // if the change also concerns the new listing, apply it
                        {
                            if (!listing->CommitChange(change))
                                break;
                        }
                        change = change->NextChange;
                    }
                    if (change != NULL)               // error while applying changes to the new listing
                        listing->ClearListingItems(); // discard the new listing; everything stays with the old one (as if the new listing could not be used)
                    else                              // the changes (if there were any) are applied to the new listing
                    {
                        listing->ListingState = ulsInProgressButObsolete;
                        listing->ListingStartTime = listingStartTime;

                        // discard the collected changes; they are no longer useful
                        listing->ClearListingChanges();
                        if (listing->LatestChangeTime < listingStartTime) // otherwise we must not reset listing->LatestChangeTime - it contains
                            listing->LatestChangeTime = 0;                // the time of the last change in the listing
                    }
                }
                else
                {
                    listing->ListingStartTime = listingStartTime;
                    listing->LatestChangeTime = 0; // reset because it is always less than 'listingStartTime' (so it is useless)
                    if (listing->ListingState == ulsNotAccessible)
                        listing->ListingState = ulsReady;
                    if (listing->ListingState == ulsInProgressButMayBeOutdated)
                        listing->ListingState = ulsInProgressButObsolete;
                }
            }
            else // error parsing the new listing, or low memory
            {
                if (listing->ListingState == ulsReady)
                {
                    Listing.Delete(index);
                    if (!Listing.IsGood())
                        Listing.ResetState(); // Delete cannot fail; it only reports an error when shrinking the array
                    ret = FALSE;
                }
                else
                {
                    listing->ClearListingItems();                          // discard the new listing
                    if (listing->ListingState == ulsInProgressButObsolete) // it is impossible to determine whether the transition to ulsInProgressButObsolete was preceded by an "unknown listing change", so put the listing into an error state
                        listing->ListingState = ulsInProgressButMayBeOutdated;
                }
            }
        }
    }
    else // the path is not in the cache yet
    {
        if (!onlyUpdate) // if it is possible to add the listing, add it
        {
            CUploadPathListing* listing = new CUploadPathListing(path, pathType, ulsReady, listingStartTime, TRUE /* listing being added = listing from the panel */);
            if (listing != NULL && listing->IsGood())
            {
                if (listing->ParseListing(pathListing, pathListingLen, pathListingDate, pathType,
                                          welcomeReply, systReply, suggestedListingServerType, NULL))
                {
                    Listing.Add(listing);
                    if (!Listing.IsGood())
                    {
                        Listing.ResetState();
                        delete listing;
                        ret = FALSE;
                    }
                }
                else // the listing cannot be parsed or memory is low
                {
                    delete listing;
                    ret = FALSE;
                }
            }
            else
            {
                if (listing != NULL)
                    delete listing;
                else
                    TRACE_E(LOW_MEMORY);
                ret = FALSE;
            }
        }
    }
    return ret;
}

void CUploadListingsOnServer::RemoveNotAccessibleListings()
{
    int i;
    for (i = Listing.Count - 1; i >= 0; i--)
    {
        CUploadPathListing* listing = Listing[i];
        if (listing->ListingState == ulsNotAccessible)
        {
            Listing.Delete(i);
            if (!Listing.IsGood())
                Listing.ResetState(); // Delete cannot fail; it only reports an error when shrinking the array
        }
    }
}

CUploadPathListing*
CUploadListingsOnServer::AddEmptyListing(const char* path, const char* dirName, CFTPServerPathType pathType,
                                         CUploadListingState listingState, BOOL doNotCheckIfPathIsKnown)
{
    CUploadPathListing* ret = NULL;
    char dir[FTP_MAX_PATH];
    lstrcpyn(dir, path, FTP_MAX_PATH);
    if (dirName == NULL || FTPPathAppend(pathType, dir, FTP_MAX_PATH, dirName, TRUE))
    {
        int index;
        if (doNotCheckIfPathIsKnown || !FindPath(dir, pathType, index)) // the path is not in the cache yet
        {
            CUploadPathListing* listing = new CUploadPathListing(dir, pathType, listingState, IncListingCounter(), FALSE);
            if (listing != NULL && listing->IsGood())
            {
                Listing.Add(listing);
                if (Listing.IsGood())
                    ret = listing;
                else
                {
                    Listing.ResetState();
                    delete listing;
                }
            }
            else
            {
                if (listing != NULL)
                    delete listing;
                else
                    TRACE_E(LOW_MEMORY);
            }
        }
    }
    return ret;
}

BOOL CUploadListingsOnServer::FindPath(const char* path, CFTPServerPathType pathType, int& index)
{
    if (path == NULL)
    {
        TRACE_E("Unexpected situation in CUploadListingsOnServer::FindPath()!");
        return FALSE;
    }
#ifdef _DEBUG
    FoundPathIndexesTotal++;
#endif
    index = -1;
    int i;
    for (i = 0; i < FOUND_PATH_IND_CACHE_SIZE; i++) // first try indexes that were found in the past
    {
        int ind = FoundPathIndexes[i];
        if (ind >= 0 && ind < Listing.Count &&
            FTPIsTheSameServerPath(pathType, Listing[ind]->Path, path))
        {
            index = ind;
            if (i > 0) // bubble the found index up to the first position in the lookup cache (giving it the longest lifetime)
            {
                memmove(FoundPathIndexes + 1, FoundPathIndexes, sizeof(int) * i);
                FoundPathIndexes[0] = i;
            }
#ifdef _DEBUG
            FoundPathIndexesInCache++;
#endif
            return TRUE;
        }
    }
    for (i = 0; i < Listing.Count; i++) // the cache did not help, search the entire array sequentially
    {
        if (FTPIsTheSameServerPath(pathType, Listing[i]->Path, path))
        {
            // put the found index into the lookup cache at the first position and shift the others down
            memmove(FoundPathIndexes + 1, FoundPathIndexes, sizeof(int) * (FOUND_PATH_IND_CACHE_SIZE - 1));
            FoundPathIndexes[0] = i;

            index = i;
            return TRUE;
        }
    }
    return FALSE;
}

void CUploadListingsOnServer::ReportCreateDirs(const char* workPath, CFTPServerPathType pathType,
                                               const char* newDirs, BOOL unknownResult)
{
    // feature 277: 'newDirs' (a typed name, up to 2 * MAX_PATH) was cut to FTP_MAX_PATH and its
    // last, cut component recorded as a created directory; now it is walked whole (heap buffers)
    // and a name that does not fit FTP_MAX_PATH only invalidates the listings it reaches (what the
    // server made of it is not known)
    int newLen = (int)strlen(newDirs);
    if (newLen >= FTP_MAX_PATH)
        unknownResult = TRUE;
    int bufSize = newLen + (int)strlen(workPath) + 3; // + an OS/2 drive or a VMS device, see FTPCompleteAbsolutePath()
    if (bufSize < FTP_MAX_PATH)
        bufSize = FTP_MAX_PATH;
    char* bufs = (char*)malloc(2 * bufSize);
    if (bufs == NULL)
    {
        TRACE_E(LOW_MEMORY);
        int index;
        if (FindPath(workPath, pathType, index))
            InvalidateListing(index);
        return;
    }
    char* cutDir = bufs;
    char* longPath = bufs + bufSize;
    char path[FTP_MAX_PATH];
    if (FTPIsPathRelative(pathType, newDirs))
    { // call ReportCreateDir sequentially for all directories being created
        char* relPath = longPath;
        // feature 323: count the named components first - only the last one was made by the command
        int namedLeft = 0;
        strcpy(relPath, newDirs);
        while (FTPCutFirstDirFromRelativePath(pathType, relPath, cutDir, bufSize))
        {
            if (SalFtpMkdirIsNamedComponent(cutDir))
                namedLeft++;
        }
        strcpy(relPath, newDirs);
        lstrcpyn(path, workPath, FTP_MAX_PATH);
        while (FTPCutFirstDirFromRelativePath(pathType, relPath, cutDir, bufSize))
        {
            if (strcmp(cutDir, "..") == 0)
                FTPCutDirectory(pathType, path, FTP_MAX_PATH, NULL, 0, NULL); // assumption: ".." is the parent directory or is meaningless
            // assumption: "." is the current directory or is meaningless; an empty component
            // (feature 323) creates nothing
            else if (SalFtpMkdirIsNamedComponent(cutDir))
            {
                namedLeft--;
                int index;
                if (FindPath(path, pathType, index)) // find the path in the cache
                    ReportCreateDirComponent(index, path, cutDir, pathType, unknownResult, namedLeft == 0);
                if (!FTPPathAppend(pathType, path, FTP_MAX_PATH, cutDir, TRUE))
                    break; // ignore paths that are too long
            }
        }
    }
    else // newDirs is an absolute path, so trim it up to the root and call ReportCreateDir for all subdirectories (we do not know how many subdirectories were created)
    {
        strcpy(longPath, newDirs);
        FTPCompleteAbsolutePath(pathType, longPath, bufSize, workPath); // convert the path to a full absolute path if necessary (always fits 'bufSize')
        FTPRemovePointsFromPath(longPath, pathType);                    // assumption: "." is the current directory or is meaningless, ".." is the parent directory or is meaningless
        BOOL lastNamed = TRUE;                                          // feature 323: cut from the end - the first named component is the one the command made
        while (FTPCutDirectory(pathType, longPath, bufSize, cutDir, bufSize, NULL))
        {
            if (!SalFtpMkdirIsNamedComponent(cutDir))
                continue;
            int index;
            if ((int)strlen(longPath) < FTP_MAX_PATH && FindPath(longPath, pathType, index)) // find the path in the cache (a longer one is never there)
                ReportCreateDirComponent(index, longPath, cutDir, pathType, unknownResult, lastNamed);
            lastNamed = FALSE;
        }
    }
    free(bufs);
}

void CUploadListingsOnServer::ReportCreateDirComponent(int index, const char* parentPath, const char* name,
                                                       CFTPServerPathType pathType, BOOL unknownResult,
                                                       BOOL isLastNamed)
{
    // feature 323: an earlier component of a created path ("MKD .cfg/new") existed - the server
    // makes only the last one; if the cached parent listing does not show it as a directory (a dot
    // directory a plain LIST hides, "Docs" typed as "docs", or the listing is still being received),
    // the listing missed something and is not trusted any more; recording it as a new, empty
    // directory let an upload into it overwrite its files without the overwrite question
    CUploadPathListing* listing = Listing[index];
    BOOL parentListsIt = FALSE;
    if (!unknownResult && !isLastNamed &&
        (listing->ListingState == ulsReady || listing->ListingState == ulsInProgressButObsolete))
    {
        int item;
        parentListsIt = listing->FindItem(name, item) &&
                        listing->ListingItem[item]->ItemType != ulitFile; // a file cannot have held the new directory
    }
    switch (SalFtpMkdirComponentAction(unknownResult != FALSE, isLastNamed != FALSE, parentListsIt != FALSE))
    {
    case sfmaInvalidateParent:
        InvalidateListing(index);
        break;

    case sfmaRecordCreated:
    {
        BOOL dirCreated, lowMem;
        listing->ReportCreateDir(name, &dirCreated, &lowMem);
        if (lowMem)
            InvalidateListing(index);
        if (dirCreated)
            AddEmptyListing(parentPath, name, pathType, ulsReady, FALSE); // add an empty listing to the listing cache for the newly created directory
        break;
    }

    case sfmaNothing:
        break;
    }
}

void CUploadListingsOnServer::ReportRename(const char* workPath, CFTPServerPathType pathType,
                                           const char* fromName, const char* newName,
                                           BOOL unknownResult)
{
    // fromName is always a name (no path) on workPath - the change on workPath is certain;
    // newName is provided by the user and can be anything - for example, on VMS it is quite complicated to determine
    // what actually happened (a move within the server, changes just to the name/extension ("a." and ".a"),
    // etc.)
    // feature 302: invalidating only workPath left the listings of a renamed directory, of the
    // directory 'newName' moves into (Quick Rename accepts a path) and of everything below them
    // trusted - e.g. the empty listing Create Directory adds for a new directory: an upload into it
    // after "a.txt" -> "new/a.txt" sent STOR without the overwrite question. What a rename reaches is
    // not resolved here, so every listing of the server is invalidated (the next upload lists its
    // target again - a cost only while an upload to this server exists)
    InvalidateAllListings();
}

void CUploadListingsOnServer::InvalidateAllListings()
{
    int i;
    for (i = Listing.Count - 1; i >= 0; i--) // InvalidateListing() may delete the item - from the end
        InvalidateListing(i);
}

void CUploadListingsOnServer::ReportDelete(const char* workPath, CFTPServerPathType pathType,
                                           const char* name, BOOL unknownResult)
{
    int index;
    BOOL invalidateNameDir = unknownResult;
    if (FindPath(workPath, pathType, index)) // find the path in the cache
    {
        if (unknownResult)
            InvalidateListing(index);
        else
        {
            BOOL lowMem;
            Listing[index]->ReportDelete(name, &invalidateNameDir, &lowMem);
            if (lowMem)
                InvalidateListing(index);
        }
    }

    if (invalidateNameDir)
    {
        // just in case 'name' is a directory or a link to a directory, invalidate
        // the listing of the path to that directory
        char path[FTP_MAX_PATH];
        lstrcpyn(path, workPath, FTP_MAX_PATH);
        if (FTPPathAppend(pathType, path, FTP_MAX_PATH, name, TRUE))
        {
            if (FindPath(path, pathType, index)) // find the path in the cache (if this was a file, the path cannot be found)
                InvalidateListing(index);
        }
    }
}

void CUploadListingsOnServer::ReportStoreFile(const char* workPath, CFTPServerPathType pathType, const char* name)
{
    int index;
    if (FindPath(workPath, pathType, index)) // find the path in the cache
    {
        BOOL lowMem;
        Listing[index]->ReportStoreFile(name, &lowMem);
        if (lowMem)
            InvalidateListing(index);
    }
}

void CUploadListingsOnServer::ReportFileUploaded(const char* workPath, CFTPServerPathType pathType, const char* name,
                                                 const CQuadWord& fileSize, BOOL unknownResult)
{
    int index;
    if (FindPath(workPath, pathType, index)) // find the path in the cache
    {
        if (unknownResult)
            InvalidateListing(index);
        else
        {
            BOOL lowMem;
            Listing[index]->ReportFileUploaded(name, fileSize, &lowMem);
            if (lowMem)
                InvalidateListing(index);
        }
    }
}

void CUploadListingsOnServer::InvalidatePathListing(const char* path, CFTPServerPathType pathType)
{
    int index;
    if (FindPath(path, pathType, index))
        InvalidateListing(index);
}

BOOL CUploadListingsOnServer::IsListingFromPanel(const char* path, CFTPServerPathType pathType)
{
    int index;
    if (FindPath(path, pathType, index))
        return Listing[index]->FromPanel;
    return FALSE;
}

void CUploadListingsOnServer::ReportUnknownChange(const char* workPath, CFTPServerPathType pathType)
{
    // feature 302: a command typed by the user (Send FTP Command) may change any directory, also
    // one below workPath whose (e.g. empty, from Create Directory) listing is cached - every
    // listing of the server is invalidated, not only workPath's
    InvalidateAllListings();
}

void CUploadListingsOnServer::InvalidateListing(int index)
{
    CUploadPathListing* listing = Listing[index];
    if (listing->ListingState == ulsReady) // remove the listing from the array because it can no longer be trusted
    {
        Listing.Delete(index);
        if (!Listing.IsGood())
            Listing.ResetState(); // Delete cannot fail; it only reports an error when shrinking the array
    }
    else
    {
        if (listing->ListingState != ulsNotAccessible)
        {
            if (listing->ListingState == ulsInProgressButObsolete) // discard the newer listing; it is no longer useful
                listing->ClearListingItems();
            if (listing->ListingState == ulsInProgress) // discard the accumulated changes; they are no longer useful
                listing->ClearListingChanges();
            listing->ListingState = ulsInProgressButMayBeOutdated;
        }
        listing->LatestChangeTime = IncListingCounter();
        listing->FromPanel = FALSE;
    }
}

BOOL CUploadListingsOnServer::GetListing(const char* path, CFTPServerPathType pathType, int workerMsg,
                                         int workerUID, BOOL* listingInProgress, BOOL* notAccessible,
                                         BOOL* getListing, const char* name, CUploadListingItem** existingItem,
                                         BOOL* nameExists, BOOL caseOnlyCounts)
{
    BOOL ret = TRUE;
    int index;
    if (FindPath(path, pathType, index))
    {
        CUploadPathListing* listing = Listing[index];
        if (listing->ListingState == ulsNotAccessible) // the listing is not accessible
            *notAccessible = TRUE;
        else
        {
            if (listing->ListingState == ulsInProgress ||
                listing->ListingState == ulsInProgressButObsolete ||
                listing->ListingState == ulsInProgressButMayBeOutdated) // the listing is being fetched; add a worker to report completion/error
            {
                *listingInProgress = TRUE;
                ret = listing->AddWaitingWorker(workerMsg, workerUID);
            }
            else
            {
                if (listing->ListingState == ulsReady) // the listing is ready
                {
                    int index2;
                    BOOL found = listing->FindItem(name, index2);
                    BOOL caseOnly = FALSE;
                    if (!found && caseOnlyCounts) // feature 303: a name differing only in case counts (see the declaration)
                    {
                        // a folder does not: a case-insensitive server refuses STOR onto it anyway, a
                        // case-sensitive one stores the file beside it - "cannot create the file" would
                        // only block that upload (review of 303)
                        TIndirectArray<CUploadListingItem>* items = &listing->ListingItem;
                        index2 = SalFtpFindCaseOnlyName(items->Count, [items](int i)
                                                        { return items->At(i)->ItemType == ulitDirectory ? (const char*)NULL : (const char*)items->At(i)->Name; },
                                                        name);
                        found = caseOnly = index2 >= 0;
                    }
                    if (found) // item 'name' found; copy its data into 'existingItem' and set 'nameExists' to TRUE
                    {
                        if (nameExists != NULL)
                            *nameExists = TRUE;
                        if (existingItem != NULL)
                        {
                            CUploadListingItem* item = listing->ListingItem[index2];
                            *existingItem = new CUploadListingItem;
                            if (*existingItem != NULL)
                            {
                                (*existingItem)->Name = SalamanderGeneral->DupStr(item->Name);
                                if ((*existingItem)->Name != NULL)
                                {
                                    (*existingItem)->ItemType = item->ItemType;
                                    (*existingItem)->ByteSize = caseOnly ? UPLOADSIZE_UNKNOWN : item->ByteSize; // feature 303: never another name's size
                                }
                                else
                                {
                                    ret = FALSE;
                                    delete *existingItem;
                                    *existingItem = NULL;
                                }
                            }
                            else
                                ret = FALSE;
                            if (!ret)
                                TRACE_E(LOW_MEMORY);
                        }
                    }
                }
                else
                    TRACE_E("CUploadListingsOnServer::GetListing(): Unexpected state of listing: " << listing->ListingState);
            }
        }
    }
    else // the path is not in the cache yet
    {
        CUploadPathListing* listing = AddEmptyListing(path, NULL, pathType, ulsInProgress, TRUE);
        if (listing != NULL)
        {
            *getListing = TRUE;
            *listingInProgress = TRUE;
        }
        else
            ret = FALSE;
    }
    return ret;
}

void CUploadListingsOnServer::ListingFailed(const char* path, CFTPServerPathType pathType,
                                            BOOL listingIsNotAccessible,
                                            CUploadWaitingWorker** uploadFirstWaitingWorker,
                                            BOOL* listingOKErrorIgnored)
{
    int index;
    if (FindPath(path, pathType, index))
    {
        CUploadPathListing* listing = Listing[index];
        if (listing->ListingState == ulsInProgress ||
            listing->ListingState == ulsInProgressButObsolete ||
            listing->ListingState == ulsInProgressButMayBeOutdated)
        {
            listing->InformWaitingWorkers(uploadFirstWaitingWorker);
            if (listing->ListingState == ulsInProgressButObsolete) // we already have the listing, so a worker-reported listing error does not matter
            {
                listing->ListingState = ulsReady;
                if (listingOKErrorIgnored != NULL)
                    *listingOKErrorIgnored = TRUE;
            }
            else
            {
                if (listingIsNotAccessible)
                {
                    listing->ClearListingItems();
                    listing->ClearListingChanges();
                    listing->LatestChangeTime = 0;
                    listing->ListingStartTime = IncListingCounter(); // only a new listing can update it
                    listing->ListingState = ulsNotAccessible;
                }
                else
                {
                    Listing.Delete(index);
                    if (!Listing.IsGood())
                        Listing.ResetState(); // Delete cannot fail; it only reports an error when shrinking the array
                }
            }
        }
        else
            TRACE_E("CUploadListingsOnServer::ListingFailed(): listing is not in progress!");
    }
    else
        TRACE_E("CUploadListingsOnServer::ListingFailed(): path was not found!");
}

BOOL CUploadListingsOnServer::ListingFinished(const char* path, CFTPServerPathType pathType,
                                              const char* pathListing, int pathListingLen,
                                              const CFTPDate& pathListingDate, const char* welcomeReply,
                                              const char* systReply, const char* suggestedListingServerType)
{
    // feature 288: the names of the listing are evidence of this server (FTPGetServerEnc enters
    // only its own SRW lock - allowed inside UploadLstCacheCritSect)
    CFTPListingServerScope listingServer(FTPGetServerEnc(Host, Port, User));
    BOOL ret = TRUE;
    int index;
    if (FindPath(path, pathType, index))
    {
        CUploadPathListing* listing = Listing[index];
        if (listing->ListingState == ulsInProgress ||
            listing->ListingState == ulsInProgressButObsolete ||
            listing->ListingState == ulsInProgressButMayBeOutdated)
        {
            listing->InformWaitingWorkers(NULL);
            if (listing->ListingState == ulsInProgressButObsolete) // we already have a newer listing than this one, so ignore this listing and keep the newer one
                listing->ListingState = ulsReady;
            else
            {
                if (listing->ListingState == ulsInProgressButMayBeOutdated) // we know this listing is probably invalid (and we have no other), so remove the path from the cache; the listing will then be downloaded again
                {
                    Listing.Delete(index);
                    if (!Listing.IsGood())
                        Listing.ResetState(); // Delete cannot fail; it only reports an error when shrinking the array
                }
                else // ulsInProgress: process the new listing and commit the changes to it
                {
                    listing->ClearListingItems(); // probably unnecessary, just to be safe
                    BOOL lowMem;
                    if (listing->ParseListing(pathListing, pathListingLen, pathListingDate, pathType,
                                              welcomeReply, systReply, suggestedListingServerType, &lowMem))
                    {
                        CUploadListingChange* change = listing->FirstChange;
                        while (change != NULL)
                        {
                            if (change->ChangeTime > listing->ListingStartTime) // probably "always true"
                            {
                                if (!listing->CommitChange(change))
                                    break;
                            }
                            change = change->NextChange;
                        }
                        if (change != NULL) // error while applying changes to the new listing; this can only be caused by low memory, so treat it as a temporary error, remove the path from the cache, and download the listing again later
                        {
                            Listing.Delete(index);
                            if (!Listing.IsGood())
                                Listing.ResetState(); // Delete cannot fail; it only reports an error when shrinking the array
                            ret = FALSE;
                        }
                        else // the changes (if there were any) are applied to the new listing
                        {
                            listing->ListingState = ulsReady;
                            listing->ClearListingChanges(); // discard the accumulated changes; they are no longer useful
                        }
                    }
                    else
                    {
                        if (lowMem) // low memory = temporary error; remove the path from the cache, and the listing will be downloaded again later
                        {
                            Listing.Delete(index);
                            if (!Listing.IsGood())
                                Listing.ResetState(); // Delete cannot fail; it only reports an error when shrinking the array
                            ret = FALSE;
                        }
                        else // parsing the new listing failed = permanent error - mark the listing for this path as "unobtainable"
                        {
                            listing->ListingState = ulsNotAccessible;
                            listing->ClearListingChanges();
                            listing->ClearListingItems();
                        }
                    }
                }
            }
        }
        else
            TRACE_E("CUploadListingsOnServer::ListingFinished(): listing is not in progress!");
    }
    else
        TRACE_E("CUploadListingsOnServer::ListingFinished(): path was not found!");
    return ret;
}

//
// ****************************************************************************
// CUploadPathListing
//

CUploadPathListing::CUploadPathListing(const char* path, CFTPServerPathType pathType,
                                       CUploadListingState listingState, DWORD listingStartTime,
                                       BOOL fromPanel)
    : ListingItem(50, 200, dtNoDelete)
{
    BOOL err = path == NULL;
    Path = SalamanderGeneral->DupStr(path);
    PathType = pathType;

    ListingState = listingState;
    ListingStartTime = listingStartTime;
    FirstChange = NULL;
    LastChange = NULL;
    LatestChangeTime = 0;
    FirstWaitingWorker = NULL;
    FromPanel = fromPanel;

    // if there is an error, release and null the data
    if (err)
    {
        if (Path != NULL)
            SalamanderGeneral->Free(Path);
        Path = NULL;
    }
}

CUploadPathListing::~CUploadPathListing()
{
    if (FirstWaitingWorker != NULL)
        TRACE_E("CUploadPathListing::~CUploadPathListing(): FirstWaitingWorker is not NULL!");
    ClearListingItems();
    if (Path != NULL)
        SalamanderGeneral->Free(Path);
    ClearListingChanges();
}

void CUploadPathListing::ClearListingItems()
{
    int i;
    for (i = 0; i < ListingItem.Count; i++)
    {
        CUploadListingItem* item = ListingItem[i];
        SalamanderGeneral->Free(item->Name);
        delete item;
    }
    ListingItem.DetachMembers();
}

void CUploadPathListing::ClearListingChanges()
{
    CUploadListingChange* change = FirstChange;
    while (change != NULL)
    {
        CUploadListingChange* del = change;
        change = change->NextChange;
        delete del;
    }
    FirstChange = LastChange = NULL;
}

BOOL CUploadPathListing::AddItemDoNotSort(CUploadListingItemType itemType, const char* name, const CQuadWord& byteSize)
{
    if (name == NULL)
        TRACE_E("Unexpected situation in CUploadPathListing::AddItemDoNotSort()!");
    else
    {
        CUploadListingItem* item = new CUploadListingItem;
        if (item != NULL)
        {
            item->Name = SalamanderGeneral->DupStr(name);
            if (item->Name != NULL)
            {
                item->ItemType = itemType;
                item->ByteSize = byteSize;

                ListingItem.Add(item);
                if (ListingItem.IsGood())
                    return TRUE;
                else
                    ListingItem.ResetState();
                SalamanderGeneral->Free(item->Name);
            }
            delete item;
        }
        else
            TRACE_E(LOW_MEMORY);
    }
    return FALSE;
}

BOOL CUploadPathListing::InsertNewItem(int index, CUploadListingItemType itemType, const char* name,
                                       const CQuadWord& byteSize)
{
    if (name == NULL)
        TRACE_E("Unexpected situation in CUploadPathListing::InsertNewItem()!");
    else
    {
        CUploadListingItem* item = new CUploadListingItem;
        if (item != NULL)
        {
            item->Name = SalamanderGeneral->DupStr(name);
            if (item->Name != NULL)
            {
                item->ItemType = itemType;
                item->ByteSize = byteSize;

                ListingItem.Insert(index, item);
                if (ListingItem.IsGood())
                    return TRUE;
                else
                    ListingItem.ResetState();
                SalamanderGeneral->Free(item->Name);
            }
            delete item;
        }
        else
            TRACE_E(LOW_MEMORY);
    }
    return FALSE;
}

void UploadListingSortItemsAux(TIndirectArray<CUploadListingItem>* listingItem, int left, int right)
{

LABEL_UploadListingSortItemsAux:

    int i = left, j = right;
    const char* pivot = listingItem->At((i + j) / 2)->Name;

    do
    {
        while (strcmp(listingItem->At(i)->Name, pivot) < 0 && i < right)
            i++;
        while (strcmp(pivot, listingItem->At(j)->Name) < 0 && j > left)
            j--;

        if (i <= j)
        {
            CUploadListingItem* swap = listingItem->At(i);
            listingItem->At(i) = listingItem->At(j);
            listingItem->At(j) = swap;
            i++;
            j--;
        }
    } while (i <= j);

    // the following "nice" code was replaced with code that significantly saves stack usage (maximum log(N) recursion depth)
    //  if (left < j) UploadListingSortItemsAux(listingItem, left, j);
    //  if (i < right) UploadListingSortItemsAux(listingItem, i, right);

    if (left < j)
    {
        if (i < right)
        {
            if (j - left < right - i) // both "halves" need to be sorted, so recurse into the smaller one and process the other via "goto"
            {
                UploadListingSortItemsAux(listingItem, left, j);
                left = i;
                goto LABEL_UploadListingSortItemsAux;
            }
            else
            {
                UploadListingSortItemsAux(listingItem, i, right);
                right = j;
                goto LABEL_UploadListingSortItemsAux;
            }
        }
        else
        {
            right = j;
            goto LABEL_UploadListingSortItemsAux;
        }
    }
    else
    {
        if (i < right)
        {
            left = i;
            goto LABEL_UploadListingSortItemsAux;
        }
    }
}

void UploadListingSortItemsCaseInsensitiveAux(TIndirectArray<CUploadListingItem>* listingItem, int left, int right)
{

LABEL_UploadListingSortItemsCaseInsensitiveAux:

    int i = left, j = right;
    const char* pivot = listingItem->At((i + j) / 2)->Name;

    do
    {
        while (SalamanderGeneral->StrICmp(listingItem->At(i)->Name, pivot) < 0 && i < right)
            i++;
        while (SalamanderGeneral->StrICmp(pivot, listingItem->At(j)->Name) < 0 && j > left)
            j--;

        if (i <= j)
        {
            CUploadListingItem* swap = listingItem->At(i);
            listingItem->At(i) = listingItem->At(j);
            listingItem->At(j) = swap;
            i++;
            j--;
        }
    } while (i <= j);

    // the following "nice" code was replaced with code that significantly saves stack usage (maximum log(N) recursion depth)
    //  if (left < j) UploadListingSortItemsCaseInsensitiveAux(listingItem, left, j);
    //  if (i < right) UploadListingSortItemsCaseInsensitiveAux(listingItem, i, right);

    if (left < j)
    {
        if (i < right)
        {
            if (j - left < right - i) // both "halves" need to be sorted, so recurse into the smaller one and process the other via "goto"
            {
                UploadListingSortItemsCaseInsensitiveAux(listingItem, left, j);
                left = i;
                goto LABEL_UploadListingSortItemsCaseInsensitiveAux;
            }
            else
            {
                UploadListingSortItemsCaseInsensitiveAux(listingItem, i, right);
                right = j;
                goto LABEL_UploadListingSortItemsCaseInsensitiveAux;
            }
        }
        else
        {
            right = j;
            goto LABEL_UploadListingSortItemsCaseInsensitiveAux;
        }
    }
    else
    {
        if (i < right)
        {
            left = i;
            goto LABEL_UploadListingSortItemsCaseInsensitiveAux;
        }
    }
}

void CUploadPathListing::SortItems()
{
    if (ListingItem.Count > 1)
    {
        if (FTPIsCaseSensitive(PathType))
            UploadListingSortItemsAux(&ListingItem, 0, ListingItem.Count - 1);
        else
            UploadListingSortItemsCaseInsensitiveAux(&ListingItem, 0, ListingItem.Count - 1);
    }
}

BOOL CUploadPathListing::FindItem(const char* name, int& index)
{
    if (ListingItem.Count == 0)
    {
        index = 0;
        return FALSE;
    }

    BOOL caseSensitive = FTPIsCaseSensitive(PathType);
    int l = 0, r = ListingItem.Count - 1, m;
    while (1)
    {
        m = (l + r) / 2;
        int res;
        if (caseSensitive)
            res = strcmp(ListingItem[m]->Name, name);
        else
            res = SalamanderGeneral->StrICmp(ListingItem[m]->Name, name);
        if (res == 0) // found
        {
            index = m;
            return TRUE;
        }
        else if (res > 0)
        {
            if (l == r || l > m - 1) // not found
            {
                index = m; // it should be at this position
                return FALSE;
            }
            r = m - 1;
        }
        else
        {
            if (l == r) // not found
            {
                index = m + 1; // it should be right after this position
                return FALSE;
            }
            l = m + 1;
        }
    }
}

BOOL CUploadPathListing::ParseListing(const char* pathListing, int pathListingLen, const CFTPDate& pathListingDate,
                                      CFTPServerPathType pathType, const char* welcomeReply, const char* systReply,
                                      const char* suggestedListingServerType, BOOL* lowMemory)
{
    CALL_STACK_MESSAGE2("CUploadPathListing::ParseListing(, %d,)", pathListingLen);

    if (lowMemory != NULL)
        *lowMemory = FALSE;
    if (pathListing == NULL || welcomeReply == NULL || systReply == NULL)
    {
        TRACE_E("CUploadPathListing::ParseListing(): pathListing == NULL or welcomeReply == NULL or systReply == NULL!");
        return FALSE;
    }

    BOOL isVMS = pathType == ftpsptOpenVMS;
    BOOL needSimpleListing = TRUE;
    char listingServerType[SERVERTYPE_MAX_SIZE];
    if (suggestedListingServerType == NULL)
        listingServerType[0] = 0;
    else
        lstrcpyn(listingServerType, suggestedListingServerType, SERVERTYPE_MAX_SIZE);

    // reset the helper variable used to determine which server type has already been tested (unsuccessfully)
    CServerTypeList* serverTypeList = Config.LockServerTypeList();
    int serverTypeListCount = serverTypeList->Count;
    int j;
    for (j = 0; j < serverTypeListCount; j++)
        serverTypeList->At(j)->ParserAlreadyTested = FALSE;

    BOOL err = FALSE;
    CServerType* serverType = NULL;
    if (listingServerType[0] != 0) // this is not autodetection; find the matching listingServerType
    {
        int i;
        for (i = 0; i < serverTypeListCount; i++)
        {
            serverType = serverTypeList->At(i);
            const char* s = serverType->TypeName;
            if (*s == '*')
                s++;
            if (SalamanderGeneral->StrICmp(listingServerType, s) == 0)
            {
                // serverType has been selected; try its parser on the listing
                serverType->ParserAlreadyTested = TRUE;
                if (ParseListingToArray(pathListing, pathListingLen, pathListingDate, serverType, &err, isVMS))
                    needSimpleListing = FALSE; // successfully parsed the listing
                if (err && lowMemory != NULL)
                    *lowMemory = TRUE;
                break; // found the requested server type, stop here
            }
        }
        if (i == serverTypeListCount)
            listingServerType[0] = 0; // listingServerType is missing -> perform autodetection
    }

    // autodetection - select the server type whose autodetection condition is satisfied
    if (!err && needSimpleListing && listingServerType[0] == 0)
    {
        int welcomeReplyLen = (int)strlen(welcomeReply);
        int systReplyLen = (int)strlen(systReply);
        int i;
        for (i = 0; i < serverTypeListCount; i++)
        {
            serverType = serverTypeList->At(i);
            if (!serverType->ParserAlreadyTested) // only if we have not tried it yet
            {
                if (serverType->CompiledAutodetCond == NULL)
                {
                    serverType->CompiledAutodetCond = CompileAutodetectCond(HandleNULLStr(serverType->AutodetectCond),
                                                                            NULL, NULL, NULL, NULL, 0);
                    if (serverType->CompiledAutodetCond == NULL) // this can only be a low-memory error
                    {
                        err = TRUE;
                        if (lowMemory != NULL)
                            *lowMemory = TRUE;
                        break;
                    }
                }
                if (serverType->CompiledAutodetCond->Evaluate(welcomeReply, welcomeReplyLen,
                                                              systReply, systReplyLen))
                {
                    // serverType has been selected; try its parser on the listing
                    serverType->ParserAlreadyTested = TRUE;
                    if (ParseListingToArray(pathListing, pathListingLen, pathListingDate, serverType, &err, isVMS) || err)
                    {
                        if (err && lowMemory != NULL)
                            *lowMemory = TRUE;
                        if (!err)
                        {
                            const char* s = serverType->TypeName;
                            if (*s == '*')
                                s++;
                            lstrcpyn(listingServerType, s, SERVERTYPE_MAX_SIZE);
                        }
                        needSimpleListing = err; // either the listing was parsed successfully, or an out-of-memory error occurred; stop here
                        break;
                    }
                }
            }
        }

        // autodetection - selection of the remaining server types
        if (!err && needSimpleListing)
        {
            int k;
            for (k = 0; k < serverTypeListCount; k++)
            {
                serverType = serverTypeList->At(k);
                if (!serverType->ParserAlreadyTested) // only if we have not tested it yet
                {
                    // serverType has been selected; try its parser on the listing
                    // serverType->ParserAlreadyTested = TRUE;  // unnecessary, not used later
                    if (ParseListingToArray(pathListing, pathListingLen, pathListingDate, serverType, &err, isVMS) || err)
                    {
                        if (err && lowMemory != NULL)
                            *lowMemory = TRUE;
                        if (!err)
                        {
                            const char* s = serverType->TypeName;
                            if (*s == '*')
                                s++;
                            lstrcpyn(listingServerType, s, SERVERTYPE_MAX_SIZE);
                        }
                        needSimpleListing = err; // either successfully parsed the listing or encountered an out-of-memory error; stop here
                        break;
                    }
                }
            }
        }
    }
    Config.UnlockServerTypeList();
    return !err && !needSimpleListing;
}

BOOL CUploadPathListing::ParseListingToArray(const char* pathListing, int pathListingLen,
                                             const CFTPDate& pathListingDate,
                                             CServerType* serverType, BOOL* lowMem, BOOL isVMS)
{
    BOOL ret = FALSE;
    *lowMem = FALSE;
    ClearListingItems();

    // compute the 'validDataMask' mask
    DWORD validDataMask = VALID_DATA_HIDDEN | VALID_DATA_ISLINK; // Name + NameLen + Hidden + IsLink
    int i;
    for (i = 0; i < serverType->Columns.Count; i++)
    {
        switch (serverType->Columns[i]->Type)
        {
        case stctExt:
            validDataMask |= VALID_DATA_EXTENSION;
            break;
        case stctSize:
            validDataMask |= VALID_DATA_SIZE;
            break;
        case stctDate:
            validDataMask |= VALID_DATA_DATE;
            break;
        case stctTime:
            validDataMask |= VALID_DATA_TIME;
            break;
        case stctType:
            validDataMask |= VALID_DATA_TYPE;
            break;
        }
    }

    BOOL err = FALSE;
    CFTPListingPluginDataInterface* dataIface = new CFTPListingPluginDataInterface(&(serverType->Columns), FALSE,
                                                                                   validDataMask, isVMS);
    if (dataIface != NULL)
    {
        DWORD* emptyCol = new DWORD[serverType->Columns.Count]; // helper preallocated array for GetNextItemFromListing
        if (dataIface->IsGood() && emptyCol != NULL)
        {
            validDataMask |= dataIface->GetPLValidDataMask();
            CFTPParser* parser = serverType->CompiledParser;
            if (parser == NULL)
            {
                parser = CompileParsingRules(HandleNULLStr(serverType->RulesForParsing), &(serverType->Columns),
                                             NULL, NULL, NULL);
                serverType->CompiledParser = parser; // do not deallocate 'parser'; it is already stored in 'serverType'
            }
            if (parser != NULL)
            {
                CFileData file;
                const char* listing = pathListing;
                const char* listingEnd = pathListing + pathListingLen;
                BOOL isDir = FALSE;

                int rightsCol = dataIface->FindRightsColumn(); // index of the permissions column (used to detect links)

                parser->BeforeParsing(listing, listingEnd, pathListingDate.Year, pathListingDate.Month,
                                      pathListingDate.Day, FALSE); // initialize the parser
                while (parser->GetNextItemFromListing(&file, &isDir, dataIface, &(serverType->Columns), &listing,
                                                      listingEnd, NULL, &err, emptyCol))
                {
                    if (!isDir || file.NameLen > 2 ||
                        file.Name[0] != '.' || (file.Name[1] != 0 && file.Name[1] != '.')) // not the directories "." and ".."
                    {
                        CUploadListingItemType itemType;
                        if (rightsCol != -1 && IsUNIXLink(dataIface->GetStringFromColumn(file, rightsCol)))
                            itemType = ulitLink;
                        else
                            itemType = isDir ? ulitDirectory : ulitFile;

                        BOOL sizeInBytes; // TRUE = 'size' is in bytes
                        CQuadWord size;   // variable for the size of the current file
                        if (itemType != ulitFile || !dataIface->GetSize(file, size, sizeInBytes) || !sizeInBytes)
                            size = UPLOADSIZE_UNKNOWN; // the size of the file in bytes is unknown

                        err = !AddItemDoNotSort(itemType, file.Name, size);
                    }
                    // release the data for the file or directory
                    dataIface->ReleasePluginData(file, isDir);
                    SalamanderGeneral->Free(file.Name);

                    if (err)
                        break;
                }
                if (!err && listing == listingEnd)
                    ret = TRUE; // parsing completed successfully
            }
            else
                err = TRUE; // can only be a memory shortage
        }
        else
        {
            if (emptyCol == NULL)
                TRACE_E(LOW_MEMORY);
            err = TRUE; // low memory
        }
        if (emptyCol != NULL)
            delete[] emptyCol;
        if (dataIface != NULL)
            delete dataIface;
    }
    else
    {
        TRACE_E(LOW_MEMORY);
        err = TRUE; // low memory
    }
    *lowMem = err;
    if (ret)
        SortItems();
    return ret;
}

void CUploadPathListing::ReportCreateDir(const char* newDir, BOOL* dirCreated, BOOL* lowMem)
{
    LatestChangeTime = IncListingCounter(); // record the time of this change
    *lowMem = FALSE;
    *dirCreated = FALSE;
    int index;
    switch (ListingState)
    {
    case ulsReady:
    case ulsInProgressButObsolete:
    {
        if (!FindItem(newDir, index)) // the name is available; the directory can be created
        {
            if (InsertNewItem(index, ulitDirectory, newDir, UPLOADSIZE_UNKNOWN))
                *dirCreated = TRUE;
            else
                *lowMem = TRUE;
        }
        break;
    }

    case ulsInProgress:
    {
        CUploadListingChange* ch = new CUploadListingChange(LatestChangeTime, ulctCreateDir, newDir);
        if (ch != NULL && ch->IsGood())
            AddChange(ch);
        else
        {
            if (ch != NULL)
                delete ch;
            else
                TRACE_E(LOW_MEMORY);
            *lowMem = TRUE;
        }
        break;
    }

        // case ulsInProgressButMayBeOutdated:   // nothing to do
        // case ulsNotAccessible:                // nothing to do
    }
}

void CUploadPathListing::ReportDelete(const char* name, BOOL* invalidateNameDir, BOOL* lowMem)
{
    LatestChangeTime = IncListingCounter(); // record the time of this change
    *lowMem = FALSE;
    *invalidateNameDir = TRUE; // we do not know whether it is a directory or a link, so try to invalidate the directory listing (if it is a file, it will be ignored)
    int index;
    switch (ListingState)
    {
    case ulsReady:
    case ulsInProgressButObsolete:
    {
        if (FindItem(name, index))
        {
            CUploadListingItem* item = ListingItem[index];
            if (item->ItemType == ulitFile)
                *invalidateNameDir = FALSE; // file = no need to invalidate the directory listing
            SalamanderGeneral->Free(item->Name);
            delete item;
            ListingItem.Detach(index);
            if (!ListingItem.IsGood())
                ListingItem.ResetState();
        }
        else
            TRACE_E("CUploadPathListing::ReportDelete(): delete for unknown name reported: " << name); // warning only
        break;
    }

    case ulsInProgress:
    {
        CUploadListingChange* ch = new CUploadListingChange(LatestChangeTime, ulctDelete, name);
        if (ch != NULL && ch->IsGood())
            AddChange(ch);
        else
        {
            if (ch != NULL)
                delete ch;
            else
                TRACE_E(LOW_MEMORY);
            *lowMem = TRUE;
        }
        break;
    }

        // case ulsInProgressButMayBeOutdated:   // nothing to do
        // case ulsNotAccessible:                // nothing to do
    }
}

void CUploadPathListing::ReportStoreFile(const char* name, BOOL* lowMem)
{
    LatestChangeTime = IncListingCounter(); // record the time of this change
    *lowMem = FALSE;
    int index;
    switch (ListingState)
    {
    case ulsReady:
    case ulsInProgressButObsolete:
    {
        if (!FindItem(name, index)) // the name is available; create the file
        {
            if (!InsertNewItem(index, ulitFile, name, UPLOADSIZE_NEEDUPDATE))
                *lowMem = TRUE;
        }
        else // the name already exists; if it is a file, invalidate its size (a link has no size)
        {
            CUploadListingItem* item = ListingItem[index];
            if (item->ItemType == ulitFile)
                item->ByteSize = UPLOADSIZE_NEEDUPDATE;
        }
        break;
    }

    case ulsInProgress:
    {
        CUploadListingChange* ch = new CUploadListingChange(LatestChangeTime, ulctStoreFile, name);
        if (ch != NULL && ch->IsGood())
            AddChange(ch);
        else
        {
            if (ch != NULL)
                delete ch;
            else
                TRACE_E(LOW_MEMORY);
            *lowMem = TRUE;
        }
        break;
    }

        // case ulsInProgressButMayBeOutdated:   // nothing to do
        // case ulsNotAccessible:                // nothing to do
    }
}

void CUploadPathListing::ReportFileUploaded(const char* name, const CQuadWord& fileSize, BOOL* lowMem)
{
    LatestChangeTime = IncListingCounter(); // record the time of this change
    *lowMem = FALSE;
    int index;
    switch (ListingState)
    {
    case ulsReady:
    case ulsInProgressButObsolete:
    {
        if (FindItem(name, index)) // if the item exists, update its size if it is a file
        {
            CUploadListingItem* item = ListingItem[index];
            if (item->ItemType == ulitFile)
                item->ByteSize = fileSize;
        }
        break;
    }

    case ulsInProgress:
    {
        CUploadListingChange* ch = new CUploadListingChange(LatestChangeTime, ulctFileUploaded, name, &fileSize);
        if (ch != NULL && ch->IsGood())
            AddChange(ch);
        else
        {
            if (ch != NULL)
                delete ch;
            else
                TRACE_E(LOW_MEMORY);
            *lowMem = TRUE;
        }
        break;
    }

        // case ulsInProgressButMayBeOutdated:   // nothing to do
        // case ulsNotAccessible:                // nothing to do
    }
}

BOOL CUploadPathListing::CommitChange(CUploadListingChange* change)
{
    int index;
    switch (change->Type)
    {
    case ulctDelete:
    {
        if (FindItem(change->Name, index))
        {
            CUploadListingItem* item = ListingItem[index];
            SalamanderGeneral->Free(item->Name);
            delete item;
            ListingItem.Detach(index);
            if (!ListingItem.IsGood())
                ListingItem.ResetState();
        }
        else
            TRACE_I("CUploadPathListing::CommitChange(): delete for unknown name reported: " << change->Name); // warning only
        return TRUE;
    }

    case ulctCreateDir:
    {
        if (!FindItem(change->Name, index)) // the name is available; the directory can be created
            return InsertNewItem(index, ulitDirectory, change->Name, UPLOADSIZE_UNKNOWN);
        return TRUE;
    }

    case ulctStoreFile:
    {
        if (!FindItem(change->Name, index)) // the name is free; create the file
        {
            return InsertNewItem(index, ulitFile, change->Name, UPLOADSIZE_NEEDUPDATE);
        }
        else // the name already exists; if it is a file, invalidate its size (a link has no size)
        {
            CUploadListingItem* item = ListingItem[index];
            if (item->ItemType == ulitFile)
                item->ByteSize = UPLOADSIZE_NEEDUPDATE;
        }
        return TRUE;
    }

    case ulctFileUploaded:
    {
        if (FindItem(change->Name, index)) // if found, update its size if it is a file
        {
            CUploadListingItem* item = ListingItem[index];
            if (item->ItemType == ulitFile)
                item->ByteSize = change->FileSize;
        }
        return TRUE;
    }

    default:
        TRACE_E("CUploadPathListing::CommitChange(): unknown type of change!");
        break;
    }
    return FALSE;
}

void CUploadPathListing::AddChange(CUploadListingChange* ch)
{
    if (LastChange != NULL)
    {
        LastChange->NextChange = ch;
        LastChange = ch;
    }
    else
        FirstChange = LastChange = ch;
}

BOOL CUploadPathListing::AddWaitingWorker(int workerMsg, int workerUID)
{
    CUploadWaitingWorker* worker = new CUploadWaitingWorker;
    if (worker == NULL)
    {
        TRACE_E(LOW_MEMORY);
        return FALSE;
    }
    worker->NextWorker = FirstWaitingWorker;
    worker->WorkerMsg = workerMsg;
    worker->WorkerUID = workerUID;
    FirstWaitingWorker = worker;
    return TRUE;
}

void CUploadPathListing::InformWaitingWorkers(CUploadWaitingWorker** uploadFirstWaitingWorker)
{
    if (uploadFirstWaitingWorker != NULL) // add the waiting workers to the list
    {
        if (FirstWaitingWorker != NULL)
        {
            if (*uploadFirstWaitingWorker != NULL)
            {
                CUploadWaitingWorker* worker = FirstWaitingWorker;
                while (worker->NextWorker != NULL)
                    worker = worker->NextWorker;
                worker->NextWorker = *uploadFirstWaitingWorker;
            }
            *uploadFirstWaitingWorker = FirstWaitingWorker;
        }
    }
    else // we need to post WORKER_TGTPATHLISTINGFINISHED to the waiting workers
    {
        CUploadWaitingWorker* worker = FirstWaitingWorker;
        while (worker != NULL)
        {
            // because we are already in CSocketsThread::CritSect, this call is safe (no deadlock risk)
            SocketsThread->PostSocketMessage(worker->WorkerMsg, worker->WorkerUID, WORKER_TGTPATHLISTINGFINISHED, NULL);

            CUploadWaitingWorker* del = worker;
            worker = worker->NextWorker;
            delete del;
        }
    }
    FirstWaitingWorker = NULL;
}

//
// ****************************************************************************
// CUploadListingChange
//

CUploadListingChange::CUploadListingChange(DWORD changeTime, CUploadListingChangeType type,
                                           const char* name, const CQuadWord* fileSize)
{
    BOOL err = name == NULL;
    Name = SalamanderGeneral->DupStr(name);
    if (fileSize != NULL)
        FileSize = *fileSize;
    else
        FileSize = UPLOADSIZE_UNKNOWN;
    Type = type;
    ChangeTime = changeTime;
    NextChange = NULL;

    // if there is an error, release and null the data
    if (err)
    {
        if (Name != NULL)
            SalamanderGeneral->Free(Name);
        Name = NULL;
    }
}

CUploadListingChange::~CUploadListingChange() // release the data, but WARNING: must not free NextChange
{
    if (Name != NULL)
        SalamanderGeneral->Free(Name);
}

//
// ****************************************************************************
// CFTPOpenedFiles
//

CFTPOpenedFile::CFTPOpenedFile(int myUID, const char* user, const char* host, unsigned short port,
                               const char* path, CFTPServerPathType pathType, const char* name,
                               CFTPFileAccessType accessType)
{
    Set(myUID, user, host, port, path, pathType, name, accessType);
}

void CFTPOpenedFile::Set(int myUID, const char* user, const char* host, unsigned short port,
                         const char* path, CFTPServerPathType pathType, const char* name,
                         CFTPFileAccessType accessType)
{
    UID = myUID;
    AccessType = accessType;
    lstrcpyn(User, user, USER_MAX_SIZE);
    lstrcpyn(Host, host, HOST_MAX_SIZE);
    Port = port;
    lstrcpyn(Path, path, FTP_MAX_PATH);
    PathType = pathType;
    lstrcpyn(Name, name, _countof(Name));
}

BOOL CFTPOpenedFile::IsSameFile(const char* user, const char* host, unsigned short port,
                                const char* path, CFTPServerPathType pathType, const char* name)
{
    // feature 347: the host is not compared - two names of one server (localhost / 127.0.0.1, two of
    // its addresses) are maybe the same server, and the client cannot tell them from two servers
    // (feature 341: a server answers on several addresses, a proxy hides its address); two uploads
    // under two names stored one file at once.
    // feature 348: neither are the user and the port - two accounts can share folders and one server
    // can be reached through a forwarded port (feature 345's rule: every other connection is maybe
    // the same server); two uploads as two users / through two ports stored one file at once.
    // Cost: a conflicting access to a file of the same server path and name on any other connection
    // (also an unrelated server or account) is refused "in use" until the first one ends; two reads
    // still run together.
    (void)user;
    (void)host;
    (void)port;
    return FTPIsTheSameServerPath(pathType, Path, path) &&
           // feature 277: a case-insensitive server's names by the file system's rule (092; StrICmp folded
           // UTF-8 bytes by the code page: two other names matched, case twins did not)
           (FTPIsCaseSensitive(pathType) ? strcmp(Name, name) == 0 : SalNameOrderEqualCI(Name, -1, name, -1));
}

BOOL CFTPOpenedFile::IsInConflictWith(CFTPFileAccessType accessType)
{
    return AccessType != accessType || // two different operations on a single file are not possible
           accessType == ffatWrite;    // two uploads of one file are not possible
                                       // two downloads at the same time do no harm,
                                       // two deletions do not matter either - the second ends with a "not found" error (the outcome is certain, independent of the server implementation)
                                       // two renames do not matter either and, moreover, cannot happen (Quick Rename can run only one at a time), but renaming to a name that differs only in letter casing is possible (the same source and target of the rename are two names in the array)
}

CFTPOpenedFiles::CFTPOpenedFiles() : OpenedFiles(50, 100), AllocatedObjects(50, 100)
{
    HANDLES(InitializeCriticalSection(&FTPOpenedFilesCritSect));
    NextOpenedFileUID = 1;
}

CFTPOpenedFiles::~CFTPOpenedFiles()
{
    HANDLES(DeleteCriticalSection(&FTPOpenedFilesCritSect));
    if (OpenedFiles.Count > 0)
        TRACE_E("CFTPOpenedFiles::~CFTPOpenedFiles(): unexpected situation: OpenedFiles.Count > 0!");
}

BOOL CFTPOpenedFiles::OpenFile(const char* user, const char* host, unsigned short port,
                               const char* path, CFTPServerPathType pathType,
                               const char* name, int* newUID, CFTPFileAccessType accessType)
{
    BOOL ret = TRUE;
    HANDLES(EnterCriticalSection(&FTPOpenedFilesCritSect));
    int i;
    for (i = 0; i < OpenedFiles.Count; i++)
    {
        CFTPOpenedFile* file = OpenedFiles[i];
        if (file->IsSameFile(user, host, port, path, pathType, name) &&
            file->IsInConflictWith(accessType))
        {
            ret = FALSE;
            break;
        }
    }
    if (ret)
    {
        int uid = NextOpenedFileUID++;
        CFTPOpenedFile* n;
        if (AllocatedObjects.Count > 0) // if we have something preallocated, reuse it
        {
            n = AllocatedObjects[AllocatedObjects.Count - 1];
            AllocatedObjects.Detach(AllocatedObjects.Count - 1);
            if (!AllocatedObjects.IsGood())
                AllocatedObjects.ResetState(); // detaching cannot fail
            n->Set(uid, user, host, port, path, pathType, name, accessType);
        }
        else
            n = new CFTPOpenedFile(uid, user, host, port, path, pathType, name, accessType);
        if (n != NULL)
        {
            OpenedFiles.Add(n);
            if (OpenedFiles.IsGood())
                *newUID = uid;
            else
            {
                OpenedFiles.ResetState();
                ret = FALSE;
                delete n;
            }
        }
        else
        {
            TRACE_E(LOW_MEMORY);
            ret = FALSE;
        }
    }
    HANDLES(LeaveCriticalSection(&FTPOpenedFilesCritSect));
    return ret;
}

void CFTPOpenedFiles::CloseFile(int UID)
{
    HANDLES(EnterCriticalSection(&FTPOpenedFilesCritSect));
    BOOL found = FALSE;
    int i;
    for (i = 0; i < OpenedFiles.Count; i++)
    {
        if (OpenedFiles[i]->IsUID(UID))
        {
            AllocatedObjects.Add(OpenedFiles[i]);
            if (AllocatedObjects.IsGood())
                OpenedFiles.Detach(i);
            else
            {
                AllocatedObjects.ResetState();
                OpenedFiles.Delete(i);
            }
            if (!OpenedFiles.IsGood())
                OpenedFiles.ResetState(); // detach or delete cannot fail; only the array compaction did not succeed
            found = TRUE;
            break;
        }
    }
    if (!found)
        TRACE_E("CFTPOpenedFiles::CloseFile(): unable to find file with UID: " << UID);
    HANDLES(LeaveCriticalSection(&FTPOpenedFilesCritSect));
}
