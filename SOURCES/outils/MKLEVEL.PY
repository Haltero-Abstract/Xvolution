# -*- coding: utf-8 -*-
r"""MKLEVEL.PY - makes a first printed-circuit level for SHOTEMUP
(LEVEL1.MAP) : copper buses, traces, vias, and components (scenery).
   python MKLEVEL.PY [out.MAP] [rows] [seed]

.MAP format (text, also written by OUTILS\EDITEUR.HTML) :
   ; comment
   SEU 1                     magic + version
   SIZE 16 <rows>            columns (always 16) and rows
   <rows lines of 16 tile characters>   row 0 = END of the level (top),
                                        the last row = START (bottom)
   C <type> <col> <row>      component, top-left tile (col 0..15)
   END
Component types (size in tiles, columns x rows) :
   P processor 4x4   M memory 2x4   R resistor 2x1   K capacitor 1x1
   X quartz 2x1      H header 4x1   Q QFP 4x4 (COMBEL, VIDEL)
   F 68030 heatsink + fan 4x4       D DIP 2x5      O SOIC 2x2
   A red resistor array 1x4         U blue SIP 1x1 Z electrolytic 2x2
   G RAM board 6x10  N ferrite 3x1  V D-sub connector 2x5
   python MKLEVEL.PY out.MAP rows seed falcon   : dense Falcon 030 style board
"""
import sys, random

COMP = {'P': (4, 4), 'M': (2, 4), 'R': (2, 1), 'K': (1, 1), 'X': (2, 1), 'H': (4, 1),
        'Q': (4, 4), 'F': (4, 4), 'D': (2, 5), 'O': (2, 2), 'A': (1, 4), 'U': (1, 1),
        'Z': (2, 2), 'G': (6, 10), 'N': (3, 1), 'V': (2, 5)}

def make(rows, seed):
    rnd = random.Random(seed)
    g = [['.'] * 16 for _ in range(rows)]
    used = [[False] * 16 for _ in range(rows)]
    comps = []

    def free(c, r, w, h, m=1):
        for y in range(r - m, r + h + m):
            for x in range(c - m, c + w + m):
                if 0 <= y < rows and 0 <= x < 16 and used[y][x]:
                    return False
        return 0 <= c and c + w <= 16 and 0 <= r and r + h <= rows

    def put(t, c, r):
        w, h = COMP[t]
        for y in range(r, r + h):
            for x in range(c, c + w):
                used[y][x] = True
        comps.append((t, c, r))

    # gold fingers at the start (bottom) and copper planes at the end (top)
    for r in range(rows - 3, rows):
        for c in range(1, 15):
            g[r][c] = '='
    for r in range(0, 3):
        for c in range(16):
            g[r][c] = '#'
    # vertical buses : 2 traces that change column now and then
    for bus in (3, 12):
        c = bus
        r = rows - 4
        while r > 3:
            seg = rnd.randint(10, 30)
            for y in range(max(4, r - seg), r + 1):
                g[y][c] = '|'
            r -= seg
            if r <= 4:
                break
            nc = max(1, min(14, c + rnd.choice((-2, -1, 1, 2))))
            if nc == c:
                continue
            g[r][c] = '7' if nc < c else 'r'          # (from below, turns)
            g[r][nc] = 'L' if nc < c else 'J'
            for x in range(min(c, nc) + 1, max(c, nc)):
                g[r][x] = '-'
            c = nc
            r -= 1
    # components, one group every 8 to 14 rows
    r = rows - 10
    while r > 6:
        t = rnd.choice('PPMMRRRKKXH')
        w, h = COMP[t]
        for _ in range(20):
            c = rnd.randint(0, 16 - w)
            rr = r - h + 1
            if free(c, rr, w, h) and all(g[y][x] == '.' for y in range(rr, rr + h)
                                         for x in range(c, c + w)):
                put(t, c, rr)
                # silkscreen around big chips, pads under small parts
                if t in 'PM':
                    for x in range(c - 1, c + w + 1):
                        for y in (rr - 1, rr + h):
                            if 0 <= x < 16 and 0 <= y < rows and g[y][x] == '.':
                                g[y][x] = 's'
                if t in 'RX':
                    g[rr][c] = 'p'; g[rr][c + w - 1] = 'p'
                # a trace from the part to the side, ending with a via
                y = rr + h // 2
                x = c + w
                n = 0
                while x < 16 and g[y][x] in '.s' and n < rnd.randint(2, 5):
                    g[y][x] = '-'; x += 1; n += 1
                if n:
                    g[y][x - 1] = 'a'
                break
        # a few vias and capacitors around
        for _ in range(rnd.randint(1, 3)):
            vy = rnd.randint(max(4, r - 8), r)
            vx = rnd.randint(0, 15)
            if g[vy][vx] == '.' and not used[vy][vx]:
                g[vy][vx] = rnd.choice('ooOt')
        r -= rnd.randint(8, 14)
    return g, comps

def make_falcon(rows, seed):
    rnd = random.Random(seed)
    g = [['.'] * 16 for _ in range(rows)]
    used = [[False] * 16 for _ in range(rows)]
    comps = []
    def free(c, r, w, h, m=0):
        if c < 0 or r < 0 or c + w > 16 or r + h > rows:
            return False
        for y in range(r - m, r + h + m):
            for x in range(c - m, c + w + m):
                if 0 <= y < rows and 0 <= x < 16 and (used[y][x] or g[y][x] != '.'):
                    return False
        return True
    def put(t, c, r, m=0):
        w, h = COMP[t]
        if not free(c, r, w, h, m):
            return False
        for y in range(r, r + h):
            for x in range(c, c + w):
                used[y][x] = True
        comps.append((t, c, r))
        return True
    for r in range(rows - 2, rows):                 # cartridge port fingers
        for c in range(2, 14):
            g[r][c] = '='
    for r in range(0, 2):
        for c in range(16):
            g[r][c] = '#'
    # big parts : RAM board + 68030 under its fan, QFP chips, D-sub on the left
    rm = int(rows * 0.45)
    put('G', 9, rm); put('F', 10, rm - 6); put('X', 10, rm - 8); put('X', 13, rm - 8)
    for q in range(4, rows - 20, 55):
        r = q + rnd.randint(0, 20)
        for _ in range(10):
            if put('Q', rnd.randint(2, 10), r, 1):
                break
    for r in range(8, rows - 12, 30):
        put('V', 0, r + rnd.randint(0, 8))
    # the rest, dense
    small = 'DDOOOAAUUUZRRKKNXRUUAO'
    for r in range(rows - 4, 3, -1):
        for _ in range(2 if r % 2 else 1):
            t = rnd.choice(small)
            w, h = COMP[t]
            put(t, rnd.randint(0, 16 - w), r - h + 1)
    # buses of fine traces in the free space, ended by rows of vias
    for _ in range(rows // 2):
        y = rnd.randint(3, rows - 4); x = rnd.randint(0, 12)
        n = 0
        while x + n < 16 and g[y][x + n] == '.' and not used[y][x + n]:
            n += 1
        if n >= 3:
            for i in range(n):
                g[y][x + i] = 'h'
    for _ in range(rows // 2):
        x = rnd.randint(1, 14); y = rnd.randint(4, rows - 6)
        n = 0
        while y + n < rows - 2 and g[y + n][x] == '.' and not used[y + n][x]:
            n += 1
        if n >= 3:
            g[y][x] = 'k'
            for i in range(1, n - 1):
                g[y + i][x] = 'v'
            g[y + n - 1][x] = 'k'
    for _ in range(rows // 3):                      # vias, silkscreen
        y = rnd.randint(3, rows - 4); x = rnd.randint(0, 15)
        if g[y][x] == '.' and not used[y][x]:
            g[y][x] = rnd.choice('ooot')
    return g, comps

def write(path, g, comps):
    with open(path, 'w', newline='\r\n') as f:
        f.write('; SHOTEMUP level - printed circuit board (OUTILS\\EDITEUR.HTML)\n')
        f.write('; row 0 = end of the level (top), last row = start (bottom)\n')
        f.write('SEU 1\nSIZE 16 %d\n' % len(g))
        for row in g:
            f.write(''.join(row) + '\n')
        for t, c, r in sorted(comps, key=lambda k: k[2]):
            f.write('C %s %d %d\n' % (t, c, r))
        f.write('END\n')

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'LEVEL1.MAP'
    rows = int(sys.argv[2]) if len(sys.argv) > 2 else 300
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 1990
    if len(sys.argv) > 4 and sys.argv[4] == 'falcon':
        g, comps = make_falcon(rows, seed)
    else:
        g, comps = make(rows, seed)
    write(out, g, comps)
    print(out, rows, 'rows,', len(comps), 'components')
