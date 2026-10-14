"""Feature 189 negative control: the saltests cases of TestMultiSzToLine189 run through the
panel's old REG_MULTI_SZ loop (regedt fs2.cpp at 188, replicated). Every case the old loop gets
wrong is printed; the new rule (salmultisz.h, replicated) must get all right."""

MAX_DATASIZE = 200


def old_fs2(units):
    t = list(units)
    size = len(t)
    i = 0
    while i < min(size, MAX_DATASIZE):
        if t[i] == '\0':
            if i + 2 == len(units):
                size -= 1
                break
            t[i] = ' '
        i += 1
    return ''.join(t[:size]).split('\0')[0]  # what the preview shows: up to the first NUL


def new_rule(units):
    t = list(units)
    end = len(t)
    while end > 0 and t[end - 1] == '\0':
        end -= 1
    for i in range(end):
        if t[i] == '\0':
            t[i] = ' '
    n = end + 1 if end < len(t) else end
    return ''.join(t[:n]).split('\0')[0]


CASES = [('alpha\0beta\0\0', 'alpha beta'), ('alpha\0beta\0', 'alpha beta'),
         ('alpha\0beta', 'alpha beta'), ('zeta\0\0\0', 'zeta'), ('a\0\0b\0\0', 'a  b'),
         ('\0\0', ''), ('\0', ''), ('', '')]
bad_old = bad_new = 0
for data, want in CASES:
    o, n = old_fs2(data), new_rule(data)
    if o != want:
        bad_old += 1
        print('old wrong: %r -> %r (want %r)' % (data, o, want))
    if n != want:
        bad_new += 1
        print('NEW WRONG: %r -> %r (want %r)' % (data, n, want))
print('old loop wrong in %d of %d cases; new rule wrong in %d' % (bad_old, len(CASES), bad_new))
