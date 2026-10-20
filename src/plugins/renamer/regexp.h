// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

// ******************************************************************
//
// Internal RegExp routines
//

#define MAX_SUBEXP 256

class CRegExp : public CRegExpAbstract
{
    CRegExpErrors State;
    unsigned Options;
    int Compiled;

    char RegStart; // Internal use only.
    char RegAnch;  // Internal use only.
    char* RegMust; // Internal use only.
    int RegMLen;   // Internal use only.
    char* Program; // Internal use only.

public:
    virtual BOOL RegComp(char* exp, unsigned options);
    virtual BOOL RegExec(char* string, int length, int offset, BOOL separateThread = FALSE);
    virtual BOOL IsGood() { return State == reeNoError; }
    virtual CRegExpErrors GetState() { return State; }
    virtual const char* GetStateText() { return RegExpErrorText(State); }

    CRegExp()
    {
        State = reeNoError, Program = NULL;
        Startp = NULL;
        Compiled = 0;
        ClassTests = ClassRanges = NULL;
        ClassNTests = ClassNRanges = ClassCap = 0;
    }
    ~CRegExp()
    {
        if (Program)
            free(Program);
        if (Startp)
            free(Startp);
    }

private:
    int Caseles;

    // Global work variables for regcomp().

    char* RegParse; // Input-scan pointer.
    char RegDummy;
    char* RegCode; // Code-emit pointer; &regdummy = don't.
    long RegSize;  // Code size.

    // RegComp()'s friends.
    char* RegExt(int paren, int* flagp, int* fixedwp);
    char* Reg(int paren, int nocapture, int* flagp, int* fixedwp);
    char* RegBranch(int* flagp, int* fixedwp);
    char* RegPiece(int* flagp, int* fixedw);
    char* RegAtom(int* flagp, int* fixedw);
    char* RegNode(char op);
    char* RegNext(char* p);
    void RegC(char b);
    void RegInsert(char op, char* opnd);
    void RegTail(char* p, char* val);
    void RegOpTail(char* p, char* val);
    int IsPosixClass(char* scan);
    char GetEscapedChar();

    // feature 254: a class is built here (both passes) and emitted as a variable-length operand:
    // the bitmap of ASCII (bits 0-127) and of bytes that start no UTF-8 letter (bits 128-255),
    // the flags (NEG = the bracket's '^' for the other letters), type tests and code-point ranges
    unsigned char ClassMap[32];
    unsigned* ClassTests;  // pairs: type mask (salu8letter.h), negated
    unsigned* ClassRanges; // pairs: the lowest and the highest code point
    int ClassNTests;
    int ClassNRanges;
    int ClassCap; // pairs each array holds (the pattern's length bounds them)

    void ClassBegin();
    void ClassSetByte(unsigned b) { ClassMap[(b & 0xFF) >> 3] |= (unsigned char)(1 << (b & 0x07)); }
    void ClassAddValue(unsigned value);
    void ClassAddRange(unsigned lo, unsigned hi);
    void ClassAddRangeOf(unsigned first, unsigned last, BOOL lastEscaped);
    int ClassAddPosix(const char* scan);
    void ClassEmit(int comp);
    unsigned ParseLiteralUnit();
    unsigned GetEscapedUnit();

    // Global work variables for regexec().
    char* RegInput;   /* String-input pointer. */
    char* RegBol;     /* Beginning of input, for ^ check. */
    char* RegEol;     /* End of input */
    char** RegStartp; /* Pointer to startp array. */
    char** RegEndp;   /* Ditto for endp. */

    // RegExec()'s friends
    static DWORD WINAPI RegExecThread(void* data);
    int RegTry(char* string);
    int RegMatch(char* prog);
    int RegRepeat(char* p);
    int RegMatchSimple(char op, char* opnd);

    // feature 254: the engine steps by whole UTF-8 letters (units, salu8letter.h)
    int UnitAt(const char* p); // the length of the unit at 'p' (0 at RegEol)
    int ClassMatch(const char* opnd, const char* p); // the unit's length when it is in the class, else 0
    int ExactlyAt(const char* opnd, const char* p);  // the length of a one-unit literal matched at 'p', else 0
    int IsWordUnitAt(const char* p);
    int IsWordUnitBefore(const char* p);
    char* UnitsBack(char* q, int count); // 'count' units back from 'q', NULL when the text has fewer
    int RegMatchEol(char* scan)
    {
        if (scan == RegEol)
            return 1;
        if ((Options & RE_LF) && *scan == '\n')
            return 1;
        if ((Options & RE_CR) && *scan == '\r')
            return 1;
        if ((Options & RE_NULL) && *scan == '\0')
            return 1;
        if ((Options & RE_CRLF) && scan + 1 < RegEol &&
            scan[0] == '\r' && scan[1] == '\n')
            return 1;
        return 0;
    }

    int IsNewLine();
};
