"""Feature 341: feature 323's ftpmini_hide.py listening on another loopback address (row MULTI-REN:
one folder served on 127.0.0.1 and 127.0.0.2).

Usage: python -I ftpmini_at.py ADDR ROOT PORT LOG [ENC ...] - ADDR is a 127.x.y.z address; the rest
is passed to ftpmini_hide.py unchanged. The server's control listener binds ADDR; a PORT command
may name any loopback address (the client's source address for 127.0.0.2 may be 127.0.0.1).
"""
import os
import sys

ADDR = sys.argv[1]
if not ADDR.startswith('127.'):
    sys.exit('loopback addresses only')
del sys.argv[1]

here = os.path.dirname(os.path.abspath(__file__))
src_path = os.path.join(here, '..', '..', '323-ftp-upload-cache-args', 'probe', 'ftpmini_hide.py')
with open(src_path, encoding='utf-8') as f:
    src = f.read()

pairs = [
    ("Server(('127.0.0.1', PORT), Session)", "Server((BIND_ADDR, PORT), Session)"),
    ("if host != '127.0.0.1':", "if not host.startswith('127.'):"),
]
for old, new in pairs:
    if src.count(old) != 1:
        sys.exit('ftpmini_hide.py changed: ' + old)
    src = src.replace(old, new)

sys.argv[0] = src_path
exec(compile(src, src_path, 'exec'), {'__name__': '__main__', '__file__': src_path, 'BIND_ADDR': ADDR})
