# -*- coding: utf-8 -*-
r"""MKEXT.PY - lengthens a level of XVOLUTION : an EXTENSION BOARD (made here,
   traces routed between its chips) is added after the motherboard, joined to
   it by a flat cable, and ATTACK ZONES (W lines) are placed in the level.
     python MKEXT.PY BASE.MAP OUT.MAP level [seed]
   BASE.MAP : the motherboard map (cartes_base\LEVELn.MAP, made by PCB2MAP.PY)
   level    : 1 = 800 XL + 1050 drive, 2 = 520 ST + SF314 drive,
              3 = STE + RAM board, 4 = Falcon 030 + CT60 board
   Row 0 = END of the level (top) : the extension is put above the board.
   W <row> [waves] : attack zone, the ground stops at this row and waves of
   enemies come (ZONES.S).
"""
import sys, random, heapq

COMP = {'P': (4, 4), 'M': (2, 4), 'R': (2, 1), 'K': (1, 1), 'X': (2, 1), 'H': (4, 1),
        'Q': (4, 4), 'F': (4, 4), 'D': (2, 5), 'O': (2, 2), 'A': (1, 4), 'U': (1, 1),
        'Z': (2, 2), 'G': (6, 10), 'N': (3, 1), 'V': (2, 5)}
# connections (N, E, S, W bits) -> tile character (OUTILS\MKTILES.PY)
N, E, S, W = 1, 2, 4, 8
TILE = {N | S: '|', E | W: '-', N | E | S | W: '+', E | S: 'r', W | S: '7', N | E: 'L',
        N | W: 'J', E | W | S: 'T', E | W | N: 'W', N | S | E: 'E', N | S | W: '3',
        N: 'o', S: 'o', E: 'o', W: 'o'}

# the extension of each level : name, rows, theme style, chips (type, name),
#   boss (type, name), small parts
EXT = {
    1: ('ATARI 1050 DISK DRIVE', 40, 'classic',
        [('P', 'RIOT_6532'), ('P', 'FDC_2793'), ('M', '6810_RAM'), ('D', 'DOS_ROM'),
         ('D', '74LS14'), ('D', '74LS74'), ('X', None), ('H', None)],
        ('P', '*6507'), 'RRRRKKKKXRRK'),
    2: ('ATARI SF314 DRIVE', 40, 'classic',
        [('P', 'READ_AMP'), ('P', 'MOTOR_DRV'), ('D', 'STEP_DRV'), ('D', '74HC04'),
         ('D', '74HC14'), ('H', None), ('X', None)],
        ('Q', '*FDD_CTRL'), 'RRRRKKKKRRKZ'),
    3: ('STE 4 MB RAM BOARD', 40, 'classic',
        [('M', 'SIMM_1MB'), ('M', 'SIMM_1MB'), ('M', 'SIMM_1MB'), ('M', 'SIMM_1MB'),
         ('D', '74F245'), ('D', '74F245'), ('O', None), ('H', None)],
        ('Q', '*DRAM_CTRL'), 'RRKKKKURRKZ'),
    4: ('CT60 ACCELERATOR', 40, 'dense',
        [('Q', 'CPLD'), ('M', 'SDRAM'), ('M', 'SDRAM'), ('M', 'SDRAM'), ('M', 'SDRAM'),
         ('D', 'FLASH'), ('O', 'PLL'), ('Q', 'ETHERNAT')],
        ('F', '*68060'), 'DOOAAUUUZRRKKNXU'),
}

def load(path):
    head, rows, comps, other = [], [], [], []
    cols = nrows = None
    for l in open(path, encoding='latin-1'):
        l = l.rstrip('\r\n')
        t = l.split()
        if nrows is not None and len(rows) < nrows:
            if l.strip() and not l.startswith(';'):
                rows.append(l)
            continue
        if not t or l.startswith(';'):
            head.append(l)
        elif t[0] == 'SIZE':
            cols, nrows = int(t[1]), int(t[2])
        elif t[0] in ('SEU', 'THEME'):
            head.append(l)
        elif t[0] == 'C':
            comps.append((t[1], int(t[2]), int(t[3]), t[4] if len(t) > 4 else ''))
        elif t[0] == 'END':
            pass
        else:
            other.append(l)
    rows = [r.ljust(cols, '.')[:cols] for r in rows]
    return head, cols, rows, comps

def make_ext(cols, rows, spec, rnd):
    name, _, style, chips, boss, small = spec
    con = [[0] * cols for _ in range(rows)]        # trace connections
    g = [['.'] * cols for _ in range(rows)]        # fixed tiles
    used = [[False] * cols for _ in range(rows)]   # under a component
    comps = []
    def free(c, r, w, h, m):
        if c < 1 or r < 3 or c + w > cols - 1 or r + h > rows - 2:
            return False
        for y in range(r - m, r + h + m):
            for x in range(c - m, c + w + m):
                if 0 <= y < rows and 0 <= x < cols and (used[y][x] or g[y][x] != '.'):
                    return False
        return True
    def put(t, c, r, nm, m=1):
        w, h = COMP[t]
        if not free(c, r, w, h, m):
            return False
        for y in range(r, r + h):
            for x in range(c, c + w):
                used[y][x] = True
        comps.append((t, c, r, nm or ''))
        return True
    for r in range(0, 2):                           # copper plane at the end
        for c in range(cols):
            g[r][c] = '#'
    for c in range(cols):                           # its edge connector (start)
        g[rows - 1][c] = '='
    # the boss chip in the middle, silkscreen around it
    bt, bn = boss
    bw, bh = COMP[bt]
    bc, br = cols // 2 - bw // 2, rows // 2 - bh // 2
    put(bt, bc, br, bn, 0)
    for x in range(bc - 1, bc + bw + 1):
        for y in (br - 1, br + bh):
            g[y][x] = 's'
    # named chips, then small parts
    for t, nm in chips:
        w, h = COMP[t]
        for _ in range(400):
            if put(t, rnd.randint(1, cols - w - 1), rnd.randint(3, rows - h - 3), nm, 1):
                break
    for _ in range(rows * cols // 22):
        t = rnd.choice(small)
        w, h = COMP[t]
        put(t, rnd.randint(1, cols - w - 1), rnd.randint(3, rows - h - 3), None, 1)
    # pins : cells beside the components (left / right sides, ends of small parts)
    pins = []
    for t, c, r, nm in comps:
        w, h = COMP[t]
        side = []
        for y in range(r, r + h):
            side.append((c - 1, y, E))              # (bit towards the part)
            side.append((c + w, y, W))
        if w >= 3 and h <= 2:
            for x in range(c, c + w):
                side.append((x, r - 1, S))
                side.append((x, r + h, N))
        rnd.shuffle(side)
        k = 2 if t in "RKUXNOZ" else (10 if t in "PQFG" else 6)
        pins += [(x, y, b) for x, y, b in side[:k]
                 if 0 <= x < cols and 3 <= y < rows - 2 and not used[y][x] and g[y][x] == '.']
    # routing : each pin to the nearest trace or to the connector, turns
    #   cost more (straight traces like the real boards)
    def route(sx, sy, sb):
        if con[sy][sx]:
            return
        dist = {}
        pq = [(0, sx, sy, -1, None)]
        prev = {}
        goal = None
        while pq:
            d, x, y, dr, pr = heapq.heappop(pq)
            if (x, y, dr) in dist:
                continue
            dist[(x, y, dr)] = d
            prev[(x, y, dr)] = pr
            if (x, y) != (sx, sy) and (con[y][x] or y == rows - 2):
                goal = (x, y, dr)
                break
            for nd, (dx, dy) in enumerate(((0, -1), (1, 0), (0, 1), (-1, 0))):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < cols and 2 <= ny < rows - 1):
                    continue
                if used[ny][nx] or g[ny][nx] != '.':
                    continue
                if con[ny][nx] and con[ny][nx] & 15 == 15:
                    continue
                c2 = d + 1 + (3 if dr not in (-1, nd) else 0) + (2 if con[ny][nx] else 0)
                if c2 > 120:
                    continue
                heapq.heappush(pq, (c2, nx, ny, nd, (x, y, dr)))
        if not goal:
            return
        path = []
        k = goal
        while k:
            path.append((k[0], k[1]))
            k = prev[k]
        path.reverse()
        con[sy][sx] |= sb
        for (x0, y0), (x1, y1) in zip(path, path[1:]):
            b0 = N if y1 < y0 else S if y1 > y0 else E if x1 > x0 else W
            b1 = {N: S, S: N, E: W, W: E}[b0]
            con[y0][x0] |= b0
            con[y1][x1] |= b1
        gx, gy = path[-1]
        if gy == rows - 2 and not (con[gy][gx] & S):
            con[gy][gx] |= S                        # into the connector
    for x, y, b in pins:
        route(x, y, b)
    for y in range(rows):
        for x in range(cols):
            if con[y][x] and g[y][x] == '.' and not used[y][x]:
                g[y][x] = TILE.get(con[y][x] & 15, '+')
    for _ in range(rows * cols // 25):              # vias, silkscreen
        y, x = rnd.randint(3, rows - 3), rnd.randint(0, cols - 1)
        if g[y][x] == '.' and not used[y][x]:
            g[y][x] = rnd.choice('ooOt' if style == 'classic' else 'oooi')
    return [''.join(r) for r in g], comps

def cable(cols, n, rnd):
    """flat cable between the two boards : connector, fine lines, connector"""
    w = min(cols - 4, 16)
    c0 = (cols - w) // 2
    rows = []
    for i in range(n):
        if i in (0, n - 1):
            r = '.' * c0 + '=' * w + '.' * (cols - c0 - w)
        else:
            r = '.' * c0 + 'v' * w + '.' * (cols - c0 - w)
        rows.append(r)
    return rows

def main():
    base, out, lvl = sys.argv[1], sys.argv[2], int(sys.argv[3])
    seed = int(sys.argv[4]) if len(sys.argv) > 4 else 1992 + lvl
    rnd = random.Random(seed)
    head, cols, rows, comps = load(base)
    spec = EXT[lvl]
    erows, ecomps = make_ext(cols, spec[1], spec, rnd)
    crows = cable(cols, 6, rnd)
    top = len(erows) + len(crows)                   # base rows shifted by this
    allrows = erows + crows + rows
    allcomps = ecomps + [(t, c, r + top, nm) for t, c, r, nm in comps]
    # attack zones : in the middle of the extension (not on its boss), and
    #   at 1/3 and 2/3 of the motherboard, away from its bosses
    boss_rows = [r for t, c, r, nm in allcomps if nm.startswith('*')]
    def ok(r):
        return all(abs(r - b) > 10 for b in boss_rows)
    zones = []
    for want in (top + len(rows) * 2 // 3, top + len(rows) // 3, len(erows) // 4,
                 len(erows) * 3 // 4):
        for d in range(0, 20):
            for r in (want - d, want + d):
                if 6 < r < len(allrows) - 15 and ok(r) and all(abs(r - z) > 12 for z in zones):
                    zones.append(r)
                    break
            else:
                continue
            break
        if len(zones) >= 3:
            break
    with open(out, 'w', newline='\r\n', encoding='latin-1') as f:
        for l in head:
            if l.startswith('SEU') or l.startswith('THEME'):
                continue
            f.write(l + '\n')
        f.write('; + extension board %s (%d rows, OUTILS\\MKEXT.PY, made up) and a\n'
                ';   flat cable : rows 0..%d ; the motherboard from row %d\n'
                % (spec[0], len(erows), top - 1, top))
        for l in head:
            if l.startswith('SEU') or l.startswith('THEME'):
                f.write(l + '\n')
        f.write('SIZE %d %d\n' % (cols, len(allrows)))
        for r in allrows:
            f.write(r + '\n')
        for t, c, r, nm in sorted(allcomps, key=lambda k: k[2]):
            f.write('C %s %d %d%s\n' % (t, c, r, (' ' + nm) if nm else ''))
        for z in sorted(zones):
            f.write('W %d\n' % z)
        f.write('END\n')
    print(out, len(allrows), 'rows,', len(allcomps), 'components, zones', sorted(zones))

if __name__ == '__main__':
    main()
