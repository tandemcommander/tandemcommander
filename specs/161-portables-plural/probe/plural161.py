"""A port of salamdr4.cpp ExpandPluralString (one parameter given), to check the 161 patterns."""
import sys


def expand(fmt, pars):
    assert fmt.startswith('{!}')
    s = fmt[3:]
    out = []
    i = 0
    act = 0
    used = [False] * len(pars)
    while i < len(s):
        c = s[i]
        if c == '\\' and i + 1 < len(s) and s[i + 1] in '|\\:{}':
            out.append(s[i + 1]); i += 2; continue
        if c != '{':
            out.append(c); i += 1; continue
        i += 1
        j = i; n = 0
        while j < len(s) and s[j].isdigit():
            n = n * 10 + int(s[j]); j += 1
        if j < len(s) and s[j] == ':' and j > i:
            if not 1 <= n <= len(pars):
                return ''.join(out) + '<STOP: index %d out of range>' % n
            arg = pars[n - 1]; used[n - 1] = True; i = j + 1
        else:
            if act >= len(pars):
                return ''.join(out) + '<STOP: few parameters>'
            arg = pars[act]; used[act] = True; act += 1
        while i < len(s) and s[i] != '}':
            sub = []
            while i < len(s) and s[i] not in '}|':
                sub.append(s[i]); i += 1
            if i < len(s) and s[i] == '|':
                i += 1
            num = []
            while i < len(s) and s[i] not in '}|':
                num.append(s[i]); i += 1
            if i < len(s) and s[i] == '|':
                i += 1
            if not num or arg <= int(''.join(num)):
                out.append(''.join(sub))
                while i < len(s) and s[i] != '}':
                    i += 1
        if i < len(s) and s[i] == '}':
            i += 1
    warn = '' if all(used) else '  <TRACE: a parameter not used>'
    return ''.join(out) + warn


PATS = {
    'english-old': '{!}%d selected device{2:s|0||1|s}',
    'english': '{!}%d selected device{s|0||1|s}',
    'czech': '{!}%d vybran{ých zařízení|0|é zařízení|1|á zařízení|4|ých zařízení}',
    'slovak': '{!}%d vybran{ých zariadení|0|é zariadenie|1|é zariadenia|4|ých zariadení}',
    'german': '{!}%d ausgewählte{ Geräte|0|s Gerät|1| Geräte}',
    'french': '{!}%d appareil{s|0||1|s} sélectionné{1:s|0||1|s}',
    'dutch': '{!}%d geselecteerd{e apparaten|0| apparaat|1|e apparaten}',
    'hungarian': '{!}%d kiválasztott eszköz{|0||1|}',
    'romanian': '{!}%d dispozitiv{e|0||1|e} selectat{1:e|0||1|e}',
    'spanish': '{!}%d dispositivo{s|0||1|s} seleccionado{1:s|0||1|s}',
}
sys.stdout.reconfigure(encoding='utf-8')
for k, p in PATS.items():
    print('%-12s ' % k + ' | '.join((expand(p, [v]) % v) if '%d' in expand(p, [v]) else expand(p, [v]) for v in (0, 1, 2, 5, 21)))
