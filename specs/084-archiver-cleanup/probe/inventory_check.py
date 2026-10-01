"""Cross-check of specs/084-archiver-cleanup/inventory.md against the source.

Every extension the product offers as an archive - the default associations
(src/pack3.cpp CPackerFormatConfig::AddDefault) and the panel archivers of the
plug-ins that are "on" in plugins.cfg - must have a row in the inventory's
format table, and no extension the inventory marks "removed" may be offered.

Usage: python inventory_check.py   (from anywhere; exit code = problems found)
"""

import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))


def read(rel):
    with open(os.path.join(ROOT, rel), encoding='utf-8-sig', errors='replace') as f:
        return f.read()


def strip_comments(code):
    code = re.sub(r'/\*.*?\*/', '', code, flags=re.S)
    return re.sub(r'//[^\n]*', '', code)


def exts_of(text):
    return {e.strip().lower() for e in text.split(';') if e.strip()}


offered = {}  # extension -> where it comes from

# default associations: the "case 0" block of CPackerFormatConfig::AddDefault
pack3 = strip_comments(read('src/pack3.cpp'))
m = re.search(r'void CPackerFormatConfig::AddDefault\(int SalamVersion\)(.*?)\n}\n', pack3, re.S)
if not m:
    sys.exit('AddDefault not found')
for ext in re.findall(r'SetFormat\(index,\s*"([^"]+)"', m.group(1)):
    for e in exts_of(ext):
        offered.setdefault(e, 'default association')

# plug-ins that are on
enabled = set()
for line in read('plugins.cfg').splitlines():
    line = line.strip()
    if line and not line.startswith('#') and '=' in line:
        name, state = line.split('=', 1)
        if state.strip() == 'on':
            enabled.add(name.strip())
for plugin in sorted(enabled):
    d = os.path.join(ROOT, 'src', 'plugins', plugin)
    if not os.path.isdir(d):
        continue
    for fn in os.listdir(d):
        if not fn.endswith('.cpp'):
            continue
        code = strip_comments(read(os.path.join('src', 'plugins', plugin, fn)))
        for ext in re.findall(r'AddPanelArchiver\("([^"]+)"', code):
            for e in exts_of(ext):
                offered.setdefault(e, 'plug-in ' + plugin)

# the inventory's format table (section 2): first column = extensions, "Status" column
inv = read('specs/084-archiver-cleanup/inventory.md')
sec = inv.split('## 2. Formats', 1)[1].split('\n## ', 1)[0]
documented = {}
for row in sec.splitlines():
    if not row.startswith('|') or row.startswith('|---') or row.startswith('| Extension'):
        continue
    cells = [c.strip() for c in row.strip('|').split('|')]
    status = cells[5].lower() if len(cells) > 5 else ''  # Extension | 0.1.8 | clean | +7-Zip | +WinRAR | Status | Reason
    for e in re.split(r'[,;]', re.sub(r'\(.*?\)', '', cells[0])):
        e = e.strip().lower()
        if e:
            documented[e] = status

problems = 0
for e, src in sorted(offered.items()):
    if e not in documented:
        print('OFFERED BUT NOT DOCUMENTED: %s (%s)' % (e, src))
        problems += 1
    elif 'removed' in documented[e]:
        print('DOCUMENTED AS REMOVED BUT OFFERED: %s (%s)' % (e, src))
        problems += 1
for e, status in sorted(documented.items()):
    if 'removed' not in status and e not in offered and e not in ('rar', 'r##'):
        # rar/r## are offered by the 7zip plug-in only once stage S7 is in
        print('DOCUMENTED AS HANDLED BUT NOT OFFERED: %s' % e)
        problems += 1
print('offered: %d extensions, documented: %d, problems: %d' % (len(offered), len(documented), problems))
sys.exit(problems)
