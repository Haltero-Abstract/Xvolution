# -*- coding: utf-8 -*-
"""MKTILES.PY - printed circuit board tiles for SHOTEMUP (20 x 20 pixels,
Falcon True Color RGB565 big-endian) -> PCBTILES.BIN, and PCBTILES.JS for the
editor (same pictures, base64).      python MKTILES.PY [outdir] [falcon|classic|a8|st|ste]
(output name depends on the theme : PCBTF30, PCBTA8, PCBTST, PCBTSTE)

The tile characters are also the characters of the .MAP files (TILES below,
the order = index in PCBTILES.BIN ; CARTE.S has the same string).
"""
import sys, os, base64

T = 20
def rgb(r, g, b):                       # 8-bit -> RGB565
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)

# theme : 'falcon' (dark green solder mask, traces seen through the mask,
#   like the Falcon 030 board) or 'classic' (lighter green, copper traces)
THEME = 'falcon'
for a in sys.argv[2:]:
    THEME = a
OUTNAME = {'falcon': 'PCBTF30', 'a8': 'PCBTA8', 'st': 'PCBTST', 'ste': 'PCBTSTE',
           'classic': 'PCBTILES'}
if THEME == 'classic':
    BOARD, BOARD2, BOARDD = (12, 92, 44), (16, 104, 52), (8, 70, 34)
    CU, CUH, CUD = (200, 132, 52), (236, 176, 92), (150, 92, 36)
elif THEME == 'a8':     # 8-bit board of the 80s : pale beige-green, copper traces
    BOARD, BOARD2, BOARDD = (196, 196, 132), (206, 204, 142), (176, 178, 116)
    CU, CUH, CUD = (196, 120, 48), (232, 164, 88), (146, 84, 30)
elif THEME == 'st':     # medium green, visible traces
    BOARD, BOARD2, BOARDD = (34, 112, 60), (40, 124, 68), (26, 92, 48)
    CU, CUH, CUD = (70, 152, 84), (104, 184, 112), (46, 118, 62)
elif THEME == 'ste':    # a bit darker green
    BOARD, BOARD2, BOARDD = (24, 84, 46), (30, 94, 52), (18, 68, 36)
    CU, CUH, CUD = (52, 124, 70), (82, 156, 96), (36, 96, 54)
else:
    BOARD, BOARD2, BOARDD = (18, 44, 28), (22, 52, 32), (12, 34, 22)
    CU, CUH, CUD = (52, 96, 62), (74, 124, 84), (34, 70, 44)
TIN    = (196, 200, 206)
TINH   = (240, 244, 248)
TIND   = (120, 124, 132)
GOLD   = (232, 184, 40)
GOLDH  = (255, 226, 120)
HOLE   = (20, 24, 20)
SILK   = (232, 236, 228)

def board():
    p = [[BOARD] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            if (x * 7 + y * 13) % 11 == 0: p[y][x] = BOARD2   # fibre texture
            if (x * 5 + y * 3) % 17 == 0: p[y][x] = BOARDD
    return p

def hseg(p, x0, x1):                    # trace 4 px wide (rows 8..11)
    for x in range(x0, x1):
        p[8][x] = CUH; p[9][x] = CU; p[10][x] = CU; p[11][x] = CUD
def vseg(p, y0, y1):
    for y in range(y0, y1):
        p[y][8] = CUH; p[y][9] = CU; p[y][10] = CU; p[y][11] = CUD

def traces(dirs):                       # dirs : letters of 'lrud'
    p = board()
    if 'l' in dirs: hseg(p, 0, 12)
    if 'r' in dirs: hseg(p, 8, 20)
    if 'u' in dirs: vseg(p, 0, 12)
    if 'd' in dirs: vseg(p, 8, 20)
    if len(dirs) > 1:
        for y in range(8, 12):
            for x in range(8, 12):
                p[y][x] = CU
    return p

def via(base=None, big=False):
    p = base or board()
    r = 7 if big else 5
    for y in range(T):
        for x in range(T):
            d2 = (x - 9.5) ** 2 + (y - 9.5) ** 2
            if d2 <= r * r:
                p[y][x] = TINH if (x + y) < 18 else TIN
            if d2 <= (r - 2.5) ** 2:
                p[y][x] = TIND
            if d2 <= 2.2 ** 2:
                p[y][x] = HOLE
    return p

def pad():                              # square solder pad
    p = board()
    for y in range(3, 17):
        for x in range(3, 17):
            p[y][x] = TINH if (x < 5 or y < 5) else (TIND if (x > 14 or y > 14) else TIN)
    return p

def finger():                           # gold edge connector finger
    p = board()
    for y in range(T):
        for x in range(4, 16):
            p[y][x] = GOLDH if x < 7 else GOLD
    return p

def plane():                            # copper ground plane (hatched)
    p = [[CU] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            if (x + y) % 5 == 0: p[y][x] = CUD
            if (x - y) % 5 == 0: p[y][x] = CUH
    return p

def bundle(vertical):                  # 4 fine traces (2 px) side by side
    p = board()
    for k in (2, 7, 12, 17):
        for i in range(T):
            if vertical:
                p[i][k - 1] = CUH; p[i][k] = CU
            else:
                p[k - 1][i] = CUH; p[k][i] = CU
    return p

def viarow():                           # row of 4 small vias (bus ends)
    p = board()
    for k in (2, 7, 12, 17):
        for y in range(T):
            for x in range(T):
                d2 = (x - k) ** 2 + (y - 9.5) ** 2
                if d2 <= 2.6 ** 2: p[y][x] = TIN
                if d2 <= 1.0: p[y][x] = HOLE
    return p

def silk():                             # silkscreen outline
    p = board()
    for i in range(2, 18):
        if i % 4 < 3:
            p[2][i] = SILK; p[17][i] = SILK; p[i][2] = SILK; p[i][17] = SILK
    return p

def silkh():                            # silkscreen line + text
    p = board()
    for x in range(T):
        if x % 3 != 2: p[4][x] = SILK
    for x in (3, 4, 6, 8, 9, 11, 13, 14, 16):
        p[12][x] = SILK; p[13][x] = SILK
    return p

TILES = [
    ('.', 'board', board()),
    ('-', 'trace -', traces('lr')), ('|', 'trace |', traces('ud')),
    ('+', 'cross', traces('lrud')),
    ('r', 'corner r', traces('rd')), ('7', 'corner 7', traces('ld')),
    ('L', 'corner L', traces('ur')), ('J', 'corner J', traces('ul')),
    ('T', 'tee T', traces('lrd')), ('W', 'tee W', traces('lru')),
    ('E', 'tee E', traces('udr')), ('3', 'tee 3', traces('udl')),
    ('o', 'via', via()), ('O', 'big via', via(big=True)),
    ('a', 'via on -', via(traces('lr'))), ('i', 'via on |', via(traces('ud'))),
    ('p', 'pad', pad()), ('=', 'gold finger', finger()),
    ('#', 'copper plane', plane()), ('s', 'silk box', silk()),
    ('t', 'silk text', silkh()),
    ('h', 'bus -', bundle(False)), ('v', 'bus |', bundle(True)),
    ('k', 'bus vias', viarow()),
]
CHARS = ''.join(c for c, _, _ in TILES)

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    data = bytearray()
    for c, _, p in TILES:
        for row in p:
            for (r, g, b) in row:
                data += rgb(r, g, b).to_bytes(2, 'big')
    open(os.path.join(out, OUTNAME.get(THEME, 'PCBTILES') + '.BIN'), 'wb').write(data)
    names = [n for _, n, _ in TILES]
    js = ('var PCB_CHARS=%r;\nvar PCB_NAMES=%r;\nvar PCB_TILES="%s";\n'
          % (CHARS, names, base64.b64encode(data).decode()))
    open(os.path.join(out, OUTNAME.get(THEME, 'PCBTILES') + '.JS'), 'w').write(js)
    print(OUTNAME.get(THEME, 'PCBTILES') + '.BIN', THEME, len(TILES), 'tiles', len(data), 'bytes ; chars', CHARS)

if __name__ == '__main__':
    main()
