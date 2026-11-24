#!/bin/bash
# run.sh DISK_DIR PRG CMDFILE [MEM_MB=14] [OUTDIR=out]
#   Hatari headless : Falcon 030 16 MHz cycle exact, DSP, VGA, EmuTOS,
#   DISK_DIR = GEMDOS drive C:, PRG started from C:\ (auto).
#   CMDFILE lines :  wait <s> | key <char|scancode> | down <k> | up <k>
#     (scancode : 2+ characters, e.g. 57 = space, 0x01 = ESC ; 1 char = ASCII)
#                    shot | raw <hatari control command> | quit
T=$(cd "$(dirname "$0")" && pwd)/tools
DISK=$(realpath "$1"); PRG=$2; CMD=$3; MEM=${4:-14}; OUT=$(realpath -m "${5:-out}")
mkdir -p "$OUT"; FIFO=$OUT/fifo; rm -f "$FIFO"
export SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy LD_LIBRARY_PATH=$HOME/tc/sdlinst/lib
"$T/hatari" --configfile /dev/null --machine falcon --cpulevel 3 --cpuclock 16 --fpu none \
  --cpu-exact on --dsp emu --memsize $MEM --monitor vga --tos "$T/etos512fr.img" \
  --fast-boot on --harddrive "$DISK" --gemdos-drive C --protect-hd off \
  --auto "C:\\$PRG" --confirm-quit off --sound off --statusbar off --drive-led off \
  --screenshot-dir "$OUT" --cmd-fifo "$FIFO" --log-file "$OUT/hatari.log" --log-level info \
  > "$OUT/stdout.txt" 2>&1 &
PID=$!
for i in $(seq 50); do [ -p "$FIFO" ] && break; sleep 0.2; done
exec 3>"$FIFO"
n=0
while read -r c a; do
  case "$c" in
    wait) sleep "$a";;
    key)  echo "hatari-event keypress $a" >&3;;
    down) echo "hatari-event keydown $a" >&3;;
    up)   echo "hatari-event keyup $a" >&3;;
    shot) echo "hatari-shortcut screenshot" >&3; sleep 1; n=$((n+1));;
    raw)  echo "$a" >&3;;
    quit) echo "hatari-shortcut quit" >&3;;
  esac
done < "$CMD"
sleep 2; kill $PID 2>/dev/null; wait $PID 2>/dev/null
ls "$OUT"/*.png 2>/dev/null
