;=====================================================================
; SOL.S - SCROLLING GROUND WITHOUT REDRAWING IT (hardware scroll)
;   (included by SHOTEMUP.S ; settings in PARAMS.S)
;
; 3 tall buffers of RING + 240 lines : G (clean ground, never shown) and
; the 2 screens D0 / D1. World line w is kept at line (w mod RING) and, if
; that is < 240, also at + RING : the screen shown starts at line
; (gpos mod RING) ; G also holds the GM lines above the screen, where the
; components are baked (COMPOS.S) before they come into view,
; so scrolling = moving the video address ; each frame only the
; SCROLL_SPD new lines are drawn (in G, then copied to the screen).
; Objects (boxes, bullets, HUD, bar) note their rectangle (obj_begin /
; obj_end, via bb_x0..bb_y1) ; next time that screen is used, the ground
; is copied back from G only under these rectangles.
;=====================================================================

GM              equ     256                     ; lines prepared above the screen
RING            equ     SCR_H+GM                ; world line w -> line (w mod RING)
TALL_H          equ     RING+SCR_H              ;  (+ RING when < 240 : copy)
TALLSZ          equ     TALL_H*LINEB
MAXDR           equ     200                     ; rectangles per screen
                rsreset
BF_ADR          rs.l    1                       ; top of the tall buffer
BF_LAST         rs.l    1                       ; gpos when last drawn
BF_N            rs.w    1                       ; rectangles noted
BF_FULL         rs.w    1                       ; list full : whole copy
BF_BL           rs.w    1                       ; top band : its line (-1 none)
BF_BX           rs.w    1                       ;  and column (camx)
BF_R            rs.b    MAXDR*8                 ; line.w lines.w off.w longs.w
BF_SZ           rs.b    0


;---------------------------------------------------------------------
; gnd_init : buffers + whole ground for gpos (start, new game, loop)
gnd_init:
                movem.l d0-d2/a0-a2,-(sp)
                move.l  #tallmem+255,d0
                and.l   #$ffffff00,d0
                move.l  d0,gbuf
                add.l   #TALLSZ,d0
                move.l  d0,bufd0+BF_ADR
                add.l   #TALLSZ,d0
                move.l  d0,bufd1+BF_ADR
                bsr     gnd_full
                movem.l (sp)+,d0-d2/a0-a2
                rts

; gnd_full : G drawn for gpos (the screen + GM lines above it),
;   components baked in it, copied to both screens
gnd_full:
                movem.l d0-d2/a0-a2,-(sp)
                move.l  gpos,d2
                sub.l   #GM,d2
                move.w  #RING-1,d1
.l:             move.l  d2,d0
                bsr     gnd_gline
                addq.l  #1,d2
                dbra    d1,.l
                move.l  gpos,g_last
                bsr     bake_reset              ; components (COMPOS.S)
                bsr     bake_all
                lea     bufd0,a2
                bsr     gnd_copyall
                lea     bufd1,a2
                bsr     gnd_copyall
                movem.l (sp)+,d0-d2/a0-a2
                rts

; gnd_copyall : a2 = screen : whole G copied, list emptied
gnd_copyall:
                movem.l d0-d5/d7/a0-a1/a3-a4,-(sp)
                move.l  gbuf,a1
                move.l  BF_ADR(a2),a0
                move.w  #TALL_H*LINEB/160-1,d7
.l:             rept    5
                movem.l (a1)+,d0-d5/a3-a4
                movem.l d0-d5/a3-a4,(a0)
                lea     32(a0),a0
                endr
                dbra    d7,.l
                move.l  gpos,BF_LAST(a2)
                clr.w   BF_N(a2)
                clr.w   BF_FULL(a2)
                movem.l (sp)+,d0-d5/d7/a0-a1/a3-a4
                rts

; gnd_phys : d0.l = world line (>= -GM) -> d0 = offset of its line in a
;   tall buffer (bytes), a0 = this line in G ; d1 = offset of its copy
;   (line + RING) or -1 if none
gnd_phys:
                add.l   #RING*64,d0             ; (positive for divu)
                divu    #RING,d0
                clr.w   d0
                swap    d0                      ; w mod RING
                moveq   #-1,d1
                cmp.w   #SCR_H,d0
                bhs.s   .n
                move.l  d0,d1
                add.l   #RING,d1
                mulu    #LINEB,d1
.n:             mulu    #LINEB,d0
                move.l  gbuf,a0
                adda.l  d0,a0
                rts

; gnd_gline : world line d0.l drawn in G (and its copy)
gnd_gline:
                movem.l d0-d2/a0-a1,-(sp)
                move.l  d0,d2
                bsr     gnd_phys
                move.l  d2,d0
                bsr     gnd_line
                tst.l   d1
                bmi.s   .x
                move.l  a0,a1
                move.l  gbuf,a0
                adda.l  d1,a0
                bsr     copy_line
.x:             movem.l (sp)+,d0-d2/a0-a1
                rts

; gnd_line : world line d0.l -> line at a0 : the map_cols tiles of its map
;   row (CARTE.S), line (w mod TILE_PX) of each tile picture
gnd_line:
                movem.l d0-d2/a0-a2,-(sp)
                cmp.l   lvl_h,d0                ; (outside the level : board)
                blo.s   .in
                moveq   #0,d0
.in:            divu    #TILE_PX,d0             ; d0.w = row, high = line in the tile
                move.l  d0,d1
                swap    d1
                mulu    #TILE_PX*2,d1           ; offset of the line in a tile
                lea     mapbuf,a1
                mulu    #MAP_MAXCOLS,d0
                adda.l  d0,a1
                move.w  map_cols,d2
                subq.w  #1,d2
.t:             moveq   #0,d0
                move.b  (a1)+,d0
                mulu    #TILE_PX*TILE_PX*2,d0
                lea     pcbtiles,a2
                adda.l  d0,a2
                adda.l  d1,a2
                rept    TILE_PX/2
                move.l  (a2)+,(a0)+
                endr
                dbra    d2,.t
                movem.l (sp)+,d0-d2/a0-a2
                rts

;---------------------------------------------------------------------
; ground_frame : start of a frame in the screen cur_bf ->
;   new lines in G, the screen catches up, objects erased ;
;   a6 = top of the picture, scr_show = same (for Setscreen)
ground_frame:
                movem.l d0-d7/a0-a5,-(sp)
                move.l  gpos,d6
                move.l  g_last,d7
                cmp.l   d7,d6                   ; jump (new game, wrap) :
                bgt.s   .full                   ;  everything again
                move.l  d7,d0
                sub.l   d6,d0
                cmp.l   #SCR_H,d0
                bls.s   .g
.full:          bsr     gnd_full
                jmp   .show
.g:             move.l  d6,d0                   ; --- G : new lines (GM above)
                sub.l   #GM,d0
                sub.l   #GM,d7
.gl:            cmp.l   d7,d0
                bge.s   .gd
                bsr     gnd_gline
                addq.l  #1,d0
                bra.s   .gl
.gd:            move.l  d6,g_last
                bsr     bake_scan               ; components ready (COMPOS.S)
                move.l  cur_bf,a2               ; --- the screen catches up
                move.l  BF_LAST(a2),d7
                move.l  d7,d0
                sub.l   d6,d0
                bmi.s   .all
                cmp.l   #SCR_H,d0
                bhi.s   .all
                tst.w   BF_FULL(a2)
                bne.s   .all
                move.l  d6,d5
.cl:            cmp.l   d7,d5
                bge.s   .cd
                move.l  d5,d0                   ; the line and its copy
                bsr     gnd_phys
                move.l  a0,a1
                move.l  BF_ADR(a2),a0
                adda.l  d0,a0
                bsr     copy_line
                tst.l   d1
                bmi.s   .c2
                move.l  gbuf,a1
                adda.l  d1,a1
                move.l  BF_ADR(a2),a0
                adda.l  d1,a0
                bsr     copy_line
.c2:            addq.l  #1,d5
                bra.s   .cl
.cd:            move.l  d6,BF_LAST(a2)
                bsr     band_fix                ; top band : only what it left
                bsr     gnd_restore             ; under last time's objects
                bra.s   .show
.all:           bsr     gnd_copyall
.show:          move.l  gpos,d0                 ; picture = line (gpos mod RING),
                divu    #RING,d0                ;  column camx (horizontal scroll)
                clr.w   d0
                swap    d0
                move.w  d0,cur_b0
                mulu    #LINEB,d0
                move.l  cur_bf,a2
                move.l  BF_ADR(a2),a6
                adda.l  d0,a6
                move.w  camx,d0
                move.w  d0,cur_camx
                add.w   d0,d0
                adda.w  d0,a6
                move.l  a6,scr_show
                movem.l (sp)+,d0-d7/a0-a5
                move.l  scr_show,a6
                rts

; band_fix : a2 = screen : the top band drawn there last time is drawn again
;   at the new place this time (black) : only the lines it leaves are put
;   back (scroll : 1-2 lines) ; all of it if the camera moved sideways
band_fix:
                movem.l d0-d4/a0,-(sp)
                move.w  BF_BL(a2),d3            ; old line
                bmi.s   .x
                move.l  gpos,d0                 ; new line : gpos mod RING
                divu    #RING,d0
                swap    d0                      ; d0.w = new line
                move.w  #TOP_H,d2               ; lines to put back
                move.w  d3,d1                   ;  from the old line
                move.w  BF_BX(a2),d4
                cmp.w   camx,d4
                bne.s   .all
                move.w  d3,d2
                sub.w   d0,d2                   ; old - new (up : >= 0)
                bmi.s   .all0
                cmp.w   #TOP_H,d2
                bhi.s   .all0
                move.w  d0,d1                   ; from new + TOP_H, old - new lines
                add.w   #TOP_H,d1
                tst.w   d2
                beq.s   .n
                bra.s   .add
.all0:          move.w  #TOP_H,d2
.all:           move.w  d3,d1
.add:           move.w  BF_N(a2),d0
                cmp.w   #MAXDR,d0
                blo.s   .ok
                move.w  #1,BF_FULL(a2)
                bra.s   .n
.ok:            addq.w  #1,BF_N(a2)
                lsl.w   #3,d0
                lea     BF_R(a2,d0.w),a0
                move.w  d1,(a0)+                ; line
                move.w  d2,(a0)+                ; lines
                add.w   d4,d4
                move.w  d4,(a0)+                ; offset (bytes) : old camx
                move.w  #SCR_W/2,(a0)+          ; longs
.n:             move.w  #-1,BF_BL(a2)
.x:             movem.l (sp)+,d0-d4/a0
                rts

; copy_line : one line of a buffer (LINEB bytes) a1 -> a0 (a0, a1 kept)
copy_line:
                movem.l d0-d5/d7/a0-a1/a3-a4,-(sp)
                moveq   #LINEB/160-1,d7
.l:             rept    5
                movem.l (a1)+,d0-d5/a3-a4
                movem.l d0-d5/a3-a4,(a0)
                lea     32(a0),a0
                endr
                dbra    d7,.l
                movem.l (sp)+,d0-d5/d7/a0-a1/a3-a4
                rts

; gnd_restore : a2 = screen : ground copied back from G under its rectangles
;   (28 bytes at a time by movem, then the rest by longs)
gnd_restore:
                movem.l d0-d7/a0-a6,-(sp)
                move.w  BF_N(a2),d7
                beq     .x
                subq.w  #1,d7
                lea     BF_R(a2),a4
.r:             movem.w (a4)+,d0-d3             ; line, lines, offset, longs
                mulu    #LINEB,d0
                add.l   d2,d0
                move.l  gbuf,a1
                adda.l  d0,a1
                move.l  BF_ADR(a2),a0
                adda.l  d0,a0
                move.w  d1,d6
                subq.w  #1,d6                   ; lines - 1
                moveq   #0,d0
                move.w  d3,d0
                divu    #7,d0                   ; d0 = blocks of 7 longs
                move.l  d0,d1
                swap    d1                      ; d1 = longs left
                move.l  a4,-(sp)
.y:             movem.l a0-a1,-(sp)
                move.w  d0,d2
                beq.s   .b2
                subq.w  #1,d2
.b:             movem.l (a1)+,d3-d5/a3-a6
                movem.l d3-d5/a3-a6,(a0)
                lea     28(a0),a0
                dbra    d2,.b
.b2:            move.w  d1,d2
                beq.s   .ny
                subq.w  #1,d2
.c:             move.l  (a1)+,(a0)+
                dbra    d2,.c
.ny:            movem.l (sp)+,a0-a1
                lea     LINEB(a0),a0
                lea     LINEB(a1),a1
                dbra    d6,.y
                move.l  (sp)+,a4
                dbra    d7,.r
                clr.w   BF_N(a2)
.x:             movem.l (sp)+,d0-d7/a0-a6
                rts

;---------------------------------------------------------------------
; obj_begin / obj_end : rectangle of what is drawn between them
;   (bb_x0..bb_y1, updated by fillrect and d3dbox) noted in cur_bf
obj_begin:
                move.w  #$7fff,bb_x0
                move.w  #$7fff,bb_y0
                move.w  #-1,bb_x1
                move.w  #-1,bb_y1
                rts
obj_end:
                movem.l d0-d3/a0,-(sp)
                movem.w bb_x0,d0-d3             ; x0 y0 x1 y1
                cmp.w   d2,d0
                bgt.s   .x
                cmp.w   d3,d1
                bgt.s   .x
                bsr.s   add_rect
.x:             movem.l (sp)+,d0-d3/a0
                rts

; add_rect : d0,d1 - d2,d3 (screen, clipped) noted in cur_bf (+ camx)
add_rect:
                movem.l d0-d4/a0,-(sp)
                move.l  cur_bf,a0
                move.w  BF_N(a0),d4
                cmp.w   #MAXDR,d4
                blo.s   .ok
                move.w  #1,BF_FULL(a0)          ; too many : whole copy next time
                bra.s   .x
.ok:            addq.w  #1,BF_N(a0)
                lsl.w   #3,d4
                lea     BF_R(a0,d4.w),a0
                sub.w   d1,d3
                addq.w  #1,d3                   ; lines
                add.w   cur_b0,d1               ; line in the tall buffer
                and.w   #$fffe,d0               ; long words : x even ..
                or.w    #1,d2                   ;  .. x odd
                sub.w   d0,d2
                addq.w  #1,d2
                lsr.w   #1,d2                   ; longs
                add.w   cur_camx,d0             ; (column in the buffer)
                add.w   d0,d0                   ; offset (bytes)
                move.w  d1,(a0)+
                move.w  d3,(a0)+
                move.w  d0,(a0)+
                move.w  d2,(a0)+
.x:             movem.l (sp)+,d0-d4/a0
                rts

; bb_add : union of the rectangle d0,d1 - d2,d3 into bb (fillrect)
bb_add:
                cmp.w   bb_x0,d0
                bge.s   .1
                move.w  d0,bb_x0
.1:             cmp.w   bb_y0,d1
                bge.s   .2
                move.w  d1,bb_y0
.2:             cmp.w   bb_x1,d2
                ble.s   .3
                move.w  d2,bb_x1
.3:             cmp.w   bb_y1,d3
                ble.s   .4
                move.w  d3,bb_y1
.4:             rts
