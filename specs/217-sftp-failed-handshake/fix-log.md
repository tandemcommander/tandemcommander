# Fix log: 217 - SFTP: a failed key exchange leaks nothing, and fails no more by chance

Backlog (`specs/NEXT-WORK.md`): "SFTP: a memory leak after a failed SSH handshake" - twice in
Debug probe runs "SSH handshake failed: Unable to exchange encryption keys", then "Detected memory
leaks!" at the exit and the program not ending within 30 s; "two defects to separate: why the key
exchange fails now and then, and what the failed path leaves".

## Measured

Probe `probe/sftp217_probe.ps1` (each row its own start of the program; the left panel connects
by a typed `sftp://` address; every dialog answered - a host key "Connect Once", never stored;
then the program is closed: the END row fails on any window at the exit - the Debug build's
"Detected memory leaks!" box - or an exit over 30 s). `probe/fakessh.py` (127.0.0.1 only) fails
the handshake in a chosen way, or is a proxy to the test container `tandem-sftp`.

Not reproduced first (`probe/result_before.txt`): the server closing at once, after its banner,
sending garbage, closing after the client's key exchange init; the proxy cutting the real
server's stream after 1,200 / 3,000 / 6,000 bytes; 15 normal connections - all clean.

The read-only audit of the plug-in and libssh2 found the window: libssh2 makes the server's
host-key object before it checks the server's signature, and `session_free` destroys it only once
NEWKEYS was received. A proxy row **FLIPSIG** (one byte of the server's SSH_MSG_KEX_ECDH_REPLY
signature flipped - plaintext before NEWKEYS) reproduces the report exactly
(`probe/result_before_flipsig.txt`): **"Unable to exchange encryption keys", then "Detected memory
leaks!" at the exit, the program not ending within 30 s** - the leak box itself holds the exit
(a system-modal box nobody dismisses on the hidden desktop).

Why the key exchange fails now and then (read; the audit and the review agree; upstream libssh2
fixed the same as `wcng_bn_normalize`): the WinCNG backend returns the raw (EC)DH secret at the
fixed width of the group; when its top byte is 0 (about one exchange in 256) K was hashed as a
non-minimal mpint (`kex.c` takes `_libssh2_bn_bytes` = the full length), the exchange hash
differed from the server's and the server's signature did not verify. Not driven (about 1,500
connections would show ~6 failures): recorded as owed.

## Work

`src/common/dep/libssh2/src/` (local patches, marked as the earlier ones of 051):
- `session.c` `session_free`: the server's host-key object is destroyed also when NEWKEYS was not
  reached (each dtor clears its pointer; the NEWKEYS block keeps its own);
- `wincng.c`: `_libssh2_wincng_bignum_trim` (leading zero bytes dropped in place) after the byte
  reversal of the raw ECDH secret and of the raw DH secret; (review) also the DH public value `e`
  (hashed as sent - the server re-encodes it minimally) on both of its routes and the secret of the
  `mod_exp` fallback;
- `wincng.c` `_libssh2_wincng_ecdh_gen_k`: the server's public-key handle and the agreed secret
  destroyed on every path (two CNG objects per connection were left - not seen by the CRT check).

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 18 / 0 (the final build): FLIPSIG - the same message, no leak box, a
clean exit; every other row as before. `probe/result_after_real20.txt`: 20 normal connections
40 / 0 (before the review's DH `e` trim - ECDH is negotiated, DH is not reached). Regression:
205's SFTP probe 14 / 0 (`probe/regress_205.txt`).

## Review

Refute-first review: accept. The mpint analysis checked (`kex.c` 608-636 / 2055-2083; OpenSSL's
`BN_bn2bin` is minimal - the bug is WinCNG only); the trim is memory-safe (`safe_free` zeroes
`length` bytes, the tail is zeroed by the trim, `realloc` ignores the gap); no double free (the
two host-key blocks test opposite states of NEWKEYS, which is never cleared; a retry keeps the same
method); the public-key handle is owned here and destroyed once. Taken: the DH `e` and the
fallback secret. Recorded in `specs/NEXT-WORK.md` (the same leak box, other routes):
`src/plugins/sftp/session.cpp` `Disconnect` (~1188-1203) gives the teardown a 1 ms deadline on a
dead or cancelled connection - the channel close times out, `sftp_shutdown` and `session_free`
fail and the whole session leaks (suggested: on a failed `session_free` close the socket and call
it again); a server's SSH_MSG_DISCONNECT while SFTP is up leaks the SFTP structure (`channel.c`
skips the close callback once disconnected - upstream).
