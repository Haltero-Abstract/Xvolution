;=====================================================================
; PARAMS.S - SHOTEMUP SETTINGS (change here, then assemble SHOTEMUP.S)
;   World units : 1 unit = about 1 pixel on the ship plane (Z = SHIP_Z)
;   Speeds in units per frame (60 frames / s on VGA)
;=====================================================================

; --- player
NB_LIVES        equ     3               ; lives at start
LIVES_MAX       equ     6               ; lives max (bonus at the last form : +1 life)
SHIP_SPD        equ     4               ; ship speed
SHIP_XMAX       equ     145             ; ship limits (world units)
SHIP_YMAX       equ     105
SHIP_Z          equ     300             ; depth of the ship / enemies (front face)
INVUL_T         equ     90              ; invulnerability after a hit (frames)
FORM_MAX        equ     2               ; forms 0 probe, 1 fighter, 2 heavy

FPS_DIV         equ     2               ; a picture every 2 VBL : 30 / s on VGA 60 Hz
MAX_STEPS       equ     3               ; late picture : up to 3 game steps (same speed)

; --- shots
MAXB            equ     32              ; bullets on screen
BUL_SPD         equ     10
FIRE_T0         equ     6               ; frames between two shots (form 0, 1)
FIRE_T2         equ     6               ; (form 2 : 3 bullets)

; --- enemies / bonus
MAXE            equ     16              ; enemies on screen
WAVE_T          equ     24              ; frames between two enemies
EN_SPD0         equ     3               ; drone : speed down
EN_SPD1         equ     2               ; cruiser : speed down
BON_SPD         equ     2               ; bonus pod : falling speed
EN_HP0          equ     1               ; drone : hit points
EN_HP1          equ     2               ; cruiser (floppy disk)
PTS_EN0         equ     100
PTS_EN1         equ     200
PTS_BONUS       equ     500
BONUS_EVERY     equ     8               ; a bonus pod every 8 enemies killed
HIT_R           equ     12              ; contact radius ship / enemy / bonus
BUL_R           equ     8               ; bullet / enemy

; --- scenery
SCROLL_SPD8     equ     256             ; ground : 1/256 pixels per frame (256 = 1 px)
LT_VBL          equ     240             ; level name screen : VBL shown (fire : shorter)
BAKE_MAX        equ     1               ; components baked per frame (spread : no peaks)
BAKE_NEAR       equ     232             ; ... more if one is this near the screen top (lines)

; --- attack zones (W lines in LEVELn.MAP, ZONES.S : the ground stops, waves come)
MAXAZ           equ     8               ; zones max per level
AZ_Y            equ     100             ; the zone starts when its row is at this line
AZ_WAVES        equ     6               ; waves per zone (W row [waves])
AZ_FIRST        equ     40              ; frames before the 1st wave
AZ_GAP          equ     45              ; frames between two waves
AZ_PTS          equ     2000            ; points when the zone is cleared
AZ_MSG_T        equ     60              ; "INCOMING !" / "ZONE CLEARED" (frames)
AZ_TY           equ     110             ; line of that message

; --- bosses (big chips named *xxx in LEVELn.MAP : the ground stops)
MAXBOSS         equ     8               ; bosses max per level
BOSS_Y          equ     80              ; the fight starts when its centre is at this line
BOSS_HP         equ     60              ; hits to destroy it
BOSS_FIRE_T     equ     24              ; frames between two volleys (3rd = fan of 5)
BOSS_RIP_T      equ     45              ; at least these frames on the board
BOSS_RIP_PC     equ     50              ; % of life left when it tears off
BOSS_RING       equ     16              ; shots all around it when it tears off
BOSS_RINGR      equ     34              ; radius where they start
BOSS_SCL        equ     10               ; size in the air : x BOSS_SCL / 16 of the chip
BOSS_SPD0       equ     160             ; its speed on the figure of eight (angle x 256)
BOSS_SPDK       equ     4               ;  + this per hit taken
BOSS_AX         equ     125             ; half width of the eight (minus its half size)
BOSS_AY         equ     22              ; half height
BOSS_TOP        equ     -92             ; its top at least here (world y)
PTS_BOSS        equ     5000
BOSS_MSG_T      equ     90              ; "xxx DEBUGGED" (frames)
MAXEB           equ     24              ; boss bullets on screen
EB_SPD          equ     3               ; their speed
EB_R            equ     6               ; boss bullet / ship
EB_COL          equ     $FC00           ; their colour (orange)
BAR_X0          equ     80              ; life bar : x, width, line
BAR_W           equ     160
BAR_Y           equ     30
; --- graphic effects (EFFETS.S)
MAXP            equ     64              ; particles (debris, flashes, sparks)
FLASH_T         equ     8               ; (flash : life)
PART_T          equ     8               ; debris : life 8 .. 23 steps
BOOM_SPD        equ     48              ; enemy debris : speed (x16)
SPARK_N         equ     36              ; boss debugged : sparks
SPARK_SPD       equ     80
SH_DX           equ     18              ; ship shadow : offset (world) and depth
SH_DY           equ     16
SH_Z            equ     372
NPULSE          equ     14              ; light pulses on the tracks
MAXRUN          equ     400             ; straight tracks noted
PULSE_MIN       equ     3               ; (tiles : shortest track)
PULSE_SPD       equ     4               ; speed 4 .. 7 pixels per step
PULSE_LEN       equ     20              ; tail (pixels)
PULSE_COL       equ     $FFFF           ; head
PULSE_TAIL      equ     $07FF           ; tail (mixed 50 %)
FIX_COL         equ     $07E0           ; debugged chip : green halo + LED
FIX_DIM         equ     $0200
GLOW_B          equ     $FFE0           ; player bullets : halo
TRAIL_B         equ     $FC00           ;  and trail
GLOW_EB         equ     $F800           ; boss bullets : halo
SPR_DX          equ     58              ; ship sprites : 5 places across (world x)
SPR_Y01         equ     -35             ;  and 3 along : py < -35 / < 40 / more
SPR_Y12         equ     40
EN_NX           equ     9               ; enemies precomputed : places in x
EN_DX           equ     30              ;  (world units apart : -120 .. 120)
EN_NY           equ     9               ;  places in y
EN_DY           equ     20              ;  (-80 .. 80 : inside the 240 lines)
VOL_START       equ     16              ; sound volume at start : 0 .. 64 (+ / - : 4)
TOP_H           equ     16              ; black band at the top (score, lives, FPS...)
CUT_DEF         equ     0               ; split screen at the start (key C) : 1 = on
CUT_LPL         equ     1               ; Timer B events per line in VGA (real Falcon : 1)
CUT_MARG        equ     64              ; black lines under the band buffer (late Timer B)
SFX_GAIN        equ     8               ; YM (ADC input) gain : 0 .. 15 x 1.5 dB (8 = +12 dB)
VOL_T           equ     45              ; volume bar shown (frames) after + / -
TILE_PX         equ     20              ; ground tile (pixels)
GROUND_Z        equ     400             ; depth of the ground (components stand on it)

; --- camera / screen (do not change without the code)
CX              equ     160
CY              equ     120
FOC             equ     320             ; same projection as R3D.A56
SCR_W           equ     320
SCR_H           equ     240
LINEB           equ     1600            ; bytes per line of the buffers : 800 pixels
                                        ;  (the map can be wider than the screen : the
                                        ;  VIDEL skips LINEB-640 bytes after each line,
                                        ;  $FFFF820E, 9 bits -> 40 columns max)
SCRSZ           equ     SCR_H*LINEB
VMODE_VGA       equ     $0114           ; 320x240 16 bits VGA (line doubling)
VMODE_RGB       equ     $0024           ; 320x200 16 bits RGB/TV (bottom cut)
MSG_DUR         equ     120

; --- bottom bar (H key), like RICK3D
BAND_H          equ     15              ; height (2 lines of 6x6)
TXT_Y           equ     SCR_H-BAND_H    ; top of the bar
COLS            equ     53              ; characters per line (53 x 6 = 318 pixels)
LINEW           equ     54              ; (bytes of a line of text)

; --- level map (CARTE.S, LEVEL1.MAP from OUTILS\EDITEUR.HTML)
MAP_MAXROWS     equ     1500            ; rows max
MAP_MAXCOLS     equ     40              ; columns max (40 x 20 = 800 pixels = LINEB / 2)
NB_TILES        equ     24              ; tiles in a PCBTxxx.BIN (OUTILS\MKTILES.PY)
RECAP_PC        equ     80              ; % of the enemies to destroy : else the level again
NB_LEVELS       equ     4               ; LEVEL1.MAP .. LEVEL4.MAP (130 XE, ST, STE, Falcon)
MAP_DEFROWS     equ     300             ; bare board if no LEVEL1.MAP
MAXCOMP         equ     800             ; components max
LBL_LEN         equ     12              ; component name ("C P 3 10 68030") : 11 chars + 0
LBL_COL         equ     $C618           ; colour of the names printed on the chips
LBL_BG          equ     $18C3           ; dark band under the names
LBL_Z           equ     386             ; depth of the top of the chips (names)
LBL_ZF          equ     386             ; (68030 : chip, no fan now)
BK_KEY          equ     $F81F           ; colour key (magenta) : baking the components
FILE_MAX        equ     65536           ; size max of LEVEL1.MAP

; --- music (MUSIQUE.S) : ZIK\ELYSIUM.MOD (DSP) in the levels, ZIK\PWRBOAT.ORG (YM) in the menu
MUS_VOL         equ     8               ; module volume (0 .. 64)
MENU_XDIV       equ     2               ; menu X logo : VBL per rotation step (1 = 2x faster)
REPFREQ         equ     2               ; DSP replay : 2 = 32780 Hz
WORKSZ          equ     20832           ; (work area of the replay : do not touch)
YMZ_MAX         equ     16384           ; YM tune : size max of the file
YMZ_TUNE        equ     1               ; YM tune : number of the tune (d0 of its init)

; --- sound effects (SFX.S, YM2149) : SFX n plays effect n, registers kept
SFX             macro
                move.l  d0,-(sp)
                moveq   #\1,d0
                bsr     sfx_play
                move.l  (sp)+,d0
                endm

; effect numbers
SFX_SHOT        equ     0
SFX_BOOM        equ     1
SFX_HIT         equ     2
SFX_BONUS       equ     3
SFX_ALARM       equ     4
SFX_BHIT        equ     5
SFX_BSHOT       equ     6
SFX_FIXED       equ     7

