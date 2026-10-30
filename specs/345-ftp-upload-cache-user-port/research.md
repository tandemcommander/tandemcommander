# Research - 345-ftp-upload-cache-user-port

## R1 - Which identities are "maybe the same server"

- Decision: every identity other than the reported one (host as typed, user with `anonymous` =
  none, port).
- Rationale: the client cannot tell which accounts share folders (shared home, `anonymous` and a
  named account, chroot jails) or which ports reach one server (forwarding, a second listener);
  341 already treats every other host name as maybe the same server, so user and port must be
  dropped together with the host, or the combination "another user at another name" (probe row
  ALL-REN) keeps losing data. Item *Expected*; rule 098.
- Alternatives: (a) the item's middle way - only the same host name with another user or port:
  cheaper, but leaves ALL-REN (and `localhost` / `127.0.0.1` with two accounts) losing data;
  rejected. (b) Apply the change report to the other entries instead of invalidating: another
  account may see another folder under the same path; rejected (341's reasoning).

## R2 - Cost

- Decision: accepted (spec *Clarifications*). While two uploads under two identities run, each
  change through one makes the other list its folder again before its next decision; a panel
  upload after a change made elsewhere lists the folder once. One upload alone, or uploads under
  one identity, are unchanged.

## R3 - Where "own identity" is compared

- Decision: one static helper `CUploadListingCache::SameIdentity(entryUser, entryHost, entryPort,
  user, host, port)` used by `FindServer`, `StampChange` and `ChangedUnderOtherName`;
  `InvalidateOtherNamesOfServer` compares with the `exact` entry pointer `FindServer` returned
  (the reported identity's own entry, or NULL when it has none - then every entry is another
  identity).
- Rationale: "own" must mean the same in the three places, else a stamp could be counted as
  another identity's for the panel's own listing (refusing it - only slower) or the reverse
  (unsafe).

## R4 - Pure-rule header with saltests

- Decision: not added. The rule is the three-field equality `FindServer` already used since the
  original code; the change is that the "other" side no longer filters by user and port. The
  behaviour is proven by the probe rows (before: 5 FAIL) and a negative control.
