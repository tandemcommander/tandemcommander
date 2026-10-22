// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later
// CommentsTranslationProject: TRANSLATED

#include "precomp.h"

#include "salmaskname.h"  // feature 141
#include "salmaskopt.h"   // feature 283
#include "salmaskgroup.h" // feature 298

static_assert(SAL_MASKOPT_NONE == MASK_OPTIMIZE_NONE && SAL_MASKOPT_ALL == MASK_OPTIMIZE_ALL &&
                  SAL_MASKOPT_EXTENSION == MASK_OPTIMIZE_EXTENSION,
              "salmaskopt.h and masks.h must agree");

//
//*****************************************************************************
// Functions for wildcard operations
//

void PrepareMask(char* mask, const char* src)
{
    SLOW_CALL_STACK_MESSAGE2("PrepareMask(, %s)", src);
    // feature 298: the algorithm lives in src/common/salmaskgroup.h (checked by saltests);
    // 'mask' holds strlen(src) + 1 bytes (the plug-in interface's contract)
    SalPrepareMaskU8(mask, src);
}

static BOOL AgreeMaskA(const char* filename, const char* mask, BOOL hasExtension, BOOL extendedMode)
{
    CALL_STACK_MESSAGE_NONE;
    //  CALL_STACK_MESSAGE4("AgreeMaskA(%s, %s, %d)", filename, mask, hasExtension);  // slows things down massively (called recursively)
    while (*filename != 0)
    {
        if (*mask == 0)
            return FALSE; // mask is too short
        BOOL agree;
        if (extendedMode)
            // encoding-check: allow acp-byte-table-on-name - the byte matcher runs only for ASCII pairs and for text that is not UTF-8 (feature 004); UTF-8 names go to the wide twin
            agree = (LowerCase[*filename] == LowerCase[*mask] || *mask == '?' || // match or '?' represents any character or '#' represents any digit
                     (*mask == '#' && *filename >= '0' && *filename <= '9'));
        else
            // encoding-check: allow acp-byte-table-on-name - the byte matcher runs only for ASCII pairs and for text that is not UTF-8 (feature 004); UTF-8 names go to the wide twin
            agree = (LowerCase[*filename] == LowerCase[*mask] || *mask == '?'); // match or '?' represents any character
        if (agree)
        {
            filename++;
            mask++;
        }
        else if (*mask == '*') // '*' represents a sequence of characters (possibly empty)
        {
            mask++;
            while (*filename != 0)
            {
                if (AgreeMaskA(filename, mask, hasExtension, extendedMode))
                    return TRUE; // the rest of the mask matches
                filename++;
            }
            break; // end of filename...
        }
        else
            return FALSE;
    }
    if (*mask == '*')
        mask++;                        // asterisk '*' afterwards -> represents "" -> everything is ok
    if (!hasExtension && *mask == '.') // without extension mask "*.*" must still match...
        return *(mask + 1) == 0 || (*(mask + 1) == '*' && *(mask + 2) == 0);
    else
        return *mask == 0;
}

// wide twin of AgreeMaskA for names/masks with non-ASCII content (feature 004):
// per-character case folding via CharLowerW, '?' matches one UTF-16 unit
static BOOL AgreeMaskW(const WCHAR* filename, const WCHAR* mask, BOOL hasExtension, BOOL extendedMode)
{
    CALL_STACK_MESSAGE_NONE;
    while (*filename != 0)
    {
        if (*mask == 0)
            return FALSE; // mask is too short
        WCHAR fLow = (WCHAR)(UINT_PTR)CharLowerW((LPWSTR)(UINT_PTR)(WORD)*filename);
        WCHAR mLow = (WCHAR)(UINT_PTR)CharLowerW((LPWSTR)(UINT_PTR)(WORD)*mask);
        BOOL agree;
        if (extendedMode)
            agree = (fLow == mLow || *mask == L'?' ||
                     (*mask == L'#' && *filename >= L'0' && *filename <= L'9'));
        else
            agree = (fLow == mLow || *mask == L'?');
        if (agree)
        {
            filename++;
            mask++;
        }
        else if (*mask == L'*')
        {
            mask++;
            while (*filename != 0)
            {
                if (AgreeMaskW(filename, mask, hasExtension, extendedMode))
                    return TRUE;
                filename++;
            }
            break;
        }
        else
            return FALSE;
    }
    if (*mask == L'*')
        mask++;
    if (!hasExtension && *mask == L'.')
        return *(mask + 1) == 0 || (*(mask + 1) == L'*' && *(mask + 2) == 0);
    else
        return *mask == 0;
}

BOOL AgreeMask(const char* filename, const char* mask, BOOL hasExtension, BOOL extendedMode)
{
    CALL_STACK_MESSAGE_NONE;
    // ASCII fast path keeps the exact legacy semantics; anything else matches on
    // NFC-normalized UTF-16 so canonically equivalent spellings match (FR-008)
    if (SalIsASCII(filename) && SalIsASCII(mask))
        return AgreeMaskA(filename, mask, hasExtension, extendedMode);
    WCHAR* fw = SalU8ToWAlloc(filename);
    WCHAR* mw = SalU8ToWAlloc(mask);
    BOOL ret;
    if (fw != NULL && mw != NULL)
    {
        WCHAR* fn = SalNormalizeNFCAlloc(fw, -1);
        WCHAR* mn = SalNormalizeNFCAlloc(mw, -1);
        ret = AgreeMaskW(fn != NULL ? fn : fw, mn != NULL ? mn : mw, hasExtension, extendedMode);
        if (fn != NULL)
            free(fn);
        if (mn != NULL)
            free(mn);
    }
    else // not valid UTF-8 (transitional): legacy byte matching
        ret = AgreeMaskA(filename, mask, hasExtension, extendedMode);
    if (fw != NULL)
        free(fw);
    if (mw != NULL)
        free(mw);
    return ret;
}

// feature 141: the algorithm lives in src/common/salmaskname.h (checked by saltests)
char* MaskName(char* buffer, int bufSize, const char* name, const char* mask)
{
    SLOW_CALL_STACK_MESSAGE1("MaskName()");
    // the historical contract (plug-in interface): a result that does not fit is cut
    return SalMaskNameLegacyU8(buffer, bufSize, name, mask, NULL);
}

char* MaskNameChecked(char* buffer, int bufSize, const char* name, const char* mask, BOOL* cut)
{
    SLOW_CALL_STACK_MESSAGE1("MaskNameChecked()");
    BOOL fits = SalMaskNameU8(buffer, bufSize, name, mask); // an empty buffer when it does not fit
    if (cut != NULL)
        *cut = !fits;
    return buffer;
}

//
//*****************************************************************************
// Functions for quick-search
// the '/' character represents any number of characters (like '*' in a standard mask)

// returns TRUE if it is a wildcard character replacing '*'
// it must be a character not allowed in file names
// and at the same time, it should be easy to type (see the '<' on the German keyboard;
// for the backslash on the German keyboard you must press AltGr+\)
BOOL IsQSWildChar(char ch)
{
    return (ch == '/' || ch == '\\' || ch == '<');
}

void PrepareQSMask(char* mask, const char* src)
{
    CALL_STACK_MESSAGE2("PrepareQSMask(, %s)", src);
    char* begMask = mask;
    char lastChar = 0;
    while (*src != 0)
    {
        if (IsQSWildChar(*src))
        {
            if (lastChar == '/')
                src++;
            else
            {
                // convert other wild characters to '/'
                src++;
                *mask++ = (lastChar = '/');
            }
        }
        else
            *mask++ = (lastChar = *src++);
    }
    // trim '/' at the end of the mask (it has no meaning here)
    if (mask > begMask && *(mask - 1) == '/')
        mask--;
    *mask = 0;
}

BOOL AgreeQSMaskAux(const char* filename, BOOL hasExtension, const char* filenameBase, const char* mask, BOOL wholeString, int& offset)
{
    CALL_STACK_MESSAGE_NONE
    //  CALL_STACK_MESSAGE6("AgreeQSMaskAux(%s, %d, %s, %s, %d,)", filename, hasExtension, filenameBase, mask, wholeString);
    while (*filename != 0)
    {
        if (!wholeString && *mask == 0)
        {
            offset = (int)(filename - filenameBase);
            return TRUE; // end of mask, 'offset' = how far it reaches into the file name
        }
        // encoding-check: allow acp-byte-table-on-name - the quick-search matcher runs only for ASCII pairs (fileswn0.cpp); other names go to the Unicode path
        if (LowerCase[*filename] == LowerCase[*mask])
        {
            filename++;
            mask++;
        }
        else if (*mask == '/') // '/' stands for a sequence of characters (can be empty)
        {
            mask++;
            while (*filename != 0)
            {
                if (AgreeQSMaskAux(filename, hasExtension, filenameBase, mask, wholeString, offset))
                    return TRUE; // the rest of the mask matches
                filename++;
            }
            break; // end of filename...
        }
        else
            return FALSE;
    }
    if (*mask == 0 ||
        !hasExtension && *mask == '.' && *(mask + 1) == 0) // a dot at the end of the mask is tolerated for names without an extension ('/' at the end is trimmed, not handled)
    {
        offset = (int)(filename - filenameBase);
        return TRUE; // mask matched the entire name -> 'offset' = length of the file name
    }
    else
        return FALSE;
}

BOOL AgreeQSMask(const char* filename, BOOL hasExtension, const char* mask, BOOL wholeString, int& offset)
{
    SLOW_CALL_STACK_MESSAGE5("AgreeQSMask(%s, %d, %s, %d,)", filename, hasExtension, mask, wholeString);
    offset = 0;
    return AgreeQSMaskAux(filename, hasExtension, filename, mask, wholeString, offset);
}

//*****************************************************************************
//
// CMaskGroup
//

CMaskGroup::CMaskGroup()
    : PreparedMasks(10, 10)
{
    MasksString[0] = 0;
    NeedPrepare = FALSE;
    ExtendedMode = FALSE;
    MasksHashArray = NULL;
    MasksHashArraySize = 0;
}

CMaskGroup::CMaskGroup(const char* masks, BOOL extendedMode)
    : PreparedMasks(10, 10)
{
    MasksHashArray = NULL;
    MasksHashArraySize = 0;
    SetMasksString(masks, extendedMode);
}

CMaskGroup::~CMaskGroup()
{
    Release();
}

void CMaskGroup::Release()
{
    int i;
    for (i = 0; i < PreparedMasks.Count; i++)
    {
        if (PreparedMasks[i] != NULL)
        {
            free(PreparedMasks[i]);
            PreparedMasks[i] = NULL;
        }
    }
    PreparedMasks.DestroyMembers();
    ReleaseMasksHashArray();
}

CMaskGroup&
CMaskGroup::operator=(const CMaskGroup& s)
{
    Release();

    lstrcpy(MasksString, s.MasksString);
    ExtendedMode = s.ExtendedMode;

    NeedPrepare = TRUE;
    if (!s.NeedPrepare)
    {
        int errpos = 0;
        if (!PrepareMasks(errpos)) // an error shouldn't occur, the source mask is valid
            TRACE_E("CMaskGroup::operator= Internal error, PrepareMasks() failed.");
    }
    return *this;
}

void CMaskGroup::ReleaseMasksHashArray()
{
    if (MasksHashArray != NULL)
    {
        int i;
        for (i = 0; i < MasksHashArraySize; i++)
        {
            if (MasksHashArray[i].Mask != NULL) // if this array element is not empty
            {
                free(MasksHashArray[i].Mask);
                CMasksHashEntry* next = MasksHashArray[i].Next;
                while (next != NULL) // if there are multiple masks at the same entry (hash)
                {
                    CMasksHashEntry* nextNext = next->Next;
                    if (next->Mask != NULL)
                        free(next->Mask);
                    free(next);
                    next = nextNext;
                }
            }
        }
        free(MasksHashArray); // so destructors of objects in the array aren't called
        MasksHashArray = NULL;
        MasksHashArraySize = 0;
    }
}

void CMaskGroup::SetMasksString(const char* masks, BOOL extendedMode)
{
    int l = (int)strlen(masks);
    if (l > MAX_GROUPMASK - 1)
    {
        l = MAX_GROUPMASK - 1;
        TRACE_E("Group mask string is longer than MAX_GROUPMASK, using only first MAX_GROUPMASK-1 characters...");
    }
    // originally memcpy was used, but in some calls, the masks pointer referenced
    // MasksString itself, causing overlap
    memmove(MasksString, masks, l);

    MasksString[l] = 0;

    NeedPrepare = TRUE;
    ExtendedMode = extendedMode;
}

const char*
CMaskGroup::GetMasksString()
{
    return MasksString;
}

char* CMaskGroup::GetWritableMasksString()
{
    NeedPrepare = TRUE; // unfortunately also used as a write buffer, so we have to allow another PrepareMasks
    return MasksString;
}

BOOL CMaskGroup::GetExtendedMode()
{
    return ExtendedMode;
}

// The extension shortcut (MASK_OPTIMIZE_EXTENSION: the StrICmp compares in AgreeMasks and this
// table key) folds bytes through the code-page LowerCase table - it holds only masks with an ASCII
// extension (SalMaskOptimizeKind, feature 283); an accented name extension can never equal one
// (a UTF-8 continuation byte never folds to ASCII - saltests), it only picks some bucket
#define COMPUTEMASKGROUPHASH(hash, exten) \
    { \
        const unsigned char* __CMGH_ext = (exten); \
        if (*__CMGH_ext != 0) \
        { \
            hash = (LowerCase[*__CMGH_ext] - 'a'); \
            if (*++__CMGH_ext != 0) \
            { \
                hash += 3 * (LowerCase[*__CMGH_ext] - 'a'); \
                if (*++__CMGH_ext != 0) \
                    hash += 7 * (LowerCase[*__CMGH_ext] - 'a'); \
            } \
        } \
        hash = hash % MasksHashArraySize; \
    }

BOOL CMaskGroup::PrepareMasks(int& errorPos, const char* masksString)
{
    CALL_STACK_MESSAGE1("CMaskGroup::PrepareMasks(,)");
    if (masksString == NULL && !NeedPrepare)
        return TRUE;

    int i;
    for (i = 0; i < PreparedMasks.Count; i++)
        if (PreparedMasks[i] != NULL)
            free(PreparedMasks[i]);
    PreparedMasks.DestroyMembers();
    ReleaseMasksHashArray();

    const char* useMasksString = masksString == NULL ? MasksString : masksString;
    const char* s = useMasksString;
    int excludePos = -1;   // if not -1, all following masks are exclude type
                           // and will be inserted at the beginning of the array
    int hashableMasks = 0; // number of masks that can be hashed (MASK_OPTIMIZE_EXTENSION + CMaskItemFlags::Exclude==0)

    // to avoid unnecessary reallocations for longer arrays, set a reasonable delta
    size_t masksLen = strlen(s);
    PreparedMasks.SetDelta(max(10, (int)(masksLen / 6) / 2)); // "*.xxx;" is 6 characters, use half the extensions

    // feature 298: one mask may fill the whole group text (were two MAX_PATH stack buffers - a single
    // mask of 260+ bytes ran over the stack); neither the cut nor PrepareMask writes more than the
    // text's length + 1 bytes (salmaskgroup.h), so every mask is prepared whole
    struct CWorkFree
    {
        char* P;
        ~CWorkFree() { free(P); }
    } workFree = {(char*)malloc(2 * (masksLen + 1))};
    if (workFree.P == NULL)
    {
        TRACE_E(LOW_MEMORY);
        errorPos = 0;
        return FALSE;
    }
    char* maskBuf = workFree.P;
    char* buf = workFree.P + masksLen + 1;

    while (1)
    {
        s = SalMaskGroupCutMask(s, maskBuf);
        if (*s != 0 && *s != ';' && (*s != '|' || excludePos != -1)) // the exclude character '|' may appear only once in the mask
        {
            errorPos = (int)(s - useMasksString);
            return FALSE;
        }

        char* mask = SalMaskGroupTrimMask(maskBuf);

        if (*mask != 0)
        {
            SalPrepareMaskU8(buf, mask); // PrepareMask, for extendedMode as well
            if (buf[0] != 0)
            {
                int l = (int)strlen(buf) + 1;
                char* newMask = (char*)malloc(1 + l);
                if (newMask != NULL)
                {
                    CMaskItemFlags* flags = (CMaskItemFlags*)newMask;
                    // determine whether one of the optimizations can be used (*.* or *; *.xxxx with
                    // an ASCII extension - feature 283: an accented one goes to AgreeMask)
                    flags->Optimize = SalMaskOptimizeKind(buf, ExtendedMode);
                    if (flags->Optimize == MASK_OPTIMIZE_EXTENSION && excludePos == -1)
                        hashableMasks++;
                    flags->Exclude = excludePos != -1 ? 1 : 0;

                    memmove(newMask + 1, buf, l);
                    if (excludePos != -1)
                        PreparedMasks.Insert(0, newMask); // insert exclude masks at the beginning
                    else
                        PreparedMasks.Add(newMask); // append include masks at the end
                    if (!PreparedMasks.IsGood())
                    {
                        free(newMask);
                        PreparedMasks.ResetState();
                        errorPos = 0;
                        return FALSE;
                    }
                }
                else
                {
                    TRACE_E(LOW_MEMORY);
                    errorPos = 0;
                    return FALSE;
                }
            }
        }

        if (*s == 0)
        {
            if (excludePos != -1 && (PreparedMasks.Count == 0 ||
                                     ((CMaskItemFlags*)PreparedMasks[0])->Exclude == 0))
            {
                // if the '|' character is not followed by another mask, the syntax is invalid
                errorPos = excludePos;
                return FALSE;
            }
            break;
        }
        if (*s == '|')
        {
            if (PreparedMasks.Count == 0)
            {
                // the user specified a sequence starting with '|', we must append an implicit * at the end
                char* newMask = (char*)malloc(1 + 2);
                if (newMask != NULL)
                {
                    CMaskItemFlags* flags = (CMaskItemFlags*)newMask;
                    flags->Optimize = MASK_OPTIMIZE_ALL;
                    flags->Exclude = 0;
                    newMask[1] = '*';
                    newMask[2] = 0;
                    PreparedMasks.Add(newMask);
                    if (!PreparedMasks.IsGood())
                    {
                        free(newMask);
                        PreparedMasks.ResetState();
                        errorPos = 0;
                        return FALSE;
                    }
                }
                else
                {
                    TRACE_E(LOW_MEMORY);
                    errorPos = 0;
                    return FALSE;
                }
            }
            excludePos = (int)(s - useMasksString); // the next mask will be of the exclude type
        }
        s++;
    }

    if (hashableMasks >= 10) // to be worthwhile there should be at least 10
    {
        MasksHashArraySize = 2 * hashableMasks;
        MasksHashArray = (CMasksHashEntry*)malloc(MasksHashArraySize * sizeof(CMasksHashEntry));
        if (MasksHashArray != NULL)
        {
            memset(MasksHashArray, 0, MasksHashArraySize * sizeof(CMasksHashEntry));
            int i2;
            for (i2 = PreparedMasks.Count - 1; i2 >= 0; i2--)
            {
                CMaskItemFlags* mask = (CMaskItemFlags*)PreparedMasks[i2];
                if (mask->Optimize == MASK_OPTIMIZE_EXTENSION &&
                    mask->Exclude == 0)
                { // this mask can be hashed; add it to the hash array
                    DWORD hash = 0;
                    COMPUTEMASKGROUPHASH(hash, (unsigned char*)mask + 3);
                    if (MasksHashArray[hash].Mask == NULL)
                    {
                        MasksHashArray[hash].Mask = mask;
                        PreparedMasks.Detach(i2);
                        if (!PreparedMasks.IsGood())
                            PreparedMasks.ResetState(); // Detach always succeeds (at most the array won't shift, which is fine)
                    }
                    else
                    {
                        CMasksHashEntry* next = &MasksHashArray[hash];
                        while (next->Next != NULL)
                        {
                            next = next->Next;
                        }
                        next->Next = (CMasksHashEntry*)malloc(sizeof(CMasksHashEntry));
                        if (next->Next != NULL)
                        {
                            next->Next->Mask = mask;
                            next->Next->Next = NULL;
                            PreparedMasks.Detach(i2);
                            if (!PreparedMasks.IsGood())
                                PreparedMasks.ResetState(); // Detach always succeeds (at most the array won't shift, which is fine)
                        }
                        else // out of memory -> nothing happens, we skip this one mask
                            TRACE_E(LOW_MEMORY);
                    }
                }
            }
            /*
#ifdef _DEBUG
      int maxDepth = 0;
      int squareOfDepths = 0;
      int usedIndexes = 0;
      for (i = 0; i < MasksHashArraySize; i++)
      {
        CMasksHashEntry *next = &MasksHashArray[i];
        if (next->Mask != NULL)
        {
          int depth = 1;
          while (next->Next != NULL)
          {
            next = next->Next;
            depth++;
          }
          if (depth > maxDepth) maxDepth = depth;
          if (depth > 1) squareOfDepths += depth * depth;
          usedIndexes++;
        }
      }
      TRACE_I("CMaskGroup::PrepareMasks(): maxHashDepth=" << maxDepth << ", count=" <<
              hashableMasks << ", squareOfDepths=" << squareOfDepths << ", usedIndexes=" << usedIndexes);
#endif // _DEBUG
*/
        }
        else // out of memory -> we simply won't accelerate searching in masks
        {
            TRACE_E(LOW_MEMORY);
            MasksHashArraySize = 0;
        }
    }
    NeedPrepare = FALSE;
    return TRUE;
}

BOOL CMaskGroup::AgreeMasks(const char* fileName, const char* fileExt)
{
    if (NeedPrepare)
        TRACE_E("CMaskGroup::AgreeMasks: PrepareMasks must be called before AgreeMasks!");

    SLOW_CALL_STACK_MESSAGE3("CMaskGroup::AgreeMasks(%s, %s)", fileName, fileExt);
    if (fileExt == NULL)
    {
        int tmpLen = lstrlen(fileName);
        fileExt = fileName + tmpLen;
        while (--fileExt >= fileName && *fileExt != '.')
            ;
        if (fileExt < fileName)
            fileExt = fileName + tmpLen; // ".cvspass" in Windows is an extension ...
        else
            fileExt++;
    }
    const char* ext = fileExt;
    if (*ext == 0 && *fileName == '.' && *(ext - 1) != '.') // may be the ".cvspass" case; ".." has no extension
    {
        TRACE_E("CMaskGroup::AgreeMasks: Unexpected situation: fileName starts with '.' but fileExt points to end of name: " << fileName);
        ext = fileName + 1;
    }
    int i;
    // an extension mask (*.xxxx) is ASCII only (feature 283): the byte compare with StrICmp decides
    // as AgreeMask does for an ASCII name and never matches an accented extension; accented
    // extension masks are MASK_OPTIMIZE_NONE (AgreeMask, whole letters)
    for (i = 0; i < PreparedMasks.Count; i++)
    {
        char* mask = PreparedMasks[i];
        if (mask != NULL)
        {
            CMaskItemFlags* flags = (CMaskItemFlags*)mask;
            if (flags->Exclude == 1)
            {
                if (flags->Optimize == MASK_OPTIMIZE_ALL) // *.*; *
                    return FALSE;
                if (flags->Optimize == MASK_OPTIMIZE_EXTENSION) // *.xxxx
                {
                    if (StrICmp(ext, mask + 3) == 0)
                        return FALSE;
                    else
                        continue;
                }
                mask++;
                if (AgreeMask(fileName, mask, *fileExt != 0, ExtendedMode))
                    return FALSE;
            }
            else
            {
                if (flags->Optimize == MASK_OPTIMIZE_ALL) // *.*; *
                    return TRUE;
                if (flags->Optimize == MASK_OPTIMIZE_EXTENSION) // *.xxxx
                {
                    if (StrICmp(ext, mask + 3) == 0)
                        return TRUE;
                    else
                        continue;
                }
                mask++;
                if (AgreeMask(fileName, mask, *fileExt != 0, ExtendedMode))
                    return TRUE;
            }
        }
    }
    if (MasksHashArray != NULL) // there are still some masks in the hash array
    {
        DWORD hash = 0;
        COMPUTEMASKGROUPHASH(hash, (unsigned char*)ext);
        CMasksHashEntry* item = &MasksHashArray[hash];
        if (item->Mask != NULL)
        {
            do
            {
                if (StrICmp(ext, ((char*)item->Mask) + 3) == 0)
                    return TRUE;
                item = item->Next;
            } while (item != NULL);
        }
    }
    return FALSE;
}
