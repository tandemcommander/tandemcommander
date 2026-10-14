"""Feature 164 probe helper: a ZIP of N small members.

    python bigzip.py make <arc.zip> <N>     members d/a00001.txt ... (every second one named *.del)
    python bigzip.py check <arc.zip> <N>    prints COUNT <n> KEPT <k> DEL <d> BAD <b>: the kept members
                                            must be exactly the *.txt ones with their own content
"""
import sys
import zipfile


def name(i):
    return 'd/a%06d.%s' % (i, 'del' if i % 2 else 'txt')


def data(i):
    return ('member %d\r\n' % i).encode('ascii') * (1 + i % 7)


if sys.argv[1] == 'make':
    arc, n = sys.argv[2], int(sys.argv[3])
    with zipfile.ZipFile(arc, 'w', zipfile.ZIP_DEFLATED) as z:
        for i in range(n):
            z.writestr(zipfile.ZipInfo(name(i), (2026, 1, 2, 3, 4, 6)), data(i))
    print('ok')
else:
    arc, n = sys.argv[2], int(sys.argv[3])
    kept = deleted = bad = 0
    with zipfile.ZipFile(arc) as z:
        infos = z.infolist()
        names = set(i.filename for i in infos)
        for i in range(n):
            nm = name(i)
            if nm.endswith('.del'):
                if nm in names:
                    bad += 1
                else:
                    deleted += 1
            else:
                if nm not in names or z.read(nm) != data(i):
                    bad += 1
                else:
                    kept += 1
        if z.testzip() is not None:
            bad += 1
    print('COUNT %d KEPT %d DEL %d BAD %d' % (len(infos), kept, deleted, bad))
