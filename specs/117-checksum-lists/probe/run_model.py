# Feature 117: runs m117_model.exe over every fixture list and compares each row's verdict and
# shown name with expected117.json ("after"). Exit code = number of mismatches.
import json
import os
import subprocess
import sys

exe, root = sys.argv[1], sys.argv[2]
exp = json.load(open(os.path.join(root, 'expected117.json'), encoding='ascii'))
bad = 0
total = 0
for lst in exp['lists']:
    p = os.path.join(root, 'data', lst['file'])
    out = subprocess.run([exe, p], capture_output=True, text=True).stdout.splitlines()
    head = out[0] if out else '<no output>'
    rows = [l.split(' ', 2) for l in out[1:] if l.startswith('ROW ')]
    print('%-28s %s' % (lst['file'], head.split(' ', 2)[-1] if out else head))
    if len(rows) != len(lst['rows']):
        print('   MISMATCH: %d rows, expected %d' % (len(rows), len(lst['rows'])))
        bad += 1
    for i, er in enumerate(lst['rows']):
        total += 1
        if i >= len(rows):
            break
        verdict = rows[i][1]
        hexname = rows[i][2] if len(rows[i]) > 2 else ''
        name = ''.join(chr(int(hexname[k:k + 4], 16)) for k in range(0, len(hexname), 4))
        ok = verdict == er['after'] and name == er['name']
        if not ok:
            bad += 1
        print('   %-4s %-8s expected %-8s name %s%s' % ('ok' if ok else 'BAD', verdict, er['after'],
              name.encode('ascii', 'backslashreplace').decode(),
              '' if name == er['name'] else ' (expected %s)' % er['name'].encode('ascii', 'backslashreplace').decode()))
print('model rows: %d, mismatches: %d' % (total, bad))
sys.exit(bad)
