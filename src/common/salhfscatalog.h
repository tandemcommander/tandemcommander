// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salhfscatalog.h
//
// The leaf records of an HFS+ catalog B-tree, checked against the bytes they
// were loaded into (feature 322). Header-only, no globals; for the ISO plug-in
// (uniso, hfs.cpp) and saltests.
//
// The ISO plug-in loads the catalog file of an HFS+ volume whole into memory
// and walks its leaf nodes (Apple TN1150): the header node (node 0) gives the
// node size and the first leaf node, each leaf node links to the next one and
// ends with a table of its record offsets. All of these come from the image.
// The walk used them as they were: a node number or a link past the loaded
// catalog, a node size of 0, a record count or a record offset outside the
// node read outside the buffer, and a link back to an earlier node made the
// walk endless.
//
// Here a node is used only when it lies wholly inside the catalog, a node met
// twice (a cycle) ends the walk, the record table must fit its node and every
// record offset must point into the node's record area (after the 14-byte
// descriptor, before the record table) with room for the key length. A tree
// that breaks any of this is DAMAGED - refused as a whole.
//
// Not checked (a stricter rule than any bound needs; such images open today):
// the kind of each leaf node, the header's leafRecords count (MagicISO 5.2 is
// known to write a wrong one), the key-length attributes.
//
// SalHfsCatalogKeyView then checks one catalog leaf record: its key, the name
// inside the key and the record type after it lie inside the record's bytes.
// The caller checks the folder / file data size against BodyAvail.
//
//*****************************************************************************

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#define SAL_HFSCAT_OK 0
#define SAL_HFSCAT_NOT_HEADER 1 // the first node is not a header node
#define SAL_HFSCAT_DAMAGED 2    // a node, link, size or record offset outside the catalog; a cycle
#define SAL_HFSCAT_NOMEM 3

#define SAL_HFSCAT_NODE_DESC 14   // sizeof(BTNodeDescriptor)
#define SAL_HFSCAT_HEADER_REC 106 // sizeof(BTHeaderRec)
// the smallest node that holds the header node's descriptor and header record
#define SAL_HFSCAT_MIN_NODE (SAL_HFSCAT_NODE_DESC + SAL_HFSCAT_HEADER_REC)

struct SalHfsCatalogRecordRef
{
    size_t Offset; // the record's first byte, from the start of the catalog
    size_t Avail;  // bytes from there to the end of its node's record area (>= 2)
};

struct SalHfsCatalogKey
{
    unsigned KeyLength;  // the key's length field (the key is KeyLength + 2 bytes)
    unsigned NameLength; // UTF-16 units of the node name (0 for thread records)
    size_t BodyOffset;   // the record data after the key, from the record's start
    size_t BodyAvail;    // bytes of record data (>= 2: the record type)
};

namespace SalHfsCatalogDetail
{
    inline size_t Be16(const unsigned char* p) { return ((size_t)p[0] << 8) | p[1]; }
    inline unsigned Be32(const unsigned char* p)
    {
        return ((unsigned)p[0] << 24) | ((unsigned)p[1] << 16) | ((unsigned)p[2] << 8) | p[3];
    }
} // namespace SalHfsCatalogDetail

// Walks the leaf chain of an HFS+ B-tree loaded whole into data[0..size). On OK *records is a
// malloc'd array of *count references (NULL when 0) - free() it; on any other result *records is
// NULL and *count 0. Never reads outside data[0..size); always returns (each node is used once).
inline int SalHfsCatalogWalk(const unsigned char* data, size_t size,
                             SalHfsCatalogRecordRef** records, int* count)
{
    using namespace SalHfsCatalogDetail;
    *records = NULL;
    *count = 0;
    if (data == NULL || size < SAL_HFSCAT_MIN_NODE)
        return SAL_HFSCAT_DAMAGED;
    if ((signed char)data[8] != 1) // BTNodeDescriptor::kind of node 0: kBTHeaderNode
        return SAL_HFSCAT_NOT_HEADER;

    const unsigned char* header = data + SAL_HFSCAT_NODE_DESC; // BTHeaderRec
    size_t nodeSize = Be16(header + 18);
    unsigned node = Be32(header + 10); // firstLeafNode
    if (nodeSize < SAL_HFSCAT_MIN_NODE || nodeSize > size)
        return SAL_HFSCAT_DAMAGED;
    if (node == 0)
        return SAL_HFSCAT_OK; // an empty tree (TN1150: firstLeafNode 0)

    size_t nodes = size / nodeSize; // whole nodes inside the catalog
    unsigned char* seen = (unsigned char*)calloc(nodes / 8 + 1, 1);
    if (seen == NULL)
        return SAL_HFSCAT_NOMEM;

    SalHfsCatalogRecordRef* recs = NULL;
    size_t n = 0, cap = 0;
    int ret = SAL_HFSCAT_OK;
    for (;;)
    {
        if (node >= nodes || (seen[node / 8] & (1 << (node % 8))) != 0)
        {
            ret = SAL_HFSCAT_DAMAGED; // past the catalog, or a cycle
            break;
        }
        seen[node / 8] |= (unsigned char)(1 << (node % 8));

        size_t base = (size_t)node * nodeSize; // node < nodes: base + nodeSize <= size
        const unsigned char* p = data + base;
        size_t numRecords = Be16(p + 10);
        if (SAL_HFSCAT_NODE_DESC + 2 * numRecords > nodeSize)
        {
            ret = SAL_HFSCAT_DAMAGED; // the record table does not fit the node
            break;
        }
        size_t areaEnd = nodeSize - 2 * numRecords; // the record table starts here

        if (n + numRecords > (size_t)INT_MAX)
        {
            ret = SAL_HFSCAT_NOMEM;
            break;
        }
        if (n + numRecords > cap)
        {
            size_t newCap = cap ? cap * 2 : 64;
            if (newCap < n + numRecords)
                newCap = n + numRecords;
            SalHfsCatalogRecordRef* tmp = (SalHfsCatalogRecordRef*)realloc(recs, newCap * sizeof(*recs));
            if (tmp == NULL)
            {
                ret = SAL_HFSCAT_NOMEM;
                break;
            }
            recs = tmp;
            cap = newCap;
        }
        for (size_t i = 0; i < numRecords && ret == SAL_HFSCAT_OK; i++)
        {
            size_t ofs = Be16(p + nodeSize - 2 * (i + 1));
            if (ofs < SAL_HFSCAT_NODE_DESC || ofs + 2 > areaEnd)
                ret = SAL_HFSCAT_DAMAGED; // into the descriptor, the record table or past the node
            else
            {
                recs[n].Offset = base + ofs;
                recs[n].Avail = areaEnd - ofs;
                n++;
            }
        }
        if (ret != SAL_HFSCAT_OK)
            break;

        node = Be32(p); // fLink
        if (node == 0)
            break;
    }
    free(seen);
    if (ret != SAL_HFSCAT_OK)
    {
        free(recs);
        return ret;
    }
    if (n == 0)
    {
        free(recs);
        recs = NULL;
    }
    *records = recs;
    *count = (int)n;
    return SAL_HFSCAT_OK;
}

// The key of a catalog leaf record of 'avail' bytes: false when the key, its node name or the
// record type does not fit. HFSPlusCatalogKey: keyLength (2), parentID (4), nodeName.length (2),
// nodeName.unicode (2 a unit); a key length of 6 is a thread record's key (an empty name).
inline bool SalHfsCatalogKeyView(const unsigned char* rec, size_t avail, SalHfsCatalogKey* key)
{
    using namespace SalHfsCatalogDetail;
    if (rec == NULL || avail < 2)
        return false;
    size_t keyLength = Be16(rec);
    if (keyLength < 6 || 2 + keyLength + 2 > avail) // the record type follows the key
        return false;
    size_t nameLength = Be16(rec + 6);
    if (8 + 2 * nameLength > 2 + keyLength)
        return false;
    key->KeyLength = (unsigned)keyLength;
    key->NameLength = (unsigned)nameLength;
    key->BodyOffset = 2 + keyLength;
    key->BodyAvail = avail - 2 - keyLength;
    return true;
}
