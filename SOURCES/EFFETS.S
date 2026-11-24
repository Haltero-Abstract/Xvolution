;=====================================================================
; EFFETS.S - GRAPHIC EFFECTS (included by XVOLUTION.S, settings in PARAMS.S)
;   blend_rect  : rectangle mixed 50 % with a colour (shadow, glows)
;   particles   : explosions (debris + flash), sparks of the bosses
;   fx_shadow   : shadow of the ship on the board
;   pulses      : light pulses running along the copper tracks
;   fx_fixed    : recapped chips : green halo + blinking LED
;=====================================================================
                section text

; blend_rect : d0,d1 - d2,d3 (inclusive), d4.w = colour, a6 = screen :
;   each pixel = (pixel + colour) / 2  (colour 0 : darker = shadow)
blend_rect:
                movem.l d0-d7/a0-a1,-(sp)
                tst.w   d0
                bpl.s   .q1
                moveq   #0,d0
.q1:            cmp.w   #SCR_W-1,d2
                ble.s   .q2
                move.w  #SCR_W-1,d2
.q2:            cmp.w   d2,d0
                bgt     .x
                cmp.w   clip_y0,d1
                bge.s   .q3
                move.w  clip_y0,d1
.q3:            cmp.w   clip_y1,d3
                ble.s   .q4
                move.w  clip_y1,d3
.q4:            cmp.w   d3,d1
                bgt     .x
                bsr     bb_add                  ; (erasing rectangle)
                sub.w   d1,d3                   ; lines - 1
                move.w  d4,d5
                lsr.w   #1,d5
                and.w   #$7BEF,d5               ; colour / 2
                move.w  d5,d4                   ; d5.l = colour / 2 twice
                swap    d5
                move.w  d4,d5
                sub.w   d0,d2
                addq.w  #1,d2                   ; width
                moveq   #0,d6
                move.w  d1,d6
                mulu    #LINEB,d6
                lea     (a6,d6.l),a0
                add.w   d0,d0
                adda.w  d0,a0
                move.l  #$7BEF7BEF,d4
                move.l  a6,d1                   ; (a6 + 2*x0 : long aligned ?)
                add.w   d0,d1
.ln:            move.l  a0,a1
                move.w  d2,d7
                btst    #1,d1
                beq.s   .al
                move.w  (a1),d6                 ; first pixel alone
                lsr.w   #1,d6
                and.w   d4,d6
                add.w   d5,d6
                move.w  d6,(a1)+
                subq.w  #1,d7
                beq.s   .nl
.al:            move.w  d7,d0
                lsr.w   #1,d0
                beq.s   .r
                subq.w  #1,d0
.lp:            move.l  (a1),d6                 ; 2 pixels
                lsr.l   #1,d6
                and.l   d4,d6
                add.l   d5,d6
                move.l  d6,(a1)+
                dbra    d0,.lp
.r:             btst    #0,d7
                beq.s   .nl
                move.w  (a1),d6
                lsr.w   #1,d6
                and.w   d4,d6
                add.w   d5,d6
                move.w  d6,(a1)+
.nl:            lea     LINEB(a0),a0
                dbra    d3,.ln
.x:             movem.l (sp)+,d0-d7/a0-a1
                rts

; fill_small : d0,d1 - d2,d3 colour d4 (a few pixels) : in the screen,
;   written directly ; else fillrect (clipped). Erased next time.
fill_small:
                movem.l d0-d6/a0-a1,-(sp)
                tst.w   d0
                bmi.s   .slow
                cmp.w   #SCR_W-1,d2
                bgt.s   .slow
                cmp.w   clip_y0,d1
                blt.s   .slow
                cmp.w   clip_y1,d3
                bgt.s   .slow
                bsr     add_rect
                sub.w   d1,d3                   ; lines - 1
                sub.w   d0,d2                   ; pixels - 1
                mulu    #LINEB,d1
                lea     (a6,d1.l),a0
                add.w   d0,d0
                adda.w  d0,a0
.y:             move.l  a0,a1
                move.w  d2,d5
.x:             move.w  d4,(a1)+
                dbra    d5,.x
                lea     LINEB(a0),a0
                dbra    d3,.y
                movem.l (sp)+,d0-d6/a0-a1
                rts
.slow:          bsr     obj_begin
                bsr     fillrect
                bsr     obj_end
                movem.l (sp)+,d0-d6/a0-a1
                rts

; w2s : world (ship plane) d0,d1 -> screen d0,d1
w2s:
                muls    #FOC,d0
                divs    #SHIP_Z,d0
                add.w   #CX,d0
                muls    #FOC,d1
                divs    #SHIP_Z,d1
                add.w   #CY,d1
                rts

;---------------------------------------------------------------------
; particles : 16 bytes : life x*16 y*16 dx dy colour size -
fx_reset:
                movem.l d0/a0,-(sp)
                lea     parts,a0
                move.w  #MAXP*8-1,d0
.c:             clr.w   (a0)+
                dbra    d0,.c
                movem.l (sp)+,d0/a0
                rts

; fx_flash : white flash at d2,d3 (world), d4 = size (pixels)
fx_flash:
                movem.l d0-d1/a0,-(sp)
                bsr     fx_free
                beq.s   .x
                move.w  #FLASH_T,(a0)
                move.w  d2,d0
                lsl.w   #4,d0
                move.w  d0,2(a0)
                move.w  d3,d0
                lsl.w   #4,d0
                move.w  d0,4(a0)
                clr.l   6(a0)
                move.w  #$FFFF,10(a0)
                move.w  d4,12(a0)
                move.w  #1,14(a0)               ; (flash : it shrinks)
.x:             movem.l (sp)+,d0-d1/a0
                rts

; fx_burst : d4 debris at d2,d3 (world), a1 = 4 colours, d5 = speed (x16)
fx_burst:
                movem.l d0-d7/a0-a1,-(sp)
                subq.w  #1,d4
.l:             bsr     fx_free
                beq.s   .x
                bsr     rnd                     ; life
                and.w   #15,d0
                add.w   #PART_T,d0
                move.w  d0,(a0)
                move.w  d2,d0
                lsl.w   #4,d0
                move.w  d0,2(a0)
                move.w  d3,d0
                lsl.w   #4,d0
                move.w  d0,4(a0)
                bsr     rnd                     ; dx, dy : -d5 .. d5
                and.w   #63,d0
                sub.w   #32,d0
                muls    d5,d0
                asr.l   #5,d0
                move.w  d0,6(a0)
                bsr     rnd
                and.w   #63,d0
                sub.w   #32,d0
                muls    d5,d0
                asr.l   #5,d0
                move.w  d0,8(a0)
                bsr     rnd                     ; colour
                lsr.w   #8,d0
                and.w   #3,d0
                add.w   d0,d0
                move.w  (a1,d0.w),10(a0)
                bsr     rnd
                lsr.w   #8,d0
                and.w   #1,d0
                addq.w  #1,d0
                move.w  d0,12(a0)               ; size 1 or 2
                clr.w   14(a0)
                dbra    d4,.l
.x:             movem.l (sp)+,d0-d7/a0-a1
                rts

; fx_free : a0 = free particle (Z clear) ; Z set = none
fx_free:
                move.l  d0,-(sp)
                lea     parts,a0
                moveq   #MAXP-1,d0
.l:             tst.w   (a0)
                beq.s   .f
                lea     16(a0),a0
                dbra    d0,.l
                move.l  (sp)+,d0
                clr.w   -(sp)                   ; Z set : none
                tst.w   (sp)+
                rts
.f:             move.l  (sp)+,d0
                move.w  #1,-(sp)                ; Z clear
                tst.w   (sp)+
                rts

; fx_boom : enemy at a1 explodes (kill_enemy)
fx_boom:
                movem.l d2-d5/a1,-(sp)
                move.w  2(a1),d2
                move.w  4(a1),d3
                moveq   #10,d4
                bsr     fx_flash
                moveq   #12,d4
                moveq   #BOOM_SPD,d5
                lea     pal_boom,a1
                bsr     fx_burst
                movem.l (sp)+,d2-d5/a1
                rts

; fx_update : particles move (one game step)
fx_update:
                movem.l d0-d1/a0,-(sp)
                addq.w  #1,fx_clock
                lea     parts,a0
                moveq   #MAXP-1,d1
.l:             tst.w   (a0)
                beq.s   .n
                subq.w  #1,(a0)
                tst.w   14(a0)
                beq.s   .d
                subq.w  #2,12(a0)               ; flash : smaller
                bgt.s   .n
                clr.w   (a0)
                bra.s   .n
.d:             move.w  6(a0),d0                ; debris : move, slower
                add.w   d0,2(a0)
                asr.w   #3,d0
                sub.w   d0,6(a0)
                move.w  8(a0),d0
                add.w   d0,4(a0)
                asr.w   #3,d0
                sub.w   d0,8(a0)
.n:             lea     16(a0),a0
                dbra    d1,.l
                movem.l (sp)+,d0-d1/a0
                rts

; fx_render : the particles ; a6 = screen
fx_render:
                movem.l d0-d7/a0,-(sp)
                lea     parts,a0
                moveq   #MAXP-1,d7
.l:             tst.w   (a0)
                beq.s   .n
                move.w  2(a0),d0
                asr.w   #4,d0
                move.w  4(a0),d1
                asr.w   #4,d1
                bsr     w2s
                move.w  12(a0),d5
                move.w  d0,d2
                add.w   d5,d2
                sub.w   d5,d0
                move.w  d1,d3
                add.w   d5,d3
                sub.w   d5,d1
                move.w  10(a0),d4
                tst.w   14(a0)
                bne.s   .fl
                bsr     fill_small              ; debris : a small square
                bra.s   .n
.fl:            bsr     obj_begin
                bsr     blend_rect              ; flash : halo + white core
                addq.w  #3,d0
                addq.w  #3,d1
                subq.w  #3,d2
                subq.w  #3,d3
                bsr     fillrect
                bsr     obj_end
.n:             lea     16(a0),a0
                dbra    d7,.l
                movem.l (sp)+,d0-d7/a0
                rts

;---------------------------------------------------------------------
; fx_shadow : shadow of the ship (model a0) on the board ; a6 = screen :
;   its runs made by sh_prerender, moved by the ship (all in the screen),
;   else the boxes one by one (fx_shadow_box)
SH_CX           equ     SH_DX*FOC/SH_Z+CX       ; (centre of the shadow : ship at 0,0)
SH_CY           equ     SH_DY*FOC/SH_Z+CY
fx_shadow:
                tst.w   spr_done
                beq     fx_shadow_box
                movem.l d0-d7/a0-a3,-(sp)
                move.w  form,d0
                lsl.w   #4,d0
                lea     sh_tab,a2
                adda.w  d0,a2
                move.l  12(a2),d0               ; its runs
                beq     .x
                move.l  d0,a0
                move.w  px,d0                   ; top left : centre + ship / SH_Z
                muls    #FOC,d0
                divs    #SH_Z,d0
                add.w   #SH_CX,d0
                add.w   8(a2),d0
                move.w  py,d1
                muls    #FOC,d1
                divs    #SH_Z,d1
                add.w   #SH_CY,d1
                add.w   10(a2),d1
                move.w  4(a2),d4                ; w, h
                move.w  6(a2),d5
                tst.w   d0                      ; all in the screen ?
                bmi    .slow
                move.w  d0,d2
                add.w   d4,d2
                cmp.w   #SCR_W,d2
                bgt    .slow
                cmp.w   clip_y0,d1
                blt    .slow
                move.w  d1,d3
                add.w   d5,d3
                subq.w  #1,d3
                cmp.w   clip_y1,d3
                bgt    .slow
                subq.w  #1,d2                   ; erased next time
                bsr     add_rect
                mulu    #LINEB,d1
                lea     (a6,d1.l),a1
                add.w   d0,d0
                adda.w  d0,a1
                move.l  #$7BEF7BEF,d4
                subq.w  #1,d5
.ry:            move.w  (a0)+,d2                ; runs of the line
                subq.w  #1,d2
                bmi.s   .rn
.rr:            move.w  (a0)+,d3
                lea     (a1,d3.w),a3
                move.w  (a0)+,d3                ; pixels - 1
                move.w  d3,d6
                addq.w  #1,d6
                add.w   d6,d6
                adda.w  d6,a0                   ; (its pixels : not used)
                addq.w  #1,d3
                lsr.w   #1,d3                   ; pairs (carry : one more)
                bcc.s   .ev
                move.w  (a3),d0                 ; the odd one
                lsr.w   #1,d0
                and.w   d4,d0
                move.w  d0,(a3)+
.ev:            subq.w  #1,d3
                bmi.s   .rd
.rp:            move.l  (a3),d0                 ; 2 pixels : half (darker)
                lsr.l   #1,d0
                and.l   d4,d0
                move.l  d0,(a3)+
                dbra    d3,.rp
.rd:            dbra    d2,.rr
.rn:            lea     LINEB(a1),a1
                dbra    d5,.ry
.x:             movem.l (sp)+,d0-d7/a0-a3
                rts
.slow:          movem.l (sp)+,d0-d7/a0-a3
                ; (falls into fx_shadow_box : a0 = model)

; fx_shadow_box : the shadow box by box (blend_rect)
fx_shadow_box:
                movem.l d0-d7/a0,-(sp)
                bsr     obj_begin
.l:             move.w  (a0)+,d0
                cmp.w   #-99,d0
                beq.s   .x
                move.w  (a0)+,d1
                move.w  (a0)+,d2
                move.w  (a0)+,d3
                addq.l  #8,a0                   ; (z0 z1, colours)
                add.w   px,d0                   ; world + offset (light from the
                add.w   px,d2                   ;  top left)
                add.w   py,d1
                add.w   py,d3
                add.w   #SH_DX,d0
                add.w   #SH_DX,d2
                add.w   #SH_DY,d1
                add.w   #SH_DY,d3
                muls    #FOC,d0                 ; projected on the board
                divs    #SH_Z,d0
                add.w   #CX,d0
                muls    #FOC,d2
                divs    #SH_Z,d2
                add.w   #CX,d2
                muls    #FOC,d1
                divs    #SH_Z,d1
                add.w   #CY,d1
                muls    #FOC,d3
                divs    #SH_Z,d3
                add.w   #CY,d3
                subq.w  #1,d2
                subq.w  #1,d3
                moveq   #0,d4
                bsr     blend_rect
                bra.s   .l
.x:             bsr     obj_end
                movem.l (sp)+,d0-d7/a0
                rts

;---------------------------------------------------------------------
; pulse_init : straight tracks of the map ('|' and '-' not under a
;   component, PULSE_MIN tiles or more) -> runs ; pulses off (level_reset)
pulse_init:
                movem.l d0-d7/a0-a3,-(sp)
                lea     pulses,a0
                moveq   #NPULSE-1,d0
.p:             move.w  #-1,(a0)
                addq.l  #8,a0
                dbra    d0,.p
                clr.w   nruns
                lea     covbuf,a0               ; --- tiles under components
                move.w  #MAP_MAXROWS*MAP_MAXCOLS/4-1,d0
.c:             clr.l   (a0)+
                dbra    d0,.c
                move.w  ncomps,d7
                beq.s   .cd
                subq.w  #1,d7
                lea     comps,a1
.cl:            move.w  (a1),d2                 ; type -> w, h
                lea     comp_w,a2
                moveq   #0,d3
                move.b  (a2,d2.w),d3
                lea     comp_h,a2
                moveq   #0,d4
                move.b  (a2,d2.w),d4
                move.w  4(a1),d1                ; row
                subq.w  #1,d4
.cr:            cmp.w   map_rows,d1
                bhs.s   .cn
                move.w  d1,d5
                mulu    #MAP_MAXCOLS,d5
                lea     covbuf,a2
                adda.l  d5,a2
                move.w  2(a1),d0                ; columns
                move.w  d3,d6
                subq.w  #1,d6
.cc:            cmp.w   #MAP_MAXCOLS,d0
                bhs.s   .cs
                st      (a2,d0.w)
.cs:            addq.w  #1,d0
                dbra    d6,.cc
                addq.w  #1,d1
                dbra    d4,.cr
.cn:            addq.l  #8,a1
                dbra    d7,.cl
.cd:            lea     runs,a3
                moveq   #0,d0                   ; --- vertical runs ('|' = 2)
.vc:            cmp.w   map_cols,d0
                bhs.s   .vd
                moveq   #0,d1
                moveq   #-1,d2                  ; start of the run (-1 : none)
.vr:            moveq   #0,d4                   ; (row past the end : stop)
                cmp.w   map_rows,d1
                bhs.s   .v1
                move.w  d1,d5
                mulu    #MAP_MAXCOLS,d5
                add.w   d0,d5
                lea     mapbuf,a2
                cmp.b   #2,(a2,d5.l)
                bne.s   .v1
                lea     covbuf,a2
                tst.b   (a2,d5.l)
                bne.s   .v1
                moveq   #1,d4
.v1:            tst.w   d4
                beq.s   .v2
                tst.w   d2
                bpl.s   .vn
                move.w  d1,d2                   ; a run starts
                bra.s   .vn
.v2:            tst.w   d2                      ; a run ends
                bmi.s   .vn
                moveq   #0,d6
                bsr     run_add
                moveq   #-1,d2
.vn:            addq.w  #1,d1
                cmp.w   map_rows,d1
                bls.s   .vr
                addq.w  #1,d0
                bra.s   .vc
.vd:            moveq   #0,d1                   ; --- horizontal runs ('-' = 1)
.hr:            cmp.w   map_rows,d1
                bhs.s   .hd
                move.w  d1,d5
                mulu    #MAP_MAXCOLS,d5
                moveq   #0,d0
                moveq   #-1,d2
.hc:            moveq   #0,d4
                cmp.w   map_cols,d0
                bhs.s   .h1
                lea     mapbuf,a2
                lea     (a2,d5.l),a2
                cmp.b   #1,(a2,d0.w)
                bne.s   .h1
                lea     covbuf,a2
                lea     (a2,d5.l),a2
                tst.b   (a2,d0.w)
                bne.s   .h1
                moveq   #1,d4
.h1:            tst.w   d4
                beq.s   .h2
                tst.w   d2
                bpl.s   .hn
                move.w  d0,d2
                bra.s   .hn
.h2:            tst.w   d2
                bmi.s   .hn
                moveq   #1,d6
                bsr     run_add
                moveq   #-1,d2
.hn:            addq.w  #1,d0
                cmp.w   map_cols,d0
                bls.s   .hc
                addq.w  #1,d1
                bra.s   .hr
.hd:            movem.l (sp)+,d0-d7/a0-a3
                rts

; run_add : d6 = 0 vertical (column d0, rows d2 .. d1-1) / 1 horizontal
;   (row d1, columns d2 .. d0-1) ; a3 = next run
run_add:
                movem.l d0-d3,-(sp)
                cmp.w   #MAXRUN,nruns
                bhs.s   .x
                tst.w   d6
                bne.s   .h
                move.w  d1,d3                   ; vertical : len = d1 - d2
                sub.w   d2,d3
                move.w  d0,d1                   ; col
                move.w  d2,d0                   ; row
                bra.s   .s
.h:             move.w  d0,d3                   ; horizontal : len = d0 - d2
                sub.w   d2,d3
                move.w  d1,d0                   ; row
                move.w  d2,d1                   ; col
.s:             cmp.w   #PULSE_MIN,d3
                blo.s   .x
                move.w  d6,(a3)+                ; dir col row len
                move.w  d1,(a3)+
                move.w  d0,(a3)+
                move.w  d3,(a3)+
                addq.w  #1,nruns
.x:             movem.l (sp)+,d0-d3
                rts

; pulse_update : pulses go on ; new ones start on visible tracks
pulse_update:
                movem.l d0-d4/a0-a1,-(sp)
                tst.w   nruns
                beq     .x
                lea     pulses,a0
                moveq   #NPULSE-1,d4
.l:             move.w  (a0),d0
                bmi.s   .new
                move.w  4(a0),d1                ; moves
                add.w   d1,2(a0)
                lsl.w   #3,d0
                lea     runs,a1
                move.w  6(a1,d0.w),d1           ; len * TILE_PX
                mulu    #TILE_PX,d1
                cmp.w   2(a0),d1
                bgt.s   .n
                move.w  #-1,(a0)                ; end of the track
                bra.s   .n
.new:           bsr     rnd                     ; (1 chance in 8 per step)
                and.w   #$700,d0
                bne.s   .n
                bsr     rnd
                mulu    nruns,d0
                swap    d0                      ; run 0 .. nruns-1
                move.w  d0,d1
                lsl.w   #3,d1
                lea     runs,a1
                adda.w  d1,a1
                moveq   #0,d2                   ; visible ? rows y0 .. y1 (pixels)
                move.w  4(a1),d2
                mulu    #TILE_PX,d2
                move.l  d2,d3
                add.l   #TILE_PX,d3
                tst.w   (a1)
                bne.s   .v
                moveq   #0,d1
                move.w  6(a1),d1
                mulu    #TILE_PX,d1
                add.l   d1,d3
.v:             move.l  gpos,d1
                cmp.l   d1,d3
                blt.s   .n
                add.l   #SCR_H,d1
                cmp.l   d1,d2
                bgt.s   .n
                move.w  d0,(a0)
                clr.w   2(a0)
                bsr     rnd
                lsr.w   #8,d0
                and.w   #3,d0
                addq.w  #PULSE_SPD,d0
                move.w  d0,4(a0)
.n:             addq.l  #8,a0
                dbra    d4,.l
.x:             movem.l (sp)+,d0-d4/a0-a1
                rts

; pulse_render : head + glowing tail ; a6 = screen
pulse_render:
                movem.l d0-d7/a0-a1,-(sp)
                lea     pulses,a0
                moveq   #NPULSE-1,d7
.l:             move.w  (a0),d0
                bmi     .n
                lsl.w   #3,d0
                lea     runs,a1
                adda.w  d0,a1
                move.w  2(a1),d0                ; col -> x
                mulu    #TILE_PX,d0
                sub.w   camx,d0
                moveq   #0,d1                   ; row -> y
                move.w  4(a1),d1
                mulu    #TILE_PX,d1
                sub.l   gpos,d1
                cmp.l   #-400,d1
                blt     .n
                cmp.l   #SCR_H+400,d1
                bgt     .n
                bsr     pulse_fast              ; all in the screen : direct
                beq     .n
                bsr     obj_begin
                tst.w   (a1)
                bne.s   .h
                addq.w  #8,d0                   ; --- vertical : going down
                add.w   2(a0),d1
                move.w  d0,d2
                addq.w  #3,d2
                move.w  d1,d3
                subq.w  #1,d3
                sub.w   #PULSE_LEN,d1
                move.w  #PULSE_TAIL,d4
                bsr     blend_rect
                move.w  d3,d1
                addq.w  #1,d1
                addq.w  #4,d3
                bra.s   .hd
.h:             add.w   2(a0),d0                ; --- horizontal : going right
                add.w   #8,d1
                move.w  d1,d3
                addq.w  #3,d3
                move.w  d0,d2
                subq.w  #1,d2
                sub.w   #PULSE_LEN,d0
                move.w  #PULSE_TAIL,d4
                bsr     blend_rect
                move.w  d2,d0
                addq.w  #1,d0
                addq.w  #4,d2
.hd:            move.w  #PULSE_COL,d4
                bsr     fillrect
                bsr     obj_end
.n:             addq.l  #8,a0
                dbra    d7,.l
                movem.l (sp)+,d0-d7/a0-a1
                rts

;---------------------------------------------------------------------
; pulse_fast : pulse a0 on run a1 at d0 (x of its column), d1 (y of its
;   row) : all in the screen -> drawn directly (tail mixed 50 %, white
;   head), Z set ; else Z clear (fillrect / blend_rect)
pulse_fast:
                movem.l d0-d7/a2,-(sp)
                tst.w   (a1)
                bne     .h
                addq.w  #8,d0                   ; vertical : x .. x+3,
                add.w   2(a0),d1                ;  tail y-20 .. y-1, head .. y+3
                move.w  d0,d2
                addq.w  #3,d2
                move.w  d1,d3
                addq.w  #3,d3
                sub.w   #PULSE_LEN,d1
                bsr     .vis                    ; (not seen at all : nothing)
                bne     .skip
                bsr     .in
                bne     .no
                bsr     add_rect
                bsr     .adr
                moveq   #PULSE_LEN-1,d7
.vt:            move.l  (a2),d0                 ; 4 pixels : 2 longs
                lsr.l   #1,d0
                and.l   d5,d0
                add.l   d6,d0
                move.l  d0,(a2)
                move.l  4(a2),d0
                lsr.l   #1,d0
                and.l   d5,d0
                add.l   d6,d0
                move.l  d0,4(a2)
                lea     LINEB(a2),a2
                dbra    d7,.vt
                moveq   #3,d7
.vh:            move.l  d4,(a2)
                move.l  d4,4(a2)
                lea     LINEB(a2),a2
                dbra    d7,.vh
                bra     .ok
.h:             add.w   2(a0),d0                ; horizontal : y+8 .. y+11,
                addq.w  #8,d1                   ;  tail x-20 .. x-1, head .. x+3
                move.w  d0,d2
                addq.w  #3,d2
                sub.w   #PULSE_LEN,d0
                move.w  d1,d3
                addq.w  #3,d3
                bsr     .vis
                bne     .skip
                bsr     .in
                bne.s   .no
                bsr     add_rect
                bsr     .adr
                moveq   #3,d7
.hl:            move.l  a2,a1
                moveq   #PULSE_LEN/2-1,d2
.ht:            move.l  (a1),d0
                lsr.l   #1,d0
                and.l   d5,d0
                add.l   d6,d0
                move.l  d0,(a1)+
                dbra    d2,.ht
                move.l  d4,(a1)+                ; head
                move.l  d4,(a1)
                lea     LINEB(a2),a2
                dbra    d7,.hl
.skip:
.ok:            movem.l (sp)+,d0-d7/a2
                moveq   #0,d0                   ; Z set : done (d0 not kept)
                rts
.no:            movem.l (sp)+,d0-d7/a2
                rts
.in:            tst.w   d0                      ; d0..d3 in the screen ? (Z set)
                bmi.s   .out
                cmp.w   #SCR_W-1,d2
                bgt.s   .out
                cmp.w   clip_y0,d1
                blt.s   .out
                cmp.w   clip_y1,d3
                bgt.s   .out
                moveq   #0,d4
                rts
.out:           moveq   #1,d4
                rts
.vis:           tst.w   d2                      ; d0..d3 out of the screen ?
                bmi.s   .out                    ;  (Z clear : out)
                cmp.w   #SCR_W-1,d0
                bgt.s   .out
                cmp.w   clip_y0,d3
                blt.s   .out
                cmp.w   clip_y1,d1
                bgt.s   .out
                moveq   #0,d4
                rts
.adr:           move.w  d1,d7                   ; a2 = d0, d1 ; d4 head x2,
                mulu    #LINEB,d7               ;  d5 mask, d6 tail colour / 2 x2
                lea     (a6,d7.l),a2
                move.w  d0,d7
                add.w   d7,d7
                adda.w  d7,a2
                move.l  #PULSE_COL<<16+PULSE_COL,d4
                move.l  #$7BEF7BEF,d5
                move.l  #((PULSE_TAIL>>1)&$7BEF)*$10001,d6
                rts

; fx_fixed : the recapped chips : green halo around them + blinking LED
fx_fixed:
                movem.l d0-d7/a0-a2,-(sp)
                move.w  nboss,d7
                beq     .x
                subq.w  #1,d7
                lea     boss_list,a1
                lea     boss_fixed,a2
.b:             tst.b   (a2)
                beq     .n
                move.w  (a1),d4
                lsl.w   #3,d4
                lea     comps,a0
                adda.w  d4,a0
                move.w  (a0),d5                 ; type
                move.w  2(a0),d0                ; screen rectangle (board)
                mulu    #TILE_PX,d0
                sub.w   camx,d0
                moveq   #0,d1
                move.w  4(a0),d1
                mulu    #TILE_PX,d1
                sub.l   gpos,d1
                cmp.l   #-300,d1
                blt     .n
                cmp.l   #SCR_H,d1
                bge     .n
                lea     comp_w,a0
                moveq   #0,d2
                move.b  (a0,d5.w),d2
                mulu    #TILE_PX,d2
                add.w   d0,d2
                lea     comp_h,a0
                moveq   #0,d3
                move.b  (a0,d5.w),d3
                mulu    #TILE_PX,d3
                add.w   d1,d3
                subq.w  #3,d0                   ; halo : 4 bands outside (each
                subq.w  #3,d1                   ;  erased on its own : not the
                addq.w  #2,d2                   ;  chip inside, it is in G)
                addq.w  #2,d3
                movem.w d0-d3,-(sp)
                move.w  #FIX_COL,d4
                move.w  d1,d3                   ;  top
                addq.w  #2,d3
                bsr     .band
                movem.w (sp),d0-d3
                move.w  d3,d1                   ;  bottom
                subq.w  #2,d1
                bsr     .band
                movem.w (sp),d0-d3
                addq.w  #3,d1
                subq.w  #3,d3
                move.w  d0,d2                   ;  left
                addq.w  #2,d2
                bsr     .band
                movem.w (sp),d0-d3
                addq.w  #3,d1
                subq.w  #3,d3
                move.w  d2,d0                   ;  right
                subq.w  #2,d0
                bsr     .band
                movem.w (sp)+,d0-d3
                move.w  d2,d0                   ; LED : top right corner
                sub.w   #9,d0
                subq.w  #4,d2
                addq.w  #4,d1
                move.w  d1,d3
                addq.w  #4,d3
                move.w  #FIX_COL,d4
                btst    #3,fx_clock+1
                beq.s   .led
                move.w  #FIX_DIM,d4
.led:           bsr     obj_begin
                bsr     fillrect
                bsr     obj_end
.n:             addq.l  #2,a1
                addq.l  #1,a2
                dbra    d7,.b
.x:             movem.l (sp)+,d0-d7/a0-a2
                rts
.band:          bsr     obj_begin
                bsr     blend_rect
                bra     obj_end

;---------------------------------------------------------------------
                section data
pal_boom:       dc.w    $FC00,$FFE0,$FFFF,$8410 ; enemy debris
pal_spark:      dc.w    $07FF,$001F,$FFFF,$5DFF ; boss sparks (blue)
pal_hit:        dc.w    $F800,$FFFF,$FC00,$F800 ; ship hit

                section bss
fx_clock:       ds.w    1
parts:          ds.w    MAXP*8
nruns:          ds.w    1
runs:           ds.w    MAXRUN*4                ; dir col row len
pulses:         ds.w    NPULSE*4                ; run (-1 : off) pos speed -
boss_fixed:     ds.b    MAXBOSS
covbuf:         ds.b    MAP_MAXROWS*MAP_MAXCOLS
                even

;---------------------------------------------------------------------
; SHIP SPRITES : the 3D ship (9 DSP boxes, ~8 ms per frame on a real
;   Falcon) is drawn once per form / place at the start (ship_prerender)
;   into tmpbuf, cropped and kept ; ship_sprite copies the nearest one
;   (5 places across x 3 places along : its side faces stay right).
                section text
SPR_NX          equ     5
SPR_NY          equ     3
SPR_HALF        equ     32                      ; (drawn in 64 x 64 around it)

ship_prerender:
                movem.l d0-d7/a0-a6,-(sp)
                move.l  #spr_pool,spr_free
                move.w  clip_y0,-(sp)
                move.w  clip_y1,-(sp)
                clr.w   clip_y0
                move.w  #SCR_H-1,clip_y1
                move.w  #SHIP_Z,mdl_z
                lea     spr_tab,a4
                moveq   #0,d7                   ; form
.f:             moveq   #0,d6                   ; place y
.y:             moveq   #0,d5                   ; place x
.x:             movem.l d5-d7,-(sp)
                move.w  d5,d0                   ; world x, y of this place
                subq.w  #SPR_NX/2,d0
                muls    #SPR_DX,d0
                move.w  d6,d1
                add.w   d1,d1
                lea     spr_wy,a0
                move.w  (a0,d1.w),d1
                move.w  d0,d2                   ; screen centre sx, sy
                move.w  d1,d3
                muls    #FOC,d2
                divs    #SHIP_Z,d2
                add.w   #CX,d2
                muls    #FOC,d3
                divs    #SHIP_Z,d3
                add.w   #CY,d3
                movem.w d0-d3,-(sp)
                lea     tmpbuf,a6               ; 64 x 64 of key colour
                move.w  d3,d4
                sub.w   #SPR_HALF,d4
                mulu    #LINEB,d4
                lea     (a6,d4.l),a0
                move.w  d2,d4
                sub.w   #SPR_HALF,d4
                add.w   d4,d4
                adda.w  d4,a0
                moveq   #2*SPR_HALF-1,d4
.k1:            move.l  a0,a1
                moveq   #2*SPR_HALF-1,d0
.k2:            move.w  #BK_KEY,(a1)+
                dbra    d0,.k2
                lea     LINEB(a0),a0
                dbra    d4,.k1
                movem.w (sp),d0-d3
                move.w  d7,d4                   ; the ship : 3D picture of this
                mulu    #SPR_NX*SPR_NY,d4       ;  form and place (SHIPGFX.S,
                move.w  d6,d0                   ;  outils\SHIPGEN.PY)
                mulu    #SPR_NX,d0
                add.w   d0,d4
                add.w   d5,d4
                lsl.w   #2,d4
                lea     ship_imgs,a0
                move.l  (a0,d4.w),a0
                bsr     ship_img
                movem.w (sp)+,d0-d3
                ; --- bounds of the drawn pixels (d2,d3 = centre)
                move.w  d3,d4
                sub.w   #SPR_HALF,d4
                mulu    #LINEB,d4
                lea     (a6,d4.l),a0
                move.w  d2,d4
                sub.w   #SPR_HALF,d4
                add.w   d4,d4
                adda.w  d4,a0                   ; a0 = top left of the 64 x 64
                move.w  #999,d4                 ; x0 y0 x1 y1 (in the 64 x 64)
                move.w  #999,d5
                moveq   #-1,d6
                moveq   #-1,d7
                moveq   #0,d1
.by:            move.l  a0,a1
                moveq   #0,d0
.bx:            cmp.w   #BK_KEY,(a1)+
                beq.s   .bn
                cmp.w   d4,d0
                bge.s   .b1
                move.w  d0,d4
.b1:            cmp.w   d6,d0
                ble.s   .b2
                move.w  d0,d6
.b2:            cmp.w   d5,d1
                bge.s   .b3
                move.w  d1,d5
.b3:            move.w  d1,d7
.bn:            addq.w  #1,d0
                cmp.w   #2*SPR_HALF,d0
                blt.s   .bx
                lea     LINEB(a0),a0
                addq.w  #1,d1
                cmp.w   #2*SPR_HALF,d1
                blt.s   .by
                tst.w   d6                      ; nothing drawn : empty sprite
                bpl.s   .ok
                clr.l   (a4)+
                clr.l   (a4)+
                clr.l   (a4)+
                clr.l   (a4)+
                bra.s   .nx
.ok:            move.l  spr_free,a2             ; entry : ptr w h offx offy
                move.l  a2,(a4)+
                sub.w   d4,d6
                addq.w  #1,d6                   ; w
                sub.w   d5,d7
                addq.w  #1,d7                   ; h
                move.w  d6,(a4)+
                move.w  d7,(a4)+
                move.w  d4,d0
                sub.w   #SPR_HALF,d0
                move.w  d0,(a4)+                ; offx (from the centre)
                move.w  d5,d0
                sub.w   #SPR_HALF,d0
                move.w  d0,(a4)+                ; offy
                lea     -2*SPR_HALF*LINEB(a0),a0   ; copy the cropped pixels
                move.w  d5,d0
                mulu    #LINEB,d0
                adda.l  d0,a0
                add.w   d4,d4
                adda.w  d4,a0
                move.w  d6,d0                   ; (w, h for rle_build)
                move.w  d7,d1
                subq.w  #1,d7
.cy:            move.l  a0,a1
                move.w  d6,d2
                subq.w  #1,d2
.cx:            move.w  (a1)+,(a2)+
                dbra    d2,.cx
                lea     LINEB(a0),a0
                dbra    d7,.cy
                move.l  a2,spr_free
                move.l  -12(a4),a0              ; its pixels -> runs
                bsr     rle_build
                move.l  a0,(a4)+                ; entry : + runs
.nx:            movem.l (sp)+,d5-d7
                bsr     spr_tick                ; progress bar
                addq.w  #1,d5
                cmp.w   #SPR_NX,d5
                blt     .x
                addq.w  #1,d6
                cmp.w   #SPR_NY,d6
                blt     .y
                addq.w  #1,d7
                cmp.w   #3,d7
                blt     .f
                move.w  (sp)+,clip_y1
                move.w  (sp)+,clip_y0
                movem.l (sp)+,d0-d7/a0-a6
                rts

; en_prerender : the 3 enemies (joystick, cartridge, disk) drawn once at
;   EN_NX x EN_NY places (after ship_prerender : same pool)
en_prerender:
                movem.l d0-d7/a0-a6,-(sp)
                move.w  clip_y0,-(sp)
                move.w  clip_y1,-(sp)
                clr.w   clip_y0
                move.w  #SCR_H-1,clip_y1
                move.w  #SHIP_Z,mdl_z
                lea     en_tab,a4
                moveq   #0,d7                   ; form
.f:             moveq   #0,d6                   ; place y
.y:             moveq   #0,d5                   ; place x
.x:             movem.l d5-d7,-(sp)
                move.w  d5,d0                   ; world x, y of this place
                sub.w   #EN_NX/2,d0
                muls    #EN_DX,d0
                move.w  d6,d1
                add.w   d1,d1
                lea     en_wy,a0
                move.w  (a0,d1.w),d1
                move.w  d0,d2                   ; screen centre sx, sy
                move.w  d1,d3
                muls    #FOC,d2
                divs    #SHIP_Z,d2
                add.w   #CX,d2
                muls    #FOC,d3
                divs    #SHIP_Z,d3
                add.w   #CY,d3
                movem.w d0-d3,-(sp)
                lea     tmpbuf,a6               ; 64 x 64 of key colour
                move.w  d3,d4
                sub.w   #SPR_HALF,d4
                mulu    #LINEB,d4
                lea     (a6,d4.l),a0
                move.w  d2,d4
                sub.w   #SPR_HALF,d4
                add.w   d4,d4
                adda.w  d4,a0
                moveq   #2*SPR_HALF-1,d4
.k1:            move.l  a0,a1
                moveq   #2*SPR_HALF-1,d0
.k2:            move.w  #BK_KEY,(a1)+
                dbra    d0,.k2
                lea     LINEB(a0),a0
                dbra    d4,.k1
                movem.w (sp),d0-d3
                lea     en_mdls,a0              ; the model, drawn there
                move.w  d7,d4
                lsl.w   #2,d4
                move.l  (a0,d4.w),a0
                move.w  d0,d6
                move.w  d1,d7
                bsr     draw_model
                movem.w (sp)+,d0-d3
                ; --- bounds of the drawn pixels (d2,d3 = centre)
                move.w  d3,d4
                sub.w   #SPR_HALF,d4
                mulu    #LINEB,d4
                lea     (a6,d4.l),a0
                move.w  d2,d4
                sub.w   #SPR_HALF,d4
                add.w   d4,d4
                adda.w  d4,a0                   ; a0 = top left of the 64 x 64
                move.w  #999,d4                 ; x0 y0 x1 y1 (in the 64 x 64)
                move.w  #999,d5
                moveq   #-1,d6
                moveq   #-1,d7
                moveq   #0,d1
.by:            move.l  a0,a1
                moveq   #0,d0
.bx:            cmp.w   #BK_KEY,(a1)+
                beq.s   .bn
                cmp.w   d4,d0
                bge.s   .b1
                move.w  d0,d4
.b1:            cmp.w   d6,d0
                ble.s   .b2
                move.w  d0,d6
.b2:            cmp.w   d5,d1
                bge.s   .b3
                move.w  d1,d5
.b3:            move.w  d1,d7
.bn:            addq.w  #1,d0
                cmp.w   #2*SPR_HALF,d0
                blt.s   .bx
                lea     LINEB(a0),a0
                addq.w  #1,d1
                cmp.w   #2*SPR_HALF,d1
                blt.s   .by
                tst.w   d6                      ; nothing drawn : empty sprite
                bpl.s   .ok
                clr.l   (a4)+
                clr.l   (a4)+
                clr.l   (a4)+
                clr.l   (a4)+
                bra.s   .nx
.ok:            move.l  spr_free,a2             ; entry : ptr w h offx offy
                move.l  a2,(a4)+
                sub.w   d4,d6
                addq.w  #1,d6                   ; w
                sub.w   d5,d7
                addq.w  #1,d7                   ; h
                move.w  d6,(a4)+
                move.w  d7,(a4)+
                move.w  d4,d0
                sub.w   #SPR_HALF,d0
                move.w  d0,(a4)+                ; offx (from the centre)
                move.w  d5,d0
                sub.w   #SPR_HALF,d0
                move.w  d0,(a4)+                ; offy
                lea     -2*SPR_HALF*LINEB(a0),a0   ; copy the cropped pixels
                move.w  d5,d0
                mulu    #LINEB,d0
                adda.l  d0,a0
                add.w   d4,d4
                adda.w  d4,a0
                move.w  d6,d0                   ; (w, h for rle_build)
                move.w  d7,d1
                subq.w  #1,d7
.cy:            move.l  a0,a1
                move.w  d6,d2
                subq.w  #1,d2
.cx:            move.w  (a1)+,(a2)+
                dbra    d2,.cx
                lea     LINEB(a0),a0
                dbra    d7,.cy
                move.l  a2,spr_free
                move.l  -12(a4),a0              ; its pixels -> runs
                bsr     rle_build
                move.l  a0,(a4)+                ; entry : + runs
.nx:            movem.l (sp)+,d5-d7
                bsr     spr_tick                ; progress bar
                addq.w  #1,d5
                cmp.w   #EN_NX,d5
                blt     .x
                addq.w  #1,d6
                cmp.w   #EN_NY,d6
                blt     .y
                addq.w  #1,d7
                cmp.w   #3,d7
                blt     .f
                move.w  (sp)+,clip_y1
                move.w  (sp)+,clip_y0
                movem.l (sp)+,d0-d7/a0-a6
                rts

; sh_prerender : the shadow of each form (ship at 0,0, fx_shadow_box into
;   tmpbuf, black on the key colour) -> runs (sh_tab : like spr_tab, offx
;   offy from SH_CX, SH_CY)
sh_prerender:
                movem.l d0-d7/a0-a6,-(sp)
                move.w  clip_y0,-(sp)
                move.w  clip_y1,-(sp)
                clr.w   clip_y0
                move.w  #SCR_H-1,clip_y1
                move.w  px,-(sp)
                move.w  py,-(sp)
                clr.w   px
                clr.w   py
                lea     sh_tab,a4
                moveq   #0,d7                   ; form
.f:             lea     tmpbuf,a6               ; 64 x 64 of key colour
                lea     (SH_CY-SPR_HALF)*LINEB+(SH_CX-SPR_HALF)*2(a6),a0
                moveq   #2*SPR_HALF-1,d4
.k1:            move.l  a0,a1
                moveq   #2*SPR_HALF-1,d0
.k2:            move.w  #BK_KEY,(a1)+
                dbra    d0,.k2
                lea     LINEB(a0),a0
                dbra    d4,.k1
                lea     ship_imgs,a0            ; the ship's picture (middle
                move.w  d7,d4                   ;  place), black
                mulu    #SPR_NX*SPR_NY,d4
                add.w   #SPR_NX+SPR_NX/2,d4
                lsl.w   #2,d4
                move.l  (a0,d4.w),a0
                move.w  #SH_CX+SH_DX*FOC/SH_Z,d2
                move.w  #SH_CY+SH_DY*FOC/SH_Z,d3
                bsr     ship_mask
.bd:            move.w  #SH_CX,d2               ; crop + runs (centre SH_CX, SH_CY)
                move.w  #SH_CY,d3
                bsr     spr_crop
                lea     16(a4),a4
                addq.w  #1,d7
                cmp.w   #3,d7
                blt     .f
                move.w  (sp)+,py
                move.w  (sp)+,px
                move.w  (sp)+,clip_y1
                move.w  (sp)+,clip_y0
                movem.l (sp)+,d0-d7/a0-a6
                rts

; bon_prerender : the bonus pod (mdl_bonus) drawn once, at the centre
;   (small : the same picture everywhere) -> bon_tab
bon_prerender:
                movem.l d0-d7/a0-a6,-(sp)
                move.w  clip_y0,-(sp)
                move.w  clip_y1,-(sp)
                clr.w   clip_y0
                move.w  #SCR_H-1,clip_y1
                lea     tmpbuf,a6
                lea     (CY-SPR_HALF)*LINEB+(CX-SPR_HALF)*2(a6),a0
                moveq   #2*SPR_HALF-1,d4
.k1:            move.l  a0,a1
                moveq   #2*SPR_HALF-1,d0
.k2:            move.w  #BK_KEY,(a1)+
                dbra    d0,.k2
                lea     LINEB(a0),a0
                dbra    d4,.k1
                move.w  #SHIP_Z,mdl_z
                lea     mdl_bonus,a0
                moveq   #0,d6
                moveq   #0,d7
                bsr     draw_model
                move.w  #CX,d2
                move.w  #CY,d3
                lea     bon_tab,a4
                bsr     spr_crop
                move.w  (sp)+,clip_y1
                move.w  (sp)+,clip_y0
                movem.l (sp)+,d0-d7/a0-a6
                rts

; spr_crop : the 64 x 64 of tmpbuf around d2, d3 (screen) : what is not the
;   key colour -> entry a4 (ptr w h offx offy runs : 16 bytes, cleared if
;   nothing), pixels and runs at spr_free
spr_crop:
                movem.l d0-d7/a0-a4,-(sp)
                lea     tmpbuf,a6
                move.w  d3,d4
                sub.w   #SPR_HALF,d4
                mulu    #LINEB,d4
                lea     (a6,d4.l),a0
                move.w  d2,d4
                sub.w   #SPR_HALF,d4
                add.w   d4,d4
                adda.w  d4,a0                   ; a0 = top left of the 64 x 64
                move.w  #999,d4                 ; x0 y0 x1 y1 (in the 64 x 64)
                move.w  #999,d5
                moveq   #-1,d6
                moveq   #-1,d7
                moveq   #0,d1
.by:            move.l  a0,a1
                moveq   #0,d0
.bx:            cmp.w   #BK_KEY,(a1)+
                beq.s   .bn
                cmp.w   d4,d0
                bge.s   .b1
                move.w  d0,d4
.b1:            cmp.w   d6,d0
                ble.s   .b2
                move.w  d0,d6
.b2:            cmp.w   d5,d1
                bge.s   .b3
                move.w  d1,d5
.b3:            move.w  d1,d7
.bn:            addq.w  #1,d0
                cmp.w   #2*SPR_HALF,d0
                blt.s   .bx
                lea     LINEB(a0),a0
                addq.w  #1,d1
                cmp.w   #2*SPR_HALF,d1
                blt.s   .by
                tst.w   d6
                bpl.s   .ok
                clr.l   (a4)+                   ; nothing
                clr.l   (a4)+
                clr.l   (a4)+
                clr.l   (a4)+
                bra.s   .x
.ok:            move.l  spr_free,a2
                move.l  a2,(a4)+
                sub.w   d4,d6
                addq.w  #1,d6                   ; w
                sub.w   d5,d7
                addq.w  #1,d7                   ; h
                move.w  d6,(a4)+
                move.w  d7,(a4)+
                move.w  d4,d0
                sub.w   #SPR_HALF,d0
                move.w  d0,(a4)+                ; offx
                move.w  d5,d0
                sub.w   #SPR_HALF,d0
                move.w  d0,(a4)+                ; offy
                lea     -2*SPR_HALF*LINEB(a0),a0
                move.w  d5,d0
                mulu    #LINEB,d0
                adda.l  d0,a0
                add.w   d4,d4
                adda.w  d4,a0
                move.w  d6,d0
                move.w  d7,d1
                subq.w  #1,d7
.cy:            move.l  a0,a1
                move.w  d6,d2
                subq.w  #1,d2
.cx:            move.w  (a1)+,(a2)+
                dbra    d2,.cx
                lea     LINEB(a0),a0
                dbra    d7,.cy
                move.l  a2,spr_free
                move.l  -12(a4),a0
                bsr     rle_build
                move.l  a0,(a4)+
.x:             movem.l (sp)+,d0-d7/a0-a4
                rts

; en_sprite : enemy d4 = type (0 joystick, 1 cartridge, 2 disk) at world
;   d6, d7 (SHIP_Z) : the precomputed sprite of the nearest place
en_sprite:
                movem.l d0-d7/a0-a2,-(sp)
                move.w  d6,d0                   ; place x
                add.w   #EN_DX*(EN_NX/2)+EN_DX/2,d0
                ext.l   d0
                divs    #EN_DX,d0
                bpl.s   .p1
                moveq   #0,d0
.p1:            cmp.w   #EN_NX-1,d0
                ble.s   .p2
                moveq   #EN_NX-1,d0
.p2:            move.w  d7,d1                   ; place y
                add.w   #EN_DY*(EN_NY/2)+EN_DY/2,d1
                ext.l   d1
                divs    #EN_DY,d1
                bpl.s   .p3
                moveq   #0,d1
.p3:            cmp.w   #EN_NY-1,d1
                ble.s   .p4
                moveq   #EN_NY-1,d1
.p4:            mulu    #EN_NY,d4               ; entry (type*NY + y)*NX + x
                add.w   d1,d4
                mulu    #EN_NX,d4
                add.w   d0,d4
                lsl.w   #4,d4                   ; (16 bytes per entry)
                lea     en_tab,a2
                adda.l  d4,a2
                move.w  d6,d0                   ; its shadow : on the board,
                add.w   #SH_DX,d0               ;  offset like the ship's
                muls    #FOC,d0
                divs    #SH_Z,d0
                add.w   #CX,d0
                move.w  d7,d1
                add.w   #SH_DY,d1
                muls    #FOC,d1
                divs    #SH_Z,d1
                add.w   #CY,d1
                bsr     sh_runs
                move.w  d6,d0                   ; screen centre
                muls    #FOC,d0
                divs    #SHIP_Z,d0
                add.w   #CX,d0
                move.w  d7,d1
                muls    #FOC,d1
                divs    #SHIP_Z,d1
                add.w   #CY,d1
                bsr     spr_blit
                movem.l (sp)+,d0-d7/a0-a2
                rts

; sh_runs : the sprite a2 (entry : runs at 12, w h at 4, offx offy at 8)
;   as a shadow (pixels under it half as bright), centre d0, d1 ; nothing
;   if not all inside the screen
sh_runs:
                movem.l d0-d7/a0-a3,-(sp)
                move.l  12(a2),d2
                beq     .x
                move.l  d2,a0
                add.w   8(a2),d0
                add.w   10(a2),d1
                move.w  4(a2),d4
                move.w  6(a2),d5
                tst.w   d0
                bmi     .x
                move.w  d0,d2
                add.w   d4,d2
                cmp.w   #SCR_W,d2
                bgt     .x
                cmp.w   clip_y0,d1
                blt     .x
                move.w  d1,d3
                add.w   d5,d3
                subq.w  #1,d3
                cmp.w   clip_y1,d3
                bgt     .x
                subq.w  #1,d2                   ; erased next time
                bsr     add_rect
                mulu    #LINEB,d1
                lea     (a6,d1.l),a1
                add.w   d0,d0
                adda.w  d0,a1
                move.l  #$7BEF7BEF,d4
                subq.w  #1,d5
.ry:            move.w  (a0)+,d2
                subq.w  #1,d2
                bmi.s   .rn
.rr:            move.w  (a0)+,d3
                lea     (a1,d3.w),a3
                move.w  (a0)+,d3
                move.w  d3,d6
                addq.w  #1,d6
                add.w   d6,d6
                adda.w  d6,a0
                addq.w  #1,d3
                lsr.w   #1,d3
                bcc.s   .ev
                move.w  (a3),d0
                lsr.w   #1,d0
                and.w   d4,d0
                move.w  d0,(a3)+
.ev:            subq.w  #1,d3
                bmi.s   .rd
.rp:            move.l  (a3),d0
                lsr.l   #1,d0
                and.l   d4,d0
                move.l  d0,(a3)+
                dbra    d3,.rp
.rd:            dbra    d2,.rr
.rn:            lea     LINEB(a1),a1
                dbra    d5,.ry
.x:             movem.l (sp)+,d0-d7/a0-a3
                rts

; spr_prepare : sprites of the ship and the enemies, once (at the 1st
;   level) ; progress : a 3.5" floppy disk (the old cruiser of the game)
;   appears on the black picture from the bottom to the top
spr_prepare:
                tst.w   spr_done
                bne     .x
                movem.l d0-d7/a0-a2,-(sp)
                clr.w   spr_cnt
                clr.w   dk_rows
                lea     dk_img,a0               ; the disk : boxes of the model,
                lea     dk_box,a1               ;  front colours, x DK_S
.b:             movem.w (a1)+,d0-d4             ; x0 y0 x1 y1 colour (-99 : end)
                cmp.w   #-99,d0
                beq.s   .bd
                add.w   #13,d0                  ; units -13..13 -> pixels
                add.w   #13,d1
                add.w   #13,d2
                add.w   #13,d3
                mulu    #DK_S,d0
                mulu    #DK_S,d1
                mulu    #DK_S,d2
                mulu    #DK_S,d3
                sub.w   d0,d2                   ; width
                subq.w  #1,d2
                sub.w   d1,d3                   ; height
                subq.w  #1,d3
                mulu    #DK_W*2,d1
                lea     (a0,d1.l),a2
                add.w   d0,d0
                adda.w  d0,a2
.by:            move.w  d2,d5
                move.l  a2,-(sp)
.bx:            move.w  d4,(a2)+
                dbra    d5,.bx
                move.l  (sp)+,a2
                lea     DK_W*2(a2),a2
                dbra    d3,.by
                bra.s   .b
.bd:            lea     dk_txt,a0               ; text under the disk (x2)
                move.w  #DK_TY,d1
                move.w  #$FFFF,d2
                moveq   #2,d3
                bsr     bs_text
                movem.l (sp)+,d0-d7/a0-a2
                bsr     ship_prerender
                bsr     en_prerender
                bsr     sh_prerender
                bsr     bon_prerender
                move.w  #1,spr_done
                movem.l d0-d1/a0,-(sp)          ; disk wiped (black again)
                lea     blackscr+DK_Y*SCR_W*2,a0
                move.w  #(DK_TY+12-DK_Y)*SCR_W/2-1,d0
.c:             clr.l   (a0)+
                dbra    d0,.c
                movem.l (sp)+,d0-d1/a0
.x:             rts

; spr_tick : one more sprite : the disk rises (DK_W lines for PB_N sprites)
spr_tick:
                movem.l d0-d3/a0-a1,-(sp)
                addq.w  #1,spr_cnt
                move.w  spr_cnt,d0
                mulu    #DK_W,d0
                divu    #PB_N,d0
                cmp.w   #DK_W,d0
                bls.s   .w
                move.w  #DK_W,d0
.w:             move.w  dk_rows,d1              ; new lines, from the bottom
.l:             cmp.w   d0,d1
                bhs.s   .x
                addq.w  #1,d1
                move.w  #DK_W,d2
                sub.w   d1,d2                   ; line of the disk
                move.w  d2,d3
                mulu    #DK_W*2,d3
                lea     dk_img,a0
                adda.l  d3,a0
                add.w   #DK_Y,d2
                mulu    #SCR_W*2,d2
                lea     blackscr+DK_X*2,a1
                adda.l  d2,a1
                moveq   #DK_W/2-1,d3
.p:             move.l  (a0)+,(a1)+
                dbra    d3,.p
                bra.s   .l
.x:             move.w  d1,dk_rows
                movem.l (sp)+,d0-d3/a0-a1
                rts

; bs_text : string a0 centred on line d1 of blackscr (640-byte lines), TOS
;   6x6 font (font6) with pixels of d3 x d3 (1..4), colour d2
bs_text:
                movem.l d0-d7/a0-a3,-(sp)
                move.l  a0,a1                   ; width -> x
                moveq   #0,d0
.n:             tst.b   (a1)+
                beq.s   .n1
                addq.w  #1,d0
                bra.s   .n
.n1:            mulu    #6,d0
                mulu    d3,d0
                neg.w   d0
                add.w   #SCR_W,d0
                bpl.s   .n2
                moveq   #0,d0
.n2:            lsr.w   #1,d0
                mulu    #SCR_W*2,d1
                lea     blackscr,a3
                adda.l  d1,a3
                add.w   d0,d0
                adda.w  d0,a3
                move.w  d3,d7                   ; bytes of a font pixel
                add.w   d7,d7
                subq.w  #1,d3
.ch:            moveq   #0,d0
                move.b  (a0)+,d0
                beq.s   .x
                lsl.w   #3,d0
                lea     font6,a1
                adda.w  d0,a1                   ; its 6 rows
                move.l  a3,a2
                moveq   #5,d6
.fl:            move.b  (a1)+,d5                ; bits 7..2
                moveq   #5,d4
                move.l  a2,-(sp)
.px:            add.b   d5,d5
                bcc.s   .p0
                move.l  a2,-(sp)                ; d3 x d3 square
                move.w  d3,d1
.sy:            move.w  d3,d0
                move.l  a2,-(sp)
.sx:            move.w  d2,(a2)+
                dbra    d0,.sx
                move.l  (sp)+,a2
                lea     SCR_W*2(a2),a2
                dbra    d1,.sy
                move.l  (sp)+,a2
.p0:            adda.w  d7,a2
                dbra    d4,.px
                move.l  (sp)+,a2
                move.w  d3,d0                   ; next font row : d3 lines
                addq.w  #1,d0
                mulu    #SCR_W*2,d0
                adda.l  d0,a2
                dbra    d6,.fl
                move.w  d7,d0                   ; next character : 6 pixels
                mulu    #6,d0
                adda.w  d0,a3
                bra.s   .ch
.x:             movem.l (sp)+,d0-d7/a0-a3
                rts

DK_S            equ     4                       ; pixels per unit of the model
DK_W            equ     26*DK_S                 ; size of the disk (square)
DK_X            equ     (SCR_W-DK_W)/2          ; place on blackscr
DK_Y            equ     (SCR_H-DK_W)/2
DK_TY           equ     DK_Y+DK_W+12            ; line of the text
PB_N            equ     3*(SPR_NX*SPR_NY+EN_NX*EN_NY)

                section data
; the 3.5" disk (former cruiser mdl_en1) : x0 y0 x1 y1 (units), colour
dk_box:         dc.w    -13,-13,13,13,$2A7F     ; disk (blue)
                dc.w    -6,-13,6,-3,$C618       ; metal shutter
                dc.w    -2,-11,1,-5,$2945       ;  (its window)
                dc.w    -10,1,10,12,$FFFF       ; label
                dc.w    -10,4,10,5,$F800        ;  (a red line on it)
                dc.w    -99,0,0,0,0
dk_txt:         dc.b    'PLEASE WAIT, LOADING',0
                even
                section bss
dk_img:         ds.w    DK_W*DK_W
dk_rows:        ds.w    1                       ; lines of the disk shown
                section text

; ship_mask : as ship_img, but its pixels in black (the shadow)
ship_mask:
                movem.l d0-d5/a0-a2,-(sp)
                movem.w (a0)+,d4-d5             ; w h
                add.w   (a0)+,d2                ; + offx offy
                add.w   (a0)+,d3
                mulu    #LINEB,d3
                lea     (a6,d3.l),a1
                add.w   d2,d2
                adda.w  d2,a1
                move.w  d5,d1
                subq.w  #1,d1
.y:             move.l  a1,a2
                move.w  d4,d0
                subq.w  #1,d0
.x:             cmp.w   #BK_KEY,(a0)+
                beq.s   .n
                clr.w   (a2)
.n:             addq.l  #2,a2
                dbra    d0,.x
                lea     LINEB(a1),a1
                dbra    d1,.y
                movem.l (sp)+,d0-d5/a0-a2
                rts

; ship_img : picture a0 (w, h, offx, offy, pixels) at the place centre d2,d3 of a6
ship_img:
                movem.l d0-d5/a0-a2,-(sp)
                movem.w (a0)+,d4-d5             ; w h
                add.w   (a0)+,d2                ; + offx offy
                add.w   (a0)+,d3
                mulu    #LINEB,d3
                lea     (a6,d3.l),a1
                add.w   d2,d2
                adda.w  d2,a1
                move.w  d5,d1
                subq.w  #1,d1
.y:             move.l  a1,a2
                move.w  d4,d0
                subq.w  #1,d0
.x:             move.w  (a0)+,(a2)+
                dbra    d0,.x
                lea     LINEB(a1),a1
                dbra    d1,.y
                movem.l (sp)+,d0-d5/a0-a2
                rts

                section data
                include 'SHIPGFX.S'
                section text

; ship_sprite : the ship (form, px, py) ; a6 = screen
ship_sprite:
                movem.l d0-d7/a0-a2,-(sp)
                move.w  px,d0                   ; nearest place x : 0 .. 4
                add.w   #SPR_DX*(SPR_NX/2)+SPR_DX/2,d0
                ext.l   d0
                divs    #SPR_DX,d0
                bpl.s   .p1
                moveq   #0,d0
.p1:            cmp.w   #SPR_NX-1,d0
                ble.s   .p2
                moveq   #SPR_NX-1,d0
.p2:            moveq   #0,d1                   ; place y
                move.w  py,d2
                cmp.w   #SPR_Y01,d2
                blt.s   .p3
                moveq   #1,d1
                cmp.w   #SPR_Y12,d2
                blt.s   .p3
                moveq   #2,d1
.p3:            move.w  form,d2                 ; entry (form*NY + y)*NX + x
                mulu    #SPR_NY,d2
                add.w   d1,d2
                mulu    #SPR_NX,d2
                add.w   d0,d2
                lsl.w   #4,d2                   ; (16 bytes per entry)
                lea     spr_tab,a2
                adda.w  d2,a2
                move.w  px,d0                   ; screen centre of the ship
                muls    #FOC,d0
                divs    #SHIP_Z,d0
                add.w   #CX,d0
                move.w  py,d1
                muls    #FOC,d1
                divs    #SHIP_Z,d1
                add.w   #CY,d1
                bsr     spr_blit
.x:             movem.l (sp)+,d0-d7/a0-a2
                rts

; rle_build : pixels a0 (w d0 x h d1, key = transparent) -> runs at spr_free,
;   a0 = them. Each line : number of runs.w, then for each run : offset
;   (bytes).w, pixels - 1.w, the pixels
rle_build:
                movem.l d0-d6/a1-a3,-(sp)
                move.l  spr_free,a2
                move.l  a2,-(sp)
                move.w  d1,d6
                subq.w  #1,d6
.y:             move.l  a2,a3                   ; (number of runs : here)
                clr.w   (a2)+
                moveq   #0,d2                   ; x
.x:             cmp.w   d0,d2
                bge.s   .ny
                cmp.w   #BK_KEY,(a0)
                bne.s   .run
                addq.l  #2,a0
                addq.w  #1,d2
                bra.s   .x
.run:           addq.w  #1,(a3)
                move.w  d2,d3
                add.w   d3,d3
                move.w  d3,(a2)+                ; offset
                move.l  a2,a1                   ; (length : here)
                move.w  #-1,(a2)+
.rp:            move.w  (a0)+,(a2)+
                addq.w  #1,(a1)
                addq.w  #1,d2
                cmp.w   d0,d2
                bge.s   .ny
                cmp.w   #BK_KEY,(a0)
                bne.s   .rp
                bra.s   .x
.ny:            dbra    d6,.y
                move.l  a2,spr_free
                move.l  (sp)+,a0
                movem.l (sp)+,d0-d6/a1-a3
                rts

; spr_blit : sprite entry a2 (ptr w h offx offy runs) at screen centre d0, d1
;   (key colour skipped, clipped, erased next time : add_rect) ; all in the
;   screen : copied by runs (fast)
spr_blit:
                movem.l d0-d7/a0-a3,-(sp)
                move.l  (a2)+,a0
                move.l  a0,d2
                beq     .x
                move.w  (a2)+,d4                ; w
                move.w  (a2)+,d5                ; h
                add.w   (a2)+,d0                ; x0
                add.w   (a2)+,d1                ; y0
                tst.w   d0                      ; --- inside ? runs
                bmi.s   .cl
                move.w  d0,d2
                add.w   d4,d2
                cmp.w   #SCR_W,d2
                bgt.s   .cl
                cmp.w   clip_y0,d1
                blt.s   .cl
                move.w  d1,d2
                add.w   d5,d2
                subq.w  #1,d2
                cmp.w   clip_y1,d2
                bgt.s   .cl
                move.l  (a2),a0                 ; runs
                movem.w d0-d1/d4-d5,-(sp)       ; erased next time
                move.w  d0,d2
                add.w   d4,d2
                subq.w  #1,d2
                move.w  d1,d3
                add.w   d5,d3
                subq.w  #1,d3
                bsr     add_rect
                movem.w (sp)+,d0-d1/d4-d5
                mulu    #LINEB,d1
                lea     (a6,d1.l),a1
                add.w   d0,d0
                adda.w  d0,a1
                subq.w  #1,d5
.ry:            move.w  (a0)+,d2                ; runs of the line
                subq.w  #1,d2
                bmi.s   .rn
.rr:            move.w  (a0)+,d3
                lea     (a1,d3.w),a3
                move.w  (a0)+,d3
.rc:            move.w  (a0)+,(a3)+
                dbra    d3,.rc
                dbra    d2,.rr
.rn:            lea     LINEB(a1),a1
                dbra    d5,.ry
                bra     .x
.cl:
                move.w  d4,d6                   ; d6 = source line (bytes)
                add.w   d6,d6
                tst.w   d0                      ; --- clipping
                bpl.s   .c1
                add.w   d0,d4                   ;  left
                sub.w   d0,a0
                sub.w   d0,a0
                moveq   #0,d0
.c1:            move.w  d0,d2
                add.w   d4,d2
                sub.w   #SCR_W,d2
                ble.s   .c2
                sub.w   d2,d4                   ;  right
.c2:            move.w  clip_y0,d2
                sub.w   d1,d2
                ble.s   .c3
                sub.w   d2,d5                   ;  top
                mulu    d6,d2
                adda.l  d2,a0
                move.w  clip_y0,d1
.c3:            move.w  d1,d2
                add.w   d5,d2
                subq.w  #1,d2
                sub.w   clip_y1,d2
                ble.s   .c4
                sub.w   d2,d5                   ;  bottom
.c4:            tst.w   d4
                ble.s   .x
                tst.w   d5
                ble.s   .x
                movem.w d0-d1/d4-d5,-(sp)       ; erased next time
                move.w  d0,d2
                add.w   d4,d2
                subq.w  #1,d2
                move.w  d1,d3
                add.w   d5,d3
                subq.w  #1,d3
                bsr     add_rect
                movem.w (sp)+,d0-d1/d4-d5
                move.w  d1,d2                   ; destination
                mulu    #LINEB,d2
                lea     (a6,d2.l),a1
                add.w   d0,d0
                adda.w  d0,a1
                move.w  #BK_KEY,d7
                subq.w  #1,d5
.ly:            move.l  a0,a2
                move.l  a1,d3
                move.w  d4,d2
                subq.w  #1,d2
.lx:            move.w  (a2)+,d0
                cmp.w   d7,d0
                beq.s   .s
                move.w  d0,(a1)
.s:             addq.l  #2,a1
                dbra    d2,.lx
                adda.w  d6,a0
                move.l  d3,a1
                lea     LINEB(a1),a1
                dbra    d5,.ly
.x:             movem.l (sp)+,d0-d7/a0-a3
                rts

                section data
spr_wy:         dc.w    -70,0,80                ; places along (world y)
en_wy:
EN_I            set     0
                rept    EN_NY
                dc.w    (EN_I-EN_NY/2)*EN_DY
EN_I            set     EN_I+1
                endr
en_mdls:        dc.l    mdl_en0,mdl_en2,mdl_en1
                section bss
spr_free:       ds.l    1
spr_cnt:        ds.w    1
spr_done:       ds.w    1
spr_tab:        ds.w    3*SPR_NX*SPR_NY*8       ; ptr.l w h offx offy runs.l
en_tab:         ds.w    3*EN_NX*EN_NY*8
sh_tab:         ds.w    3*8                     ; shadows (sh_prerender)
bon_tab:        ds.w    8                       ; bonus pod (bon_prerender)
spr_pool:       ds.w    3*(SPR_NX*SPR_NY+EN_NX*EN_NY+2)*2*SPR_HALF*2*SPR_HALF*2
                even
                section text
