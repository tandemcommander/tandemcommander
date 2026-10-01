"""Re-key the committed salamand translations to the new STRINGTABLE bundle numbering.

Feature 084 removed whole 16-id string bundles and added new ones. The merge
tool identifies a string-table row by (section number, id), and the section
number is the bundle's ORDINAL - so every bundle after the change gets a new
number and every row in it would look new (the feature-079 incident: 456 rows
per language here). This script maps each committed section to the template
section that holds the same bundle (base id = id // 16) BEFORE the merge, in
the .slt and in its .origin sidecar, so the merge carries every existing
translation over and only the genuinely new strings remain gaps. Rows of a
bundle that no longer exists get a section number that matches nothing and are
dropped by the merge as obsolete.

Usage: python rekey_stringtables.py <template.slt> <language folder>...
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HEADER = re.compile(r'^\[STRINGTABLE (\d+)\]\s*$')
ROW = re.compile(r'^(\d+),')
GONE = 90000  # section numbers for bundles that no longer exist


def bundles(lines):
    """section number -> bundle base id (first row's id // 16)"""
    out = {}
    current = None
    for line in lines:
        m = HEADER.match(line)
        if m:
            current = int(m.group(1))
            continue
        if current is not None:
            r = ROW.match(line)
            if r:
                out.setdefault(current, int(r.group(1)) // 16)
            elif line.startswith('['):
                current = None
    return out


def main():
    template = Path(sys.argv[1]).read_text(encoding='utf-8-sig').splitlines()
    new_by_base = {base: sec for sec, base in bundles(template).items()}
    for lang in sys.argv[2:]:
        slt_path = ROOT / 'translations' / lang / 'salamand.slt'
        origin_path = ROOT / 'translations' / lang / 'salamand.origin'
        raw = slt_path.read_bytes()
        bom = raw.startswith(b'\xef\xbb\xbf')
        text = raw.decode('utf-8-sig')
        nl = '\r\n' if '\r\n' in text else '\n'
        lines = text.split(nl)
        old = bundles(lines)
        mapping = {}
        for sec, base in old.items():
            mapping[sec] = new_by_base.get(base, GONE + sec)
        out = []
        for line in lines:
            m = HEADER.match(line)
            if m:
                line = '[STRINGTABLE %d]' % mapping.get(int(m.group(1)), GONE + int(m.group(1)))
            out.append(line)
        slt_path.write_bytes((b'\xef\xbb\xbf' if bom else b'') + nl.join(out).encode('utf-8'))

        origin = json.loads(origin_path.read_text(encoding='utf-8'))
        rekeyed = {}
        for k, v in origin.items():
            parts = k.split(':', 2)
            if parts[0] == 'STRINGTABLE':
                sec = int(parts[1])
                new = mapping.get(sec)
                if new is None or new >= GONE:
                    continue  # the bundle is gone
                k = 'STRINGTABLE:%d:%s' % (new, parts[2])
            rekeyed[k] = v
        origin_path.write_text(json.dumps(rekeyed, indent=0, sort_keys=True, ensure_ascii=False), encoding='utf-8')
        moved = sum(1 for s, n in mapping.items() if n != s and n < GONE)
        gone = sum(1 for n in mapping.values() if n >= GONE)
        print('%s: %d sections renumbered, %d bundles gone, origin %d -> %d keys'
              % (lang, moved, gone, len(origin), len(rekeyed)))


if __name__ == '__main__':
    main()
