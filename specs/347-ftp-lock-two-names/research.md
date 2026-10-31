# Research - 347-ftp-lock-two-names

## R1. Which host names may be one server?

- **Decision**: every host name, given the same user and port.
- **Rationale**: feature 341 (review 1) showed one server answering on 127.0.0.1 and 127.0.0.2:
  neither equal nor different addresses prove two names are one server or two; the item's
  *Expected* asks for "two host names of the same user and port".
- **Alternatives**: resolve both names and compare addresses - rejected by 341 (a server answers on
  several addresses; a proxy hides the address; a lookup inside a critical section would block);
  keep a list of names known to be one server - the client cannot learn it.

## R2. Wait or refuse?

- **Decision**: refuse with each caller's existing answer (`ITEMPR_TGTFILEINUSE` /
  `ITEMPR_SRCFILEINUSE` / the panel's "in use" message); the user retries.
- **Rationale**: identical to one name today; no new state, no new UI text. The item accepts
  "waits or is refused".

## R3. Cost

Two different servers with the same user, port, folder and file name: a conflicting access (a
write with anything, a delete / rename with another type) to one while the other is in progress is
refused "in use" and can be retried. Two reads never conflict. Upload auto-rename
(`operatsb.cpp`, the auto-rename loop) treats a locked candidate name as taken and tries the next
name - harmless. Accepted (item *Notes*: "a cost to weigh"; refusing loses nothing, the old
behaviour loses a file).

## R4. Scope left out

Another user or port of the same server (measured on `main`: row OTHER-USER, two overlapping STOR)
- outside the item; Inbox item `measure:347`.
