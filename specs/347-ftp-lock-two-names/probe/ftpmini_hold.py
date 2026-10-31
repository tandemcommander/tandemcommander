"""Feature 347: feature 323's ftpmini_hide.py whose STOR of a name starting with "hold" waits
HOLD_SECONDS after the data connection is open and before the file is created (an upload in
flight: the file is not on the server yet, the client's STOR is not answered). Logs
{"event": "stor-begin" / "stor-done", "name": ...} around every STOR, so a probe can tell two
STOR of one file that overlap.

Usage: python -I ftpmini_hold.py MINIPY [ADDR] ROOT PORT LOG [ENC ...] - MINIPY is
ftpmini_hide.py; ADDR (optional, a 127.x.y.z address) binds the control listener there instead
of 127.0.0.1 (as feature 341's ftpmini_at.py does).
"""
import sys

HOLD_SECONDS = 20
src_path = sys.argv[1]
del sys.argv[1]
BIND_ADDR = '127.0.0.1'
if len(sys.argv) > 1 and sys.argv[1].startswith('127.'):
    BIND_ADDR = sys.argv[1]
    del sys.argv[1]
with open(src_path, encoding='utf-8') as f:
    src = f.read()

pairs = [
    ("""            self.reply('150 Receiving')
            c = self.data_conn()
            with open(r, 'ab' if verb == 'APPE' else 'wb') as f:""",
     """            self.reply('150 Receiving')
            c = self.data_conn()
            log({'event': 'stor-begin', 'name': os.path.basename(r)})
            if os.path.basename(r).startswith('hold'):
                time.sleep(HOLD_SECONDS)
            with open(r, 'ab' if verb == 'APPE' else 'wb') as f:"""),
    ("""                    f.write(b)
            c.close()
            self.reply('226 Stored')""",
     """                    f.write(b)
            c.close()
            log({'event': 'stor-done', 'name': os.path.basename(r)})
            self.reply('226 Stored')"""),
    ("Server(('127.0.0.1', PORT), Session)", "Server((BIND_ADDR, PORT), Session)"),
    ("if host != '127.0.0.1':", "if not host.startswith('127.'):"),
]
for old, new in pairs:
    if src.count(old) != 1:
        sys.exit('ftpmini_hide.py changed: ' + old.strip().splitlines()[0])
    src = src.replace(old, new)

sys.argv[0] = src_path
exec(compile(src, src_path, 'exec'), {'__name__': '__main__', '__file__': src_path,
                                      'HOLD_SECONDS': HOLD_SECONDS, 'BIND_ADDR': BIND_ADDR})
