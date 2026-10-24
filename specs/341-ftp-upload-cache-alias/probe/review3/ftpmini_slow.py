"""Review 3 of 341: feature 323's ftpmini_hide.py whose STOR of a name starting with "slow" holds
its 226 reply for SLOW_SECONDS after the file is fully written (a change made on the server and not
yet reported to the client - an upload in flight).

Usage: python -I ftpmini_slow.py MINIPY ROOT PORT LOG [ENC ...]
"""
import sys

SLOW_SECONDS = 25
src_path = sys.argv[1]
del sys.argv[1]
with open(src_path, encoding='utf-8') as f:
    src = f.read()

old = """                    f.write(b)
            c.close()
            self.reply('226 Stored')"""
new = """                    f.write(b)
            c.close()
            if os.path.basename(r).startswith('slow'):
                time.sleep(SLOW_SECONDS)
            self.reply('226 Stored')"""
if src.count(old) != 1:
    sys.exit('ftpmini_hide.py changed: STOR branch')
src = src.replace(old, new)

sys.argv[0] = src_path
exec(compile(src, src_path, 'exec'), {'__name__': '__main__', '__file__': src_path, 'SLOW_SECONDS': SLOW_SECONDS})
