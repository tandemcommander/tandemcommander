// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

/*
 * regcomp and regexec -- regsub and regerror are elsewhere
 *
 *  Copyright (c) 1986 by University of Toronto.
 *  Written by Henry Spencer.  Not derived from licensed software.
 *
 *  Permission is granted to anyone to use this software for any
 *  purpose on any computer system, and to redistribute it freely,
 *  subject to the following restrictions:
 *
 *  1. The author is not responsible for the consequences of use of
 *    this software, no matter how awful, even if they arise
 *    from defects in it.
 *
 *  2. The origin of this software must not be misrepresented, either
 *    by explicit claim or by omission.
 *
 *  3. Altered versions must be plainly marked as such, and must not
 *    be misrepresented as being the original software.
 *
 * Beware that some of this code is subtly aware of the way operator
 * precedence is structured in regular expressions.  Serious changes in
 * regular-expression syntax might require a total rethink.
 */

#include "precomp.h"

#include <process.h>

#include "regexp.h"
#include "../../common/salu8letter.h"

// feature 254: the engine steps, backs off, classifies and starts matches by whole UTF-8 letters
// ("units", salu8letter.h) - it judged single bytes: '.' or a class took the lead byte of a letter
// (the new name was refused "(123)"), '\b' found a boundary inside a Cyrillic word (a wrong letter
// replaced), a quantifier after a letter repeated its last byte, a look-behind stepped one byte.
// ASCII is judged as before (the CType table); a class holds code-point ranges and type tests for
// the other letters; '\x' escapes forming one character are one letter.

// feature 210: a case-insensitive match folds ASCII only - the code page's table also folded the
// bytes of UTF-8 letters (cp1250: 8A / 9A), matching another letter or a piece of one; the
// renamer folds the other characters of the pattern and the name by characters (salu8fold.h)
#define REG_LOWER(c) (((unsigned char)(c)) < 0x80 ? LowerCase[(unsigned char)(c)] : (char)(c))
#define REG_INVERT(c) (((unsigned char)(c)) < 0x80 ? (char)InvertCase((unsigned char)(c)) : (char)(c))

// the same for the engine's memory searches (MemChrI / MemCmpI fold every byte by the code page)
static char* RegMemChrI(char* s, char c, int n)
{
    for (; n > 0; n--, s++)
        if (REG_LOWER(*s) == c)
            return s;
    return NULL;
}

static int RegMemCmpI(const char* s1, const char* s2, int n)
{
    for (; n > 0; n--, s1++, s2++)
    {
        char a = REG_LOWER(*s1), b = REG_LOWER(*s2);
        if (a != b)
            return (unsigned char)a < (unsigned char)b ? -1 : 1;
    }
    return 0;
}

//    - option to define your own messages; otherwise just copy it into the code

const char* RegExpErrorText(CRegExpErrors err)
{
    CALL_STACK_MESSAGE_NONE
    switch (err)
    {
    case reeNoError:
        return "No error.";
    case reeLowMemory:
        return "Low memory.";
    case reeEmpty:
        return "Regular expression is empty.";
    case reeTooBig:
        return "Regular expression is too big.";
    case reeTooManyParenthesises:
        return "Too many ().";
    case reeUnmatchedParenthesis:
        return "Unmatched ().";
    case reeOperandCouldBeEmpty:
        return "*+ operand could be empty.";
    case reeNested:
        return "Nested *?+.";
    //case reeInvalidRange: return "Invalid [] range.";
    case reeUnmatchedBracket:
        return "Unmatched [].";
    case reeFollowsNothing:
        return "?+* follows nothing.";
    case reeTrailingBackslash:
        return "Trailing \\.";
    case reeInternalDisaster:
        return "Internal disaster.";
    case reeExpectingExtendedPattern1:
        return "Expecting one of :=!< after (?";
    case reeExpectingExtendedPattern2:
        return "Expecting one of =! after (?<";
    case reeInvalidPosixClass:
        return "Unknown POSIX class name.";
    case reeExpectingXDigit:
        return "Expecting two hexadecimal digits after \\x.";
    case reeStackOverflow:
        return "Stack overflow";
    case reeNoPattern:
        return "Compiled expression required.";
    case reeErrorStartingThread:
        return "Unable to start new thread.";
    case reeBadFixedWidthLookBehind:
        return "Look-behind pattern has not fixed width.";
    default:
        return "Unknown error.";
    }
}

//*****************************************************************************
//*****************************************************************************
//
// original regexp.cpp
//
//*****************************************************************************
//*****************************************************************************

/*
 * The first byte of the regexp internal "program" is actually this magic
 * number; the start node begins in the second byte.
 */
#define MAGIC ((char)0234)

/*
 * The "internal use only" fields in regexp.h are present to pass info from
 * compile to execute that permits the execute phase to run lots faster on
 * simple cases.  They are:
 *
 * regstart char that must begin a match; '\0' if none obvious
 * reganch  is the match anchored (at beginning-of-line only)?
 * regmust  string (pointer into program) that match must include, or NULL
 * regmlen  length of regmust string
 *
 * Regstart and reganch permit very fast decisions on suitable starting points
 * for a match, cutting down the work a lot.  Regmust permits fast rejection
 * of lines that cannot possibly match.  The regmust tests are costly enough
 * that regcomp() supplies a regmust only if the r.e. contains something
 * potentially expensive (at present, the only such thing detected is * or +
 * at the start of the r.e., which can involve a lot of backup).  Regmlen is
 * supplied because the test in regexec() needs it and regcomp() is computing
 * it anyway.
 */

/*
 * Structure for regexp "program".  This is essentially a linear encoding
 * of a nondeterministic finite-state machine (aka syntax charts or
 * "railroad normal form" in parsing technology).  Each node is an opcode
 * plus a "next" pointer, possibly plus an operand.  "Next" pointers of
 * all nodes except BRANCH implement concatenation; a "next" pointer with
 * a BRANCH on both ends of it is connecting two alternatives.  (Here we
 * have one of the subtle syntax dependencies:  an individual BRANCH (as
 * opposed to a collection of them) is never concatenated with anything
 * because of operator precedence.)  The operand of some types of node is
 * a literal string; for others, it is a node leading into a sub-FSM.  In
 * particular, the operand of a BRANCH node is the first node of the branch.
 * (NB this is *not* a tree structure:  the tail of the branch connects
 * to the thing following the set of BRANCHes.)  The opcodes are:
 */

/* definition number  opnd? meaning */
#define END 0      /* no End of program. */
#define BOL 1      /* no Match "" at beginning of line. */
#define EOL 2      /* no Match "" at end of line. */
#define BOS 3      /* no Match "" at beginning of string. */
#define EOS 4      /* no Match "" at end of string, */
                   /* or before the newline at the end. */
#define VEOS 5     /* no Match "" at the very end of string. */
#define WORDB 6    /* no Match "" at a word boundary. */
#define NOTWORDB 7 /* no Match "" at a non-(word boundary). */
#define ANY 8      /* no Match any one character except newline. */
#define ANYDOT 9   /* no Match any one character including newline. */
#define ANYOF 10   /* bitmap(32B) Match any character in this class. */
//#define ANYBUT  9 /* str  Match any character not in this string. */
#define BRANCH 11   /* node Match this alternative, or the next... */
#define UGBRANCH 12 /* node Match the next or this alternative. */
                    /* it's used by ungreedy variants of ?*+ */
#define BACK 13     /* no Match "", "next" ptr points backward. */
#define EXACTLY 14  /* str  Match this string. */
#define NOTHING 15  /* no Match empty string. */
#define STAR 16     /* node Match this (simple) thing 0 or more times. */
#define PLUS 17     /* node Match this (simple) thing 1 or more times. */
#define UGSTAR 18   /* node Match this (simple) thing 0 or more times. Ungreedy variant. */
#define UGPLUS 19   /* node Match this (simple) thing 1 or more times. Ungreedy variant. */
#define OPEN 20     /* n Mark this point in input as start of #n. */
#define CLOSE 21    /* no Analogous to OPEN. */
#define PLOOKA 22   /* node Positive look-ahead, try to match node. */
#define NLOOKA 23   /* node Negative look-ahead, try to match node. */
#define PLOOKB 24   /* len, node Positive look-behind, try to match node. */
#define NLOOKB 25   /* len, node Negative look-behind, try to match node. */

/*
 * Opcode notes:
 *
 * BRANCH The set of branches constituting a single choice are hooked
 *    together with their "next" pointers, since precedence prevents
 *    anything being concatenated to any individual branch.  The
 *    "next" pointer of the last BRANCH in a choice points to the
 *    thing following the whole choice.  This is also where the
 *    final "next" pointer of each individual branch points; each
 *    branch starts with the operand node of a BRANCH node.
 *
 * BACK   Normal "next" pointers all implicitly point forward; BACK
 *    exists to make loop structures possible.
 *
 * STAR,PLUS  '?', and complex '*' and '+', are implemented as circular
 *    BRANCH structures using BACK.  Simple cases (one character
 *    per match) are implemented with STAR and PLUS for speed
 *    and to minimize recursive plunges.
 *
 * OPEN,CLOSE ...are numbered at compile time.
 */

/*
 * A node is one char of opcode followed by two chars of "next" pointer.
 * "Next" pointers are stored as two 8-bit pieces, high order first.  The
 * value is a positive offset from the opcode of the node containing it.
 * An operand, if any, simply follows the node.  (Note that much of the
 * code generation knows about this implicit relationship.)
 *
 * Using two bytes for the "next" pointer is vast overkill for most things,
 * but allows patterns to get big without disasters.
 */
#define OP(p) (*(p))
#define NEXT(p) (((*((p) + 1) & 0377) << 8) + (*((p) + 2) & 0377))
#define OPERAND(p) ((p) + 3)

/*
 * Utility definitions.
 */
#ifndef CHARBITS
#define UCHARAT(p) ((int)*(unsigned char*)(p))
#else
#define UCHARAT(p) ((int)*(p) & CHARBITS)
#endif

#define FAIL(e) \
    { \
        State = e; \
        return (NULL); \
    }
#define ISMULT(c) ((c) == '*' || (c) == '+' || (c) == '?')
#define META "^$.[()|?+*\\"

#define INCLASS(b, c) (((const unsigned char*)(b))[(c) >> 3] & (1 << ((c) & 0x07)))

// feature 254: the class operand after its ANYOF node (data-model.md)
#define CLASS_FLAGS 32  // 1 byte: CLASS_NEG
#define CLASS_NTESTS 33 // 2 bytes (unaligned)
#define CLASS_NRANGES 35
#define CLASS_ITEMS 37 // tests (4 bytes mask + 1 byte negated), then ranges (4 + 4 bytes)
#define CLASS_NEG 0x01

/*
 * Flags to be passed up and down.
 */
#define HASWIDTH 01 /* Known never to match null string. */
#define SIMPLE 02   /* Simple enough to be STAR/PLUS operand. */
#define SPSTART 04  /* Starts with * or +. */
#define WORST 0     /* Worst case. */

// often used POSIX character classes
const char* Word = "word:]";
const char* NonWord = "^word:]";
const char* Space = "space:]";
const char* NonSpace = "^space:]";
const char* Digit = "digit:]";
const char* NonDigit = "^digit:]";

/*
 - regcomp - compile a regular expression into internal code
 *
 * We can't allocate space until we know how big the compiled form will be,
 * but we can't compile it (and thus know how big it is) until we've got a
 * place to put the code.  So we cheat:  we compile it twice, once with code
 * generation turned off and size counting turned on, and once "for real".
 * This also means that we don't allocate space until we are sure that the
 * thing really will compile successfully, and we never have to move the
 * code and thus invalidate pointers into it.  (Note that it has to be in
 * one piece because free() must be able to free it all.)
 *
 * Beware that the optimization-preparation code in here knows about some
 * of the structure of the compiled regexp.
 */

BOOL CRegExp::RegComp(char* exp, unsigned options)
{
    CALL_STACK_MESSAGE_NONE
    char* scan;
    char* longest;
    int len;
    int flags;
    int fixedw;

    Compiled = 0;
    State = reeNoError;

    Options = options;
    Caseles = Options & RE_CASELES;

    // feature 254: the class builder's arrays - every test or range takes at least one byte of
    // the pattern, so its length bounds them
    struct CFreeClassArrays
    {
        CRegExp* R;
        ~CFreeClassArrays()
        {
            free(R->ClassTests);
            free(R->ClassRanges);
            R->ClassTests = R->ClassRanges = NULL;
            R->ClassCap = 0;
        }
    } freeClassArrays = {this};
    ClassCap = (int)strlen(exp) + 2;
    ClassTests = (unsigned*)malloc(sizeof(unsigned) * 2 * ClassCap);
    ClassRanges = (unsigned*)malloc(sizeof(unsigned) * 2 * ClassCap);
    if (ClassTests == NULL || ClassRanges == NULL)
    {
        State = reeLowMemory;
        return FALSE;
    }

    /* First pass: determine size, legality. */
    RegParse = exp;
    SubExpCount = 1;
    RegSize = 0L;
    RegCode = &RegDummy;
    RegC(MAGIC);
    if (RegExt(0, &flags, &fixedw) == NULL)
    {
        return FALSE;
    }

    /* Small enough for pointer-storage convention? */
    if (RegSize >= 32767L) /* Probably could be 65535L. */
    {
        State = reeTooBig;
        return FALSE;
    }

    /* Allocate space. */
    Program = (char*)realloc(Program, (unsigned)RegSize);
    Startp = (char**)realloc(Startp, sizeof(char*) * SubExpCount * 2);
    if (!Program || !Startp)
    {
        State = reeLowMemory;
        return FALSE;
    }
    Endp = Startp + SubExpCount;

    /* Second pass: emit code. */
    RegParse = exp;
    SubExpCount = 1;
    RegCode = Program;
    RegC(MAGIC);
    if (RegExt(0, &flags, &fixedw) == NULL)
    {
        return FALSE;
    }

    /* Dig out information for optimizations. */
    RegStart = '\0'; /* Worst-case defaults. */
    RegAnch = 0;
    RegMust = NULL;
    RegMLen = 0;
    scan = Program + 1; /* First BRANCH. */
    int op = OP(RegNext(scan));
    if (OP(RegNext(scan)) == END)
    { /* Only one top-level choice. */
        scan = OPERAND(scan);

        /* Starting-point info. */
        switch (OP(scan))
        {
        case EXACTLY:
            RegStart = *OPERAND(scan);
            break;
        case BOS:
            RegAnch++;
            break;
        case STAR:
        case PLUS:
        case UGSTAR:
        case UGPLUS:
            if (OP(OPERAND(scan)) == ANYDOT)
                RegAnch++;
            break;
        }

        /*
     * If there's something expensive in the r.e., find the
     * longest literal string that must appear and make it the
     * regmust.  Resolve ties in favor of later strings, since
     * the regstart check works with the beginning of the r.e.
     * and avoiding duplication strengthens checking.  Not a
     * strong reason, but sufficient in the absence of others.
     */
        if (flags & SPSTART)
        {
            longest = NULL;
            len = 0;
            for (; scan != NULL; scan = RegNext(scan))
                if (OP(scan) == EXACTLY && (int)strlen(OPERAND(scan)) >= len)
                {
                    longest = OPERAND(scan);
                    len = (int)strlen(OPERAND(scan));
                }
            RegMust = longest;
            RegMLen = len;
        }
    }

    State = reeNoError; // success
    Compiled = 1;
    return TRUE;
}

/*
 - RegExt - extended regular expression, i.e. main body or parenthesized thing
 *
 * Caller must absorb opening parenthesis.
 *
 * Combining parenthesis handling with the base level of regular expression
 * is a trifle forced, but the need to tie the tails of the branches to what
 * follows makes it hard to avoid.
 */
char* CRegExp::RegExt(int paren /* Parenthesized? */, int* flagp, int* fixedwp)
{
    CALL_STACK_MESSAGE_NONE
    char* ret;
    char* reg;
    char* ender;
    char c;

    /* Check for extended pattern. */
    if (paren && *RegParse == '?')
    {
        RegParse++;
        c = *RegParse++;
        switch (c)
        {
        case '<':
        {
            c = *RegParse++;
            if (c == '=')
                ret = RegNode(PLOOKB);
            else if (c == '!')
                ret = RegNode(NLOOKB);
            else
                FAIL(reeExpectingExtendedPattern2);

            /* reserve space for pattern width */
            if (RegCode != &RegDummy)
                RegCode += 2;
            else
                RegSize += 2;
            reg = Reg(paren, 1, flagp, fixedwp);
            if (reg == NULL)
                return NULL;
            ender = RegNode(END);
            RegTail(reg, ender);

            if (*fixedwp < 0 || *fixedwp > 0xFFFF)
                FAIL(reeBadFixedWidthLookBehind);
            if (RegCode != &RegDummy)
            {
                *(unsigned short*)OPERAND(ret) = (unsigned short)*fixedwp;
                // (ret+3)[0] = (char) (*fixedwp & 0xFF);
                // (ret+3)[1] = (char) ((*fixedwp >> 8) & 0xFF);
            }
            *flagp &= ~HASWIDTH;
            *fixedwp = 0;
            break;
        }
        case '=':
            ret = RegNode(PLOOKA);
            goto LOOKA;
        case '!':
            ret = RegNode(NLOOKA);
        LOOKA:
            reg = Reg(paren, 1, flagp, fixedwp);
            if (reg == NULL)
                return NULL;
            ender = RegNode(END);
            RegTail(reg, ender);
            *flagp &= ~HASWIDTH;
            *fixedwp = 0;
            break;
        case ':':
            ret = Reg(paren, 1, flagp, fixedwp);
            break;
        default:
            FAIL(reeExpectingExtendedPattern1);
        }
    }
    else
        ret = Reg(paren, 0, flagp, fixedwp);

    return ret;
}
/*
 - Reg - regular expression, i.e. main body or parenthesized thing
 *
 * Caller must absorb opening parenthesis.
 *
 * Combining parenthesis handling with the base level of regular expression
 * is a trifle forced, but the need to tie the tails of the branches to what
 * follows makes it hard to avoid.
 */
char* CRegExp::Reg(int paren /* Parenthesized? */,
                   int nocapture /* Not capturing parenthesis*/, int* flagp, int* fixedwp)
{
    CALL_STACK_MESSAGE_NONE
    char* ret;
    char* br;
    char* ender;
    int parno;
    int flags;
    int fixedw;

    *flagp = HASWIDTH; /* Tentatively. */
    *fixedwp = 0;

    /* Make an OPEN node, if parenthesized. */
    if (paren)
    {
        if (nocapture == 0)
        {
            nocapture = 0;
            if (SubExpCount >= MAX_SUBEXP)
                FAIL(reeTooManyParenthesises);
            parno = SubExpCount;
            SubExpCount++;
            ret = RegNode((char)(OPEN));
            RegC(parno);
        }
        else
            ret = NULL;
    }
    else
        ret = NULL;

    /* Pick up the branches, linking them together. */
    br = RegBranch(&flags, fixedwp);
    if (br == NULL)
        return (NULL);
    if (ret != NULL)
        RegTail(ret, br); /* OPEN -> first. */
    else
        ret = br;
    if (!(flags & HASWIDTH))
        *flagp &= ~HASWIDTH;
    *flagp |= flags & SPSTART;
    while (*RegParse == '|')
    {
        RegParse++;
        br = RegBranch(&flags, &fixedw);
        if (br == NULL)
            return (NULL);
        RegTail(ret, br); /* BRANCH -> BRANCH. */
        if (!(flags & HASWIDTH))
            *flagp &= ~HASWIDTH;
        *flagp |= flags & SPSTART;
        if (fixedw != *fixedwp)
            *fixedwp = -1;
    }

    /* Make a closing node, and hook it on the end. */
    if (paren)
    {
        if (nocapture)
            ender = RegNode(NOTHING);
        else
        {
            ender = RegNode(CLOSE);
            RegC(parno);
        }
    }
    else
        ender = RegNode(END);
    RegTail(ret, ender);

    /* Hook the tails of the branches to the closing node. */
    for (br = ret; br != NULL; br = RegNext(br))
        RegOpTail(br, ender);

    /* Check for proper termination. */
    if (paren && *RegParse++ != ')')
    {
        FAIL(reeUnmatchedParenthesis);
    }
    else if (!paren && *RegParse != '\0')
    {
        if (*RegParse == ')')
        {
            FAIL(reeUnmatchedParenthesis);
        }
    }

    return (ret);
}

/*
 - RegBranch - one alternative of an | operator
 *
 * Implements the concatenation operator.
 */
char* CRegExp::RegBranch(int* flagp, int* fixedwp)
{
    CALL_STACK_MESSAGE_NONE
    char* ret;
    char* chain;
    char* latest;
    int flags;
    int fixedw;

    *flagp = WORST; /* Tentatively. */
    *fixedwp = 0;

    ret = RegNode(BRANCH);
    chain = NULL;
    while (*RegParse != '\0' && *RegParse != '|' && *RegParse != ')')
    {
        latest = RegPiece(&flags, &fixedw);
        if (latest == NULL)
            return (NULL);
        *flagp |= flags & HASWIDTH;
        if (fixedw >= 0)
        {
            if (*fixedwp >= 0)
                *fixedwp += fixedw;
        }
        else
            *fixedwp = -1;
        if (chain == NULL) /* First piece. */
            *flagp |= flags & SPSTART;
        else
            RegTail(chain, latest);
        chain = latest;
    }
    if (chain == NULL) /* Loop ran zero times. */
        (void)RegNode(NOTHING);

    return (ret);
}

/*
 - RegPiece - something followed by possible [*+?]
 *
 * Note that the branching code sequences used for ? and the general cases
 * of * and + are somewhat optimized:  they use the same NOTHING node as
 * both the endmarker for their branch list and the body of the last branch.
 * It might seem that this node could be dispensed with entirely, but the
 * endmarker role is not redundant.
 */
char* CRegExp::RegPiece(int* flagp, int* fixedw)
{
    CALL_STACK_MESSAGE_NONE
    char* ret;
    char op;
    char* next;
    int flags;
    int greedy;

    ret = RegAtom(&flags, fixedw);
    if (ret == NULL)
        return (NULL);

    op = *RegParse;
    if (!ISMULT(op))
    {
        *flagp = flags;
        return (ret);
    }

    if (!(flags & HASWIDTH) && op != '?')
        FAIL(reeOperandCouldBeEmpty);
    *flagp = (op != '+') ? (WORST | SPSTART) : (WORST | HASWIDTH);
    *fixedw = -1;

    if (RegParse[1] == '?')
    {
        greedy = 0;
        RegParse++;
    }
    else
        greedy = 1;

    if (op == '*' && (flags & SIMPLE))
        RegInsert(greedy ? STAR : UGSTAR, ret);
    else if (op == '*')
    {
        /* Emit x* as (x&|), where & means "self". */
        RegInsert(greedy ? BRANCH : UGBRANCH, ret); /* Either x */
        RegOpTail(ret, RegNode(BACK));              /* and loop */
        RegOpTail(ret, ret);                        /* back */
        RegTail(ret, RegNode(BRANCH));              /* or */
        RegTail(ret, RegNode(NOTHING));             /* null. */
    }
    else if (op == '+' && (flags & SIMPLE))
        RegInsert(greedy ? PLUS : UGPLUS, ret);
    else if (op == '+')
    {
        /* Emit x+ as x(&|), where & means "self". */
        next = RegNode(greedy ? BRANCH : UGBRANCH); /* Either */
        RegTail(ret, next);
        RegTail(RegNode(BACK), ret);    /* loop back */
        RegTail(next, RegNode(BRANCH)); /* or */
        RegTail(ret, RegNode(NOTHING)); /* null. */
    }
    else if (op == '?')
    {
        /* Emit x? as (x|) */
        RegInsert(greedy ? BRANCH : UGBRANCH, ret); /* Either x */
        RegTail(ret, RegNode(BRANCH));              /* or */
        next = RegNode(NOTHING);                    /* null. */
        RegTail(ret, next);
        RegOpTail(ret, next);
    }
    RegParse++;
    if (ISMULT(*RegParse))
        FAIL(reeNested);

    return (ret);
}

/*
 - RegAtom - the lowest level
 *
 * Optimization:  gobbles an entire sequence of ordinary characters so that
 * it can turn them into a single node, which is smaller to store and
 * faster to run.  Backslashed characters are exceptions, each becoming a
 * separate node; the code is simpler that way and it's not worth fixing.
 */
char* CRegExp::RegAtom(int* flagp, int* fixedw)
{
    CALL_STACK_MESSAGE_NONE
    char* ret;
    int flags;

    *flagp = WORST; /* Tentatively. */
    *fixedw = 0;

    switch (*RegParse++)
    {
    case '^':
        ret = RegNode((Options & RE_MULTILINE) ? BOL : BOS);
        break;
    case '$':
        ret = RegNode((Options & RE_MULTILINE) ? EOL : EOS);
        break;
    case '.':
        ret = RegNode((Options & RE_SINGLELINE) ? ANYDOT : ANY);
        *flagp |= HASWIDTH | SIMPLE;
        *fixedw = 1;
        break;
    case '[':
    {
        // feature 254: the members are whole letters - a literal or '\x' letter is a code point,
        // a range with a non-ASCII bound a code-point range (ClassAddRangeOf), '\w' and the POSIX
        // classes type tests for the letters outside ASCII
        const unsigned NOCHAR = 0xFFFFFFFF;
        int comp;
        unsigned lastchar;

        lastchar = NOCHAR;
        comp = 0;
        if (*RegParse == '^')
        { /* Complement of range. */
            comp = 1;
            RegParse++;
        }
        ret = RegNode(ANYOF);
        ClassBegin();
        if (*RegParse == ':' && IsPosixClass(RegParse + 1))
        {
            if (!ClassAddPosix(RegParse + 1))
                return NULL;
            RegParse = strchr(RegParse, ']') + 1;
        }
        else
        {
            if (*RegParse == ']' || *RegParse == '-')
            {
                lastchar = (unsigned char)*RegParse;
                ClassSetByte(lastchar);
                RegParse++;
            }
            while (*RegParse != '\0' && *RegParse != ']')
            {
                if (*RegParse == '-')
                {
                    RegParse++;
                    if (*RegParse == ']' || *RegParse == '\0' || lastchar == NOCHAR)
                        ClassSetByte('-');
                    else
                    {
                        unsigned classend;
                        BOOL escaped = FALSE;
                        if (*RegParse == '\\')
                        {
                            RegParse++;
                            if (*RegParse == '\0')
                                FAIL(reeUnmatchedBracket);
                            classend = GetEscapedUnit();
                            if (!IsGood())
                                FAIL(State);
                            escaped = TRUE;
                        }
                        else
                            classend = ParseLiteralUnit();
                        ClassAddRangeOf(lastchar, classend, escaped);
                        RegParse++;
                        lastchar = NOCHAR;
                    }
                }
                else
                {
                    if (*RegParse == '[' && RegParse[1] == ':' && IsPosixClass(RegParse + 2))
                    {
                        if (!ClassAddPosix(RegParse + 2))
                            return FALSE;
                        RegParse = strchr(RegParse, ']') + 1;
                        lastchar = NOCHAR;
                    }
                    else
                    {
                        if (*RegParse == '\\')
                        {
                            RegParse++;
                            const char* classname;
                            switch (*RegParse)
                            {
                            case 'w':
                                classname = Word;
                                goto LCLASS2;
                            case 'W':
                                classname = NonWord;
                                goto LCLASS2;
                            case 's':
                                classname = Space;
                                goto LCLASS2;
                            case 'S':
                                classname = NonSpace;
                                goto LCLASS2;
                            case 'd':
                                classname = Digit;
                                goto LCLASS2;
                            case 'D':
                            {
                                classname = NonDigit;
                            LCLASS2:
                                ClassAddPosix(classname);
                                lastchar = NOCHAR;
                                break;
                            }
                            case '\0': // a trailing backslash: the bracket is not closed
                                FAIL(reeUnmatchedBracket);
                            default:
                                lastchar = GetEscapedUnit();
                                if (!IsGood())
                                    FAIL(State);
                            }
                        }
                        else
                            lastchar = ParseLiteralUnit();
                        if (lastchar != NOCHAR)
                            ClassAddValue(lastchar);
                        RegParse++;
                    }
                }
            }
            if (*RegParse != ']')
                FAIL(reeUnmatchedBracket);
            RegParse++;
        }
        ClassEmit(comp);
        *flagp |= HASWIDTH | SIMPLE;
        *fixedw = 1;
    }
    break;
    case '(':
        ret = RegExt(1, &flags, fixedw);
        if (ret == NULL)
            return (NULL);
        *flagp |= flags & (HASWIDTH | SPSTART);
        break;
    case '\0':
    case '|':
    case ')': //FAIL("internal urp"); /* Supposed to be caught earlier. */
    case '?':
    case '+':
    case '*':
        FAIL(reeFollowsNothing);
    case '\\':
        char c;
        const char* classname;
        if (*RegParse == '\0')
            FAIL(reeTrailingBackslash);
        switch (*RegParse)
        {
        case 'w':
            classname = Word;
            goto LCLASS;
        case 'W':
            classname = NonWord;
            goto LCLASS;
        case 's':
            classname = Space;
            goto LCLASS;
        case 'S':
            classname = NonSpace;
            goto LCLASS;
        case 'd':
            classname = Digit;
            goto LCLASS;
        case 'D':
        {
            classname = NonDigit;
        LCLASS:
            ret = RegNode(ANYOF);
            ClassBegin();
            ClassAddPosix(classname);
            ClassEmit(0);
            goto LENDSLASH;
        }

        case 'b':
            c = WORDB;
            goto LASSERT;
        case 'B':
            c = NOTWORDB;
            goto LASSERT;
        case 'A':
            c = BOS;
            goto LASSERT;
        case 'Z':
            c = EOS;
            goto LASSERT;
        case 'z':
        {
            c = VEOS;
        LASSERT:
            RegParse++;
            return RegNode(c);
        }

        default:
        {
            // feature 254: '\x' escapes that form one character are one letter (two nodes
            // "\xC5" "\xBD" never matched a folded name); case-insensitive it is folded like a
            // typed letter. Bytes forming no character stay single bytes (they match only the
            // same byte standing alone - EXACTLY ends on a letter boundary)
            unsigned value = GetEscapedUnit();
            if (!IsGood())
                FAIL(State);
            unsigned char enc[4];
            int n;
            if (value >= SALU8_INVALID_BASE)
                enc[0] = (unsigned char)(value - SALU8_INVALID_BASE), n = 1;
            else if (value < 0x80)
                enc[0] = (unsigned char)(Caseles ? REG_LOWER((char)value) : (char)value), n = 1;
            else
                n = SalU8EncodeChar(value, enc); // (folded by GetEscapedUnit when case-insensitive)
            ret = RegNode(EXACTLY);
            for (int i = 0; i < n; i++)
                RegC((char)enc[i]);
            RegC('\0');
        }
        }
    LENDSLASH:
        RegParse++;
        *flagp |= HASWIDTH | SIMPLE;
        *fixedw = 1;
        break;
    default:
    {
        int len;
        char ender;

        RegParse--;
        len = (int)strcspn(RegParse, META);
        if (len <= 0)
            FAIL(reeInternalDisaster);
        ender = *(RegParse + len);
        // feature 254: the run is counted and backed off by letters - one byte off "z-caron+"
        // left the quantifier on the letter's last byte
        int units = 0;
        for (const char* u = RegParse; u < RegParse + len; units++)
        {
            unsigned unitValue;
            u += SalU8UnitLen(u, RegParse + len, &unitValue);
        }
        if (units > 1 && ISMULT(ender))
        {
            len = (int)(SalU8UnitBack(RegParse, RegParse + len) - RegParse); /* Back off clear of ?+* operand. */
            units--;
        }
        *flagp |= HASWIDTH;
        if (units == 1)
            *flagp |= SIMPLE; // one letter (of any length): STAR / PLUS repeat it (ExactlyAt)
        *fixedw = units;
        ret = RegNode(EXACTLY);
        while (len > 0)
        {
            RegC(Caseles ? REG_LOWER(*RegParse) : *RegParse);
            RegParse++;
            len--;
        }
        RegC('\0');
    }
    break;
    }

    return (ret);
}

/*
 - RegNode - emit a node
 */
char* CRegExp::RegNode(char op) /* Location. */
{
    CALL_STACK_MESSAGE_NONE
    char* ret;
    char* ptr;

    ret = RegCode;
    if (ret == &RegDummy)
    {
        RegSize += 3;
        return (ret);
    }

    ptr = ret;
    *ptr++ = op;
    *ptr++ = '\0'; /* Null "next" pointer. */
    *ptr++ = '\0';
    RegCode = ptr;

    return (ret);
}

/*
 - RegC - emit (if appropriate) a byte of code
 */
void CRegExp::RegC(char b)
{
    CALL_STACK_MESSAGE_NONE
    if (RegCode != &RegDummy)
        *RegCode++ = b;
    else
        RegSize++;
}

/*
 - RegInsert - insert an operator in front of already-emitted operand
 *
 * Means relocating the operand.
 */
void CRegExp::RegInsert(char op, char* opnd)
{
    CALL_STACK_MESSAGE_NONE
    char* src;
    char* dst;
    char* place;

    if (RegCode == &RegDummy)
    {
        RegSize += 3;
        return;
    }

    src = RegCode;
    RegCode += 3;
    dst = RegCode;
    while (src > opnd)
        *--dst = *--src;

    place = opnd; /* Op node, where operand used to be. */
    *place++ = op;
    *place++ = '\0';
    *place++ = '\0';
}

/*
 - RegTail - set the next-pointer at the end of a node chain
 */
void CRegExp::RegTail(char* p, char* val)
{
    CALL_STACK_MESSAGE_NONE
    char* scan;
    char* temp;
    int offset;

    if (p == &RegDummy)
        return;

    /* Find last node. */
    scan = p;
    for (;;)
    {
        temp = RegNext(scan);
        if (temp == NULL)
            break;
        scan = temp;
    }

    if (OP(scan) == BACK)
        offset = (int)(scan - val);
    else
        offset = (int)(val - scan);
    *(scan + 1) = (char)((offset >> 8) & 0377);
    *(scan + 2) = (char)(offset & 0377);
}

/*
 - RegOpTail - RegTail on operand of first argument; nop if operandless
 */
void CRegExp::RegOpTail(char* p, char* val)
{
    CALL_STACK_MESSAGE_NONE
    /* "Operandless" and "op != BRANCH" are synonymous in practice. */
    if (p == NULL || p == &RegDummy || OP(p) != BRANCH && OP(p) != UGBRANCH)
        return;
    RegTail(OPERAND(p), val);
}

int CRegExp::IsPosixClass(char* scan)
{
    CALL_STACK_MESSAGE_NONE
    char* iterator;
    if (*scan == '^')
        scan++;
    iterator = scan;
    while (IsAlpha(*iterator++))
        ;
    if (iterator > scan && iterator[-1] == ':' && iterator[0] == ']')
        return 1;
    return 0;
}

struct CPosixClass
{
    const char* Name;
    unsigned Type;
    int ID;
};

#define PC_ASCII 1
#define PC_WORD 2

CPosixClass PosixClasses[] =
    {
        {"alnum:]", C1_ALPHA | C1_DIGIT, 0},
        {"alpha:]", C1_ALPHA, 0},
        {"ascii:]", 0, PC_ASCII},
        {"cntrl:]", C1_CNTRL, 0},
        {Digit, C1_DIGIT, 0},
        {"graph:]", C1_PUNCT | C1_ALPHA | C1_DIGIT, 0},
        {"lower:]", C1_LOWER, 0},
        {"print:]", C1_PUNCT | C1_ALPHA | C1_DIGIT | C1_BLANK, 0},
        {"punct:]", C1_PUNCT, 0},
        {Space, C1_SPACE, 0},
        {"upper:]", C1_UPPER, 0},
        {Word, C1_ALPHA | C1_DIGIT, PC_WORD},
        {"xdigit:]", C1_XDIGIT, 0},
        {NULL, C1_XDIGIT, 0}};

// feature 254: a POSIX class (also '\w', '\s', '\d' and their negations) - ASCII by the CType
// table into the bitmap as before (bytes >= 0x80 are no longer the code page's letters: they are
// bytes that start no UTF-8 letter and belong to no class but the negated ones), the other letters
// by a type test (salu8letter.h)
int CRegExp::ClassAddPosix(const char* scan)
{
    CALL_STACK_MESSAGE_NONE
    unsigned char tmpclass[32];
    int comp = 0;

    if (*scan == '^')
    {
        scan++;
        comp = 1;
    }

    CPosixClass* cls = PosixClasses;
    while (cls->Name != NULL && strncmp(scan, cls->Name, strlen(cls->Name)) != 0)
        cls++;
    if (cls->Name == NULL)
    {
        State = reeInvalidPosixClass;
        return 0;
    }

    memset(tmpclass, 0, 32);
    int c;
    for (c = 0; c < 0x80; c++)
        if (CType[c] & cls->Type)
        {
            tmpclass[c >> 3] |= (unsigned char)(1 << (c & 0x07));
            if (Caseles)
            {
                unsigned char inv = (unsigned char)REG_INVERT(c);
                tmpclass[inv >> 3] |= (unsigned char)(1 << (inv & 0x07));
            }
        }

    unsigned mask = cls->Type;
    switch (cls->ID)
    {
    case PC_ASCII:
    {
        int i;
        for (i = 0; i < 16; i++)
            tmpclass[i] = 0xFF;
        mask = 0; // no letter outside ASCII
        break;
    }
    case PC_WORD:
    {
        tmpclass['_' >> 3] |= (unsigned char)(1 << ('_' & 0x07));
        mask |= SALU8_TYPE_MARK; // a combining mark belongs to the word
        break;
    }
    }
    if (Caseles && (mask & (C1_UPPER | C1_LOWER)) != 0)
        mask |= C1_UPPER | C1_LOWER; // the name is folded: both cases

    if (comp)
    {
        int i;
        for (i = 31; i >= 0; i--)
            tmpclass[i] = (unsigned char)~tmpclass[i];
    }

    int i;
    for (i = 31; i >= 0; i--)
        ClassMap[i] |= tmpclass[i];
    if (ClassNTests < ClassCap)
    {
        ClassTests[2 * ClassNTests] = mask;
        ClassTests[2 * ClassNTests + 1] = comp;
        ClassNTests++;
    }
    return 1;
}

void CRegExp::ClassBegin()
{
    CALL_STACK_MESSAGE_NONE
    memset(ClassMap, 0, sizeof(ClassMap));
    ClassNTests = ClassNRanges = 0;
}

// one member: ASCII and a byte that starts no letter into the bitmap, a letter as a range of one
void CRegExp::ClassAddValue(unsigned value)
{
    CALL_STACK_MESSAGE_NONE
    if (value < 0x80)
    {
        ClassSetByte(value);
        if (Caseles)
            ClassSetByte((unsigned char)REG_INVERT((char)value));
    }
    else if (value >= SALU8_INVALID_BASE)
        ClassSetByte(value - SALU8_INVALID_BASE);
    else
        ClassAddRange(value, value);
}

// the code points 'lo'..'hi' (reversed: nothing); the ASCII part into the bitmap
void CRegExp::ClassAddRange(unsigned lo, unsigned hi)
{
    CALL_STACK_MESSAGE_NONE
    if (lo > hi)
        return;
    if (lo < 0x80)
    {
        unsigned c;
        for (c = lo; c <= hi && c < 0x80; c++)
            ClassAddValue(c);
        lo = 0x80;
        if (lo > hi)
            return;
    }
    if (ClassNRanges < ClassCap)
    {
        ClassRanges[2 * ClassNRanges] = lo;
        ClassRanges[2 * ClassNRanges + 1] = hi;
        ClassNRanges++;
    }
}

// the range 'first'-'last' of a bracket ('first' is already a member); two ASCII bounds or bytes
// that form no letter keep the byte loop of before, exactly (an escaped end was exclusive, a
// reversed range wrapped around); a non-ASCII letter as a bound makes a code-point range
void CRegExp::ClassAddRangeOf(unsigned first, unsigned last, BOOL lastEscaped)
{
    CALL_STACK_MESSAGE_NONE
    BOOL firstByte = first < 0x80 || first >= SALU8_INVALID_BASE;
    BOOL lastByte = last < 0x80 || last >= SALU8_INVALID_BASE;
    unsigned fb = first >= SALU8_INVALID_BASE ? first - SALU8_INVALID_BASE : first;
    unsigned lb = last >= SALU8_INVALID_BASE ? last - SALU8_INVALID_BASE : last;
    if (firstByte && lastByte)
    {
        unsigned char c = (unsigned char)(fb + 1);
        unsigned char classend = lastEscaped ? (unsigned char)lb : (unsigned char)(lb + 1);
        for (; c != classend; c++)
        {
            ClassSetByte(c);
            if (Caseles)
                ClassSetByte((unsigned char)REG_INVERT((char)c));
        }
    }
    else if (first < SALU8_INVALID_BASE && last < SALU8_INVALID_BASE)
        ClassAddRange(fb, lb);
    else // a byte that starts no letter against a letter: no range, both bounds are members
        ClassAddValue(last);
}

// the class into the program: its ANYOF operand (data-model.md)
void CRegExp::ClassEmit(int comp)
{
    CALL_STACK_MESSAGE_NONE
    if (comp)
    {
        int i;
        for (i = 31; i >= 0; i--)
            ClassMap[i] = (unsigned char)~ClassMap[i];
    }
    long size = CLASS_ITEMS + 5L * ClassNTests + 8L * ClassNRanges;
    if (RegCode == &RegDummy)
    {
        RegSize += size;
        return;
    }
    memcpy(RegCode, ClassMap, 32);
    RegCode[CLASS_FLAGS] = (char)(comp ? CLASS_NEG : 0);
    unsigned short nt = (unsigned short)ClassNTests, nr = (unsigned short)ClassNRanges;
    memcpy(RegCode + CLASS_NTESTS, &nt, 2);
    memcpy(RegCode + CLASS_NRANGES, &nr, 2);
    char* p = RegCode + CLASS_ITEMS;
    int i;
    for (i = 0; i < ClassNTests; i++, p += 5)
    {
        memcpy(p, &ClassTests[2 * i], 4);
        p[4] = (char)(ClassTests[2 * i + 1] ? 1 : 0);
    }
    for (i = 0; i < ClassNRanges; i++, p += 8)
    {
        memcpy(p, &ClassRanges[2 * i], 4);
        memcpy(p + 4, &ClassRanges[2 * i + 1], 4);
    }
    RegCode = p;
}

inline int
HexToNumber(char c)
{
    CALL_STACK_MESSAGE_NONE
    return IsDigit(c) ? c - '0' : LowerCase[c] - 'a' + 10;
}

char CRegExp::GetEscapedChar()
{
    CALL_STACK_MESSAGE_NONE
    switch (*RegParse)
    {
    case 'b':
        return '\b';
    case 't':
        return '\t';
    case 'n':
        return '\n';
    case 'r':
        return '\r';
    case 'f':
        return '\f';
    case 'a':
        return '\a';
    case 'x':
    {
        char ret;
        RegParse++;
        if (!IsXdigit(*RegParse) || !IsXdigit(RegParse[1]))
        {
            State = reeExpectingXDigit;
            return 0;
        }
        ret = HexToNumber(*RegParse) << 4;
        RegParse++;
        ret += HexToNumber(*RegParse);
        return ret;
    }
    }
    return *RegParse;
}

// feature 254: the escape at RegParse (just after the backslash) as a unit value - consecutive
// "\xHH" escapes that form one UTF-8 character (or a WTF-8 surrogate) are taken together; bytes
// forming no character one by one (SALU8_INVALID_BASE + the byte); RegParse is left on the last
// character of the escapes taken, as GetEscapedChar does
unsigned CRegExp::GetEscapedUnit()
{
    CALL_STACK_MESSAGE_NONE
    unsigned value;
    if ((unsigned char)*RegParse >= 0x80) // "\z-caron": the whole letter, never its lead byte alone
        value = ParseLiteralUnit();
    else if (*RegParse != 'x')
        return (unsigned char)GetEscapedChar();
    else
        value = GetHexEscapedUnit();
    // case-insensitive: a letter given by escapes is folded like a typed one (the pattern's
    // typed letters and the name are folded by the renamer)
    if (Caseles && value >= 0x80 && value < SALU8_INVALID_BASE && IsGood())
        value = SalU8FoldCodePoint(value);
    return value;
}

// consecutive "\xHH" escapes at RegParse (on the 'x') as one unit
unsigned CRegExp::GetHexEscapedUnit()
{
    CALL_STACK_MESSAGE_NONE
    unsigned char bytes[4];
    char* lastDigit[4];
    int count = 0;
    char* p = RegParse; // on 'x'
    while (count < 4)
    {
        if (!IsXdigit(p[1]) || !IsXdigit(p[2]))
        {
            if (count == 0)
            {
                State = reeExpectingXDigit;
                return 0;
            }
            break;
        }
        bytes[count] = (unsigned char)((HexToNumber(p[1]) << 4) + HexToNumber(p[2]));
        lastDigit[count] = p + 2;
        count++;
        if (count == 1 && bytes[0] < 0xC2)
            break; // ASCII or a byte that starts no letter: one escape
        if (p[3] != '\\' || p[4] != 'x')
            break;
        p += 4; // on the next 'x'
    }
    unsigned value;
    int n = SalU8UnitLen((const char*)bytes, (const char*)bytes + count, &value);
    RegParse = lastDigit[n - 1];
    return value;
}

// feature 254: the letter at RegParse as a unit value; RegParse is left on its last byte
unsigned CRegExp::ParseLiteralUnit()
{
    CALL_STACK_MESSAGE_NONE
    const char* end = RegParse;
    while (end - RegParse < 4 && *end != '\0')
        end++;
    unsigned value;
    int n = SalU8UnitLen(RegParse, end, &value);
    RegParse += n - 1;
    return value;
}

/*
 * regexec and friends
 */

/*
 - regexec - match a regexp against a string
 */

struct CRegExecData
{
    CRegExp* RegExp;
    char* String;
    int Length;
    int Offset;
};

BOOL CRegExp::RegExec(char* string, int length, int offset, BOOL separateThread)
{
    CALL_STACK_MESSAGE_NONE
    State = reeNoError;

    if (!Compiled)
    {
        State = reeNoPattern;
        return FALSE;
    }

    if (offset >= length)
        return FALSE;

    if (separateThread)
    {
        DWORD i;
        CRegExecData data;
        data.RegExp = this;
        data.String = string;
        data.Length = length;
        data.Offset = offset;
        HANDLE thread = CreateThread(NULL, 0, RegExecThread, &data, 0, &i);
        if (thread == 0)
        {
            State = reeErrorStartingThread;
            return FALSE;
        }
        WaitForSingleObject(thread, INFINITE);
        GetExitCodeThread(thread, &i);
        CloseHandle(thread);
        return i;
    }

    __try
    {
        char* s;

        /* Check validity of program. */
        if (UCHARAT(Program) != MAGIC)
        {
            State = reeInternalDisaster;
            return FALSE;
        }

        /* Mark beginning of line for ^ . */
        RegBol = string;
        // store the pointer past the last character of the line
        RegEol = string + length;

        /* If there is a "must appear" string, look for it. */
        if (RegMust != NULL)
        {
            s = string + offset;
            while (s + RegMLen <= RegEol &&
                   (s = (Caseles ? RegMemChrI(s, RegMust[0], (int)(RegEol - s)) : (char*)memchr(s, RegMust[0], RegEol - s))) != NULL)
            {
                if ((Caseles ? RegMemCmpI(s, RegMust, RegMLen) : memcmp(s, RegMust, RegMLen)) == 0)
                    break; /* Found it. */
                s++;
            }
            if (s == NULL || s + RegMLen > RegEol) /* Not present. */
            {
                return FALSE;
            }
        }

        /* Simplest case:  anchored match need be tried only once. */
        if (RegAnch)
        {
            return (RegTry(string + offset) > 0);
        }

        /* Messy cases:  unanchored match. */
        s = string + offset;
        if (RegStart != '\0')
            /* We know what char it must start with. */
            while ((s = (Caseles ? RegMemChrI(s, RegStart, (int)(RegEol - s)) : (char*)memchr(s, RegStart, (int)(RegEol - s)))) != NULL)
            {
                // feature 254: a match starts only where a letter starts
                if (SalU8IsUnitBoundary(string, RegEol, s) && RegTry(s))
                {
                    return TRUE;
                }
                s++;
            }
        else
            /* We don't -- general case. */
            do
            {
                if (RegTry(s))
                {
                    return TRUE;
                }
                s += UnitAt(s); // feature 254: the next letter, not the next byte
            } while (s < RegEol);

        /* Failure. */
        return FALSE;
    }
    __except (GetExceptionCode() == EXCEPTION_STACK_OVERFLOW)
    {
        State = reeStackOverflow;
        return FALSE;
    }
}

DWORD WINAPI
CRegExp::RegExecThread(void* data)
{
    CALL_STACK_MESSAGE_NONE
    CRegExecData* d = (CRegExecData*)data;
    return d->RegExp->RegExec(d->String, d->Length, d->Offset, FALSE);
}

/*
 - regtry - try match at specific point
 */
int CRegExp::RegTry(char* string) /* 0 failure, 1 success */
{
    CALL_STACK_MESSAGE_NONE
    int i;
    char** sp;
    char** ep;

    RegInput = string;
    RegStartp = Startp;
    RegEndp = Endp;

    sp = Startp;
    ep = Endp;
    for (i = SubExpCount; i > 0; i--)
    {
        *sp++ = NULL;
        *ep++ = NULL;
    }
    if (RegMatch(Program + 1))
    {
        Startp[0] = string;
        Endp[0] = RegInput;
        return (1);
    }
    else
        return (0);
}

/*
 - RegMatch - main matching routine
 *
 * Conceptually the strategy is simple:  check to see whether the current
 * node matches, call self recursively to see whether the rest matches,
 * and then act accordingly.  In practice we make some effort to avoid
 * recursion, in particular by going through "ordinary" nodes (that don't
 * need to know whether the rest of the match failed) by a loop instead of
 * by recursion.
 */
int CRegExp::RegMatch(char* prog) /* 0 failure, 1 success */
{
    CALL_STACK_MESSAGE_NONE
    char* scan; /* Current node. */
    char* next; /* Next node. */

    scan = prog;
    while (scan != NULL)
    {
        next = RegNext(scan);

        switch (OP(scan))
        {
        case BOL:
            if (RegInput != RegBol)
            {
                if ((Options & RE_LF) && RegInput[-1] == '\n')
                    break;
                if ((Options & RE_CR) && RegInput[-1] == '\r')
                    break;
                if ((Options & RE_NULL) && RegInput[-1] == '\0')
                    break;
                if ((Options & RE_CRLF) && RegInput > RegBol + 1 &&
                    RegInput[-1] == '\n' && RegInput[-2] == '\r')
                    break;
                return 0;
            }
            break;
        case EOL:
            if (!RegMatchEol(RegInput))
                return 0;
            break;
        case BOS:
            if (RegInput != RegBol)
                return (0);
            break;
        case EOS:
            if (RegInput != RegEol)
            {
                if (RegInput + 1 == RegBol)
                {
                    if ((Options & RE_LF) && *RegInput == '\n')
                        break;
                    if ((Options & RE_CR) && *RegInput == '\r')
                        break;
                    if ((Options & RE_NULL) && *RegInput == '\0')
                        break;
                }
                if (RegInput + 2 == RegBol)
                {
                    if ((Options & RE_CRLF) && RegInput + 1 < RegEol &&
                        RegInput[0] == '\r' && RegInput[1] == '\n')
                        break;
                }
                return (0);
            }
            break;
        case VEOS:
            if (RegInput != RegEol)
                return (0);
            break;
        case WORDB: // feature 254: the letters before and after, not two bytes
        {
            int prev = RegInput > RegBol && IsWordUnitBefore(RegInput);
            int cur = RegInput < RegEol && IsWordUnitAt(RegInput);
            if (prev == cur)
                return 0;
            break;
        }
        case NOTWORDB:
        {
            int prev = RegInput > RegBol && IsWordUnitBefore(RegInput);
            int cur = RegInput < RegEol && IsWordUnitAt(RegInput);
            if (prev != cur)
                return 0;
            break;
        }
        case ANY:
            if (RegMatchEol(RegInput))
                return (0);
            RegInput += UnitAt(RegInput); // feature 254: a whole letter
            break;
        case ANYDOT:
            if (RegInput == RegEol)
                return (0);
            RegInput += UnitAt(RegInput);
            break;
        case EXACTLY:
        {
            int len;
            char* opnd;

            opnd = OPERAND(scan);
            /* Inline the first character, for speed. */
            if (RegInput == RegEol || *opnd != (Caseles ? REG_LOWER(*RegInput) : *RegInput))
                return (0);
            len = (int)strlen(opnd);
            if (len > RegEol - RegInput || len > 1 &&
                                               (Caseles ? RegMemCmpI(RegInput, opnd, len) : memcmp(RegInput, opnd, len)) != 0)
                return (0);
            // feature 254: never a piece of a letter (a lone "\xC5" against "z-caron")
            if (!SalU8IsUnitBoundary(RegBol, RegEol, RegInput + len))
                return (0);
            RegInput += len;
        }
        break;
        case ANYOF:
        {
            int n;
            if (RegInput == RegEol || (n = ClassMatch(OPERAND(scan), RegInput)) == 0)
                return (0);
            RegInput += n; // feature 254: a whole letter
        }
        break;
        case NOTHING:
            break;
        case BACK:
            break;
        case OPEN:
        {
            int no;
            char* save;

            no = *OPERAND(scan);
            save = RegInput;

            if (RegMatch(next))
            {
                /*
             * Don't set startp if some later
             * invocation of the same parentheses
             * already has.
             */
                if (RegStartp[no] == NULL)
                    RegStartp[no] = save;
                return (1);
            }
            else
                return (0);
        }
        case CLOSE:
        {
            int no;
            char* save;

            no = *OPERAND(scan);
            save = RegInput;

            if (RegMatch(next))
            {
                /*
             * Don't set endp if some later
             * invocation of the same parentheses
             * already has.
             */
                if (RegEndp[no] == NULL)
                    RegEndp[no] = save;
                return (1);
            }
            else
                return (0);
        }
        case BRANCH:
        {
            char* save;

            if (OP(next) != BRANCH)   /* No choice. */
                next = OPERAND(scan); /* Avoid recursion. */
            else
            {
                do
                {
                    save = RegInput;
                    if (RegMatch(OPERAND(scan)))
                        return (1);
                    RegInput = save;
                    scan = RegNext(scan);
                } while (scan != NULL && OP(scan) == BRANCH);
                return (0);
                /* NOTREACHED */
            }
        }
        break;
        case UGBRANCH:
        {
            char* save;

            save = RegInput;
            if (RegMatch(next)) /* Try next */
                return (1);
            RegInput = save; /* or an alternative */
            next = OPERAND(scan);
        }
        break;
        case STAR:
        case PLUS:
        {
            int nextch;
            int no;
            char* save;
            int min;

            /*
           * Lookahead to avoid useless match attempts
           * when we know what character comes next.
           */
            nextch = -1;
            if (OP(next) == EXACTLY)
                nextch = *OPERAND(next);
            min = (OP(scan) == STAR) ? 0 : 1;
            save = RegInput;
            no = RegRepeat(OPERAND(scan)); // feature 254: letters, not bytes
            char* pos = RegInput;
            while (no >= min)
            {
                RegInput = pos;
                /* If it could work, try it. */
                if (nextch == -1 ||
                    (Caseles ? REG_LOWER(*RegInput) : *RegInput) == (char)nextch)
                    if (RegMatch(next))
                        return (1);
                /* Couldn't or didn't -- back up. */
                no--;
                if (no < min)
                    break;
                pos = (char*)SalU8UnitBack(save, pos); // one letter back
            }
            return (0);
        }

        case UGSTAR:
        case UGPLUS:
        {
            int nextch;
            char* save;
            char op;
            char* opnd;

            nextch = -1;
            if (OP(next) == EXACTLY)
                nextch = *OPERAND(next);
            opnd = OPERAND(OPERAND(scan));
            op = OP(OPERAND(scan));

            int n;
            if (OP(scan) == UGPLUS)
            {
                if ((n = RegMatchSimple(op, opnd)) > 0)
                    RegInput += n; // feature 254: a whole letter
                else
                    return 0;
            }
            do
            {
                save = RegInput;
                /* If it could work, try it. */
                if (nextch == -1 ||
                    (Caseles ? REG_LOWER(*RegInput) : *RegInput) == (char)nextch)
                    if (RegMatch(next))
                        return 1;
                RegInput = save;
                if ((n = RegMatchSimple(op, opnd)) > 0)
                    RegInput += n; // eat one letter more
                else
                    break;
            } while (1);

            return 0; // not matched
        }

        case PLOOKA:
        {
            char* save;

            save = RegInput;
            if (!RegMatch(OPERAND(scan)))
                return (0);
            RegInput = save;
        }
        break;

        case NLOOKA:
        {
            char* save;

            save = RegInput;
            if (RegMatch(OPERAND(scan)))
                return (0);
            RegInput = save;
        }
        break;

        case PLOOKB: // feature 254: the width counts letters
        {
            char* save;

            save = RegInput;
            RegInput = UnitsBack(RegInput, *(unsigned short*)(OPERAND(scan)));
            if (RegInput == NULL || !RegMatch(OPERAND(scan) + 2))
            {
                RegInput = save;
                return (0);
            }
            RegInput = save;
        }
        break;

        case NLOOKB:
        {
            char* save;

            save = RegInput;
            RegInput = UnitsBack(RegInput, *(unsigned short*)(OPERAND(scan)));
            if (RegInput != NULL && RegMatch(OPERAND(scan) + 2))
            {
                RegInput = save;
                return (0);
            }
            RegInput = save;
        }
        break;

        case END:
            return (1); /* Success! */
        default:
            return (0); /* memory corruption */
        }

        scan = next;
    }

    /*
   * We get here only if there's trouble -- normally "case END" is
   * the terminating point.
   */
    //  regerror("corrupted pointers");
    return (0);
}

/*
 - RegRepeat - repeatedly match something simple, report how many
 */
int CRegExp::RegRepeat(char* p)
{
    CALL_STACK_MESSAGE_NONE
    int count = 0;
    char* scan;
    char* opnd;

    // feature 254: counts LETTERS (the caller backs off letter by letter)
    int n;
    scan = RegInput;
    opnd = OPERAND(p);
    switch (OP(p))
    {
    case ANY:
        while (!RegMatchEol(scan))
        {
            scan += UnitAt(scan);
            count++;
        }
        break;
    case ANYDOT:
        while (scan < RegEol)
        {
            scan += UnitAt(scan);
            count++;
        }
        break;
    case EXACTLY:
        while (scan < RegEol && (n = ExactlyAt(opnd, scan)) > 0)
        {
            scan += n;
            count++;
        }
        break;
    case ANYOF:
        while (scan < RegEol && (n = ClassMatch(opnd, scan)) > 0)
        {
            scan += n;
            count++;
        }
        break;
    default:       /* Oh dear.  Called inappropriately. */
                   //    regerror("internal foulup");
        count = 0; /* Best compromise. */
        break;
    }
    RegInput = scan;

    return (count);
}

/*
 - RegMatchSimple - match something simple; feature 254: returns the length of the letter matched
 */
int CRegExp::RegMatchSimple(char op, char* opnd)
{
    CALL_STACK_MESSAGE_NONE
    if (RegInput >= RegEol)
        return 0;
    switch (op)
    {
    case ANY:
        return RegMatchEol(RegInput) ? 0 : UnitAt(RegInput);
    case ANYDOT:
        return UnitAt(RegInput);
    case EXACTLY:
        return ExactlyAt(opnd, RegInput);
    case ANYOF:
        return ClassMatch(opnd, RegInput);
    }
    // Oh dear.  Called inappropriately.
    return 0; // Best Compromise
}

//*****************************************************************************
// feature 254: whole letters (salu8letter.h)

int CRegExp::UnitAt(const char* p)
{
    unsigned value;
    return SalU8UnitLen(p, RegEol, &value);
}

// the class operand 'opnd' (after its ANYOF node) against the letter at 'p' (< RegEol)
int CRegExp::ClassMatch(const char* opnd, const char* p)
{
    unsigned value;
    int n = SalU8UnitLen(p, RegEol, &value);
    if (n == 0)
        return 0; // at the end of the text
    if (value < 0x80)
        return INCLASS(opnd, value) ? n : 0;
    if (value >= SALU8_INVALID_BASE) // a byte that starts no letter: the bitmap's upper half
        return INCLASS(opnd, value - SALU8_INVALID_BASE) ? n : 0;
    const unsigned char* op = (const unsigned char*)opnd;
    unsigned short nt, nr;
    memcpy(&nt, op + CLASS_NTESTS, 2);
    memcpy(&nr, op + CLASS_NRANGES, 2);
    const unsigned char* tests = op + CLASS_ITEMS;
    const unsigned char* ranges = tests + 5 * nt;
    BOOL in = FALSE;
    int i;
    for (i = 0; i < nr && !in; i++)
    {
        unsigned lo, hi;
        memcpy(&lo, ranges + 8 * i, 4);
        memcpy(&hi, ranges + 8 * i + 4, 4);
        in = value >= lo && value <= hi;
    }
    if (!in && nt > 0)
    {
        unsigned types = SalU8LetterTypes(value);
        for (i = 0; i < nt && !in; i++)
        {
            unsigned mask;
            memcpy(&mask, tests + 5 * i, 4);
            in = tests[5 * i + 4] ? (types & mask) == 0 : (types & mask) != 0;
        }
    }
    if (op[CLASS_FLAGS] & CLASS_NEG)
        in = !in;
    return in ? n : 0;
}

// a one-letter literal (a SIMPLE EXACTLY) at 'p': its length, ending on a letter boundary, or 0
int CRegExp::ExactlyAt(const char* opnd, const char* p)
{
    int len = (int)strlen(opnd);
    if (len == 0 || len > RegEol - p)
        return 0;
    if (len == 1)
    {
        if (*opnd != (Caseles ? REG_LOWER(*p) : *p))
            return 0;
    }
    else if ((Caseles ? RegMemCmpI(p, opnd, len) : memcmp(p, opnd, len)) != 0)
        return 0;
    return SalU8IsUnitBoundary(RegBol, RegEol, p + len) ? len : 0;
}

int CRegExp::IsWordUnitAt(const char* p)
{
    unsigned value;
    SalU8UnitLen(p, RegEol, &value);
    if (value < 0x80)
        return IsWord((char)value) ? 1 : 0; // ASCII as before (the CType table)
    return SalU8IsWordValue(value) ? 1 : 0;
}

int CRegExp::IsWordUnitBefore(const char* p)
{
    const char* start = SalU8UnitBack(RegBol, p);
    unsigned value;
    SalU8UnitLen(start, p, &value);
    if (value < 0x80)
        return IsWord((char)value) ? 1 : 0;
    return SalU8IsWordValue(value) ? 1 : 0;
}

char* CRegExp::UnitsBack(char* q, int count)
{
    while (count-- > 0)
    {
        if (q <= RegBol)
            return NULL;
        q = (char*)SalU8UnitBack(RegBol, q);
    }
    return q;
}

/*
 - RegNext - dig the "next" pointer out of a node
 */
char* CRegExp::RegNext(char* p)
{
    CALL_STACK_MESSAGE_NONE
    int offset;

    if (p == &RegDummy)
        return (NULL);

    offset = NEXT(p);
    if (offset == 0)
        return (NULL);

    if (OP(p) == BACK)
        return (p - offset);
    else
        return (p + offset);
}

//*****************************************************************************

// Creates CRegExp object. Returns NULL in case of low memory
CRegExpAbstract* CreateRegExp()
{
    CALL_STACK_MESSAGE_NONE
    return new CRegExp;
}

// Release CRegExp object.
void ReleaseRegExp(CRegExpAbstract* regExp)
{
    CALL_STACK_MESSAGE_NONE
    delete regExp;
}
