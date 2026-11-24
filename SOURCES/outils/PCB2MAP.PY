# -*- coding: utf-8 -*-
"""PCB2MAP.PY - turns a real printed circuit board into a SHOTEMUP level map.

  python3 PCB2MAP.PY <theme> <source> <out.MAP> [options]

  theme   : a8 | st | ste | falcon   (written in the THEME line)
  source  : file.kicad_pcb           KiCad 6/7 board (footprints, segments, vias, zones)
            file.json / ibom.html    InteractiveHtmlBom data (no tracks : they are
                                     generated : buses + L-shaped traces between pads)
            dir_or_file.GTL          Gerber RS-274X top copper ; the Altium
                                     pick & place CSV of the same folder gives the
                                     components (TopLayer only) ; the -Plated.TXT
                                     Excellon drill file gives the vias.
  options : --scale MM     mm per tile (default 4.5)
            --cols N       maximum width in tiles (default 40 ; wider boards are
                           cropped on the most interesting 40-column band)
            --max N        maximum number of components (default 1.6 * rows)
            --png F.PNG    preview (needs PIL and the tile file --tiles F.BIN)
            --tiles F.BIN  tile file (24 tiles 20x20 RGB565 big-endian)

The long side of the board is put vertically (row 0 = end of the level = top).
Only Python 3 standard library (+ PIL for the preview).
"""
import sys, os, re, math, json, glob

CHARS = '.-|+r7LJTWE3oOaip=#sthvk'
SIZES = {'P': (4, 4), 'M': (2, 4), 'R': (2, 1), 'K': (1, 1), 'X': (2, 1),
         'H': (4, 1), 'Q': (4, 4), 'F': (4, 4), 'D': (2, 5), 'O': (2, 2),
         'A': (1, 4), 'U': (1, 1), 'Z': (2, 2), 'G': (6, 10), 'N': (3, 1),
         'V': (2, 5)}
# placement priority (first placed = keeps its exact position)
PRIO = 'FPQGMDVOXHAZNURK'
WEIGHT = {'F': 12, 'P': 10, 'Q': 8, 'G': 6, 'M': 4, 'D': 3, 'O': 2, 'V': 1}

class Board:
    def __init__(self):
        self.bbox = None          # minx, miny, maxx, maxy (mm, y down)
        self.comps = []           # dict(ref, name, x, y, w, h, pads=[(x,y)], kind)
        self.segs = []            # (x1, y1, x2, y2, width)
        self.vias = []            # (x, y)
        self.holes = []           # (x, y)  mounting holes -> big via
        self.zones = []           # polygons [(x,y)...]
        self.frames = []          # (minx,miny,maxx,maxy) shields drawn as silk frames
        self.fingers = []         # (x, y) gold fingers

# ---------------------------------------------------------------- KiCad
NUM = r'(-?[\d.]+)'
def rot(x, y, a):
    t = math.radians(a)
    return x * math.cos(t) + y * math.sin(t), -x * math.sin(t) + y * math.cos(t)

def blocks(text, head):
    """top-level-ish blocks '(head ...' -> list of strings (paren matched)"""
    out = []
    for m in re.finditer(r'\n\s*\(' + head + r'[\s)]', text):
        i = m.start() + text[m.start():].index('(')
        d = 0
        j = i
        n = len(text)
        while j < n:
            c = text[j]
            if c == '(':
                d += 1
            elif c == ')':
                d -= 1
                if d == 0:
                    break
            elif c == '"':
                j = text.index('"', j + 1)
                while text[j - 1] == '\\':
                    j = text.index('"', j + 1)
            j += 1
        out.append(text[i:j + 1])
    return out

def load_kicad(path):
    b = Board()
    text = open(path, encoding='utf-8', errors='replace').read()
    for m in re.finditer(r'\(segment \(start ' + NUM + ' ' + NUM + r'\) \(end ' + NUM +
                         ' ' + NUM + r'\) \(width ' + NUM + r'\) \(layer "([^"]+)"', text):
        x1, y1, x2, y2, w = map(float, m.groups()[:5])
        if m.group(6) == 'F.Cu' and (x1, y1) != (x2, y2):
            b.segs.append((x1, y1, x2, y2, w))
    for m in re.finditer(r'\(via (?:blind |micro )?\(at ' + NUM + ' ' + NUM, text):
        b.vias.append((float(m.group(1)), float(m.group(2))))
    xs, ys = [], []
    for g in blocks(text, r'gr_(?:line|arc|rect|circle|poly)'):
        if 'Edge.Cuts' in g:
            for m in re.finditer(r'\((?:start|end|mid|center|xy) ' + NUM + ' ' + NUM, g):
                xs.append(float(m.group(1))); ys.append(float(m.group(2)))
    for z in blocks(text, 'zone'):
        if '"F.Cu"' in z.split('(polygon')[0]:
            pm = re.search(r'\(polygon\s*\(pts(.*?)\)\s*\)', z, re.S)
            if pm:
                pts = [(float(a), float(c)) for a, c in re.findall(r'\(xy ' + NUM + ' ' + NUM, pm.group(1))]
                if len(pts) > 2:
                    b.zones.append(pts)
    for fp in blocks(text, 'footprint'):
        name = re.match(r'\(footprint "([^"]*)"', fp).group(1)
        at = re.search(r'\(at ' + NUM + ' ' + NUM + '(?: ' + NUM + r')?\)', fp)
        fx, fy = float(at.group(1)), float(at.group(2))
        fa = float(at.group(3) or 0)
        layer = re.search(r'\(layer "([^"]+)"', fp).group(1)
        rm = re.search(r'\(fp_text reference "([^"]*)"', fp) or \
             re.search(r'\(property "Reference" "([^"]*)"', fp)
        ref = rm.group(1) if rm else ''
        vm = re.search(r'\(fp_text value "([^"]*)"', fp) or \
             re.search(r'\(property "Value" "([^"]*)"', fp)
        value = vm.group(1) if vm else ''
        pads, pxs, pys = [], [], []
        for pm in re.finditer(r'\(pad "[^"]*" (\w+) \w+ \(at ' + NUM + ' ' + NUM +
                              r'(?: ' + NUM + r')?\) \(size ' + NUM + ' ' + NUM, fp):
            px, py = rot(float(pm.group(2)), float(pm.group(3)), fa)
            pads.append((fx + px, fy + py))
            r = max(float(pm.group(5)), float(pm.group(6))) / 2
            pxs += [fx + px - r, fx + px + r]; pys += [fy + py - r, fy + py + r]
        for lm in re.finditer(r'\(fp_(?:line|rect) \(start ' + NUM + ' ' + NUM + r'\) \(end ' +
                              NUM + ' ' + NUM + r'\).*?\(layer "F\.(?:CrtYd|Fab)"', fp):
            for k in (0, 2):
                px, py = rot(float(lm.group(k + 1)), float(lm.group(k + 2)), fa)
                pxs.append(fx + px); pys.append(fy + py)
            # Edge.Cuts drawn inside footprints
        if 'Edge.Cuts' in fp:
            for lm in re.finditer(r'\(fp_(?:line|arc) \(start ' + NUM + ' ' + NUM + r'\) \(end ' +
                                  NUM + ' ' + NUM + r'\)[^\n]*\n?[^\n]*Edge\.Cuts', fp):
                for k in (0, 2):
                    px, py = rot(float(lm.group(k + 1)), float(lm.group(k + 2)), fa)
                    xs.append(fx + px); ys.append(fy + py)
        if not pxs:
            pxs, pys = [fx], [fy]
        b.comps.append(dict(ref=ref, name=name, value=value, layer=layer,
                            x=(min(pxs) + max(pxs)) / 2, y=(min(pys) + max(pys)) / 2,
                            w=max(pxs) - min(pxs), h=max(pys) - min(pys), pads=pads))
    if not xs:
        for s in b.segs:
            xs += [s[0], s[2]]; ys += [s[1], s[3]]
    b.bbox = (min(xs), min(ys), max(xs), max(ys))
    b.comps = [c for c in b.comps if c['layer'] == 'F.Cu']
    return b

def classify_kicad(c):
    n = c['name'].lower(); ref = c['ref'].upper(); v = c['value'].upper()
    w, h = max(c['w'], c['h']), min(c['w'], c['h'])
    if 'cage' in n or 'shield' in n:
        return 'frame'
    if 'hole' in n or (n == '' and not ref):
        return 'hole'
    if any(k in n for k in ('logo', 'silkscreen', 'soldermask', 'solderjumper', 'fiducial', 'testpoint')):
        return None
    if 'simm' in n:
        return 'G'
    if 'edge-pcb' in n or 'pinheader' in n or 'switch' in n or 'header' in n:
        return 'H'
    if any(k in n for k in ('din', 'dsub', 'rca', 'joystick', 'receptacle', 'jack')):
        return 'V'
    if '68000' in v or ('plcc-68' in n and ref == 'U100'):
        return 'P'
    if 'plcc' in n or 'qfp' in n:
        return 'Q'
    if 'oscillator' in n or 'crystal' in n:
        return 'X'
    m = re.search(r'dip-(\d+)', n)
    if m:
        p = int(m.group(1))
        if p >= 40:
            return 'P'
        if p in (16, 18):
            return 'M'
        if p <= 8:
            return 'O'
        return 'D'
    if 'r_array' in n:
        return 'A'
    if 'to-92' in n:
        return 'U'
    if 'polarized' in n or 'cp_radial' in n or 'c_radial' in n or 'tantal' in n:
        return 'Z'
    if 'ferrite' in n or 'inductor' in n:
        return 'N'
    if 'resistor' in n or 'diode' in n:
        return 'R'
    if 'capacitor' in n or 'emi_filter' in n:
        return 'K'
    if w > 20:
        return 'H'
    return 'K' if w < 6 else 'R'

# ---------------------------------------------------------------- iBOM
def load_ibom(path):
    if path.endswith('.html'):
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from lzs import decompress_b64          # LZString decoder (separate file)
        h = open(path, encoding='utf-8').read()
        d = json.loads(decompress_b64(re.search(r'LZString\.decompressFromBase64\("([^"]+)"', h).group(1)))
    else:
        d = json.load(open(path))
    b = Board()
    e = d['edges_bbox']
    b.bbox = (e['minx'], e['miny'], e['maxx'], e['maxy'])
    for f in d['footprints']:
        if f.get('layer', 'F') != 'F':
            continue
        pads = [tuple(p['pos']) for p in f['pads']]
        bb = f['bbox']
        sx, sy = bb['size']
        a = abs(bb.get('angle', 0)) % 180
        if 45 < a < 135:
            sx, sy = sy, sx
        if pads:
            cx = sum(p[0] for p in pads) / len(pads); cy = sum(p[1] for p in pads) / len(pads)
        else:
            cx, cy = bb['pos']
        smd_edge = [p for p in f['pads'] if p.get('type') == 'smd']
        b.comps.append(dict(ref=f['ref'], name='', value='', layer='F', x=cx, y=cy,
                            w=sx, h=sy, pads=pads, smd=len(smd_edge)))
    generate_tracks(b)
    return b

def classify_ibom(c):
    ref = re.match(r'[A-Z]+', c['ref']).group(0)
    w, h = max(c['w'], c['h']), min(c['w'], c['h'])
    if ref == 'U':
        if w > 45: return 'P'
        if w < 12: return 'O'
        if 20 < w < 24: return 'M'
        return 'D'
    if ref == 'J':
        if w > 60 and h < 10: return 'fingers'
        if w > 40: return 'H'
        return 'V'
    if ref == 'Y': return 'X'
    if ref == 'A': return 'A' if len(c['pads']) < 12 else 'H'
    if ref == 'C': return 'Z' if (h > 5 and w < 12) else 'K'
    if ref in ('R', 'CR'): return 'R'
    if ref == 'L': return 'N'
    if ref == 'Q': return 'U'
    if ref == 'S': return 'H'
    return None

def generate_tracks(b):
    """iBOM has no tracks : plausible ones. 1) a minimum spanning tree over the
    component centres, joined pad to pad with L-shaped traces ; 2) 4-trace buses
    between neighbouring big chips (consecutive pins)."""
    cs = [c for c in b.comps if c['pads']]
    n = len(cs)
    def d2(a, c): return (a['x'] - c['x']) ** 2 + (a['y'] - c['y']) ** 2
    intree = [False] * n; best = [1e18] * n; par = [-1] * n
    best[0] = 0
    for _ in range(n):
        i = min((k for k in range(n) if not intree[k]), key=lambda k: best[k])
        intree[i] = True
        if par[i] >= 0:
            a, c = cs[i], cs[par[i]]
            pa = min(a['pads'], key=lambda p: (p[0] - c['x']) ** 2 + (p[1] - c['y']) ** 2)
            pc = min(c['pads'], key=lambda p: (p[0] - pa[0]) ** 2 + (p[1] - pa[1]) ** 2)
            lshape(b, pa, pc, i)
        for k in range(n):
            if not intree[k]:
                dd = d2(cs[i], cs[k])
                if dd < best[k]:
                    best[k] = dd; par[k] = i
    big = [c for c in cs if c['ref'].startswith('U') and len(c['pads']) >= 14]
    for i, a in enumerate(big):
        near = sorted((c for c in big if c is not a), key=lambda c: d2(a, c))[:2]
        for c in near:
            if id(c) < id(a):
                continue
            for k in range(0, 8, 2):
                pa = a['pads'][(k + i) % len(a['pads'])]
                pc = c['pads'][(len(c['pads']) // 2 + k) % len(c['pads'])]
                lshape(b, pa, pc, k)

def lshape(b, p, q, k):
    if k % 2:
        m = (q[0], p[1])
    else:
        m = (p[0], q[1])
    b.segs.append((p[0], p[1], m[0], m[1], 0.3))
    b.segs.append((m[0], m[1], q[0], q[1], 0.3))

# ---------------------------------------------------------------- Gerber + P&P
def load_gerber(path):
    d = path if os.path.isdir(path) else os.path.dirname(path)
    gtl = path if not os.path.isdir(path) else glob.glob(os.path.join(d, '*.GTL'))[0]
    b = Board()
    aper = {}
    text = open(gtl, errors='replace').read()
    fs = re.search(r'%FSLAX(\d)(\d)Y', text)
    div = 10 ** int(fs.group(2)) if fs else 1e4
    unit = 25.4 if '%MOIN' in text else 1.0
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
            if len(poly) > 2:
                b.zones.append(poly)
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
    # drills : small plated holes = vias
    for f in glob.glob(os.path.join(d, '*RoundHoles-Plated.TXT')):
        tools = {}; t = None
        for line in open(f):
            line = line.strip()
            m = re.match(r'T(\d+)F\d+S\d+C([\d.]+)', line)
            if m:
                tools[m.group(1)] = float(m.group(2)); continue
            m = re.match(r'T(\d+)$', line)
            if m:
                t = m.group(1); continue
            m = re.match(r'(?:X(\d+))?(?:Y(\d+))?$', line)
            if m and line and t:
                if m.group(1): x = int(m.group(1)) / 1000.0
                if m.group(2): y = int(m.group(2)) / 1000.0
                if tools.get(t, 9) <= 0.5:
                    b.vias.append((x, -y))
                elif tools.get(t, 0) >= 3.0:
                    b.holes.append((x, -y))
    # board outline
    gm = glob.glob(os.path.join(d, '*.GM1'))
    xs, ys = [], []
    src = open(gm[0]).read() if gm else text
    for m in re.finditer(r'X(-?\d+)', src): xs.append(int(m.group(1)) / div * unit)
    for m in re.finditer(r'Y(-?\d+)', src): ys.append(-int(m.group(1)) / div * unit)
    b.bbox = (min(xs), min(ys), max(xs), max(ys))
    # pick and place (Altium CSV, mil)
    import csv
    pp = glob.glob(os.path.join(d, 'Pick Place*.csv'))[0]
    lines = open(pp, errors='replace').read().splitlines()
    h = next(i for i, l in enumerate(lines) if l.startswith('"Designator"'))
    for r in csv.DictReader(lines[h:]):
        if r['Layer'] != 'TopLayer':
            continue
        cx = float(r['Center-X(mil)']) * 0.0254; cy = -float(r['Center-Y(mil)']) * 0.0254
        b.comps.append(dict(ref=r['Designator'], name=r['Footprint'], value=r['Comment'],
                            desc=r['Description'], layer='F', x=cx, y=cy, w=0, h=0, pads=[]))
    return b

def classify_falcon(c):
    n = c['name'].upper(); v = (c['value'] + ' ' + c.get('desc', '')).upper()
    if 'FIDUCIAL' in n or 'TEST_PAD' in n or 'JUMPER' in n or n == 'PAD':
        return None
    if '68030' in v or 'LC030' in v or ('030' in v and 'MICROPROCESSOR' in v):
        return 'F'
    if 'DSP' in v or '56001' in v:
        return 'P'
    if 'QFP' in n or 'PLCC' in n:
        return 'Q'
    if 'SOJ' in n or 'TSOP' in n:
        return 'M'
    if 'SOIC' in n or 'SO-' in n:
        return 'O'
    m = re.search(r'DIP-(\d+)', n)
    if m:
        return 'M' if '27C' in v or 'ROM' in v else 'D'
    if 'DB' in n or 'DIN' in n or 'JACK' in n or 'DSUB' in n:
        return 'V'
    if 'HEADER' in n or 'SWITCH' in n:
        return 'H'
    if 'SIMM' in n or 'SIMM' in v:
        return 'G'
    if 'RES_PACK' in n:
        return 'A'
    if 'HC-49' in n or 'OSC' in n or 'XTAL' in n:
        return 'X'
    if 'TO-92' in n:
        return 'U'
    if 'CAPOL' in n or 'TANTAL' in n:
        return 'Z'
    if 'FERRITE' in n or 'INDUCTOR' in n:
        return 'N'
    if 'RES' in n or 'DIODE' in n:
        return 'R'
    if 'RC_FILTER' in n or 'CAP' in n:
        return 'K'
    return None

# ---------------------------------------------------------------- map building
class Grid:
    def __init__(self, b, scale, maxcols):
        x0, y0, x1, y1 = b.bbox
        self.rotate = (x1 - x0) > (y1 - y0)      # long side vertical
        W, H = ((y1 - y0), (x1 - x0)) if self.rotate else ((x1 - x0), (y1 - y0))
        self.s = scale
        self.fullcols = int(math.ceil(W / scale - 1e-6))
        self.rows = int(math.ceil(H / scale - 1e-6))
        self.cols = min(self.fullcols, maxcols)
        self.off = 0                              # first column kept (crop)
        self.b = b
    def f(self, x, y):
        """mm -> fractional (col, row) in the full (uncropped) grid"""
        x0, y0, x1, y1 = self.b.bbox
        if self.rotate:      # clockwise 90 deg : new x = (y1 - y), new y = (x - x0)
            return (y1 - y) / self.s, (x - x0) / self.s
        return (x - x0) / self.s, (y - y0) / self.s

def build(b, classify, scale, maxcols, maxcomp):
    g = Grid(b, scale, maxcols)
    # classify
    comps = []
    for c in b.comps:
        k = classify(c)
        if k == 'hole':
            b.holes.append((c['x'], c['y'])); continue
        if k == 'frame':
            b.frames.append((c['x'] - c['w'] / 2, c['y'] - c['h'] / 2, c['x'] + c['w'] / 2, c['y'] + c['h'] / 2)); continue
        if k == 'fingers':
            for p in c['pads']:
                b.fingers.append(p)
            continue
        if k is None:
            continue
        c['kind'] = k
        comps.append(c)
    # crop band : best window of maxcols columns
    if g.fullcols > g.cols:
        score = [0.0] * (g.fullcols + 1)
        for c in comps:
            if c['kind'] in WEIGHT:
                fc, fr = g.f(c['x'], c['y'])
                w = SIZES[c['kind']][0]
                score[max(0, min(g.fullcols, int(fc)))] += WEIGHT[c['kind']]
        bestv, best = -1, 0
        for o in range(0, g.fullcols - g.cols + 1):
            # components need some margin : count centres from o+2 to o+cols-2
            v = sum(score[o + 2: o + g.cols - 2])
            if v > bestv:
                bestv, best = v, o
        g.off = best
    rows, cols = g.rows, g.cols
    bits = [[0] * cols for _ in range(rows)]      # U1 D2 L4 R8
    cnt = [[0] * cols for _ in range(rows)]
    def cell(x, y):
        fc, fr = g.f(x, y)
        return int(math.floor(fc)) - g.off, int(math.floor(fr))
    def inside(c, r): return 0 <= c < cols and 0 <= r < rows
    def link(c1, r1, c2, r2):
        if not (inside(c1, r1) and inside(c2, r2)):
            return
        if c2 == c1 + 1: bits[r1][c1] |= 8; bits[r2][c2] |= 4
        elif c2 == c1 - 1: bits[r1][c1] |= 4; bits[r2][c2] |= 8
        elif r2 == r1 + 1: bits[r1][c1] |= 2; bits[r2][c2] |= 1
        elif r2 == r1 - 1: bits[r1][c1] |= 1; bits[r2][c2] |= 2
    for (x1, y1, x2, y2, w) in b.segs:
        a = g.f(x1, y1); e = g.f(x2, y2)
        ca, ra = int(math.floor(a[0])) - g.off, int(math.floor(a[1]))
        ce, re_ = int(math.floor(e[0])) - g.off, int(math.floor(e[1]))
        if (ca, ra) == (ce, re_):
            continue
        # 4-connected walk, the axis with the larger remaining error moves first
        c, r = ca, ra
        dc, dr = ce - ca, re_ - ra
        n = abs(dc) + abs(dr)
        for k in range(n):
            # ideal point after k+1 steps
            ic = ca + dc * (k + 1) / n; ir = ra + dr * (k + 1) / n
            if c != ce and (r == re_ or abs(ic - c) >= abs(ir - r)):
                nc, nr = c + (1 if dc > 0 else -1), r
            else:
                nc, nr = c, r + (1 if dr > 0 else -1)
            link(c, r, nc, nr)
            if inside(nc, nr): cnt[nr][nc] += 1
            c, r = nc, nr
    tile = [['.'] * cols for _ in range(rows)]
    B2C = {0: '.', 1: 'o', 2: 'o', 4: 'o', 8: 'o', 3: '|', 12: '-', 10: 'r', 6: '7', 9: 'L', 5: 'J',
           14: 'T', 13: 'W', 11: 'E', 7: '3', 15: '+'}
    for r in range(rows):
        for c in range(cols):
            tile[r][c] = B2C[bits[r][c]]
    # buses : stacked horizontal / vertical traces become 'h' / 'v'
    newt = [row[:] for row in tile]
    for r in range(1, rows - 1):
        for c in range(1, cols - 1):
            t = tile[r][c]
            if t == '-' and tile[r - 1][c] == '-' and tile[r + 1][c] == '-' and \
               tile[r][c - 1] in '-+3JW7' and tile[r][c + 1] in '-+ELWrT' and cnt[r][c] >= 2:
                newt[r][c] = 'h'
            if t == '|' and tile[r][c - 1] == '|' and tile[r][c + 1] == '|' and \
               tile[r - 1][c] in '|+ET3r7' and tile[r + 1][c] in '|+EW3LJ' and cnt[r][c] >= 2:
                newt[r][c] = 'v'
    tile = newt
    # copper planes (zones) on free cells
    if b.zones:
        try:
            from PIL import Image, ImageDraw
            im = Image.new('L', (g.fullcols, rows), 0)
            dr = ImageDraw.Draw(im)
            for z in b.zones:
                pts = [g.f(x, y) for x, y in z]
                if len(pts) > 2:
                    area = abs(sum(pts[i][0] * pts[i - 1][1] - pts[i - 1][0] * pts[i][1] for i in range(len(pts)))) / 2
                    if area >= 12:            # only big pours (>= 12 tiles)
                        dr.polygon(pts, fill=255)
            for r in range(rows):
                for c in range(cols):
                    if tile[r][c] == '.' and im.getpixel((c + g.off, r)) > 0:
                        tile[r][c] = '#'
        except ImportError:
            pass
    # silk frames (shields / cages)
    for (x0, y0, x1, y1) in b.frames:
        (ca, ra), (cb, rb) = cell(x0, y0), cell(x1, y1)
        ca, cb = sorted((ca, cb)); ra, rb = sorted((ra, rb))
        for r in range(ra, rb + 1):
            for c in range(ca, cb + 1):
                if inside(c, r) and (r in (ra, rb) or c in (ca, cb)) and tile[r][c] in '.#':
                    tile[r][c] = 's'
    # vias
    for (x, y) in b.vias:
        c, r = cell(x, y)
        if inside(c, r):
            t = tile[r][c]
            tile[r][c] = {'.': 'o', '#': 'o', '-': 'a', '|': 'i'}.get(t, t)
    for (x, y) in b.holes:
        c, r = cell(x, y)
        if inside(c, r):
            tile[r][c] = 'O'
    for (x, y) in b.fingers:
        c, r = cell(x, y)
        if inside(c, r):
            tile[r][c] = '='
    # components
    occ = [[False] * cols for _ in range(rows)]
    placed = []
    def free(c, r, w, h):
        if c < 0 or r < 0 or c + w > cols or r + h > rows:
            return False
        for rr in range(r, r + h):
            for cc in range(c, c + w):
                if occ[rr][cc]:
                    return False
        return True
    order = sorted(comps, key=lambda c: (PRIO.index(c['kind']), -c.get('w', 0) * c.get('h', 0), c['ref']))
    dropped = {}
    ndone = 0
    small = set('RKNUZA')
    for c in order:
        k = c['kind']
        w, h = SIZES[k]
        fc, fr = g.f(c['x'], c['y'])
        fc -= g.off
        c0, r0 = int(round(fc - w / 2.0)), int(round(fr - h / 2.0))
        if fc < -1 or fc > cols + 1 or fr < -1 or fr > rows + 1:
            dropped[k] = dropped.get(k, 0) + 1
            continue
        if ndone >= maxcomp or (k in small and ndone >= maxcomp * 0.9):
            dropped[k] = dropped.get(k, 0) + 1
            pad_marks(c, cell, inside, tile)
            continue
        ok = None
        rad = 3 if k not in small else 1
        for d in range(rad + 1):
            for dr_ in range(-d, d + 1):
                for dc in range(-d, d + 1):
                    if max(abs(dr_), abs(dc)) != d:
                        continue
                    if free(c0 + dc, r0 + dr_, w, h):
                        ok = (c0 + dc, r0 + dr_); break
                if ok: break
            if ok: break
        if not ok:
            dropped[k] = dropped.get(k, 0) + 1
            pad_marks(c, cell, inside, tile)
            continue
        # passives : keep a 1-cell gap with other passives to avoid clutter
        cc, rr = ok
        for r in range(rr, rr + h):
            for q in range(cc, cc + w):
                occ[r][q] = True
        if k in small:
            for r in range(rr - 1, rr + h + 1):
                for q in range(cc - 1, cc + w + 1):
                    if 0 <= r < rows and 0 <= q < cols:
                        occ[r][q] = True
        placed.append((k, cc, rr, c['ref']))
        ndone += 1
    # silk text under big chips
    for (k, cc, rr, ref) in placed:
        if k in 'PQFGMD':
            r = rr + SIZES[k][1]
            for q in range(cc, cc + SIZES[k][0]):
                if r < rows and not occ[r][q] and tile[r][q] in '.#':
                    tile[r][q] = 't'; break
    return g, tile, placed, dropped

def pad_marks(c, cell, inside, tile):
    """omitted component : its pads stay as solder pads on free cells"""
    for p in c['pads'][:2]:
        q, r = cell(*p)
        if inside(q, r) and tile[r][q] in '.#':
            tile[r][q] = 'p'

# names printed on the chips in the game (processors, custom chips, ROMs)
NAMES = [(r'68LC030|68030', '68030'), (r'68882', '68882'), (r'68000', '68000'),
         (r'DSP56001|56001', 'DSP56001'), (r'BLITTER', 'BLITTER'), (r'GSTMCU', 'GST_MCU'),
         (r'GSTSHIFTER', 'SHIFTER'), (r'SHIFTER', 'SHIFTER'), (r'_MMU|^MMU', 'MMU'),
         (r'GLUE', 'GLUE'), (r'COMBEL', 'COMBEL'), (r'VIDEL', 'VIDEL'), (r'SDMA', 'SDMA'),
         (r'ST_DMA|DMA_', 'DMA'), (r'YM2149', 'YM2149'), (r'68901', 'MFP_68901'),
         (r'WD1772', 'WD1772'), (r'AJAX', 'AJAX'), (r'27C\d+|EPROM|\bROM\b', 'TOS_ROM'),
         (r'6502|SALLY', '6502'), (r'ANTIC', 'ANTIC'), (r'GTIA', 'GTIA'), (r'POKEY', 'POKEY'),
         (r'6520|6821|\bPIA\b', 'PIA'), (r'FREDDIE', 'FREDDIE')]

def chip_name(c, kind):
    """short name for processors, custom chips and ROMs ; '' for the others"""
    if c.get('label'):
        return c['label']
    v = (c.get('value', '') + ' ' + c.get('desc', '')).upper()
    for rx, nm in NAMES:
        if re.search(rx, v):
            w, h = SIZES[kind]
            room = max(w, h) * 20 - 8          # long side (pixels) / 6 per char
            return nm[:max(1, room // 6)]
    return ''

def write_map(path, theme, g, tile, placed, src, dropped, names=None):
    out = []
    out.append('; SHOTEMUP level map - made by PCB2MAP.PY from a real Atari board')
    out.append('; source : %s' % os.path.basename(src))
    out.append('; scale %.2f mm per tile, %s, columns %d..%d of %d kept'
               % (g.s, 'board turned 90 degrees' if g.rotate else 'board not turned',
                  g.off, g.off + g.cols - 1, g.fullcols))
    out.append('; components omitted : %s' % (' '.join('%s=%d' % kv for kv in sorted(dropped.items())) or 'none'))
    out.append('; see CREDITS.TXT for the licences of the source boards')
    out.append('SEU 1')
    out.append('THEME %s' % theme)
    out.append('SIZE %d %d' % (g.cols, g.rows))
    for row in tile:
        out.append(''.join(row))
    for (k, c, r, ref) in sorted(placed, key=lambda p: (p[2], p[1])):
        nm = (names or {}).get(ref, '')
        out.append('C %s %d %d' % (k, c, r) + (' ' + nm if nm else ''))
    out.append('END')
    open(path, 'w', newline='').write('\r\n'.join(out) + '\r\n')

COL = {'P': (60, 60, 64), 'Q': (40, 40, 44), 'F': (150, 150, 160), 'M': (30, 30, 30),
       'D': (24, 24, 28), 'O': (50, 50, 54), 'G': (20, 90, 30), 'V': (170, 170, 180),
       'H': (230, 230, 220), 'X': (200, 200, 210), 'A': (200, 190, 120), 'U': (40, 90, 200),
       'Z': (40, 60, 160), 'N': (90, 90, 90), 'R': (210, 170, 120), 'K': (230, 140, 40)}

def preview(mappath, tilespath, pngpath):
    from PIL import Image, ImageDraw
    data = open(tilespath, 'rb').read()
    tiles = []
    for i in range(24):
        im = Image.new('RGB', (20, 20))
        px = im.load()
        for y in range(20):
            for x in range(20):
                v = int.from_bytes(data[i * 800 + (y * 20 + x) * 2: i * 800 + (y * 20 + x) * 2 + 2], 'big')
                px[x, y] = ((v >> 11) << 3, ((v >> 5) & 63) << 2, (v & 31) << 3)
        tiles.append(im)
    lines = open(mappath, newline='').read().split('\r\n')
    i = next(k for k, l in enumerate(lines) if l.startswith('SIZE'))
    cols, rows = map(int, lines[i].split()[1:])
    im = Image.new('RGB', (cols * 20, rows * 20))
    for r in range(rows):
        for c, ch in enumerate(lines[i + 1 + r]):
            im.paste(tiles[CHARS.index(ch)], (c * 20, r * 20))
    d = ImageDraw.Draw(im)
    for l in lines[i + 1 + rows:]:
        if l.startswith('C '):
            _, k, c, r = l.split()
            c, r = int(c), int(r); w, h = SIZES[k]
            d.rectangle([c * 20 + 1, r * 20 + 1, (c + w) * 20 - 2, (r + h) * 20 - 2], fill=COL[k], outline=(255, 255, 255))
            d.text((c * 20 + 4, r * 20 + 4), k, fill=(255, 0, 0))
    im.save(pngpath)

def main():
    a = sys.argv[1:]
    opt = {}
    pos = []
    i = 0
    while i < len(a):
        if a[i].startswith('--'):
            opt[a[i][2:]] = a[i + 1]; i += 2
        else:
            pos.append(a[i]); i += 1
    theme, src, out = pos
    if src.endswith('.kicad_pcb'):
        b = load_kicad(src); cl = classify_kicad
    elif src.endswith('.json') or src.endswith('.html'):
        b = load_ibom(src); cl = classify_ibom
    else:
        b = load_gerber(src); cl = classify_falcon
    scale = float(opt.get('scale', 4.5))
    maxcols = int(opt.get('cols', 40))
    g0 = Grid(b, scale, maxcols)
    maxcomp = int(opt.get('max', int(1.6 * g0.rows)))
    g, tile, placed, dropped = build(b, cl, scale, maxcols, min(maxcomp, 800))
    names = {c['ref']: chip_name(c, c['kind']) for c in b.comps if c.get('kind')}
    write_map(out, theme, g, tile, placed, src, dropped, names)
    print('names :', ' '.join(sorted(v for v in names.values() if v)))
    from collections import Counter
    print('%s : %d x %d (full width %d, crop from %d), %d components %s, dropped %s, %d segs'
          % (out, g.cols, g.rows, g.fullcols, g.off, len(placed),
             dict(Counter(p[0] for p in placed)), dropped, len(b.segs)))
    if 'png' in opt:
        preview(out, opt['tiles'], opt['png'])

if __name__ == '__main__':
    main()
