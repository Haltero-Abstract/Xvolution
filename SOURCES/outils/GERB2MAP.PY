# -*- coding: utf-8 -*-
"""GERB2MAP.PY - level map from KiCad Gerber + Excellon files only (no pick & place).

  python3 GERB2MAP.PY <theme> <gerber_dir> <out.MAP> [PCB2MAP options] [--names F]

--names F : names printed on the chips, one per line "x_mm y_mm NAME" (board
            coordinates, Gerber Y negated ; the nearest component gets it).

The components are found from the plated holes (Excellon *-PTH.drl) :
  2 parallel rows of n holes at 2.54 mm, 7.62 / 10.16 / 15.24 mm apart = DIP-2n
  one row of 3+ holes = header ; 2 holes 7.6 .. 12.7 mm apart = resistor,
  2.5 .. 5.1 mm = capacitor ; big holes (>= 1.3 mm) = connectors / mounting.
Tracks = F_Cu (*.gtl), outline = Edge_Cuts (*.gm1), vias = holes <= 0.5 mm.
Uses PCB2MAP.PY (same folder) for the map itself.
"""
import sys, os, re, glob, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util, importlib.machinery
_f = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'PCB2MAP.PY')
_l = importlib.machinery.SourceFileLoader('PCB2MAP', _f)
_s = importlib.util.spec_from_loader('PCB2MAP', _l)
P = importlib.util.module_from_spec(_s); _l.exec_module(P)

P2 = 2.54
TOL = 0.2

def read_drill(f):
    tools, t, pts = {}, None, []
    inch = True; div = 10000.0
    for line in open(f):
        line = line.strip()
        if line.startswith('METRIC'):
            inch = False; div = 1000.0
        m = re.match(r'T(\d+)C([\d.]+)', line)
        if m:
            tools[m.group(1)] = float(m.group(2)) * (25.4 if inch else 1); continue
        m = re.match(r'T(\d+)$', line)
        if m:
            t = m.group(1); continue
        m = re.match(r'X(-?[\d.]+)Y(-?[\d.]+)', line)
        if m and t:
            def v(s):
                return float(s) * (25.4 if inch else 1) if '.' in s else int(s) / div * (25.4 if inch else 1)
            pts.append((v(m.group(1)), -v(m.group(2)), tools[t]))
    return pts

def load(d):
    gtl = glob.glob(os.path.join(d, '*.gtl')) + glob.glob(os.path.join(d, '*.GTL'))
    b = P.Board()
    text = open(gtl[0], errors='replace').read()
    fs = re.search(r'%FSLAX(\d)(\d)Y', text)
    div = 10 ** int(fs.group(2)) if fs else 1e4
    unit = 25.4 if '%MOIN' in text else 1.0
    aper = {}
    for m in re.finditer(r'%ADD(\d+)([A-Za-z_0-9]+),([\d.]+)', text):
        aper[int(m.group(1))] = (m.group(2), float(m.group(3)) * unit)
    x = y = 0.0; cur = None; region = False; poly = []
    for cmd in text.replace('\n', '').split('*'):
        if cmd.startswith('%') or cmd.startswith('G04'):
            continue
        if 'G36' in cmd:
            region = True; poly = []; continue
        if 'G37' in cmd:
            region = False
            if len(poly) > 2: b.zones.append(poly)
            continue
        m = re.match(r'(?:G0?[123])?D(\d+)$', cmd)
        if m and int(m.group(1)) >= 10:
            cur = int(m.group(1)); continue
        m = re.match(r'(?:G0?[123])?(?:X(-?\d+))?(?:Y(-?\d+))?(?:I-?\d+)?(?:J-?\d+)?D0?([123])$', cmd)
        if not m:
            continue
        nx = int(m.group(1)) / div * unit if m.group(1) else x
        ny = int(m.group(2)) / div * unit if m.group(2) else y
        op = m.group(3)
        if region:
            if op == '2' and len(poly) > 2:
                b.zones.append(poly); poly = []
            poly.append((nx, -ny))
        elif op == '1' and cur in aper and aper[cur][0] == 'C':
            b.segs.append((x, -y, nx, -ny, aper[cur][1]))
        x, y = nx, ny
    # outline
    gm = glob.glob(os.path.join(d, '*.gm1')) + glob.glob(os.path.join(d, '*.GM1'))
    src = open(gm[0]).read()
    xs = [int(v) / div * unit for v in re.findall(r'X(-?\d+)', src)]
    ys = [-int(v) / div * unit for v in re.findall(r'Y(-?\d+)', src)]
    b.bbox = (min(xs), min(ys), max(xs), max(ys))
    # holes
    holes = []
    for f in glob.glob(os.path.join(d, '*PTH.drl')) + glob.glob(os.path.join(d, '*-PTH.DRL')):
        holes += read_drill(f)
    for f in glob.glob(os.path.join(d, '*NPTH.drl')):
        for hx, hy, dia in read_drill(f):
            if dia >= 2.5: b.holes.append((hx, hy))
    pins = [(hx, hy) for hx, hy, dia in holes if 0.6 <= dia < 1.3]
    big = [(hx, hy, dia) for hx, hy, dia in holes if dia >= 1.3]
    for hx, hy, dia in holes:
        if dia < 0.6: b.vias.append((hx, hy))
    b.comps = find_comps(pins, big)
    return b

def find_comps(pins, big):
    key = lambda p: (round(p[0] / 0.05), round(p[1] / 0.05))
    used = set()
    def near(x, y):
        for i, p in enumerate(pins):
            if abs(p[0] - x) < TOL and abs(p[1] - y) < TOL:
                return i
        return -1
    # grid index for speed
    cell = {}
    for i, p in enumerate(pins):
        cell.setdefault((int(p[0] // 3), int(p[1] // 3)), []).append(i)
    def find(x, y):
        for cx in (int(x // 3) - 1, int(x // 3), int(x // 3) + 1):
            for cy in (int(y // 3) - 1, int(y // 3), int(y // 3) + 1):
                for i in cell.get((cx, cy), ()):
                    p = pins[i]
                    if abs(p[0] - x) < TOL and abs(p[1] - y) < TOL:
                        return i
        return -1
    # runs (vertical and horizontal) of pins at 2.54 mm
    runs = []
    for dx, dy in ((0, P2), (P2, 0)):
        for i, p in enumerate(pins):
            if find(p[0] - dx, p[1] - dy) >= 0:
                continue                       # not the start of a run
            run = [i]; x, y = p
            while True:
                j = find(x + dx, y + dy)
                if j < 0: break
                run.append(j); x, y = pins[j]
            if len(run) >= 3:
                runs.append(((dx, dy), run))
    comps = []
    runs.sort(key=lambda r: -len(r[1]))
    taken = set()
    # DIPs : pairs of parallel runs
    for a in range(len(runs)):
        (d1, r1) = runs[a]
        if any(i in taken for i in r1): continue
        best = None
        for bb in range(len(runs)):
            if bb == a: continue
            (d2, r2) = runs[bb]
            if d2 != d1 or len(r2) != len(r1) or any(i in taken for i in r2): continue
            p, q = pins[r1[0]], pins[r2[0]]
            if d1 == (0, P2):                  # vertical rows : offset in x
                off, al = abs(q[0] - p[0]), abs(q[1] - p[1])
            else:
                off, al = abs(q[1] - p[1]), abs(q[0] - p[0])
            if al < TOL and any(abs(off - s) < 0.3 for s in (7.62, 10.16, 15.24)):
                if best is None or off < best[0]: best = (off, bb)
        if best:
            r2 = runs[best[1]][1]
            pts = [pins[i] for i in r1 + r2]
            taken.update(r1 + r2)
            n = len(pts)
            comps.append(mk('dip-%d' % n, pts, 'U'))
    # single rows = headers
    for d, r in runs:
        if any(i in taken for i in r): continue
        if len(r) >= 4:
            taken.update(r); comps.append(mk('header', [pins[i] for i in r], 'J'))
    # 2-pin parts
    free = [i for i in range(len(pins)) if i not in taken]
    for i in free:
        if i in taken: continue
        p = pins[i]; bestj, bd = -1, 99
        for j in free:
            if j == i or j in taken: continue
            q = pins[j]
            dx, dy = abs(q[0] - p[0]), abs(q[1] - p[1])
            if min(dx, dy) > 0.3: continue      # axis aligned only
            dd = max(dx, dy)
            if 2.3 < dd < 13 and dd < bd: bestj, bd = j, dd
        if bestj >= 0:
            taken.update((i, bestj)); q = pins[bestj]
            comps.append(mk('resistor' if bd > 7 else 'capacitor', [p, q], 'R' if bd > 7 else 'C'))
    # big holes : clusters = connectors
    left = list(big); groups = []
    while left:
        g = [left.pop()]; ch = True
        while ch:
            ch = False
            for h in left[:]:
                if any(math.hypot(h[0] - k[0], h[1] - k[1]) < 9 for k in g):
                    g.append(h); left.remove(h); ch = True
        groups.append(g)
    for g in groups:
        if len(g) >= 3:
            comps.append(mk('din', [(h[0], h[1]) for h in g], 'J'))
    return comps

def mk(name, pts, ref):
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    pad = 1.3
    w = max(xs) - min(xs) + 2 * pad; h = max(ys) - min(ys) + 2 * pad
    if name.startswith('dip'):                 # body between the rows
        pass
    mk.n = getattr(mk, 'n', 0) + 1
    return dict(ref='%s%d' % (ref, mk.n), name=name, value='', layer='F.Cu', x=(min(xs) + max(xs)) / 2,
                y=(min(ys) + max(ys)) / 2, w=w, h=h, pads=list(pts))

def main():
    a = sys.argv[1:]; opt = {}; pos = []; i = 0
    while i < len(a):
        if a[i].startswith('--'): opt[a[i][2:]] = a[i + 1]; i += 2
        else: pos.append(a[i]); i += 1
    theme, src, out = pos
    b = load(src)
    if 'names' in opt:                         # "x_mm y_mm NAME" : nearest component
        for line in open(opt['names']):
            p = line.split('#')[0].split()
            if len(p) < 3: continue
            x, y = float(p[0]), float(p[1])
            c = min(b.comps, key=lambda c: (c['x'] - x) ** 2 + (c['y'] - y) ** 2)
            c['label'] = p[2]
    from collections import Counter
    print('found', dict(Counter(c['name'] for c in b.comps)), len(b.segs), 'segs', len(b.vias), 'vias',
          'board %.0f x %.0f mm' % (b.bbox[2] - b.bbox[0], b.bbox[3] - b.bbox[1]))
    scale = float(opt.get('scale', 4.5)); maxcols = int(opt.get('cols', 40))
    g0 = P.Grid(b, scale, maxcols)
    maxcomp = int(opt.get('max', int(1.6 * g0.rows)))
    g, tile, placed, dropped = P.build(b, P.classify_kicad, scale, maxcols, min(maxcomp, 800))
    names = {c['ref']: P.chip_name(c, c['kind']) for c in b.comps if c.get('kind')}
    P.write_map(out, theme, g, tile, placed, 'Gerber files of ' + os.path.basename(os.path.dirname(os.path.abspath(src))), dropped, names)
    print('%s : %d x %d, %d components %s, dropped %s'
          % (out, g.cols, g.rows, len(placed), dict(Counter(p[0] for p in placed)), dropped))
    if 'png' in opt:
        P.preview(out, opt['tiles'], opt['png'])

if __name__ == '__main__':
    main()
