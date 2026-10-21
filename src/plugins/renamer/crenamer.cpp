// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "../../common/salu8letter.h" // features 210 / 254: the search folds characters, judges letters

// ****************************************************************************
//
// CSourceFile
//

CSourceFile::CSourceFile(const CFileData* fileData,
                         const char* path, int pathLen, BOOL isDir)
{
    CALL_STACK_MESSAGE_NONE
    NameLen = pathLen + fileData->NameLen;
    if (path[pathLen - 1] != '\\')
    {
        FullName = (char*)malloc(++NameLen + 1);
        memcpy(FullName, path, pathLen);
        FullName[pathLen++] = '\\';
    }
    else
    {
        FullName = (char*)malloc(NameLen + 1);
        memcpy(FullName, path, pathLen);
    }
    Name = FullName + pathLen;
    memcpy(Name, fileData->Name, fileData->NameLen + 1);
    Ext = Name + (isDir ? fileData->NameLen : fileData->Ext - fileData->Name);
    Size = fileData->Size;
    Attr = fileData->Attr;
    FileTimeToLocalFileTime(&fileData->LastWrite, &LastWrite);
    IsDir = isDir ? 1 : 0;
    State = 0;
}

CSourceFile::CSourceFile(CSourceFile* orig)
{
    CALL_STACK_MESSAGE_NONE
    FullName = SG->DupStr(orig->FullName);
    Name = FullName + (orig->Name - orig->FullName);
    Ext = FullName + (orig->Ext - orig->FullName);
    Size = orig->Size;
    Attr = orig->Attr;
    LastWrite = orig->LastWrite;
    NameLen = orig->NameLen;
    IsDir = orig->IsDir;
    State = 0;
}

CSourceFile::CSourceFile(CSourceFile* orig, const char* newName)
{
    CALL_STACK_MESSAGE_NONE
    FullName = Name = SG->DupStr(newName);
    Ext = NULL;
    char* iterator = FullName;
    while (*iterator != 0)
    {
        if (*iterator == '\\')
        {
            Name = iterator + 1;
            Ext = NULL;
        }
        if (*iterator == '.' /*&& iterator > Name*/) // ".cvspass" is an extension in Windows
            Ext = iterator + 1;
        iterator++;
    }
    if (orig->IsDir || Ext == NULL)
        Ext = iterator; // directories do not have an extension + when a file has no extension
    NameLen = iterator - FullName;
    Size = orig->Size;
    Attr = orig->Attr;
    LastWrite = orig->LastWrite;
    IsDir = orig->IsDir;
    State = 0;
}

CSourceFile::CSourceFile(WIN32_FIND_DATAW& fd, const char* fileName, const char* path, int pathLen)
{
    CALL_STACK_MESSAGE_NONE
    // 'fileName' is fd.cFileName in UTF-8 (plugin interface 104), 'path' is UTF-8 as well
    NameLen = (unsigned)(pathLen + strlen(fileName) + 1);
    FullName = (char*)malloc(NameLen + 1);
    memcpy(FullName, path, pathLen);
    FullName[pathLen++] = '\\';
    strcpy(FullName + pathLen, fileName);
    Name = FullName + pathLen;
    Ext = FullName + NameLen;
    while (--Ext >= Name && *Ext != '.')
        ;
    if (Ext < Name)
        Ext = FullName + NameLen; // ".cvspass" is an extension in Windows
    else
        Ext++;
    Size = CQuadWord(fd.nFileSizeLow, fd.nFileSizeHigh);
    Attr = fd.dwFileAttributes;
    FileTimeToLocalFileTime(&fd.ftLastWriteTime, &LastWrite);
    IsDir = FALSE;
    State = 0;
}

CSourceFile::~CSourceFile()
{
    CALL_STACK_MESSAGE_NONE
    if (FullName)
        free(FullName);
}

CSourceFile*
CSourceFile::SetName(const char* name)
{
    CALL_STACK_MESSAGE_NONE
    if (FullName)
        free(FullName);
    FullName = Name = SG->DupStr(name);
    Ext = NULL;
    char* iterator = FullName;
    while (*iterator != 0)
    {
        if (*iterator == '\\')
        {
            Name = iterator + 1;
            Ext = NULL;
        }
        if (*iterator == '.' /*&& iterator > Name*/) // ".cvspass" is an extension in Windows
            Ext = iterator + 1;
        iterator++;
    }
    if (IsDir || Ext == NULL)
        Ext = iterator; // directories do not have an extension + when a file has no extension
    NameLen = iterator - FullName;
    return this;
}

// ****************************************************************************
//
// CRenamerOptions
//

const char* CONFIG_NEWNAME = "NewName";
const char* CONFIG_SEARCHFOR = "SearchFor";
const char* CONFIG_REPLACEWITH = "ReplaceWith";
const char* CONFIG_CASESENSITIVE = "CaseSensitive";
const char* CONFIG_WHOLEWORDS = "WholeWords";
const char* CONFIG_GLOBAL = "Global";
const char* CONFIG_REGEXP = "RegExp";
const char* CONFIG_EXCLUDEEXT = "ExcludeExt";
const char* CONFIG_FILECASE = "FileCase";
const char* CONFIG_EXTCASE = "ExtCase";
const char* CONFIG_INCLUDEPATH = "IncludePath";
const char* CONFIG_SPEC = "Spec";

void CRenamerOptions::Reset(BOOL soft)
{
    CALL_STACK_MESSAGE_NONE
    strcpy(NewName, "$(OriginalName)");
    SearchFor[0] = 0;
    ReplaceWith[0] = 0;
    CaseSensitive = TRUE;
    WholeWords = FALSE;
    Global = FALSE;
    RegExp = FALSE;
    ExcludeExt = FALSE;
    FileCase = ccDontChange;
    ExtCase = ccDontChange;
    IncludePath = FALSE;
    if (!soft)
        Spec = rsFileName;
}

BOOL CRenamerOptions::Load(HKEY regKey, CSalamanderRegistryAbstract* registry)
{
    CALL_STACK_MESSAGE1("CRenamerOptions::Load(, )");
    Reset(FALSE);
    registry->GetValue(regKey, CONFIG_NEWNAME, REG_SZ, NewName, 2 * MAX_PATH);
    registry->GetValue(regKey, CONFIG_SEARCHFOR, REG_SZ, SearchFor, 2 * MAX_PATH);
    registry->GetValue(regKey, CONFIG_REPLACEWITH, REG_SZ, ReplaceWith, MAX_PATH);
    registry->GetValue(regKey, CONFIG_CASESENSITIVE, REG_DWORD, &CaseSensitive, sizeof(BOOL));
    registry->GetValue(regKey, CONFIG_WHOLEWORDS, REG_DWORD, &WholeWords, sizeof(BOOL));
    registry->GetValue(regKey, CONFIG_GLOBAL, REG_DWORD, &Global, sizeof(BOOL));
    registry->GetValue(regKey, CONFIG_REGEXP, REG_DWORD, &RegExp, sizeof(BOOL));
    registry->GetValue(regKey, CONFIG_EXCLUDEEXT, REG_DWORD, &ExcludeExt, sizeof(BOOL));
    registry->GetValue(regKey, CONFIG_FILECASE, REG_DWORD, &FileCase, sizeof(int));
    registry->GetValue(regKey, CONFIG_EXTCASE, REG_DWORD, &ExtCase, sizeof(int));
    registry->GetValue(regKey, CONFIG_INCLUDEPATH, REG_DWORD, &IncludePath, sizeof(BOOL));
    registry->GetValue(regKey, CONFIG_SPEC, REG_DWORD, &Spec, sizeof(int));
    return TRUE;
}

BOOL CRenamerOptions::Save(HKEY regKey, CSalamanderRegistryAbstract* registry)
{
    CALL_STACK_MESSAGE1("CRenamerOptions::Save(, )");
    registry->SetValue(regKey, CONFIG_NEWNAME, REG_SZ, NewName, -1);
    registry->SetValue(regKey, CONFIG_SEARCHFOR, REG_SZ, SearchFor, -1);
    registry->SetValue(regKey, CONFIG_REPLACEWITH, REG_SZ, ReplaceWith, -1);
    registry->SetValue(regKey, CONFIG_CASESENSITIVE, REG_DWORD, &CaseSensitive, sizeof(BOOL));
    registry->SetValue(regKey, CONFIG_WHOLEWORDS, REG_DWORD, &WholeWords, sizeof(BOOL));
    registry->SetValue(regKey, CONFIG_GLOBAL, REG_DWORD, &Global, sizeof(BOOL));
    registry->SetValue(regKey, CONFIG_REGEXP, REG_DWORD, &RegExp, sizeof(BOOL));
    registry->SetValue(regKey, CONFIG_EXCLUDEEXT, REG_DWORD, &ExcludeExt, sizeof(BOOL));
    registry->SetValue(regKey, CONFIG_FILECASE, REG_DWORD, &FileCase, sizeof(int));
    registry->SetValue(regKey, CONFIG_EXTCASE, REG_DWORD, &ExtCase, sizeof(int));
    registry->SetValue(regKey, CONFIG_INCLUDEPATH, REG_DWORD, &IncludePath, sizeof(BOOL));
    registry->SetValue(regKey, CONFIG_SPEC, REG_DWORD, &Spec, sizeof(int));
    return TRUE;
}

// ****************************************************************************
//
// CRenamer
//

CRenamer::CRenamer(char (&root)[MAX_PATH], int& rootLen)
    : Root(root), RootLen(rootLen)
{
    CALL_STACK_MESSAGE2("CRenamer::CRenamer(, %d)", rootLen);
    BMSearch = SG->AllocSalamanderBMSearchData();
    RegExp = CreateRegExp();
    FoldSearch = FALSE;
    FoldRegex = FALSE;
    ExecSource = ExecFolded = NULL;
}

CRenamer::~CRenamer()
{
    CALL_STACK_MESSAGE1("CRenamer::~CRenamer()");
    SG->FreeSalamanderBMSearchData(BMSearch);
    ReleaseRegExp(RegExp);
}

BOOL CRenamer::SetOptions(CRenamerOptions* options)
{
    CALL_STACK_MESSAGE1("CRenamerOptions( )");
    Spec = options->Spec;
    FileCase = options->FileCase;
    ExtCase = options->ExtCase;
    IncludePath = options->IncludePath;

    if (!NewName.Compile(options->NewName, Error, ErrorPos1, ErrorPos2, NewNameVariables))
    {
        ErrorType = retNewName;
        return FALSE;
    }

    if (options->SearchFor[0] != '\0')
    {
        Substitute = TRUE;
        strcpy(ReplaceWith, options->ReplaceWith);
        ReplaceWithLen = (int)strlen(ReplaceWith);
        WholeWords = options->WholeWords;
        Global = options->Global;
        ExcludeExt = options->ExcludeExt;

        FoldSearch = FoldRegex = FALSE;
        if ((UseRegExp = options->RegExp) != 0)
        {
            unsigned opts = RE_SINGLELINE;
            if (!options->CaseSensitive)
                opts |= RE_CASELES;

            // feature 210: the engine folds only ASCII now (regexp.cpp); the pattern's other
            // characters are folded here - the syntax is ASCII, so nothing of it changes - and the
            // name's in RESubst
            char pattern[2 * MAX_PATH];
            strncpy_s(pattern, options->SearchFor, _TRUNCATE); // the same size as SearchFor: nothing cut
            if (!options->CaseSensitive)
            {
                FoldRegex = TRUE;
                SalU8FoldSameLength(pattern, (int)strlen(pattern), pattern, TRUE);
            }
            if (!RegExp->RegComp(pattern, opts))
            {
                Error = GetRegExpErrorID(RegExp->GetState());
                ErrorPos1 = 0;
                ErrorPos2 = 0;
                ErrorType = retRegExp;
                return FALSE;
            }

            if (!ValidetaReplacePattern())
                return FALSE;
        }
        else
        {
            // feature 210: always case-sensitive - a case-insensitive search folds the pattern here and
            // the name in BMSubst by characters (the core's fold of the bytes: "C-dot" = "E-caron")
            WORD flags = SASF_FORWARD | SASF_CASESENSITIVE;
            char pattern[2 * MAX_PATH];
            strncpy_s(pattern, options->SearchFor, _TRUNCATE); // the same size as SearchFor: nothing cut
            if (!options->CaseSensitive)
            {
                FoldSearch = TRUE;
                SalU8FoldSameLength(pattern, (int)strlen(pattern), pattern, FALSE);
            }

            BMSearch->Set(pattern, flags);
            if (!BMSearch->IsGood())
            {
                Error = IDS_LOWMEM;
                ErrorPos1 = 0;
                ErrorPos2 = 0;
                ErrorType = retBMSearch;
                return FALSE;
            }
        }
    }
    else
        Substitute = FALSE;

    Error = 0;
    return TRUE;
}

int CRenamer::Rename(CSourceFile* file, int counter, char* newName, int newNameSize, char** newPart)
{
    CALL_STACK_MESSAGE_NONE
    if (!IsGood())
        return -1;

    // feature 282: the name is built into 'newNameSize' bytes (REN_MAX_NAME - the longest path in
    // UTF-8); it was MAX_PATH. The folder part is copied only when it fits with a name character.
    int pathLen = 0;
    if (newPart)
    {
        switch (Spec)
        {
        case rsFileName:
        {
            pathLen = (int)(file->Name - file->FullName);
            if (pathLen + 2 > newNameSize)
                return -1; // does not fit: refused as too large, never cut
            memcpy(newName, file->FullName, pathLen);
            break;
        }
        case rsRelativePath:
        {
            pathLen = RootLen;
            if (pathLen + 3 > newNameSize)
                return -1;
            memcpy(newName, Root, pathLen);
            if (newName[pathLen - 1] != '\\')
                newName[pathLen++] = '\\';
            break;
        }
        case rsFullPath:
            break;
        }
        newName += pathLen;
        *newPart = newName;
    }

    // parameters for expanding the New Name var-string
    CExecuteNewNameParam param;
    param.Spec = Spec;
    param.File = file;
    param.Counter = counter;
    param.RootLen = RootLen;

    int cap = newNameSize - pathLen; // what 'newName' holds from here
    int l;
    if (Substitute)
    {
        // feature 282: on the heap, as large as the name (it was char[MAX_PATH])
        char* tmp = (char*)malloc(newNameSize);
        if (tmp == NULL)
            return -1;
        struct CFreeTmp
        {
            char* P;
            ~CFreeTmp() { free(P); }
        } freeTmp = {tmp};

        // expand the New Name into a temporary buffer
        l = NewName.Execute(tmp, newNameSize, &param);
        if (l < 0)
            return -1;
        // l is strlen(tmp)
        if (ExcludeExt && !file->IsDir) // extensions are searched only for files
        {
            int i = l, namel = l;
            while (--i >= 0 && tmp[i] != '\\')
            {
                if (tmp[i] == '.') // ".cvspass" is an extension in Windows
                {
                    namel = i;
                    break;
                }
            }

            // perform the requested substitution in the name
            int substl = UseRegExp ? RESubst(tmp, namel, newName, cap) : BMSubst(tmp, namel, newName, cap);

            // dokopirujeme extension
            if (substl < 0 || substl + (l - namel) >= cap)
                return -1;
            memcpy(newName + substl, tmp + namel, l - namel + 1);
            // calculate new name length : substed name len + appended ext len - '\0'
            l = substl + l - namel;
        }
        else
        {
            // perform the requested substitution
            l = UseRegExp ? RESubst(tmp, l, newName, cap) : BMSubst(tmp, l, newName, cap);
        }
    }
    else
    {
        // expand the New Name
        l = NewName.Execute(newName, cap, &param);
    }

    if (l < 0)
        return -1;

    if (FileCase != ccDontChange || ExtCase != ccDontChange)
    {
        char* filePart = newName + l - 1;
        char* ext = NULL;
        while (filePart >= newName && *filePart != '\\')
        {
            if (ext == NULL && *filePart == '.')
                ext = filePart; // ".cvspass" is an extension in Windows
            filePart--;
        }
        filePart++;
        if (file->IsDir || ext == NULL)
            ext = newName + l; // extensions are searched only for files

        // feature 208: the UTF-8 length may change - built anew: the part before, the name, the extension
        char* s = FileCase != ccDontChange && IncludePath ? newName : filePart;
        // 'cap': what 'newName' holds (as given to Execute)
        char* built = (char*)malloc(cap);
        if (built == NULL)
            return -1;
        int pos = (int)(s - newName);
        memcpy(built, newName, pos);
        int n = ChangeCase(FileCase, built + pos, cap - 1 - pos, s, s, ext);
        if (n >= 0)
        {
            pos += n;
            n = ChangeCase(ExtCase, built + pos, cap - 1 - pos, ext, ext, newName + l);
        }
        if (n < 0)
        {
            free(built);
            return -1; // does not fit: the name is refused as too long
        }
        pos += n;
        memcpy(newName, built, pos);
        newName[pos] = 0;
        free(built);
        l = pos;
    }

    return l;
}

int CRenamer::BMSearchForward(const char* string, int length, int offset)
{
    CALL_STACK_MESSAGE_NONE
    while (offset < length)
    {
        int ret = BMSearch->SearchForward(string, length, offset);
        if (ret == -1)
            return -1;

        if (WholeWords)
        {
            // check for a word break - feature 210: by characters (a byte of a UTF-8 letter was
            // judged through the code page); feature 254: a combining mark and a letter outside the
            // BMP belong to the word (salu8letter.h)
            int matchEnd = ret + BMSearch->GetLength();
            int prev = SalU8IsAlnumBefore(string, length, ret);
            int start = SalU8IsAlnumAt(string, length, ret);
            int end = SalU8IsAlnumBefore(string, length, matchEnd);
            int next = SalU8IsAlnumAt(string, length, matchEnd);
            if (prev != start && end != next)
                return ret;
            offset++;
        }
        else
            return ret;
    }
    return -1;
}

BOOL SafeCopy(char* dest, int max, int& pos, const char* source, int count)
{
    CALL_STACK_MESSAGE_NONE
    if (count + pos > max)
        return FALSE;
    memcpy(dest + pos, source, count);
    pos += count;
    return TRUE;
}

BOOL SafeCopy(char* dest, int max, int& pos, const char* source, int count,
              CChangeCase changeCase)
{
    CALL_STACK_MESSAGE_NONE
    // feature 208: the case changed on letters - the length may change
    int n = ChangeCase(changeCase, dest + pos, max - pos, source, source, source + count);
    if (n < 0)
        return FALSE;
    pos += n;
    return TRUE;
}

int CRenamer::BMSubst(const char* source, int len, char* dest, int max)
{
    CALL_STACK_MESSAGE_NONE
    int start;
    int pos = 0;
    int offset = 0;

    // feature 210: a case-insensitive search runs over a folded copy - its offsets are the name's
    char* folded = NULL;
    const char* searched = source;
    if (FoldSearch)
    {
        folded = (char*)malloc(len + 1);
        if (folded == NULL)
            return -1;
        SalU8FoldSameLength(source, len + 1, folded, FALSE);
        searched = folded;
    }
    struct CFreeFolded
    {
        char* P;
        ~CFreeFolded() { free(P); }
    } freeFolded = {folded};

    while ((start = BMSearchForward(searched, len, offset)) >= 0)
    {
        // copy the part before the found pattern
        if (!SafeCopy(dest, max, pos, source + offset, start - offset))
            return -1;

        // replace the found pattern with the requested substitution
        if (!SafeCopy(dest, max, pos, ReplaceWith, ReplaceWithLen))
            return -1;

        // move the offset forward
        offset = start + BMSearch->GetLength();
        if (!Global || offset >= len)
            break;
    }

    // copy the part (including the terminating NULL) after the last found string
    if (!SafeCopy(dest, max, pos, source + offset, len - offset + 1))
        return -1;

    return pos - 1; // do not count the terminating NULL
}

BOOL CRenamer::ValidetaReplacePattern()
{
    CALL_STACK_MESSAGE_NONE
    ErrorType = retReplacePattern;
    const char* replace = ReplaceWith;
    BOOL bs = FALSE;
    char paren;
    const char* numberStart;
    const char* numberEnd;
    while (*replace)
    {
        // treat '\\' as a regular character
        // if ((bs = *replace == '\\') || *replace == '$')
        if (*replace == '$')
        {
            replace++;
            paren = 0;
            if (!bs && (*replace == '(' || *replace == '{'))
            {
                paren = *replace == '(' ? ')' : '}';
                replace++;
            }
            if (IsDigit(*replace))
            {
                numberStart = replace;
                int i = 0;
                do
                {
                    i = i * 10 + *replace - '0';
                } while (IsDigit(*++replace));
                numberEnd = replace;
                CChangeCase changeCase = ccDontChange;
                if (paren)
                {
                    if (*replace == ':')
                    {
                        replace++;
                        if (SG->StrNICmp(replace, "lower", sizeof("lower") - 1) == 0)
                            replace += sizeof("lower") - 1;
                        else if (SG->StrNICmp(replace, "upper", sizeof("upper") - 1) == 0)
                            replace += sizeof("upper") - 1;
                        else if (SG->StrNICmp(replace, "mixed", sizeof("mixed") - 1) == 0)
                            replace += sizeof("mixed") - 1;
                        else if (SG->StrNICmp(replace, "stripdia", sizeof("stripdia") - 1) == 0)
                            replace += sizeof("stripdia") - 1;
                        else if (*replace != paren)
                        {
                            // expecting a closing bracket or a size definition
                            Error = IDS_REP_EXPCLOSEPAR1;
                            ErrorPos1 = ErrorPos2 = (int)(replace - ReplaceWith);
                            return FALSE;
                        }
                        if (*replace != paren)
                        {
                            // expecting a closing bracket
                            Error = IDS_REP_EXPCLOSEPAR2;
                            ErrorPos1 = ErrorPos2 = (int)(replace - ReplaceWith);
                            return FALSE;
                        }
                    }
                    else
                    {
                        if (*replace != paren)
                        {
                            // expecting a closing bracket or a colon and size definition
                            Error = IDS_REP_EXPCLOSEPAR3;
                            ErrorPos1 = ErrorPos2 = (int)(replace - ReplaceWith);
                            return FALSE;
                        }
                    }
                    replace++;
                }
                if (i >= RegExp->SubExpCount)
                {
                    // reference to an undefined subpattern
                    Error = IDS_REP_BADREF;
                    ErrorPos1 = (int)(numberStart - ReplaceWith);
                    ErrorPos2 = (int)(numberEnd - ReplaceWith);
                    return FALSE;
                }
            }
            else
            {
                if (paren)
                {
                    Error = IDS_EXP_EXPECTSUBNUM1;
                    ErrorPos1 = ErrorPos2 = (int)(replace - ReplaceWith);
                    return FALSE;
                }
                if (!bs && *replace != '$')
                {
                    Error = IDS_EXP_EXPECTSUBNUM2;
                    ErrorPos1 = ErrorPos2 = (int)(replace - ReplaceWith);
                    return FALSE;
                }
                if (*replace == 0)
                {
                    Error = IDS_EXP_EXPECTSUBNUM2;
                    ErrorPos1 = ErrorPos2 = (int)(replace - ReplaceWith);
                    return FALSE;
                }
                replace++;
            }
        }
        else
            replace++;
    }
    return TRUE;
}

BOOL CRenamer::SafeSubst(char* dest, int max, int& pos)
{
    CALL_STACK_MESSAGE_NONE
    // the ReplaceWith string must be validated; this is optimized code
    // without syntax checking
    const char* replace = ReplaceWith;
    BOOL paren;
    while (*replace)
    {
        if (pos == max)
            return FALSE;
        // treat '\\' as a regular character
        // if (*replace == '\\' || *replace == '$')
        if (*replace == '$')
        {
            paren = FALSE;
            if (*++replace == '(' || *replace == '{')
            {
                paren = TRUE;
                replace++;
            }
            if (IsDigit(*replace))
            {
                int i = 0;
                do
                {
                    i = i * 10 + *replace - '0';
                } while (IsDigit(*++replace));
                CChangeCase changeCase = ccDontChange;
                if (paren)
                {
                    if (*replace++ == ':') // skip the closing bracket or ':'
                    {
                        switch (*replace)
                        {
                        case 'l':
                            changeCase = ccLower;
                            replace += sizeof("lower") - 1 + 1;
                            break;
                        case 'u':
                            changeCase = ccUpper;
                            replace += sizeof("upper") - 1 + 1;
                            break;
                        case 'm':
                            changeCase = ccMixed;
                            replace += sizeof("mixed") - 1 + 1;
                            break;
                        case 's':
                            changeCase = ccStripDia;
                            replace += sizeof("stripdia") - 1 + 1;
                            break;
                        default: // '}' nebo ')'
                            replace++;
                            break;
                        }
                    }
                }
                // feature 210: the subexpression is copied from the name, not from its folded copy
                if (i < RegExp->SubExpCount && RegExp->Startp[i] != NULL && // a group that took part
                    !SafeCopy(dest, max, pos, ExecSource + (RegExp->Startp[i] - ExecFolded),
                              (int)(RegExp->Endp[i] - RegExp->Startp[i]), changeCase))
                    return FALSE;
            }
            else
                dest[pos++] = *replace++;
        }
        else
            dest[pos++] = *replace++;
    }
    return TRUE;
}

int CRenamer::RESubst(const char* source, int len, char* dest, int max)
{
    CALL_STACK_MESSAGE_NONE
    int pos = 0;
    int offset = 0;
    int skipChar = 0;

    // feature 210: a case-insensitive expression runs over a copy whose non-ASCII characters are
    // folded (the same length - its offsets are the name's); everything is copied from the name
    char* folded = NULL;
    const char* subject = source;
    if (FoldRegex)
    {
        folded = (char*)malloc(len + 1);
        if (folded == NULL)
            return -1;
        SalU8FoldSameLength(source, len + 1, folded, TRUE);
        subject = folded;
    }
    struct CFreeFolded
    {
        char* P;
        ~CFreeFolded() { free(P); }
    } freeFolded = {folded};
    ExecSource = source;
    ExecFolded = subject;

    while (RegExp->RegExec((char*)subject, len, offset + skipChar))
    {
        // copy the part before the found pattern
        if (!SafeCopy(dest, max, pos, source + offset,
                      (int)(RegExp->Startp[0] - subject - offset)))
            return -1;

        // replace the found pattern with the requested substitution
        if (!SafeSubst(dest, max, pos))
            return -1;

        // move the offset forward
        offset = (int)(RegExp->Endp[0] - subject);
        // feature 254: after an empty match the next attempt starts past a whole letter - one byte
        // put the replacement inside a UTF-8 letter ("(123) the name is incorrect")
        skipChar = 0;
        if (RegExp->Endp[0] == RegExp->Startp[0] && offset < len)
        {
            unsigned unitValue;
            skipChar = SalU8UnitLen(subject + offset, subject + len, &unitValue);
        }
        else if (RegExp->Endp[0] == RegExp->Startp[0])
            skipChar = 1; // at the end: RegExec refuses an offset past the text
        if (!Global)
            break;
    }

    // copy the part (including the terminating NULL) after the last found string
    if (!SafeCopy(dest, max, pos, source + offset, len - offset + 1))
        return -1;

    return pos - 1; // do not count the terminating NULL
}

// ****************************************************************************

// feature 208: the names are UTF-8 (interface 104); the case is changed on their letters - the
// code-page byte tables (CharLowerA) turned UTF-8 into invalid bytes ("(123) the name is
// incorrect") and "strip diacritics" read the bytes through CP_ACP. The UTF-8 length may change
// (c-caron 2 bytes -> c 1 byte, dotless i 2 -> I 1): the bytes written to 'dst' are returned, -1
// when they do not fit 'dstSize'. Text that is not valid UTF-8 (WTF-8 with a lone surrogate, a
// legacy name) is copied unchanged. 'dst' may be the same memory as 'start'.
int ChangeCase(CChangeCase change, char* dst, int dstSize, const char* src,
               const char* start, const char* end)
{
    CALL_STACK_MESSAGE_NONE
    int len = (int)(end - start);
    if (len <= 0)
        return 0;
    int wl = change == ccDontChange ? 0 : MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, start, len, NULL, 0);
    if (wl <= 0) // no change, or not UTF-8: unchanged
    {
        if (len > dstSize)
            return -1;
        memmove(dst, start, len);
        return len;
    }
    WCHAR* w = (WCHAR*)malloc(wl * sizeof(WCHAR));
    if (w == NULL)
        return -1;
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, start, len, w, wl);
    WCHAR* out = w; // the result in UTF-16
    int outLen = wl;
    WCHAR* stripped = NULL;
    switch (change)
    {
    case ccLower:
        CharLowerBuffW(w, wl);
        break;

    case ccUpper:
        CharUpperBuffW(w, wl);
        break;

    case ccMixed:
    {
        // the letter before 'start' (in 'src'): a capital follows a non-alphanumeric character
        BOOL prevAlnum = FALSE;
        if (start > src)
        {
            const char* p = start - 1;
            while (p > src && (*p & 0xC0) == 0x80)
                p--;
            WCHAR pw[2];
            int pl = MultiByteToWideChar(CP_UTF8, 0, p, (int)(start - p), pw, 2);
            prevAlnum = pl > 0 && IsCharAlphaNumericW(pw[pl - 1]);
        }
        for (int i = 0; i < wl; i++)
        {
            BOOL alnum = IsCharAlphaNumericW(w[i]);
            if (!prevAlnum)
                CharUpperBuffW(w + i, 1);
            else
                CharLowerBuffW(w + i, 1);
            prevAlnum = alnum;
        }
        break;
    }

    case ccStripDia:
    {
        // decomposed, without the combining marks (U+0300-U+036F), composed again
        int dl = NormalizeString(NormalizationD, w, wl, NULL, 0);
        if (dl > 0)
        {
            WCHAR* dw = (WCHAR*)malloc(dl * sizeof(WCHAR));
            if (dw != NULL)
            {
                dl = NormalizeString(NormalizationD, w, wl, dw, dl);
                if (dl > 0) // review: a failed decomposition leaves the part unchanged (it emptied it)
                {
                    int kept = 0;
                    for (int i = 0; i < dl; i++)
                    {
                        if (!(dw[i] >= 0x300 && dw[i] <= 0x36F))
                            dw[kept++] = dw[i];
                    }
                    int cl = kept > 0 ? NormalizeString(NormalizationC, dw, kept, NULL, 0) : 0;
                    if (cl > 0)
                    {
                        stripped = (WCHAR*)malloc(cl * sizeof(WCHAR));
                        if (stripped != NULL)
                        {
                            cl = NormalizeString(NormalizationC, dw, kept, stripped, cl);
                            if (cl > 0)
                            {
                                out = stripped;
                                outLen = cl;
                            }
                        }
                    }
                    else if (kept == 0)
                        outLen = 0; // only marks
                }
                free(dw);
            }
        }
        break;
    }

    default:
        break;
    }
    int n = outLen > 0 ? WideCharToMultiByte(CP_UTF8, 0, out, outLen, NULL, 0, NULL, NULL) : 0;
    int ret = -1;
    if (n <= dstSize)
    {
        if (n > 0)
            WideCharToMultiByte(CP_UTF8, 0, out, outLen, dst, n, NULL, NULL);
        ret = n;
    }
    free(stripped);
    free(w);
    return ret;
}
