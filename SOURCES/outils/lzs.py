# LZString.decompressFromBase64 (own implementation, for InteractiveHtmlBom data)
import math
KEY = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
def decompress_b64(s):
    if not s: return ''
    rev = {c: i for i, c in enumerate(KEY)}
    data = [rev[c] for c in s if c in rev]
    pos = [0]; val = [data[0]]; reset = 32; idx = [1]
    def bits(n):
        r = 0; p = 1
        for _ in range(n):
            b = val[0] & pos[0] if False else None
            # read one bit
            if pos[0] == 0:
                pos[0] = reset
                val[0] = data[idx[0]] if idx[0] < len(data) else 0
                idx[0] += 1
            bit = 1 if (val[0] & pos[0]) else 0
            pos[0] >>= 1
            r |= bit * p; p <<= 1
        return r
    pos[0] = reset
    dic = {0: 0, 1: 1, 2: 2}
    enl = 4; dsize = 4; nbits = 3
    nxt = bits(2)
    if nxt == 0: c = chr(bits(8))
    elif nxt == 1: c = chr(bits(16))
    else: return ''
    dic[3] = c; w = c; out = [c]
    while True:
        if idx[0] > len(data) + 1: return ''.join(out)
        cc = bits(nbits)
        if cc == 0:
            dic[dsize] = chr(bits(8)); dsize += 1; cc = dsize - 1; enl -= 1
        elif cc == 1:
            dic[dsize] = chr(bits(16)); dsize += 1; cc = dsize - 1; enl -= 1
        elif cc == 2:
            return ''.join(out)
        if enl == 0:
            enl = 2 ** nbits; nbits += 1
        if cc in dic: entry = dic[cc]
        elif cc == dsize: entry = w + w[0]
        else: return None
        out.append(entry)
        dic[dsize] = w + entry[0]; dsize += 1; enl -= 1
        w = entry
        if enl == 0:
            enl = 2 ** nbits; nbits += 1
