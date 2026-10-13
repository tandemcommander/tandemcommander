# Feature 134: the bytes the test server received in two probe runs must be the same (the
# feature changes texts that are shown, never what is sent). The port numbers of PORT
# commands differ from run to run and are left out.
# Usage: python compare_server_logs.py <log before> <log after>
import sys


def load(path):
    out = []
    for line in open(path, encoding='ascii'):
        kind, _, value = line.strip().partition(' ')
        if kind == 'RECV':
            raw = bytes.fromhex(value)
            if raw.upper().startswith(b'PORT '):
                raw = b'PORT <address>'
            out.append(raw)
        else:
            out.append(kind.encode())
    return out


a, b = load(sys.argv[1]), load(sys.argv[2])
diff = [i for i in range(max(len(a), len(b))) if i >= len(a) or i >= len(b) or a[i] != b[i]]
print('%d and %d lines; different (PORT numbers aside): %d' % (len(a), len(b), len(diff)))
for i in diff[:20]:
    print('  line %d: %r / %r' % (i + 1, a[i] if i < len(a) else None, b[i] if i < len(b) else None))
sys.exit(1 if diff else 0)
