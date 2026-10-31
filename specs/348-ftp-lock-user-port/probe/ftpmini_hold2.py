"""Feature 348: feature 347's ftpmini_hold.py (feature 323's ftpmini_hide.py whose STOR of a name
starting with "hold" waits HOLD_SECONDS after the data connection is open and before the file is
created) that can also listen on a second port: one server, one folder, one log, reached through
two ports (a forwarded port of one server). Every "connect" event names the port it came in on.

Usage: python -I ftpmini_hold2.py MINIPY [--port2 PORT2] ROOT PORT LOG [ENC ...] - MINIPY is
ftpmini_hide.py; PORT2 (optional) is the second control port, served by the same sessions.
"""
import sys

HOLD_SECONDS = 20
src_path = sys.argv[1]
del sys.argv[1]
PORT2 = 0
if len(sys.argv) > 2 and sys.argv[1] == '--port2':
    PORT2 = int(sys.argv[2])
    del sys.argv[1:3]
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
    ("""        log({'event': 'connect'})""",
     """        log({'event': 'connect', 'port': self.server.server_address[1]})"""),
    ("""    with Server(('127.0.0.1', PORT), Session) as srv:
        srv.serve_forever()""",
     """    if PORT2:
        srv2 = Server(('127.0.0.1', PORT2), Session)
        threading.Thread(target=srv2.serve_forever, daemon=True).start()
    with Server(('127.0.0.1', PORT), Session) as srv:
        srv.serve_forever()"""),
]
for old, new in pairs:
    if src.count(old) != 1:
        sys.exit('ftpmini_hide.py changed: ' + old.strip().splitlines()[0])
    src = src.replace(old, new)

sys.argv[0] = src_path
exec(compile(src, src_path, 'exec'), {'__name__': '__main__', '__file__': src_path,
                                      'HOLD_SECONDS': HOLD_SECONDS, 'PORT2': PORT2})
