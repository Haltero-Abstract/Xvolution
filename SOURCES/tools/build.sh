#!/bin/bash
# build.sh DIR MAIN.S [OUT.PRG]  - assembles the DSP (OUTILS/*.A56 -> *.P56)
#   then the 68030 program (vasm, Devpac syntax, -nocase).
#   A bsr / bra (b<cc> are left alone) out of range is changed into
#   jsr / jmp in the source, and the build is done again.
T=$(cd "$(dirname "$0")" && pwd)
cd "$1" || exit 1; MAIN=$2; OUT=${3:-${MAIN%.*}.PRG}
for a in OUTILS/*.A56; do [ -f "$a" ] || continue
  b=$(basename "${a%.*}").P56
  python3 "$T/ASM56.PY" "$a" "$b" || exit 1
done
for pass in 1 2 3 4 5 6 7 8; do
  "$T/vasmm68k_mot" -devpac -nocase -m68030 -Ftos -nosym -o "$OUT" "$MAIN" > build.log 2>&1
  ok=$?
  fix=$(python3 - <<'PY'
import re
log=open('build.log',encoding='latin-1').read()
n=0
for m in re.finditer(r'error \d+ in line (\d+) of "([^"]+)": .*out of range',log):
    ln,f=int(m.group(1)),m.group(2)
    L=open(f,encoding='latin-1').read().split('\n')
    s=L[ln-1]
    t=re.sub(r'\b(bsr|bra)(\.[sbwl])?(\s)',lambda x:('jsr' if x.group(1)=='bsr' else 'jmp')+x.group(3),s,count=1,flags=re.I)
    if t!=s:
        L[ln-1]=t; open(f,'w',encoding='latin-1').write('\n'.join(L)); n+=1
        print('  %s:%d  %s' % (f,ln,t.strip()))
print(n)
PY
)
  nfix=$(echo "$fix" | tail -1)
  [ "$nfix" != "0" ] && { echo "range fix :"; echo "$fix" | sed '$d'; continue; }
  break
done
grep -i -B1 -A3 "error" build.log | head -40
[ $ok -eq 0 ] && echo "OK $OUT $(stat -c %s "$OUT") bytes" || { echo "BUILD FAILED"; exit 1; }
