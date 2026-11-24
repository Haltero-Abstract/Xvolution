# -*- coding: utf-8 -*-
"""CHECKMAP.PY - checks SHOTEMUP .MAP files : python3 CHECKMAP.PY F.MAP ..."""
import sys
CHARS = '.-|+r7LJTWE3oOaip=#sthvk'
SIZES = dict(P=(4,4),M=(2,4),R=(2,1),K=(1,1),X=(2,1),H=(4,1),Q=(4,4),F=(4,4),D=(2,5),
             O=(2,2),A=(1,4),U=(1,1),Z=(2,2),G=(6,10),N=(3,1),V=(2,5))
# connection sides of trace tiles : U D L R
SIDES = {'-':'LR','|':'UD','+':'UDLR','r':'RD','7':'LD','L':'UR','J':'UL','T':'LRD','W':'LRU',
         'E':'UDR','3':'UDL','a':'LR','i':'UD','h':'LR','v':'UD'}
def check(p):
    err = []
    raw = open(p, 'rb').read()
    if b'\n' in raw.replace(b'\r\n', b''): err.append('LF without CR')
    L = [l for l in raw.decode('ascii').split('\r\n')]
    body = [l for l in L if l and not l.startswith(';')]
    if body[0] != 'SEU 1': err.append('no SEU 1')
    th = body[1].split()
    if th[0] != 'THEME' or th[1] not in ('a8','st','ste','falcon'): err.append('THEME')
    _, cols, rows = body[2].split(); cols, rows = int(cols), int(rows)
    if cols > 40 or rows > 1500: err.append('SIZE too big')
    grid = body[3:3 + rows]
    for r, l in enumerate(grid):
        if len(l) != cols: err.append('row %d len %d' % (r, len(l)))
        bad = set(l) - set(CHARS)
        if bad: err.append('row %d chars %r' % (r, bad))
    occ = {}
    n = 0
    from collections import Counter
    cnt = Counter()
    for l in body[3 + rows:]:
        if l == 'END': break
        fl = l.split()
        if len(fl) == 5 and len(fl[4]) > 11: err.append('name too long ' + l)
        t, k, c, r = fl[:4]; c, r = int(c), int(r)    # (5th field = name printed on it)
        if t != 'C' or k not in SIZES: err.append('bad line ' + l); continue
        w, h = SIZES[k]; n += 1; cnt[k] += 1
        if c < 0 or r < 0 or c + w > cols or r + h > rows: err.append('outside ' + l)
        for y in range(r, r + h):
            for x in range(c, c + w):
                if (x, y) in occ: err.append('overlap %s / %s' % (l, occ[(x, y)]))
                occ[(x, y)] = l
    if body[-1] != 'END': err.append('no END')
    if n > 800: err.append('too many components')
    # trace joins
    opp = {'U':(0,-1,'D'),'D':(0,1,'U'),'L':(-1,0,'R'),'R':(1,0,'L')}
    mism = 0
    for r in range(rows):
        for c in range(cols):
            for s in SIDES.get(grid[r][c], ''):
                dx, dy, o = opp[s]; x, y = c + dx, r + dy
                if 0 <= x < cols and 0 <= y < rows:
                    t = grid[y][x]
                    if o not in SIDES.get(t, '') and t not in 'opO=':
                        mism += 1
    print('%s : %dx%d, %d comps %s, trace mismatches %d, %s' % (p, cols, rows, n, dict(cnt), mism,
          'OK' if not err else 'ERRORS ' + '; '.join(err[:10])))
for p in sys.argv[1:]: check(p)
