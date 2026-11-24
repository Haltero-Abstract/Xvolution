;=====================================================================
; MENU.S - LEVEL MENU (like RICK3D's MENUS.S)
;   (included by SHOTEMUP.S)
;
; 4 levels = the evolution of the Atari computers : the map of each one is
; LEVELn.MAP (a level without its file is grey and cannot be chosen).
; Up / down (arrows or joystick port 1), SPACE / RETURN / fire = play,
; ESC = back to the desktop.  -> d0 = level 1..4, or -1
; (the sources of the 4 boards are credited in CREDITS.TXT)
;=====================================================================

MN_X            equ     40                      ; left of the items
MN_Y0           equ     92                      ; 1st item
MN_DY           equ     24                      ; between items
KEY_RET         equ     $1C
MXR_WIRE        equ     0                       ; mx_rend : how the X is drawn
MXR_FLAT        equ     1
MXR_CEL         equ     2
MXR_GOUR        equ     3
MNC_BG           equ     $1144                   ; colours : dark board green
MNC_TITLE        equ     $FFE0                   ;  yellow title
MNC_TEXT         equ     $FFFF                   ;  white
MNC_SEL         equ     $07E0                   ;  green : selected
MNC_GREY         equ     $8C51                   ;  grey : no map / help

; the X logo of 3Dreams turning behind the text : same object (XLOGO3D.S,
;   outils\X3GEN.PY), same 16-colour flat shading, same rotation (ax = az = t,
;   ay = 2t) and same curve as the demo (mpath : x = ax sin(3t/4),
;   y = ay cos(5t/4)), same projection (x*256/(z+300)), t : one per MENU_XDIV VBL
MX_D            equ     300                     ; distance to the viewer
MXK_AX           equ     95                      ; amplitudes of 3Dreams in 16 colours :
MXK_AY           equ     15                      ;  156 - radius, free half height - radius
MXK_CY           equ     112                     ; centre : line 92 of 200 (+ 20 : 240 lines)

; MXROT a,b,sin,cos :  a' = a*cos - b*sin ;  b' = a*sin + b*cos  (x 2^14)
MXROT           macro
                move.w  \1,d3
                muls    \4,d3
                move.w  \2,d4
                muls    \3,d4
                sub.l   d4,d3
                asl.l   #2,d3
                swap    d3
                move.w  \1,d4
                muls    \3,d4
                move.w  \2,d5
                muls    \4,d5
                add.l   d5,d4
                asl.l   #2,d4
                swap    d4
                move.w  d3,\1
                move.w  d4,\2
                endm

menu:
                movem.l d1-d7/a0-a6,-(sp)
                st      vol_inmenu              ; volume : the YM tune (SFX.S)
                bsr     vol_apply
                move.l  bufd0+BF_ADR,scr_show
                bsr     mn_avail                ; which LEVELn.MAP exist
                move.w  cur_level,d0            ; selection : the last level
                bsr     mn_fix
                move.w  d0,mn_sel
                bsr     mx_init
                move.w  #MNC_BG,mx_bgc          ; (background of M)
                move.w  #MXR_GOUR,mx_rend       ; Gouraud (DSP ; else flat)
                bsr     mxd_on                  ; DSP : 3Dreams (Gouraud)
                move.l  bufd2+BF_ADR,a6         ; menu without the X : in D2 (M)
                bsr     mn_draw
                bsr     mx_scan
                move.l  bufd2+BF_ADR,a1         ; -> D0 and D1 (the X : drawn in
                move.l  bufd0+BF_ADR,a0         ;  them in turn, mx_frame)
                bsr     mx_copyall
                move.l  bufd1+BF_ADR,a0
                bsr     mx_copyall
                move.w  #-1,-(sp)               ; D0 shown
                move.l  bufd0+BF_ADR,-(sp)
                move.l  #-1,-(sp)
                move.w  #5,-(sp)
                trap    #14
                lea     12(sp),sp
                move.w  #37,-(sp)               ; Vsync : the menu is shown now,
                trap    #14                     ;  with its lines of LINEB bytes
                addq.l  #2,sp
                move.w  #(LINEB-SCR_W*2)/2,$ffff820e.w
                lea     keyhit,a0               ; (old presses forgotten)
                moveq   #128/4-1,d0
.kc:            clr.l   (a0)+
                dbra    d0,.kc
                move.b  joy1,mn_joy
                move.l  vbl_cnt,mx_vbl
.loop:          bsr     mx_frame                ; X turning + Vsync
                lea     keyhit,a0
                move.b  joy1,d1                 ; joystick : new bits only
                move.b  mn_joy,d2
                move.b  d1,mn_joy
                not.b   d2
                and.b   d2,d1
                bsr     vol_keys                ; + / - : volume (SFX.S)
                tst.b   KEY_ESC(a0)
                bne     .quit
                moveq   #0,d0                   ; d0 : -1 up, +1 down
                tst.b   KEY_UP(a0)
                beq.s   .u1
                moveq   #-1,d0
.u1:            btst    #0,d1
                beq.s   .u2
                moveq   #-1,d0
.u2:            tst.b   KEY_DN(a0)
                beq.s   .d1
                moveq   #1,d0
.d1:            btst    #1,d1
                beq.s   .d2
                moveq   #1,d0
.d2:            tst.b   KEY_SPC(a0)
                bne.s   .go
                tst.b   KEY_RET(a0)
                bne.s   .go
                btst    #7,d1
                bne.s   .go
                movem.l d0-d1/a0,-(sp)          ; presses used
                lea     keyhit,a0
                moveq   #128/4-1,d1
.kz:            clr.l   (a0)+
                dbra    d1,.kz
                movem.l (sp)+,d0-d1/a0
                tst.w   d0
                beq.s   .loop
                move.w  mn_sel,d2               ; next available level
                moveq   #NB_LEVELS-1,d3
.mv:            add.w   d0,d2
                cmp.w   #1,d2
                bge.s   .m1
                move.w  #NB_LEVELS,d2
.m1:            cmp.w   #NB_LEVELS,d2
                ble.s   .m2
                moveq   #1,d2
.m2:            lea     mn_ok,a1
                tst.b   -1(a1,d2.w)
                bne.s   .m3
                dbra    d3,.mv
                bra     .loop
.m3:            move.w  d2,mn_sel
                move.l  bufd2+BF_ADR,a6         ; new menu picture : M, then
                bsr     mn_draw                 ;  the whole of both screens
                bsr     mx_scan
                move.l  #$00010001,mx_full
                bra     .loop
.go:            move.w  mn_sel,d0
                lea     mn_ok,a1
                tst.b   -1(a1,d0.w)
                beq     .loop                   ; (no map : not playable)
                bra.s   .x
.quit:          moveq   #-1,d0
.x:             bsr     mxd_off                 ; DSP : R3D again (game)
                sf      vol_inmenu              ; in game : the module only
                bsr     vol_apply
                lea     keyhit,a0
                moveq   #128/4-1,d1
.kx:            clr.l   (a0)+
                dbra    d1,.kx
                movem.l (sp)+,d1-d7/a0-a6
                rts

; mn_fix : d0 = level -> an available one (or 1)
mn_fix:
                lea     mn_ok,a1
                cmp.w   #1,d0
                blt.s   .f
                cmp.w   #NB_LEVELS,d0
                bgt.s   .f
                tst.b   -1(a1,d0.w)
                bne.s   .x
.f:             moveq   #1,d0
.l:             tst.b   -1(a1,d0.w)
                bne.s   .x
                addq.w  #1,d0
                cmp.w   #NB_LEVELS,d0
                ble.s   .l
                moveq   #1,d0
.x:             rts

; mn_avail : mn_ok[n-1] = 1 if LEVELn.MAP exists (Fsfirst)
mn_avail:
                movem.l d0-d2/a0-a1,-(sp)
                moveq   #1,d2
.l:             move.w  d2,d0
                add.b   #'0',d0
                move.b  d0,map_name+5
                clr.w   -(sp)                   ; Fsfirst(name, 0)
                pea     map_name
                move.w  #$4e,-(sp)
                trap    #1
                addq.l  #8,sp
                lea     mn_ok,a0
                tst.l   d0
                seq     -1(a0,d2.w)
                addq.w  #1,d2
                cmp.w   #NB_LEVELS,d2
                ble.s   .l
                movem.l (sp)+,d0-d2/a0-a1
                rts

; mn_draw : the whole menu picture in a6
mn_draw:
                movem.l d0-d7/a0-a5,-(sp)
                move.l  a6,a0                   ; background : dark green
                move.l  #MNC_BG<<16|MNC_BG,d1
                move.w  #SCR_H-1,d7
.cy:            move.l  a0,a2
                move.w  #SCR_W/2-1,d0
.cx:            move.l  d1,(a2)+
                dbra    d0,.cx
                lea     LINEB(a0),a0
                dbra    d7,.cy
                lea     mn_title,a0             ; title (x3)
                move.w  #160-9*9,d0
                moveq   #16,d1
                move.w  #MNC_TITLE,d2
                moveq   #3,d3
                bsr     big_text
                moveq   #1,d6                   ; the 4 levels (x2)
                lea     mn_items,a2
.it:            move.w  d6,d1
                subq.w  #1,d1
                mulu    #MN_DY,d1
                add.w   #MN_Y0,d1
                move.w  #MNC_TEXT,d2
                lea     mn_ok,a1
                tst.b   -1(a1,d6.w)
                bne.s   .i1
                move.w  #MNC_GREY,d2
.i1:            cmp.w   mn_sel,d6
                bne.s   .i2
                move.w  #MNC_SEL,d2
                lea     mn_arrow,a0
                move.w  #MN_X-16,d0
                moveq   #2,d3
                movem.l d1-d2,-(sp)
                bsr     big_text
                movem.l (sp)+,d1-d2
.i2:            move.l  a2,a0
                move.w  #MN_X,d0
                moveq   #2,d3
                bsr     big_text
                lea     mn_ok,a1
                tst.b   -1(a1,d6.w)
                bne.s   .i3
                lea     mn_nomap,a0             ; (no file)
                move.w  #MN_X+6*2*24,d0
                move.w  #MNC_GREY,d2
                bsr     big_text
.i3:            tst.b   (a2)+                   ; next string
                bne.s   .i3
                addq.w  #1,d6
                cmp.w   #NB_LEVELS,d6
                ble.s   .it
                lea     mn_keys,a0              ; keys (x1)
                moveq   #8,d0
                move.w  #210,d1
                move.w  #MNC_GREY,d2
                moveq   #1,d3
                bsr     big_text
                movem.l (sp)+,d0-d7/a0-a5
                rts

; big_text : string a0 at d0,d1 in a6 (6x6 TOS font, pixels d3 x d3,
;   colour d2)
big_text:
                movem.l d0-d7/a0-a5,-(sp)
                move.w  d0,d7                   ; x
.ch:            moveq   #0,d0
                move.b  (a0)+,d0
                beq     .x
                cmp.w   #' ',d0
                bls     .nc
                sub.w   fontfirst,d0
                bmi     .nc
                add.w   d0,d0
                move.l  fontoff,a1
                move.w  (a1,d0.w),d4            ; x of the character (bits)
                move.w  d4,d0
                lsr.w   #3,d0
                move.l  fontdat,a1
                adda.w  d0,a1
                and.w   #7,d4
                moveq   #0,d5
                move.w  d1,d5
                mulu    #LINEB,d5
                lea     (a6,d5.l),a3            ; line of the character
                move.w  d7,d5
                add.w   d5,d5
                adda.w  d5,a3
                moveq   #5,d6                   ; 6 lines
.fl:            move.b  (a1),d5
                lsl.w   #8,d5
                move.b  1(a1),d5
                lsl.w   d4,d5
                move.l  a3,a4
                moveq   #5,d0                   ; 6 pixels
.pb:            add.w   d5,d5
                bcc.s   .p0
                move.l  a4,a5                   ; a d3 x d3 square
                move.w  d3,-(sp)
                subq.w  #1,(sp)
.sy:            move.w  d3,-(sp)
                subq.w  #1,(sp)
                move.l  a5,-(sp)
.sx:            move.w  d2,(a5)+
                subq.w  #1,4(sp)
                bpl.s   .sx
                move.l  (sp)+,a5
                addq.l  #2,sp
                lea     LINEB(a5),a5
                subq.w  #1,(sp)
                bpl.s   .sy
                addq.l  #2,sp
.p0:            adda.w  d3,a4
                adda.w  d3,a4
                dbra    d0,.pb
                move.w  d3,d0                   ; next line of the font : d3 lines
                mulu    #LINEB,d0
                adda.l  d0,a3
                adda.w  fontw,a1
                dbra    d6,.fl
.nc:            move.w  d3,d0                   ; next character : 6 x d3
                mulu    #6,d0
                add.w   d0,d7
                bra     .ch
.x:             movem.l (sp)+,d0-d7/a0-a5
                rts

;---------------------------------------------------------------------
; THE TURNING X (code of 3Dreams : gensin, mkmat, transform, mpath,
;   bsprank, drawsolid in 16 colours ; here in True Color, behind the text)
;---------------------------------------------------------------------

; mx_init : sine table (gensin of 3Dreams), time 0, amplitudes 0
mx_init:
                movem.l d0-d7/a0,-(sp)
                lea     mx_sin,a0
                moveq   #0,d0                   ; s
                move.w  #16384,d1               ; c
                moveq   #13,d3
                move.w  #255,d7
.g:             move.w  d0,(a0)+
                move.w  d1,d2
                muls    #201,d2
                asr.l   d3,d2
                add.w   d2,d0
                move.w  d0,d2
                muls    #201,d2
                asr.l   d3,d2
                sub.w   d2,d1
                dbra    d7,.g
                clr.w   mx_t
                clr.w   mx_acc
                clr.w   mx_fr
                clr.w   mx_ax
                clr.w   mx_ay
                move.w  #1,mx_back              ; D0 shown : D1 drawn first
                clr.l   mx_full
                move.w  #-1,mx_bb
                move.w  #-1,mx_bb+8
                lea     mx_seen,a0
                move.w  #X3_NF-1,d0
.s:             move.w  #-9,(a0)+
                dbra    d0,.s
                movem.l (sp)+,d0-d7/a0
                rts

; mx_getsc : d0 = angle (256 = one turn) -> d1 = sin, d2 = cos (x 2^14)
mx_getsc:
                move.l  a0,-(sp)
                lea     mx_sin,a0
                and.w   #255,d0
                add.w   d0,d0
                move.w  (a0,d0.w),d1
                add.w   #128,d0
                and.w   #511,d0
                move.w  (a0,d0.w),d2
                move.l  (sp)+,a0
                rts

; mx_copyall : the whole picture a1 (M) -> a0
mx_copyall:
                movem.l d0-d1/a0-a2,-(sp)
                move.w  #SCR_H-1,d1
.y:             move.l  a0,a2
                move.w  #SCR_W/2-1,d0
.x:             move.l  (a1)+,(a2)+
                dbra    d0,.x
                lea     LINEB(a0),a0
                lea     LINEB-SCR_W*2(a1),a1
                dbra    d1,.y
                movem.l (sp)+,d0-d1/a0-a2
                rts

; mx_scan : mx_txt[y] = 1 if line y of M has text (the X goes under it)
mx_scan:
                movem.l d0-d3/a0-a2,-(sp)
                move.w  mx_bgc,d3
                move.l  bufd2+BF_ADR,a0
                lea     mx_txt,a1
                move.w  #SCR_H-1,d1
.y:             move.l  a0,a2
                move.w  #SCR_W-1,d0
                moveq   #0,d2
.x:             cmp.w   (a2)+,d3
                dbne    d0,.x
                beq.s   .n
                moveq   #1,d2
.n:             move.b  d2,(a1)+
                lea     LINEB(a0),a0
                dbra    d1,.y
                movem.l (sp)+,d0-d3/a0-a2
                rts

; mx_frame : one picture of the X in the hidden screen, shown at the next
;   VBL (Setscreen + Vsync : replaces the Vsync of the menu loop)
mx_frame:
                movem.l d0-d7/a0-a6,-(sp)
                move.l  vbl_cnt,d0              ; time : one step every MENU_XDIV
                move.l  d0,d1                   ;  VBL (PARAMS.S)
                sub.l   mx_vbl,d0
                move.l  d1,mx_vbl
                cmp.l   #8,d0
                bls.s   .t0
                moveq   #8,d0
.t0:            add.w   mx_acc,d0               ; (rest kept)
                ext.l   d0
                divu    #MENU_XDIV,d0
                swap    d0
                move.w  d0,mx_acc
                swap    d0
                subq.w  #1,d0
                bmi.s   .t9
.t1:            addq.w  #1,mx_t
                move.w  mx_ax,d1                ; amplitudes : 2 pixels per
                addq.w  #2,d1                   ;  frame up to theirs (curax)
                cmp.w   #MXK_AX,d1
                ble.s   .t2
                move.w  #MXK_AX,d1
.t2:            move.w  d1,mx_ax
                move.w  mx_ay,d1
                addq.w  #2,d1
                cmp.w   #MXK_AY,d1
                ble.s   .t3
                move.w  #MXK_AY,d1
.t3:            move.w  d1,mx_ay
                dbra    d0,.t1
.t9:            move.w  mx_back,d7              ; a4 = screen drawn, a5 = M
                move.l  bufd0+BF_ADR,a4
                tst.w   d7
                beq.s   .b0
                move.l  bufd1+BF_ADR,a4
.b0:            move.l  bufd2+BF_ADR,a5
                lea     mx_bb,a3                ; its last X : erased (M)
                move.w  d7,d0
                lsl.w   #3,d0
                adda.w  d0,a3
                lea     mx_full,a2
                adda.w  d7,a2
                adda.w  d7,a2
                tst.w   (a2)
                beq.s   .r1
                clr.w   (a2)
                move.l  a4,a0
                move.l  a5,a1
                bsr     mx_copyall
                bra.s   .r2
.r1:            bsr     mx_restore
.r2:            bsr     mx_matrix
                bsr     mx_path
                tst.w   mx_dsp                  ; vertices : by the DSP
                beq.s   .r3
                bsr     mxd_xform
                tst.w   mx_dsp
                beq.s   .r3
                bsr     mx_bbox
                bra.s   .r4
.r3:            bsr     mx_verts                ;  or by the 030
.r4:            bsr     mx_bsp
                bsr     mx_faces
                move.w  #-1,-(sp)               ; Setscreen(-1,a4,-1) + Vsync
                move.l  a4,-(sp)
                move.l  #-1,-(sp)
                move.w  #5,-(sp)
                trap    #14
                lea     12(sp),sp
                move.w  #37,-(sp)
                trap    #14
                addq.l  #2,sp
                eor.w   #1,mx_back
                addq.w  #1,mx_fr
                movem.l (sp)+,d0-d7/a0-a6
                rts

; mx_restore : rectangle (a3) of M (a5) -> screen a4
mx_restore:
                movem.l d0-d4/a0-a2/a6,-(sp)
                movem.w (a3),d0-d3              ; x0 y0 x1 y1
                tst.w   d0
                bmi.s   .x
                and.w   #-2,d0                  ; even columns : longs
                addq.w  #1,d2
                and.w   #-2,d2
                sub.w   d0,d2
                lsr.w   #1,d2
                subq.w  #1,d2
                bmi.s   .x
                sub.w   d1,d3
                subq.w  #1,d3
                bmi.s   .x
                mulu    #LINEB,d1
                add.w   d0,d0
                ext.l   d0
                add.l   d0,d1
                lea     (a4,d1.l),a0
                lea     (a5,d1.l),a1
.y:             move.l  a0,a2
                move.l  a1,a6
                move.w  d2,d4
.c:             move.l  (a6)+,(a2)+
                dbra    d4,.c
                lea     LINEB(a0),a0
                lea     LINEB(a1),a1
                dbra    d3,.y
.x:             movem.l (sp)+,d0-d4/a0-a2/a6
                rts

; mx_matrix : angles ax = az = t, ay = 2t -> matrix (mkmat : the axes
;   turned about y, x then z), eye (0,0,-300) in the frame of the object
;   (bsprank : rotations -z, -x, -y)
mx_matrix:
                movem.l d0-d5/a0-a1,-(sp)
                move.w  mx_t,d0
                bsr     mx_getsc
                move.w  d1,mx_sx
                move.w  d2,mx_cx
                neg.w   d1
                move.w  d1,mx_nsx
                move.w  mx_t,d0
                add.w   d0,d0
                bsr     mx_getsc
                move.w  d1,mx_sy
                move.w  d2,mx_cy
                neg.w   d1
                move.w  d1,mx_nsy
                lea     mx_m,a1
                move.w  #16384,d0               ; x axis -> column 0
                moveq   #0,d1
                moveq   #0,d2
                bsr.w   .rot
                move.w  d0,(a1)
                move.w  d1,6(a1)
                move.w  d2,12(a1)
                moveq   #0,d0                   ; y axis -> column 1
                move.w  #16384,d1
                moveq   #0,d2
                bsr.w   .rot
                move.w  d0,2(a1)
                move.w  d1,8(a1)
                move.w  d2,14(a1)
                moveq   #0,d0                   ; z axis -> column 2
                moveq   #0,d1
                move.w  #16384,d2
                bsr.w   .rot
                move.w  d0,4(a1)
                move.w  d1,10(a1)
                move.w  d2,16(a1)
                moveq   #0,d0                   ; eye
                moveq   #0,d1
                move.w  #-MX_D,d2
                MXROT   d0,d1,mx_nsx,mx_cx
                MXROT   d1,d2,mx_nsx,mx_cx
                MXROT   d2,d0,mx_nsy,mx_cy
                movem.w d0-d2,mx_eye
                lea     mx_m,a0                 ; light : lo_j = column j . L
                lea     mx_lo,a1
                moveq   #2,d5
.lo:            move.w  (a0),d0
                muls    #MX_LX,d0
                move.w  6(a0),d1
                muls    #MX_LY,d1
                add.l   d1,d0
                move.w  12(a0),d1
                muls    #MX_LZ,d1
                add.l   d1,d0
                asl.l   #2,d0
                swap    d0
                move.w  d0,(a1)+
                addq.l  #2,a0
                dbra    d5,.lo
                movem.l (sp)+,d0-d5/a0-a1
                rts
.rot:           MXROT   d2,d0,mx_sy,mx_cy
                MXROT   d1,d2,mx_sx,mx_cx
                MXROT   d0,d1,mx_sx,mx_cx
                rts

; mx_path : centre on the screen (mpath : x = ax sin(3t/4), y = ay cos(5t/4))
mx_path:
                movem.l d0-d2,-(sp)
                moveq   #0,d0
                move.w  mx_t,d0
                mulu    #3,d0
                lsr.l   #2,d0
                bsr     mx_getsc
                muls    mx_ax,d1
                asr.l   #8,d1
                asr.l   #6,d1
                add.w   #SCR_W/2,d1
                move.w  d1,mx_px
                moveq   #0,d0
                move.w  mx_t,d0
                mulu    #5,d0
                lsr.l   #2,d0
                add.w   #64,d0
                bsr     mx_getsc
                muls    mx_ay,d1
                asr.l   #8,d1
                asr.l   #6,d1
                add.w   #MXK_CY,d1
                move.w  d1,mx_py
                movem.l (sp)+,d0-d2
                rts

; mx_verts : vertices turned, projected (x*256/(z+300)) -> mx_p ;
;   rectangle of the X -> (a3)
mx_verts:
                movem.l d0-d7/a0-a2,-(sp)
                lea     x3_v,a0
                lea     mx_p,a1
                lea     mx_m,a2
                move.w  #X3_NV-1,d7
.v:             movem.w (a0)+,d0-d2
                move.w  d0,d3                   ; x'
                muls    (a2),d3
                move.w  d1,d4
                muls    2(a2),d4
                add.l   d4,d3
                move.w  d2,d4
                muls    4(a2),d4
                add.l   d4,d3
                asl.l   #2,d3
                swap    d3
                move.w  d0,d5                   ; y'
                muls    6(a2),d5
                move.w  d1,d4
                muls    8(a2),d4
                add.l   d4,d5
                move.w  d2,d4
                muls    10(a2),d4
                add.l   d4,d5
                asl.l   #2,d5
                swap    d5
                muls    12(a2),d0               ; z'
                muls    14(a2),d1
                add.l   d1,d0
                muls    16(a2),d2
                add.l   d2,d0
                asl.l   #2,d0
                swap    d0
                add.w   #MX_D,d0
                ext.l   d3
                asl.l   #8,d3
                divs    d0,d3
                add.w   mx_px,d3
                bpl.s   .x0
                moveq   #0,d3
.x0:            cmp.w   #SCR_W-1,d3
                ble.s   .x1
                move.w  #SCR_W-1,d3
.x1:            move.w  d3,(a1)+
                ext.l   d5
                asl.l   #8,d5
                divs    d0,d5
                add.w   mx_py,d5
                bpl.s   .y0
                moveq   #0,d5
.y0:            cmp.w   #SCR_H-1,d5
                ble.s   .y1
                move.w  #SCR_H-1,d5
.y1:            move.w  d5,(a1)+
                dbra    d7,.v
                movem.l (sp)+,d0-d7/a0-a2
; mx_bbox : rectangle of the X (mx_p) -> (a3)
mx_bbox:
                movem.l d0-d7/a0-a2,-(sp)
                lea     mx_p,a1                 ; rectangle
                move.w  #SCR_W,d0
                move.w  #SCR_H,d1
                moveq   #-1,d2
                moveq   #-1,d3
                move.w  #X3_NV-1,d7
.b:             movem.w (a1)+,d4-d5
                cmp.w   d0,d4
                bge.s   .b1
                move.w  d4,d0
.b1:            cmp.w   d2,d4
                ble.s   .b2
                move.w  d4,d2
.b2:            cmp.w   d1,d5
                bge.s   .b3
                move.w  d5,d1
.b3:            cmp.w   d3,d5
                ble.s   .b4
                move.w  d5,d3
.b4:            dbra    d7,.b
                addq.w  #1,d2
                addq.w  #1,d3
                movem.w d0-d3,(a3)
                movem.l (sp)+,d0-d7/a0-a2
                rts

; mx_bsp : order of the faces (the farthest first) : BSP tree of the
;   object (T lines, bspwalk of 3Dreams)
mx_bsp:
                movem.l d0-d3/a0-a1,-(sp)
                lea     mx_ord,a1
                moveq   #0,d0
                bsr.s   .walk
                move.l  a1,mx_oend
                movem.l (sp)+,d0-d3/a0-a1
                rts
.walk:          tst.w   d0                      ; d0 = node (-1 : none)
                bmi.s   .out
                mulu    #20,d0
                lea     x3_t,a0
                adda.l  d0,a0
                move.l  a0,-(sp)
                movem.w mx_eye,d1-d3            ; n . eye - d
                muls    8(a0),d1
                muls    10(a0),d2
                add.l   d2,d1
                muls    12(a0),d3
                add.l   d3,d1
                sub.l   16(a0),d1
                bgt.s   .dev
                move.w  4(a0),d0                ; eye behind : front side first
                bsr.s   .walk
                move.l  (sp),a0
                bsr.s   .emit
                move.l  (sp),a0
                move.w  6(a0),d0
                bsr.s   .walk
                bra.s   .dn
.dev:           move.w  6(a0),d0                ; eye in front : back side first
                bsr.s   .walk
                move.l  (sp),a0
                bsr.s   .emit
                move.l  (sp),a0
                move.w  4(a0),d0
                bsr.s   .walk
.dn:            addq.l  #4,sp
.out:           rts
.emit:          move.w  (a0),d0
                move.w  2(a0),d1
                subq.w  #1,d1
.e:             move.w  d0,(a1)+
                addq.w  #1,d0
                dbra    d1,.e
                rts

; mx_faces : the faces in the order of mx_ord : seen (sign of the area on
;   the screen), shade of |nz| (levels 0..13, hysteresis), colour
;   1 + material*7 + level/2 (matpal, 2 materials), filled
mx_faces:
                movem.l d0-d7/a0-a3,-(sp)
                move.l  #mx_ord,mx_op
.f:             move.l  mx_op,a0
                cmp.l   mx_oend,a0
                bhs     .x
                move.w  (a0)+,d6
                move.l  a0,mx_op
                move.w  d6,d0
                mulu    #20,d0
                lea     x3_f,a3
                adda.l  d0,a3
                lea     10(a3),a1               ; area (x 2) : sum x_i y_i+1 - x_i+1 y_i
                lea     mx_p,a2
                move.w  (a3),d7
                subq.w  #2,d7
                moveq   #0,d0
                move.b  (a1)+,d0
                lsl.w   #2,d0
                movem.w (a2,d0.w),d1-d2
                moveq   #0,d5
.s:             moveq   #0,d0
                move.b  (a1)+,d0
                lsl.w   #2,d0
                movem.w (a2,d0.w),d3-d4
                move.w  d1,d0
                muls    d4,d0
                add.l   d0,d5
                move.w  d3,d0
                muls    d2,d0
                sub.l   d0,d5
                move.w  d3,d1
                move.w  d4,d2
                dbra    d7,.s
                moveq   #0,d0
                move.b  10(a3),d0
                lsl.w   #2,d0
                movem.w (a2,d0.w),d3-d4
                move.w  d1,d0
                muls    d4,d0
                add.l   d0,d5
                move.w  d3,d0
                muls    d2,d0
                sub.l   d0,d5
                tst.l   d5                      ; visible if < 0
                bge     .f
                cmp.w   #MXR_GOUR,mx_rend       ; Gouraud by the DSP,
                bne.s   .nd
                bsr     mxd_face
                tst.w   d0
                beq     .f
.nd:
                movem.w 4(a3),d0-d2             ; nz turned
                lea     mx_m,a0
                muls    12(a0),d0
                muls    14(a0),d1
                add.l   d1,d0
                muls    16(a0),d2
                add.l   d2,d0
                asl.l   #2,d0
                swap    d0
                tst.w   d0
                bpl.s   .p
                neg.w   d0
.p:             mulu    #208,d0                 ; v = |nz| : 0..208
                moveq   #14,d1
                lsr.l   d1,d0
                cmp.w   #208,d0
                bls.s   .p1
                move.w  #208,d0
.p1:            lea     mx_seen,a0
                move.w  d6,d1
                add.w   d1,d1
                move.w  mx_fr,d2
                move.w  (a0,d1.w),d4
                move.w  d2,(a0,d1.w)
                subq.w  #1,d2
                lea     mx_lv,a0
                cmp.w   d4,d2
                bne.s   .new
                moveq   #0,d1                   ; seen in the last picture :
                move.b  (a0,d6.w),d1            ;  the level only changes when
                move.w  d1,d3                   ;  the light clearly crosses
                lsl.w   #4,d3                   ;  the boundary (no flicker)
                add.w   #12,d3
                cmp.w   d3,d0
                bls.s   .nup
                addq.w  #1,d1
                bra.s   .lv
.nup:           sub.w   #24,d3
                cmp.w   d3,d0
                bge.s   .lv
                subq.w  #1,d1
                bra.s   .lv
.new:           move.w  d0,d1
                addq.w  #8,d1
                lsr.w   #4,d1
.lv:            cmp.w   #13,d1
                bls.s   .lv2
                moveq   #13,d1
.lv2:           move.b  d1,(a0,d6.w)
                move.w  2(a3),d0                ; colour
                mulu    #7,d0
                lsr.w   #1,d1
                add.w   d1,d0
                addq.w  #1,d0
                add.w   d0,d0
                lea     x3_col,a0
                move.w  mx_rend,d2              ; wire / flat / cel
                beq.s   .wi
                cmp.w   #MXR_CEL,d2
                beq.s   .ce
                move.w  (a0,d0.w),mx_col        ; flat (and Gouraud without DSP)
                bsr     mx_poly
                bra     .f
.wi:            move.w  2(a3),d0                ; wire : the edges, its colour
                mulu    #7,d0                   ;  at its brightest
                addq.w  #7,d0
                add.w   d0,d0
                move.w  (a0,d0.w),mx_col
                bsr     mx_edges
                bra     .f
.ce:            move.w  2(a3),d0                ; cel : 3 tones (true colour)
                mulu    #3,d0                   ;  + black edges
                lea     mx_celt,a1
                moveq   #0,d2
                move.b  (a1,d1.w),d2
                add.w   d2,d0
                add.w   d0,d0
                lea     mx_celc,a0
                move.w  (a0,d0.w),mx_col
                bsr     mx_poly
                clr.w   mx_col
                bsr     mx_edges
                bra     .f
.x:             movem.l (sp)+,d0-d7/a0-a3
                rts

; mx_edges : the edges of face a3 in colour mx_col (screen a4, M a5)
mx_edges:
                movem.l d0-d7/a0-a2,-(sp)
                lea     10(a3),a1
                lea     mx_p,a2
                move.w  (a3),d7
                subq.w  #1,d7
.e:             moveq   #0,d0
                move.b  (a1)+,d0
                moveq   #0,d1
                move.b  (a1),d1
                tst.w   d7
                bne.s   .e1
                move.b  10(a3),d1
.e1:            lsl.w   #2,d0
                lsl.w   #2,d1
                movem.w (a2,d0.w),d2-d3
                movem.w (a2,d1.w),d4-d5
                bsr     mx_line
                dbra    d7,.e
                movem.l (sp)+,d0-d7/a0-a2
                rts

; mx_line : d2,d3 -> d4,d5 in colour mx_col (Bresenham, inside the screen
;   only ; on the lines with text only where M is the background)
mx_line:
                movem.l d0-d7/a0-a1,-(sp)
                move.w  d4,d0                   ; dx, sx
                sub.w   d2,d0
                moveq   #1,d6
                tst.w   d0
                bpl.s   .a
                neg.w   d0
                moveq   #-1,d6
.a:             move.w  d5,d1                   ; dy, sy
                sub.w   d3,d1
                moveq   #1,d7
                tst.w   d1
                bpl.s   .b
                neg.w   d1
                moveq   #-1,d7
.b:             move.w  d0,a0                   ; err = dx - dy
                sub.w   d1,a0
                neg.w   d1                      ; (d1 = -dy)
.l:             bsr.s   .pix
                cmp.w   d2,d4
                bne.s   .c
                cmp.w   d3,d5
                beq.s   .x
.c:             move.w  a0,a1                   ; e2 = 2 err
                add.w   a1,a1
                cmp.w   d1,a1                   ; e2 > -dy : x
                ble.s   .d
                add.w   d1,a0
                add.w   d6,d2
.d:             cmp.w   d0,a1                   ; e2 < dx : y
                bge.s   .l
                add.w   d0,a0
                add.w   d7,d3
                bra.s   .l
.x:             movem.l (sp)+,d0-d7/a0-a1
                rts
.pix:           cmp.w   #SCR_W,d2               ; (unsigned : < 0 too)
                bhs.s   .px
                cmp.w   #SCR_H,d3
                bhs.s   .px
                movem.l d0-d1/a1,-(sp)
                move.w  d3,d0
                mulu    #LINEB,d0
                move.w  d2,d1
                add.w   d1,d1
                add.w   d1,d0
                lea     mx_txt,a1
                tst.b   (a1,d3.w)
                beq.s   .p1
                move.w  (a5,d0.l),d1
                cmp.w   mx_bgc,d1
                bne.s   .p2
.p1:            move.w  mx_col,(a4,d0.l)
.p2:            movem.l (sp)+,d0-d1/a1
.px:            rts

; mx_poly : convex face a3 in colour mx_col, in screen a4 ; on the lines
;   with text, only where M (a5) is the background : the X under the text
mx_poly:
                movem.l d0-d7/a0-a6,-(sp)
                move.w  #9999,mx_y0
                move.w  #-1,mx_y1
                lea     10(a3),a1
                lea     mx_p,a2
                move.w  (a3),d7
                subq.w  #1,d7
.e:             moveq   #0,d0                   ; edge p -> q
                move.b  (a1)+,d0
                moveq   #0,d1
                move.b  (a1),d1
                tst.w   d7
                bne.s   .e1
                move.b  10(a3),d1               ; (last : back to vertex 0)
.e1:            lsl.w   #2,d0
                lsl.w   #2,d1
                movem.w (a2,d0.w),d2-d3         ; px py
                movem.w (a2,d1.w),d4-d5         ; qx qy
                cmp.w   d3,d5
                beq.s   .en                     ; (horizontal)
                bgt.s   .dn
                exg     d2,d4                   ; going up : from q, right table
                exg     d3,d5
                lea     mx_tr,a0
                bra.s   .ed
.dn:            lea     mx_tl,a0
.ed:            cmp.w   mx_y0,d3
                bge.s   .y0
                move.w  d3,mx_y0
.y0:            cmp.w   mx_y1,d5
                ble.s   .y1
                move.w  d5,mx_y1
.y1:            sub.w   d3,d5                   ; dy > 0
                sub.w   d2,d4                   ; dx
                swap    d4
                clr.w   d4
                ext.l   d5
                divs.l  d5,d4                   ; dx/dy (16.16)
                swap    d2
                move.w  #$8000,d2               ; x + 1/2
                add.w   d3,d3
                lea     (a0,d3.w),a0
                subq.w  #1,d5
.l:             swap    d2
                move.w  d2,(a0)+
                swap    d2
                add.l   d4,d2
                dbra    d5,.l
.en:            dbra    d7,.e
                move.w  mx_y0,d6                ; lines y0 .. y1-1
                move.w  mx_y1,d7
                sub.w   d6,d7
                subq.w  #1,d7
                bmi     .x
                lea     mx_tl,a0
                lea     mx_tr,a1
                move.w  d6,d0
                add.w   d0,d0
                adda.w  d0,a0
                adda.w  d0,a1
                lea     mx_txt,a6
                adda.w  d6,a6
                move.w  d6,d0
                mulu    #LINEB,d0
                lea     (a4,d0.l),a2            ; line in the screen
                lea     (a5,d0.l),a3            ;  and in M
                move.w  mx_col,d4
                move.w  d4,d5
                swap    d4
                move.w  d5,d4
                move.w  mx_bgc,d3
.r:             move.w  (a0)+,d0
                move.w  (a1)+,d1
                cmp.w   d0,d1
                bge.s   .r1
                exg     d0,d1
.r1:            sub.w   d0,d1                   ; pixels
                ble.s   .nx
                add.w   d0,d0
                lea     (a2,d0.w),a4
                tst.b   (a6)
                bne.s   .msk
                btst    #0,d1
                beq.s   .ev
                move.w  d4,(a4)+
.ev:            lsr.w   #1,d1
                subq.w  #1,d1
                bmi.s   .nx
.lp:            move.l  d4,(a4)+
                dbra    d1,.lp
                bra.s   .nx
.msk:           lea     (a3,d0.w),a5            ; text line : where M = background
                subq.w  #1,d1
.mk:            cmp.w   (a5)+,d3
                bne.s   .m1
                move.w  d4,(a4)
.m1:            addq.l  #2,a4
                dbra    d1,.mk
.nx:            lea     LINEB(a2),a2
                lea     LINEB(a3),a3
                addq.l  #1,a6
                dbra    d7,.r
.x:             movem.l (sp)+,d0-d7/a0-a6
                rts

;---------------------------------------------------------------------
; THE X BY THE DSP (Gouraud) : the DSP program of 3Dreams (3DREAMS.P56,
;   with Simplet's replay) is loaded for the menu instead of R3D ; the
;   030 sends the matrix (XFORM : vertices turned, projected, lit) then
;   each face (FACE / LINES : the DSP follows the edges and sends the
;   lines pixel by pixel in RGB565, from the ramps of the object).
;   Leaving the menu : Simplet + R3D again (d3dinit, d3dload).
;   No DSP : the X stays flat (16 colours) by the 030.
;---------------------------------------------------------------------
MXD_RAMPX       equ     $1000                   ; addresses in X of 3DREAMS.P56
MXD_RECIP       equ     $1700                   ; $7fffff / w
MXD_PRCP        equ     $1900                   ; 2^23 / d
MXD_VTX         equ     $2200                   ; vertices x,y,z,nx,ny,nz
MXD_BATCH       equ     40                      ; lines per exchange
MX_LX           equ     -6554                   ; light of 3Dreams (x 2^14)
MX_LY           equ     -9011
MX_LZ           equ     -11960

MXDW            macro                           ; sends \1 (a6 = $ffffa204)
.w\@:           btst    #1,$ffffa202.w
                beq.s   .w\@
                move.l  \1,(a6)
                endm
MXDWW           macro                           ; sends the word \1 (a5 = $ffffa206)
.w\@:           btst    #1,$ffffa202.w
                beq.s   .w\@
                move.w  \1,(a5)
                endm
MXDR            macro                           ; reads a word -> \1
.r\@:           btst    #0,$ffffa202.w
                beq.s   .r\@
                move.w  (a5),\1
                endm
MXDQ            macro                           ; word x 2^14 -> x 2^23, clamped
                move.w  \1,d0
                ext.l   d0
                asl.l   #8,d0
                add.l   d0,d0
                cmp.l   #$7fffff,d0
                ble.s   .a\@
                move.l  #$7fffff,d0
.a\@:           cmp.l   #-$800000,d0
                bge.s   .q\@
                move.l  #-$800000,d0
.q\@:           MXDW    d0
                endm

; mxd_begin / mxd_end : exchange with the DSP when the music does not talk
;   to it (Timer A masked, as d3dbegin of 3Dreams)
mxd_begin:
                move.w  sr,-(sp)
.w:             or.w    #$0700,sr
                move.b  $fffffa13.w,mxd_imra
                bclr    #5,$fffffa13.w
                tst.b   $fffffa13.w
                tst.b   MGTK_Replay_In_Service
                beq.s   .ok
                bsr.s   mxd_end
                move.w  (sp),sr
                bra.s   .w
.ok:            move.w  (sp)+,sr
                rts
mxd_end:
                btst    #5,mxd_imra
                beq.s   .x
                bset    #5,$fffffa13.w
.x:             rts

; mxd_on : Simplet + 3DREAMS.P56 in the DSP, tables, vertices, ramps
;   -> mx_dsp = 1 (else 0 : flat X by the 030)
mxd_on:
                movem.l d0-d7/a0-a6,-(sp)
                clr.w   mx_dsp
                tst.w   dspok
                beq     .out
                lea     MGTK_DSP_Replay_Code,a0 ; Simplet then 3DREAMS
                lea     mxd_comb,a1
                move.l  #MGTK_DSP_Replay_Size*3,d0
                subq.l  #1,d0
.c1:            move.b  (a0)+,(a1)+
                subq.l  #1,d0
                bpl.s   .c1
                lea     mxd_code,a0
                move.l  #mxd_cend-mxd_code,d0
                subq.l  #1,d0
.c2:            move.b  (a0)+,(a1)+
                subq.l  #1,d0
                bpl.s   .c2
                clr.w   dsp3d                   ; (R3D gone until the end of the menu)
                clr.w   d3don
                move.w  #113,-(sp)              ; Dsp_RequestUniqueAbility
                trap    #14
                addq.l  #2,sp
                move.w  d0,-(sp)
                move.l  #MGTK_DSP_Replay_Size+(mxd_cend-mxd_code)/3,-(sp)
                pea     mxd_comb
                move.w  #109,-(sp)              ; Dsp_ExecProg
                trap    #14
                lea     12(sp),sp
                move.l  #87654321,$ffffa204.w   ; connection test (Simplet)
                move.l  #100000,d1
.w:             btst    #0,$ffffa202.w
                bne.s   .g
                subq.l  #1,d1
                bne.s   .w
                bra     .out
.g:             move.l  $ffffa204.w,d0
                bsr     mxd_begin               ; PING
                move.l  #$040000,d0
                bsr     d3dput
                bmi     .ko
                bsr     d3dget
                bmi     .ko
                cmp.l   #$5a5a5a,d0
                bne     .ko
                bsr     mxd_end
                lea     mxd_buf,a0              ; 1/w table : $7fffff / w
                clr.l   (a0)+
                moveq   #1,d1
.rc:            move.l  #$7fffff,d0
                divu.l  d1,d0
                move.l  d0,(a0)+
                addq.w  #1,d1
                cmp.w   #321,d1
                bls.s   .rc
                lea     mxd_buf,a0
                move.l  #MXD_RECIP,d0
                move.w  #321,d1
                moveq   #1,d3
                bsr     mxd_up
                bmi     .out
                lea     mxd_buf,a0              ; projection : 2^23 / d rounded up
                move.l  #$7fffff,(a0)+
                moveq   #1,d1
.pr:            move.l  #$800000,d0
                add.l   d1,d0
                subq.l  #1,d0
                divu.l  d1,d0
                cmp.l   #$7fffff,d0
                bls.s   .pr1
                move.l  #$7fffff,d0
.pr1:           move.l  d0,(a0)+
                addq.w  #1,d1
                cmp.w   #1024,d1
                blo.s   .pr
                lea     mxd_buf,a0
                move.l  #MXD_PRCP,d0
                move.w  #1024,d1
                moveq   #1,d3
                bsr     mxd_up
                bmi     .out
                lea     x3_v,a0                 ; vertices : x,y,z,nx,ny,nz (longs)
                lea     x3_vn,a1
                lea     mxd_buf,a2
                move.w  #X3_NV-1,d2
.v:             moveq   #2,d1
.vc:            move.w  (a0)+,d0
                ext.l   d0
                move.l  d0,(a2)+
                dbra    d1,.vc
                moveq   #2,d1
.vn:            move.w  (a1)+,d0
                ext.l   d0
                move.l  d0,(a2)+
                dbra    d1,.vn
                dbra    d2,.v
                lea     mxd_buf,a0
                move.l  #MXD_VTX,d0
                move.w  #X3_NV*6,d1
                moveq   #1,d3
                bsr     mxd_up
                bmi.s   .out
                lea     x3_ramp,a0              ; Gouraud ramps of the 2 materials
                move.l  #MXD_RAMPX,d0
                move.w  #2*224,d1
                moveq   #0,d3
                bsr     mxd_up
                bmi.s   .out
                move.w  #1,mx_dsp
                bra.s   .out
.ko:            bsr     mxd_end
.out:           movem.l (sp)+,d0-d7/a0-a6
                rts

; mxd_off : back to Simplet + R3D for the game (DSP3D.S)
mxd_off:
                tst.w   dspok
                beq.s   .x
                movem.l d0-d7/a0-a6,-(sp)
                clr.w   mx_dsp
                bsr     d3dinit
                bsr     d3dload
                movem.l (sp)+,d0-d7/a0-a6
.x:             rts

; mxd_up : UPLOAD : a0 = data, d0 = X address, d1 = count, d3 = 1 : longs,
;   0 : words ; packets of 224 ; N = 1 on error
mxd_up:
                movem.l d0-d6/a0,-(sp)
                move.l  d0,d4
                move.w  d1,d5
.pk:            move.w  d5,d6
                beq.s   .ok
                cmp.w   #224,d6
                bls.s   .n
                move.w  #224,d6
.n:             bsr     mxd_begin
                move.l  #$010000,d0
                bsr     d3dput
                bmi.s   .ko
                move.l  d4,d0
                bsr     d3dput
                bmi.s   .ko
                moveq   #0,d0
                move.w  d6,d0
                bsr     d3dput
                bmi.s   .ko
                move.w  d6,d1
                subq.w  #1,d1
.wd:            tst.w   d3
                beq.s   .w16
                move.l  (a0)+,d0
                bra.s   .put
.w16:           moveq   #0,d0
                move.w  (a0)+,d0
.put:           bsr     d3dput
                bmi.s   .ko
                dbra    d1,.wd
.ack:           bsr     d3dget                  ; acknowledge $400000
                bmi.s   .ko
                and.l   #$c00000,d0
                cmp.l   #$400000,d0
                bne.s   .ack
                bsr     mxd_end
                add.w   d6,d4
                sub.w   d6,d5
                bra.s   .pk
.ko:            bsr     mxd_end
                clr.w   mx_dsp
                movem.l (sp)+,d0-d6/a0
                moveq   #-1,d0
                rts
.ok:            movem.l (sp)+,d0-d6/a0
                tst.w   d3dzero
                rts

; mxd_xform : XFORM : the DSP turns, projects and lights the vertices
;   -> mx_p (X Y), mx_vi (shade 0..127 x 128). mx_dsp = 0 if it fails
mxd_xform:
                movem.l d0-d7/a0-a6,-(sp)
                lea     $ffffa204.w,a6
                lea     2(a6),a5
                bsr     mxd_begin
                move.l  #$050000+X3_NV,d0
                MXDW    d0
                moveq   #0,d0                   ; 1st vertex
                MXDW    d0
                moveq   #1,d0                   ; flags : intensity
                MXDW    d0
                lea     mx_m,a0                 ; matrix
                moveq   #8,d7
.m:             MXDQ    (a0)+
                dbra    d7,.m
                lea     mx_lo,a0                ; light in the object's frame
                moveq   #2,d7
.l:             MXDQ    (a0)+
                dbra    d7,.l
                moveq   #0,d0                   ; offx offy offz
                MXDW    d0
                MXDW    d0
                MXDW    d0
                move.w  mx_px,d0                ; pathx pathy ymax
                ext.l   d0
                MXDW    d0
                move.w  mx_py,d0
                ext.l   d0
                MXDW    d0
                move.l  #SCR_H-1,d0
                MXDW    d0
                lea     mx_p,a2
                lea     mx_vi,a0
                move.w  #X3_NV-1,d7
.v:             MXDR    d0                      ; rx ry rz (not used)
                MXDR    d0
                MXDR    d0
                MXDR    (a2)+                   ; X Y
                MXDR    (a2)+
                MXDR    (a0)+                   ; shade
                dbra    d7,.v
                move.l  #D3D_TMO,d7
.t:             btst    #0,$ffffa202.w          ; end $400000
                bne.s   .tr
                subq.l  #1,d7
                bne.s   .t
                clr.w   mx_dsp
                bra.s   .tx
.tr:            move.l  (a6),d0
                and.l   #$c00000,d0
                cmp.l   #$400000,d0
                bne.s   .t
.tx:            bsr     mxd_end
                movem.l (sp)+,d0-d7/a0-a6
                rts

; mxd_face : face a3 in Gouraud by the DSP into screen a4 ; on the lines
;   with text, only where M (a5) is the background (the X under the text)
;   d0 = 0 : done ; -1 : not done (vertex off the screen, no DSP)
mxd_face:
                tst.w   mx_dsp
                beq     .no
                movem.l d1-d7/a0-a6,-(sp)
                move.l  a4,mxd_scr
                move.l  a5,mxd_m
                lea     10(a3),a1               ; vertices x, y, shade
                lea     mx_p,a2
                lea     mx_vi,a0
                lea     mxd_vb,a6
                move.w  (a3),d7
                move.w  d7,d6
                subq.w  #1,d7
.v:             moveq   #0,d4
                move.b  (a1)+,d4
                move.w  (a0,d4.w*2),d3
                move.w  (a2,d4.w*4),d1
                move.w  2(a2,d4.w*4),d2
                cmp.w   #SCR_W,d1
                bhs     .cpu
                cmp.w   #SCR_H,d2
                bhs     .cpu
                movem.w d1-d3,(a6)
                addq.l  #6,a6
                dbra    d7,.v
                move.w  2(a3),d4                ; ramp of the material (+ 48)
                mulu    #224,d4
                add.l   #MXD_RAMPX+48,d4
                lea     $ffffa204.w,a6
                lea     2(a6),a5
                lea     mxd_vb,a1
                bsr     mxd_begin
                moveq   #0,d0                   ; FACE n
                move.w  d6,d0
                or.l    #$020000,d0
                MXDW    d0
                MXDW    d4
                subq.w  #1,d6
.sv:            MXDWW   (a1)+
                MXDWW   (a1)+
                MXDWW   (a1)+
                dbra    d6,.sv
                move.l  #D3D_TMO,d2             ; header : $C00000 | ymin << 9 | lines
.fh:            subq.l  #1,d2
                beq     .err
                btst    #0,$ffffa202.w
                beq.s   .fh
                move.l  (a6),d0
                btst    #22,d0
                beq.s   .fh
                move.w  d0,d6
                and.w   #$1ff,d6
                beq     .end1
                lsr.l   #8,d0
                lsr.l   #1,d0
                and.w   #$1ff,d0                ; ymin
                lea     mx_txt,a4
                adda.w  d0,a4
                mulu    #LINEB,d0
                move.l  mxd_scr,a0
                adda.l  d0,a0                   ; line in the screen
                move.l  mxd_m,a3
                adda.l  d0,a3                   ;  and in M
                bra.s   .lines
.pk:            bsr     mxd_begin               ; LINES k
                moveq   #0,d0
                move.w  d6,d0
                cmp.w   #MXD_BATCH,d0
                bls.s   .k
                moveq   #MXD_BATCH,d0
.k:             or.l    #$030000,d0
                MXDW    d0
.lines:         move.w  d6,d5
                cmp.w   #MXD_BATCH,d5
                bls.s   .k2
                moveq   #MXD_BATCH,d5
.k2:            sub.w   d5,d6
                subq.w  #1,d5
                move.l  #D3D_TMO,d7
.hw:            btst    #0,$ffffa202.w          ; line : $800000 | x << 9 | n-1
                bne.s   .hr
                subq.l  #1,d7
                bne.s   .hw
                bra     .err
.hr:            move.l  (a6),d0
                btst    #23,d0
                beq.s   .hw
                move.l  d0,d1
                lsr.l   #8,d1
                and.w   #$3fe,d1                ; 2 x
                lea     (a0,d1.w),a2
                and.w   #$1ff,d0                ; n - 1
                tst.b   (a4)
                bne.s   .mk
                move.w  (a5),(a2)+              ; pixels read without waiting
                lsr.w   #1,d0                   ;  (the DSP is faster)
                bcc.s   .p2
                move.w  (a5),(a2)+
.p2:            subq.w  #1,d0
                bmi.s   .nl
.px:            move.w  (a5),(a2)+
                move.w  (a5),(a2)+
                dbra    d0,.px
                bra.s   .nl
.mk:            lea     (a3,d1.w),a1            ; text line : where M = background
                move.w  mx_bgc,d2
.mp:            move.w  (a5),d3
                cmp.w   (a1)+,d2
                bne.s   .m1
                move.w  d3,(a2)
.m1:            addq.l  #2,a2
                dbra    d0,.mp
.nl:            lea     LINEB(a0),a0
                lea     LINEB(a3),a3
                addq.l  #1,a4
                move.l  #D3D_TMO,d7
                dbra    d5,.hw
.tw:            btst    #0,$ffffa202.w          ; end of the packet $400000
                bne.s   .tr
                subq.l  #1,d7
                bne.s   .tw
                bra.s   .err
.tr:            move.l  (a6),d0
                and.l   #$c00000,d0
                cmp.l   #$400000,d0
                bne.s   .tw
                bsr     mxd_end
                tst.w   d6
                bne     .pk
                bra.s   .done
.end1:          bsr     mxd_end
.done:          movem.l (sp)+,d1-d7/a0-a6
                moveq   #0,d0
                rts
.err:           bsr     mxd_end
                clr.w   mx_dsp                  ; the DSP no longer answers : 030
.cpu:           movem.l (sp)+,d1-d7/a0-a6
.no:            moveq   #-1,d0
                rts

                section data
                include 'XLOGO3D.S'             ; the X (outils\X3GEN.PY)
mxd_code:       incbin  '3DREAMS.P56'           ; DSP program of 3Dreams (3 bytes per word)
mxd_cend:
                even
mx_celt:        dc.b    0,0,1,1,1,2,2,0          ; cel : shade 0..6 -> tone 0..2
mx_celc:        dc.w    $39E9,$7BD1,$CE5A,$614E,$A297,$E4BE ; 2 materials x 3 tones
mn_title:       dc.b    'XVOLUTION',0
mn_arrow:       dc.b    '>',0
mn_items:       dc.b    '1  ATARI 800 XL   1983',0
                dc.b    '2  ATARI 520 ST   1985',0
                dc.b    '3  ATARI STE      1989',0
                dc.b    '4  FALCON 030     1992',0
mn_nomap:       dc.b    'NO MAP',0
mn_keys:        dc.b    'UP/DOWN : LEVEL   SPACE/FIRE : PLAY   ESC : QUIT',0
                even
                section bss
mn_sel:         ds.w    1
mn_ok:          ds.b    NB_LEVELS
mn_joy:         ds.b    1
                even
mx_t:           ds.w    1                       ; time (angles) : tframe of 3Dreams
mx_fr:          ds.w    1                       ; pictures drawn
mx_acc:         ds.w    1                       ; VBL not yet counted in mx_t
mx_vbl:         ds.l    1                       ; vbl_cnt at the last picture
mx_back:        ds.w    1                       ; screen drawn : 0 = D0, 1 = D1
mx_full:        ds.w    2                       ; D0, D1 : whole copy of M to do
mx_bb:          ds.w    8                       ; D0, D1 : X drawn in x0 y0 x1 y1 (x0 < 0 : none)
mx_ax:          ds.w    1                       ; amplitudes (growing : curax, curay)
mx_ay:          ds.w    1
mx_px:          ds.w    1                       ; centre on the screen (pathx, pathy)
mx_py:          ds.w    1
mx_sx:          ds.w    1                       ; sin cos of ax = az, of ay
mx_cx:          ds.w    1
mx_sy:          ds.w    1
mx_cy:          ds.w    1
mx_nsx:         ds.w    1                       ; - sin (eye : inverse rotation)
mx_nsy:         ds.w    1
mx_m:           ds.w    9                       ; matrix x 2^14 : mxx mxy mxz myx .. mzz
mx_eye:         ds.w    3                       ; eye in the frame of the object
mx_y0:          ds.w    1                       ; lines of the polygon
mx_y1:          ds.w    1
mx_col:         ds.w    1
mx_op:          ds.l    1
mx_oend:        ds.l    1
mx_sin:         ds.w    256
mx_p:           ds.w    2*X3_NV                 ; vertices on the screen
mx_ord:         ds.w    X3_NF                   ; faces : order of the BSP tree
mx_seen:        ds.w    X3_NF                   ; mx_fr when last visible
mx_lv:          ds.b    X3_NF                   ; shade level 0..13 shown
                even
mx_txt:         ds.b    SCR_H                   ; line of M with text
mx_tl:          ds.w    SCR_H                   ; x of the edges going down
mx_tr:          ds.w    SCR_H                   ;  and going up
mx_dsp:         ds.w    1
mx_bgc:         ds.w    1                       ; background colour of M
mx_rend:        ds.w    1                       ; X : 0 wire 1 flat 2 cel 3 Gouraud
                       ; 1 : 3DREAMS.P56 in the DSP (Gouraud)
mx_lo:          ds.w    3                       ; light in the frame of the object
mx_vi:          ds.w    X3_NV                   ; shade of the vertices (DSP)
mxd_scr:        ds.l    1
mxd_m:          ds.l    1
mxd_vb:         ds.w    3*8                     ; vertices of a face (x y shade)
mxd_imra:       ds.b    1
                even
mxd_buf:        ds.l    1024                    ; tables sent to the DSP
mxd_comb:       ds.b    3*1600                  ; Simplet + 3DREAMS for Dsp_ExecProg
                section text
