---
title: Should PRIVACY.md name the sign-in of the share list (285)?
type: decision
status: new
severity: 2
area: privacy-security
source: review:285
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: -
feature: -
related: [share-list-sign-in-285-by-hand-the-real-windows-dialog-on-a]
depends-on: []
reason: -
---

# Should PRIVACY.md name the sign-in of the share list (285)?

## Problem

Since feature 285, when a server refuses its share list for want of a name and password, `\\server\` opens Windows' sign-in dialog and, after a sign-in, Windows connects the server's `\\server\IPC$` for the rest of the Windows session; then the list is read again. CLAUDE.md asks `PRIVACY.md` to change in the same change as new or changed network communication; a run may not write a public claim (stop-rules §1), so 285 left `PRIVACY.md` unchanged.

## Evidence

`specs/285-share-list-sign-in/research.md` R4 (the claims checked one by one), `fix-log.md` *Review* SHOULD 2. `PRIVACY.md`, section *When the program uses the network*, bullet *Network drives and shared folders* ("when you open a network location, Windows connects to it ... the program asks that server, through Windows, for the list of its shared folders ... The program handles no name or password for it.") and section *Saved passwords* ("Passwords for network drives are entered in a Windows dialog and are saved only if you choose so there, by Windows."). All stay true after 285: the program types, keeps and shows no name or password; Windows' dialog collects them and Windows connects.

## Expected

The maintainer decides whether the share-list bullet names the sign-in; if yes, the sentence is added (with the validity line, in the next release's `PRIVACY.md` change).

## Question

Should the *Network drives and shared folders* bullet of `PRIVACY.md` say that a server which refuses its list makes Windows ask for a name and password and connect to the server?

## Options

- A - add one sentence, e.g. "If the server asks for a name and password before it gives the list, Windows asks for them in its own dialog and connects to the server for the rest of your Windows session; the program does not see them." Consequence: the claim describes the new connection explicitly; one line of public text to review.
- B - leave it as it is. Consequence: no change; the existing sentences already cover it ("Windows connects to it", passwords in a Windows dialog), but the connection made for the list is not named.

## Recommendation

A - the bullet already explains the share list in detail; naming the sign-in keeps it complete at the cost of one sentence.

## Log

- 2026-10-21 — created (source review:285)
