// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salftpserverident.h
//
// FTP client, upload listing cache: may two host names of the same user and
// port be one server (feature 341)? Header-only, pure - the FTP plug-in
// includes it and saltests checks it.
//
// The upload listing cache is keyed by the host as typed. A change made
// through one name of a server ("127.0.0.1") never reached an upload that uses
// another name of it ("localhost"); the upload trusted a listing that was no
// longer true and replaced a file without the overwrite question. The plug-in
// already obtains the addresses of the hosts it connects to (a typed IPv4
// address as it is, a name by the lookup it makes to connect); those addresses
// are remembered (CSalFtpHostAddrTable) and compared here - no new lookup.
// Two names are "maybe the same" when they share an address or when either
// address is not known (e.g. through a proxy, where only the proxy's name is
// looked up); the cache then stops trusting the other name's listings. Only
// known, disjoint addresses prove two different servers.
//
//*****************************************************************************

#include <string.h>

enum SalFtpServerNameRelation
{
    sfsnSame,      // the same host text: the cache's exact entry
    sfsnMaybeSame, // another name that may be the same server: its listings are not trusted
    sfsnDifferent, // known, disjoint addresses: another server
};

// ASCII case-insensitive comparison of host names (the DNS rule); other bytes compare exactly.
inline bool SalFtpHostNameEqualAsciiCI(const char* a, const char* b)
{
    if (a == NULL || b == NULL)
        return a == b;
    for (;; a++, b++)
    {
        unsigned char ca = (unsigned char)*a;
        unsigned char cb = (unsigned char)*b;
        if (ca >= 'A' && ca <= 'Z')
            ca = (unsigned char)(ca - 'A' + 'a');
        if (cb >= 'A' && cb <= 'Z')
            cb = (unsigned char)(cb - 'A' + 'a');
        if (ca != cb)
            return false;
        if (ca == 0)
            return true;
    }
}

// The relation of two host names of the same user and port. 'sameHostText': the names are equal
// as the cache compares them; 'a' / 'b': the known IPv4 addresses of each name ('na' / 'nb' of
// them; 0 = not known).
inline SalFtpServerNameRelation SalFtpCompareServerNames(bool sameHostText,
                                                         const unsigned int* a, int na,
                                                         const unsigned int* b, int nb)
{
    if (sameHostText)
        return sfsnSame;
    if (a == NULL || b == NULL || na <= 0 || nb <= 0)
        return sfsnMaybeSame; // the identity cannot be told
    for (int i = 0; i < na; i++)
    {
        for (int j = 0; j < nb; j++)
        {
            if (a[i] == b[j])
                return sfsnMaybeSame;
        }
    }
    return sfsnDifferent;
}

// The addresses the plug-in's own lookups returned for host names, newest per name. Bounded; a
// name that does not fit a slot is not recorded (it reads as "not known" - never cut). No
// locking: the owner serialises the calls.
class CSalFtpHostAddrTable
{
public:
    enum
    {
        SLOTS = 64,
        ADDRS = 8,        // addresses kept per name (the first ones of the lookup)
        HOST_BYTES = 256, // a host name up to 255 bytes (DNS names have at most 253)
    };

protected:
    struct CSlot
    {
        char Host[HOST_BYTES];
        unsigned int Addrs[ADDRS];
        int Count; // 0 = free slot
    };
    CSlot Slots[SLOTS];
    int NextVictim; // the slot recorded longest ago when the table is full (round robin)

    int Find(const char* host) const
    {
        for (int i = 0; i < SLOTS; i++)
        {
            if (Slots[i].Count > 0 && SalFtpHostNameEqualAsciiCI(Slots[i].Host, host))
                return i;
        }
        return -1;
    }

public:
    CSalFtpHostAddrTable() { Clear(); }

    void Clear()
    {
        memset(Slots, 0, sizeof(Slots));
        NextVictim = 0;
    }

    // Records the addresses a lookup of 'host' returned (the first ADDRS of 'count'); replaces the
    // name's earlier addresses. Returns false (nothing recorded) for no host, an empty or too long
    // host, or no address.
    bool Record(const char* host, const unsigned int* addrs, int count)
    {
        if (host == NULL || host[0] == 0 || addrs == NULL || count <= 0)
            return false;
        size_t len = strlen(host);
        if (len >= HOST_BYTES)
            return false;
        if (count > ADDRS)
            count = ADDRS;
        int slot = Find(host);
        if (slot < 0)
        {
            for (int i = 0; i < SLOTS; i++)
            {
                if (Slots[i].Count == 0)
                {
                    slot = i;
                    break;
                }
            }
        }
        if (slot < 0)
        {
            slot = NextVictim;
            NextVictim = (NextVictim + 1) % SLOTS;
        }
        memcpy(Slots[slot].Host, host, len + 1);
        memcpy(Slots[slot].Addrs, addrs, count * sizeof(unsigned int));
        Slots[slot].Count = count;
        return true;
    }

    // Copies the recorded addresses of 'host' (at most 'max') to 'out'; returns their number,
    // 0 = not known.
    int Lookup(const char* host, unsigned int* out, int max) const
    {
        if (host == NULL || out == NULL || max <= 0)
            return 0;
        int slot = Find(host);
        if (slot < 0)
            return 0;
        int n = Slots[slot].Count < max ? Slots[slot].Count : max;
        memcpy(out, Slots[slot].Addrs, n * sizeof(unsigned int));
        return n;
    }
};
