// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// splloadstru8.h
//
// Feature 130: a plug-in's resource text as UTF-8, and a text of either
// encoding as UTF-8.
//
// A plug-in's LoadStr() gives the text in the code page of the system. A
// sentence composed from it and a file name (UTF-8 since interface 104) or
// GetErrorText() (UTF-8) is neither: the core's message box shows a text that
// is not valid UTF-8 through the code page, and the name is garbled (GitHub
// issue #7, in the plug-ins). A template that meets UTF-8 text is loaded with
// SplLoadStrU8() instead - and then EVERY other piece of the sentence and its
// sink must be UTF-8 too (a wide API, or a core service that takes UTF-8).
//
//   const char* LoadStrU8(int resID) { return SplLoadStrU8(SalamanderGeneral, HLanguage, resID); }
//
// The returned pointer stays valid until the plug-in is unloaded (the texts
// are kept, each converted once), so - unlike LoadStr() - any number of them
// can be used in one expression and from any thread. The text must not be
// modified.
//
// Header-only; include after spl_gen.h is not needed (the interface is a
// template parameter).
//

#include <windows.h>
#include <stdlib.h>
#include <string.h>
#include "splunicode.h"

class CSplLoadStrU8Cache
{
public:
    CSplLoadStrU8Cache()
    {
        InitializeCriticalSection(&Lock);
        memset(Buckets, 0, sizeof(Buckets));
    }

    ~CSplLoadStrU8Cache()
    {
        // at the unload of the plug-in; a thread that was killed while it held the lock leaves it
        // held for ever - then the texts are left to the process instead of waiting for ever
        if (!TryEnterCriticalSection(&Lock))
            return;
        int i;
        for (i = 0; i < BUCKETS; i++)
        {
            CNode* node = Buckets[i];
            Buckets[i] = NULL;
            while (node != NULL)
            {
                CNode* next = node->Next;
                free(node->Text);
                free(node);
                node = next;
            }
        }
        LeaveCriticalSection(&Lock);
        DeleteCriticalSection(&Lock);
    }

    // the kept text or NULL
    const char* Find(HINSTANCE module, int resID)
    {
        const char* ret = NULL;
        EnterCriticalSection(&Lock);
        CNode* node = Buckets[Bucket(module, resID)];
        for (; node != NULL; node = node->Next)
        {
            if (node->ResID == resID && node->Module == module)
            {
                ret = node->Text;
                break;
            }
        }
        LeaveCriticalSection(&Lock);
        return ret;
    }

    // keeps the UTF-8 form of 'textW' and returns it (the text another thread stored meanwhile,
    // if any); NULL when memory is low
    const char* Add(HINSTANCE module, int resID, const WCHAR* textW)
    {
        char* text = SplWToU8Alloc(textW);
        if (text == NULL)
            return NULL;
        CNode* add = (CNode*)malloc(sizeof(CNode));
        if (add == NULL)
        {
            free(text);
            return NULL;
        }
        const char* ret = NULL;
        EnterCriticalSection(&Lock);
        CNode** bucket = &Buckets[Bucket(module, resID)];
        CNode* node = *bucket;
        for (; node != NULL; node = node->Next)
        {
            if (node->ResID == resID && node->Module == module)
            {
                ret = node->Text;
                break;
            }
        }
        if (ret == NULL)
        {
            add->ResID = resID;
            add->Module = module;
            add->Text = text;
            add->Next = *bucket;
            *bucket = add;
            ret = text;
            add = NULL;
        }
        LeaveCriticalSection(&Lock);
        if (add != NULL) // another thread was faster
        {
            free(text);
            free(add);
        }
        return ret;
    }

protected:
    enum
    {
        BUCKETS = 256
    };

    struct CNode
    {
        int ResID;
        HINSTANCE Module;
        char* Text;
        CNode* Next;
    };

    static int Bucket(HINSTANCE module, int resID)
    {
        return (int)(((unsigned)resID * 2654435761u + (unsigned)((UINT_PTR)module >> 16)) >> 24) & (BUCKETS - 1);
    }

    CRITICAL_SECTION Lock; // (not a slim lock: some plug-ins are compiled for a Windows version before it)
    CNode* Buckets[BUCKETS];
};

// one per module (plug-in)
inline CSplLoadStrU8Cache& SplLoadStrU8CacheGet()
{
    static CSplLoadStrU8Cache cache;
    return cache;
}

// The text 'resID' of the language module 'module' as UTF-8; 'gen' is the plug-in's
// CSalamanderGeneralAbstract. Valid until the plug-in is unloaded. With low memory the
// code-page text of LoadStr() is returned, as before the change.
template <class GEN>
inline const char* SplLoadStrU8(GEN* gen, HINSTANCE module, int resID)
{
    CSplLoadStrU8Cache& cache = SplLoadStrU8CacheGet();
    const char* text = cache.Find(module, resID);
    if (text == NULL)
    {
        const WCHAR* textW = gen->LoadStrW(module, resID);
        if (textW != NULL)
            text = cache.Add(module, resID, textW);
    }
    return text != NULL ? text : gen->LoadStr(module, resID);
}

// A text that is UTF-8 already or code-page text (FormatMessageA, strerror, a LoadStr() text,
// a text of a library) as UTF-8 in a malloc'd buffer: a valid UTF-8 text (ASCII too) is copied
// as it is, any other is converted from the code page. free() the result; NULL for NULL or
// when memory is low. For a piece that joins a UTF-8 sentence.
inline char* SplLegacyToU8Alloc(const char* text)
{
    if (text == NULL)
        return NULL;
    WCHAR* w = SplU8ToWAlloc(text);
    if (w != NULL) // valid UTF-8: as it is
    {
        free(w);
        size_t size = strlen(text) + 1;
        char* copy = (char*)malloc(size);
        if (copy != NULL)
            memcpy(copy, text, size);
        return copy;
    }
    int units = MultiByteToWideChar(CP_ACP, 0, text, -1, NULL, 0); // with the terminator
    if (units <= 0)
        return NULL;
    w = (WCHAR*)malloc(units * sizeof(WCHAR));
    if (w == NULL)
        return NULL;
    char* ret = NULL;
    if (MultiByteToWideChar(CP_ACP, 0, text, -1, w, units) > 0)
        ret = SplWToU8Alloc(w);
    free(w);
    return ret;
}

// the same into a buffer; a text that does not fit is cut at a whole character
inline void SplLegacyToU8(const char* text, char* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return;
    char* u8 = SplLegacyToU8Alloc(text);
    SplU8CopyTrunc(buf, bufSize, u8 != NULL ? u8 : "");
    if (u8 != NULL)
        free(u8);
}
