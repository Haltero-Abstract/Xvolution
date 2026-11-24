;=====================================================================
; COMPOS.S - COMPONENTS OF THE CIRCUIT BOARD IN 3D (scenery for now)
;   (included by SHOTEMUP.S ; the list comes from LEVEL1.MAP, CARTE.S)
;
; Each component type has a model : boxes in pixels of the ground
; (x0 y0 x1 y1 from the top-left corner of its first tile) and the depth
; of their top (z0, the ground is at GROUND_Z), drawn by draw_box (DSP)
; after conversion to world units at GROUND_Z (like the old pillars).
; Model : x0 y0 x1 y1 z0 .w, colours .l ; -99 = end. Boxes far first.
;=====================================================================

; The components do not move on the board : each one is drawn ONCE in 3D
; ("baked") into the clean ground G (SOL.S) as soon as it is completely in
; the GM lines prepared above the screen, then it scrolls for free with the
; ground. It is drawn as if it were in the middle of the screen (its side
; faces left / right are right, the top / bottom ones are those of the
; middle) : first in tmpbuf (filled with the colour key), then copied
; into the lines of G (and their copies).
BK_PAD          equ     16                      ; perspective margin (lines)

; bake_reset : no component baked (new ground)
bake_reset:
                movem.l d0/a0,-(sp)
                move.w  ncomps,d0
                beq.s   .x
                subq.w  #1,d0
                lea     comps+6,a0
.l:             clr.w   (a0)
                addq.l  #8,a0
                dbra    d0,.l
.x:             movem.l (sp)+,d0/a0
                rts

; bake_scan : bakes the components now completely in G (above the screen
;   or on it after a jump)
bake_scan:
                move.w  #BAKE_MAX,bk_budget     ; in the frame : BAKE_MAX at most
                bra.s   bake_go                 ;  (unless one is near the screen)
bake_all:                                       ; full redraw : all of them
                move.w  #$7fff,bk_budget
bake_go:
                movem.l d0-d7/a0-a2,-(sp)
                move.w  ncomps,d7
                beq     .x
                subq.w  #1,d7
                lea     comps,a2
                move.l  gpos,d5
                sub.l   #GM-BK_PAD,d5           ; top of G (+ margin)
.c:             tst.w   6(a2)
                bne.s   .n                      ; (already baked)
                moveq   #0,d0                   ; its top world line
                move.w  4(a2),d0
                mulu    #TILE_PX,d0
                cmp.l   d5,d0
                blt.s   .n                      ; not yet all in G
                tst.w   bk_budget               ; budget of this frame used :
                bgt.s   .ok                     ;  only if it will soon reach
                move.l  gpos,d1                 ;  the screen (BAKE_NEAR lines)
                sub.l   #BAKE_NEAR,d1
                cmp.l   d1,d0
                blt.s   .n
.ok:            subq.w  #1,bk_budget
                move.w  #1,6(a2)
                move.l  gpos,d1                 ; already gone below the screen :
                add.l   #SCR_H,d1               ;  nothing to draw
                cmp.l   d1,d0
                bgt.s   .n
                bsr     bake_one
.n:             addq.l  #8,a2
                dbra    d7,.c
.x:             movem.l (sp)+,d0-d7/a0-a2
                rts

; bake_one : component a2 (type, column, row) -> tmpbuf -> G
bake_one:
                movem.l d0-d7/a0-a6,-(sp)
                move.w  (a2),d2
                lea     comp_h,a0               ; height (rows) -> centred on CY
                moveq   #0,d3
                move.b  (a0,d2.w),d3
                mulu    #TILE_PX,d3
                lsr.w   #1,d3
                move.w  #CY,d1
                sub.w   d3,d1                   ; y on tmpbuf of its 1st row
                move.w  d1,bk_y
                move.w  (a2),d2                 ; --- horizontal : the view of the
                lea     comp_w,a0               ;  camera, moved so that the whole
                moveq   #0,d3                   ;  component is on the screen
                move.b  (a0,d2.w),d3
                mulu    #TILE_PX,d3             ; d3 = width
                move.w  2(a2),d0
                mulu    #TILE_PX,d0             ; d0 = x in the map
                move.w  camx,d4                 ; d4 = view
                move.w  d0,d5
                sub.w   d4,d5
                cmp.w   #16,d5
                bge.s   .v1
                move.w  d0,d4
                sub.w   #16,d4
.v1:            move.w  d0,d5
                add.w   d3,d5
                sub.w   d4,d5
                cmp.w   #SCR_W-16,d5
                ble.s   .v2
                move.w  d0,d4
                add.w   d3,d4
                sub.w   #SCR_W-16,d4
.v2:            tst.w   d4
                bpl.s   .v3
                moveq   #0,d4
.v3:            cmp.w   cam_max,d4
                ble.s   .v4
                move.w  cam_max,d4
.v4:            move.w  d4,bk_vx
                sub.w   d4,d0                   ; x on tmpbuf
                move.w  (a2),d2
                lsl.w   #2,d2
                lea     comp_mdl,a0
                move.l  (a0,d2.w),a0
                lea     tmpbuf,a6
                bsr     obj_begin
                bsr     comp_draw
                bsr     comp_label              ; its name on the top
                movem.w bb_x0,d0-d3             ; drawn box x0 y0 x1 y1
                cmp.w   d2,d0
                bgt     .x
                cmp.w   d3,d1
                bgt     .x
                ; --- copy the non-key pixels to G, line by line
                sub.w   d0,d2                   ; width - 1
                sub.w   d1,d3                   ; lines - 1
                moveq   #0,d4                   ; world line of tmpbuf line d1 :
                move.w  4(a2),d4                ;  row * 20 + (d1 - bk_y)
                mulu    #TILE_PX,d4
                move.w  d1,d5
                sub.w   bk_y,d5
                ext.l   d5
                add.l   d5,d4
                move.w  d1,d5
                mulu    #LINEB,d5
                lea     tmpbuf,a3
                adda.l  d5,a3
                add.w   d0,d0
                adda.w  d0,a3                   ; a3 = 1st pixel in tmpbuf
                moveq   #0,d6
                move.w  d0,d6                   ; d6 = x offset (bytes) in G :
                move.w  bk_vx,d0                ;  + the view
                add.w   d0,d0
                add.w   d0,d6
.ln:            move.l  d4,d0
                movem.l d2-d3,-(sp)
                bsr     gnd_phys                ; a0 = line in G, d1 = copy
                movem.l (sp)+,d2-d3
                adda.l  d6,a0
                move.l  d1,a5
                tst.l   d1
                bmi.s   .nc
                move.l  gbuf,a5
                adda.l  d1,a5
                adda.l  d6,a5
.nc:            move.l  a3,a4
                move.w  d2,d7
                move.w  #BK_KEY,d1
                cmp.l   #-1,a5
                beq.s   .one
.two:           move.w  (a4)+,d0                ; line with a copy : both
                cmp.w   d1,d0
                beq.s   .t1
                move.w  d0,(a0)
                move.w  d0,(a5)
                move.w  d1,-2(a4)               ; (tmpbuf cleaned)
.t1:            addq.l  #2,a0
                addq.l  #2,a5
                dbra    d7,.two
                bra.s   .k2
.one:           move.w  (a4)+,d0                ; line without a copy
                cmp.w   d1,d0
                beq.s   .o1
                move.w  d0,(a0)
                move.w  d1,-2(a4)
.o1:            addq.l  #2,a0
                dbra    d7,.one
.k2:
                lea     LINEB(a3),a3
                addq.l  #1,d4
                dbra    d3,.ln
.x:             movem.l (sp)+,d0-d7/a0-a6
                rts

; comp_label : name of the component a2 printed on its top in tmpbuf
;   (d0 = x on tmpbuf of its 1st column, bk_y = y of its 1st row). Centre of
;   the top = centre of the ground box seen at the depth LBL_Z. Long side
;   vertical : written from bottom to top (like on the real chips).
comp_label:
                movem.l d0-d7/a0-a1/a3/a6,-(sp)
                move.l  a2,d1                   ; index = (a2 - comps) / 8
                sub.l   #comps,d1
                lsr.l   #3,d1
                mulu    #LBL_LEN,d1
                lea     comp_lbl,a0
                adda.l  d1,a0
                cmp.b   #'*',(a0)               ; (* = boss : not printed)
                bne.s   .nb
                addq.l  #1,a0
.nb:            tst.b   (a0)
                beq     .x
                move.w  (a2),d2
                lea     comp_w,a1
                moveq   #0,d3
                move.b  (a1,d2.w),d3
                mulu    #TILE_PX,d3             ; d3 = width (pixels)
                lea     comp_h,a1
                moveq   #0,d4
                move.b  (a1,d2.w),d4
                mulu    #TILE_PX,d4             ; d4 = height
                move.w  #LBL_Z,d1               ; depth of its top
                cmp.w   #7,d2                   ; (F : the 68030 fan is higher)
                bne.s   .z
                move.w  #LBL_ZF,d1
.z:             move.w  d3,d5                   ; centre x on the ground
                lsr.w   #1,d5
                add.w   d0,d5
                sub.w   #CX,d5                  ; -> at the depth of the top
                muls    #GROUND_Z,d5
                divs    d1,d5
                add.w   #CX,d5
                move.w  d4,d6                   ; centre y
                lsr.w   #1,d6
                add.w   bk_y,d6
                sub.w   #CY,d6
                muls    #GROUND_Z,d6
                divs    d1,d6
                add.w   #CY,d6
                move.l  a0,a1                   ; n = length
                moveq   #0,d7
.n:             tst.b   (a1)+
                beq.s   .n1
                addq.w  #1,d7
                bra.s   .n
.n1:            lea     tmpbuf,a6
                move.w  d7,d2                   ; half length = n * 3
                mulu    #3,d2
                cmp.w   d3,d4
                bgt.s   .vert
                sub.w   d2,d5                   ; horizontal : x0 = cx - 3n
                subq.w  #3,d6                   ;  y0 = cy - 3
                movem.w d5-d6,-(sp)             ; dark band under the name :
                subq.w  #1,d5                   ;  (x0-1, y0-1) 6n+1 x 8
                subq.w  #1,d6
                move.w  d7,d3
                mulu    #6,d3
                moveq   #7,d4
                bsr     lbl_band
                movem.w (sp)+,d5-d6
.hc:            move.b  (a0)+,d0
                beq     .x
                bsr     lbl_glyph               ; a1 = glyph, d1 = shift
                bmi.s   .hn
                moveq   #5,d2                   ; 6 lines
                move.w  d6,d3
.hl:            move.b  (a1),d4
                lsl.w   #8,d4
                move.b  1(a1),d4
                lsl.w   d1,d4
                move.w  d3,d7
                mulu    #LINEB,d7
                lea     (a6,d7.l),a3
                move.w  d5,d7
                add.w   d7,d7
                adda.w  d7,a3
                moveq   #5,d7
.hp:            add.w   d4,d4
                bcc.s   .h0
                move.w  #LBL_COL,(a3)
.h0:            addq.l  #2,a3
                dbra    d7,.hp
                addq.w  #1,d3
                adda.w  fontw,a1
                dbra    d2,.hl
.hn:            addq.w  #6,d5
                bra.s   .hc
.vert:          add.w   d2,d6                   ; vertical : 1st char at the bottom
                subq.w  #3,d5                   ;  x0 = cx - 3 (glyph line r -> x0 + r)
                movem.w d5-d6,-(sp)             ; dark band : (x0-1, base-6n-1) 8 x 6n+1
                subq.w  #1,d5
                move.w  d7,d4
                mulu    #6,d4
                sub.w   d4,d6
                subq.w  #1,d6
                moveq   #7,d3
                bsr     lbl_band
                movem.w (sp)+,d5-d6
.vc:            move.b  (a0)+,d0
                beq     .x
                bsr     lbl_glyph
                bmi.s   .vn
                moveq   #0,d2                   ; glyph line r = 0..5
.vl:            move.b  (a1),d4
                lsl.w   #8,d4
                move.b  1(a1),d4
                lsl.w   d1,d4
                moveq   #0,d7                   ; column c = 0..5 -> y = base - 1 - c
.vp:            add.w   d4,d4
                bcc.s   .v0
                move.w  d6,d3
                subq.w  #1,d3
                sub.w   d7,d3
                mulu    #LINEB,d3
                lea     (a6,d3.l),a3
                move.w  d5,d3
                add.w   d2,d3
                add.w   d3,d3
                move.w  #LBL_COL,(a3,d3.w)
.v0:            addq.w  #1,d7
                cmp.w   #6,d7
                blt.s   .vp
                adda.w  fontw,a1
                addq.w  #1,d2
                cmp.w   #6,d2
                blt.s   .vl
.vn:            subq.w  #6,d6
                bra.s   .vc
.x:             movem.l (sp)+,d0-d7/a0-a1/a3/a6
                rts

; lbl_band : rectangle d5,d6 (x,y) of d3+1 x d4+1 pixels in a6, chip colour
lbl_band:
                movem.l d0-d4/a3,-(sp)
.y:             move.w  d6,d0
                mulu    #LINEB,d0
                lea     (a6,d0.l),a3
                move.w  d5,d0
                add.w   d0,d0
                adda.w  d0,a3
                move.w  d3,d0
.x:             move.w  #LBL_BG,(a3)+
                dbra    d0,.x
                addq.w  #1,d6
                dbra    d4,.y
                movem.l (sp)+,d0-d4/a3
                rts

; lbl_glyph : character d0 -> a1 = 1st line of its glyph, d1 = bit shift ;
;   N set = nothing to draw (space, _ , unknown)
lbl_glyph:
                and.w   #$ff,d0
                cmp.w   #'_',d0
                beq.s   .no
                cmp.w   #' ',d0
                bls.s   .no
                sub.w   fontfirst,d0
                bmi.s   .no
                add.w   d0,d0
                move.l  fontoff,a1
                move.w  (a1,d0.w),d1
                move.w  d1,d0
                lsr.w   #3,d0
                move.l  fontdat,a1
                adda.w  d0,a1
                and.w   #7,d1
                moveq   #0,d0                   ; N clear
                rts
.no:            moveq   #-1,d0
                rts

; bake_init : tmpbuf filled with the key (once)
bake_init:
                movem.l d0-d1/a0,-(sp)
                lea     tmpbuf,a0
                move.l  #(BK_KEY<<16)|BK_KEY,d1
                move.l  #LINEB*SCR_H/4-1,d0
.f:             move.l  d1,(a0)+
                subq.l  #1,d0
                bpl.s   .f
                movem.l (sp)+,d0-d1/a0
                rts

; comp_draw : model a0 at the screen position d0 (x), d1 (y) of the ground
comp_draw:
                movem.l d0-d7/a0-a1,-(sp)
                move.w  d0,d6
                move.w  d1,d7
.b:             move.w  (a0)+,d0
                cmp.w   #-99,d0
                beq.s   .x
                move.w  (a0)+,d1
                move.w  (a0)+,d2
                move.w  (a0)+,d3
                move.w  (a0)+,d4                ; z0 (top)
                move.l  (a0)+,a1
                add.w   d6,d0                   ; -> world at GROUND_Z :
                add.w   d6,d2                   ;  (screen - centre) * GZ / FOC
                add.w   d7,d1
                add.w   d7,d3
                sub.w   #CX,d0
                sub.w   #CX,d2
                sub.w   #CY,d1
                sub.w   #CY,d3
                muls    #GROUND_Z,d0
                divs    #FOC,d0
                muls    #GROUND_Z,d2
                divs    #FOC,d2
                muls    #GROUND_Z,d1
                divs    #FOC,d1
                muls    #GROUND_Z,d3
                divs    #FOC,d3
                move.w  #GROUND_Z,d5
                bsr     draw_box
                bra.s   .b
.x:             movem.l (sp)+,d0-d7/a0-a1
                rts

;---------------------------------------------------------------------
                section bss
bk_y:           ds.w    1
bk_vx:          ds.w    1                       ; view used to draw it (column)
tmpbuf:         ds.b    LINEB*SCR_H             ; (components drawn here first)
                section data
comp_h:         dc.b    4,4,1,1,1,1,4,4,5,2,4,1,2,10,1,5    ; rows of each type
comp_w:         dc.b    4,2,2,1,2,4,4,4,2,2,1,1,2,6,3,2     ; columns of each type
                even
comp_mdl:       dc.l    mdl_cpu,mdl_ram,mdl_res,mdl_cap,mdl_xtal,mdl_hdr
                dc.l    mdl_qfp,mdl_fan,mdl_dip,mdl_soic,mdl_rarr,mdl_rblu
                dc.l    mdl_ecap,mdl_ramb,mdl_ferr,mdl_dsub

; colours : front (top), side, top edge, bottom edge
col_chip:       dc.w    $2104,$1082,$18C3,$0841     ; black epoxy
col_mark:       dc.w    $9CD3,$632C,$7BEF,$4208     ; marking
col_tin:        dc.w    $C618,$8410,$A514,$630C     ; tin pins
col_beige:      dc.w    $E6B4,$A4AE,$C5B0,$8410     ; resistor body
col_nband:      dc.w    $8A22,$5100,$6980,$3080
col_kband:      dc.w    $1082,$0841,$1082,$0000
col_rband:        dc.w    $E8A4,$9802,$C043,$6000
col_gband:       dc.w    $FE60,$B400,$D520,$8B00
col_cap:        dc.w    $2A39,$1910,$21B4,$10AA     ; capacitor can
col_capt:       dc.w    $DEFB,$9492,$BDD7,$6B4D     ; its top
col_xtal:       dc.w    $EF7D,$9CD3,$C618,$7BEF
col_qfp:        dc.w    $3186,$18C3,$2124,$1082     ; QFP (COMBEL, VIDEL)
col_alu:        dc.w    $BDF7,$7BEF,$9CF3,$5ACB     ; heatsink
col_fan:        dc.w    $18E3,$0861,$10A2,$0020
col_rarr:       dc.w    $D8A3,$9000,$B841,$6000     ; red resistor array
col_blue:       dc.w    $2B3F,$1197,$1A5B,$08CF     ; blue SIP
col_ecap:       dc.w    $2945,$10A2,$18E3,$0861     ; electrolytic can
col_ramb:       dc.w    $5D0A,$3326,$4428,$2204     ; RAM board (green)

mdl_cpu:                                        ; processor 4 x 4 tiles
                dc.w    10,4,70,10,394
                dc.l    col_tin
                dc.w    10,70,70,76,394
                dc.l    col_tin
                dc.w    4,10,10,70,394
                dc.l    col_tin
                dc.w    70,10,76,70,394
                dc.l    col_tin
                dc.w    10,10,70,70,380
                dc.l    col_chip
                dc.w    -99
mdl_ram:                                        ; memory 2 x 4 tiles
                dc.w    3,8,8,72,395
                dc.l    col_tin
                dc.w    32,8,37,72,395
                dc.l    col_tin
                dc.w    8,4,32,76,384
                dc.l    col_chip
                dc.w    -99
mdl_res:                                        ; resistor 2 x 1 tiles
                dc.w    2,8,12,12,396
                dc.l    col_tin
                dc.w    28,8,38,12,396
                dc.l    col_tin
                dc.w    10,5,30,15,390
                dc.l    col_beige
                dc.w    13,5,15,15,389
                dc.l    col_nband
                dc.w    17,5,19,15,389
                dc.l    col_kband
                dc.w    21,5,23,15,389
                dc.l    col_rband
                dc.w    26,5,28,15,389
                dc.l    col_gband
                dc.w    -99
mdl_cap:                                        ; capacitor 1 x 1 (tall)
                dc.w    3,3,17,17,352
                dc.l    col_cap
                dc.w    5,5,15,15,351
                dc.l    col_capt
                dc.w    -99
mdl_xtal:                                       ; quartz 2 x 1
                dc.w    4,4,36,16,392
                dc.l    col_tin
                dc.w    6,6,34,14,386
                dc.l    col_xtal
                dc.w    -99
mdl_hdr:                                        ; header 4 x 1 (4 pins)
                dc.w    2,4,78,16,390
                dc.l    col_chip
                dc.w    10,8,14,12,372
                dc.l    col_gband
                dc.w    30,8,34,12,372
                dc.l    col_gband
                dc.w    46,8,50,12,372
                dc.l    col_gband
                dc.w    66,8,70,12,372
                dc.l    col_gband
                dc.w    -99
mdl_qfp:                                        ; QFP 4 x 4 (COMBEL, VIDEL)
                dc.w    2,2,78,78,397
                dc.l    col_tin
                dc.w    8,8,72,72,388
                dc.l    col_qfp
                dc.w    -99
mdl_fan:                                        ; 68030 : QFP chip 4 x 4 (no fan)
                dc.w    2,2,78,78,397
                dc.l    col_tin
                dc.w    8,8,72,72,388
                dc.l    col_chip
                dc.w    -99
mdl_dip:                                        ; DIP chip 2 x 5
                dc.w    3,4,8,96,396
                dc.l    col_tin
                dc.w    32,4,37,96,396
                dc.l    col_tin
                dc.w    8,2,32,98,386
                dc.l    col_chip
                dc.w    -99
mdl_soic:                                       ; SOIC 2 x 2
                dc.w    3,8,37,32,397
                dc.l    col_tin
                dc.w    8,6,32,34,390
                dc.l    col_chip
                dc.w    -99
mdl_rarr:                                       ; red resistor array 1 x 4
                dc.w    6,2,14,78,384
                dc.l    col_rarr
                dc.w    -99
mdl_rblu:                                       ; blue SIP 1 x 1
                dc.w    5,3,15,17,388
                dc.l    col_blue
                dc.w    -99
mdl_ecap:                                       ; electrolytic capacitor 2 x 2
                dc.w    3,3,37,37,330
                dc.l    col_ecap
                dc.w    7,7,33,33,329
                dc.l    col_capt
                dc.w    -99
mdl_ramb:                                       ; RAM board 6 x 10 (raised)
                dc.w    0,0,120,200,372
                dc.l    col_ramb
                dc.w    40,14,84,40,366
                dc.l    col_chip
                dc.w    40,58,84,84,366
                dc.l    col_chip
                dc.w    40,102,84,128,366
                dc.l    col_chip
                dc.w    40,146,84,172,366
                dc.l    col_chip
                dc.w    -99
mdl_ferr:                                       ; ferrite 3 x 1 (black cylinder)
                dc.w    4,4,56,16,384
                dc.l    col_kband
                dc.w    -99
mdl_dsub:                                       ; D-sub connector 2 x 5
                dc.w    2,2,38,98,376
                dc.l    col_tin
                dc.w    8,8,32,92,375
                dc.l    col_chip
                dc.w    -99
                even
                section text

                section bss
bk_budget:      ds.w    1                       ; bakes left in this frame
                section text
