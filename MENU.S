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
MNC_BG           equ     $1144                   ; colours : dark board green
MNC_TITLE        equ     $FFE0                   ;  yellow title
MNC_TEXT         equ     $FFFF                   ;  white
MNC_SEL         equ     $07E0                   ;  green : selected
MNC_GREY         equ     $8C51                   ;  grey : no map / help

menu:
                movem.l d1-d7/a0-a6,-(sp)
                st      vol_inmenu              ; volume : the YM tune (SFX.S)
                bsr     vol_apply
                move.l  bufd0+BF_ADR,a6         ; picture : top-left of D0
                move.l  a6,scr_show
                bsr     mn_avail                ; which LEVELn.MAP exist
                move.w  cur_level,d0            ; selection : the last level
                bsr     mn_fix
                move.w  d0,mn_sel
                bsr     mn_draw
                move.w  #-1,-(sp)               ; shown
                move.l  a6,-(sp)
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
.loop:          move.w  #37,-(sp)               ; Vsync
                trap    #14
                addq.l  #2,sp
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
                bsr     mn_draw
                bra     .loop
.go:            move.w  mn_sel,d0
                lea     mn_ok,a1
                tst.b   -1(a1,d0.w)
                beq     .loop                   ; (no map : not playable)
                bra.s   .x
.quit:          moveq   #-1,d0
.x:             sf      vol_inmenu              ; in game : the module only
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
                move.l  a6,a0                   ; background : dark board green
                move.l  #(MNC_BG<<16)|MNC_BG,d1
                move.w  #SCR_H-1,d7
.cy:            move.l  a0,a1
                move.w  #SCR_W/2-1,d0
.cx:            move.l  d1,(a1)+
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

                section data
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
                section text
