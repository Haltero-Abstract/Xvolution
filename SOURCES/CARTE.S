;=====================================================================
; CARTE.S - LEVEL MAP (printed circuit board) : LEVEL1.MAP + PCB tiles
;   (included by SHOTEMUP.S ; settings in PARAMS.S)
;
; LEVEL1.MAP (text, written by OUTILS\EDITEUR.HTML or OUTILS\MKLEVEL.PY) :
;   ; comment            SEU 1            SIZE 16 <rows>
;   <rows lines of 16 tile characters>   row 0 = END of the level (top),
;                                        last row = START (bottom)
;   W <row> [waves]      attack zone (ZONES.S)
;   C <type> <col> <row> [name]   component (letters of comp_types), top-left
;                          tile, optional name printed on it (11 chars, _ = space)
;   END
; Tiles : PCBTILES.BIN (OUTILS\MKTILES.PY), 20 x 20 pixels each, in the
;   order of the characters of tile_chars.
; No map file : a bare board of MAP_DEFROWS rows (map_err = 1).
;=====================================================================

;---------------------------------------------------------------------
; map_load : LEVELn.MAP (n = cur_level) -> map_cols, map_rows, mapbuf (tile
;   numbers, MAP_MAXCOLS per row), comps ; THEME -> tiles PCBTxxx.BIN loaded
;   (missing : the tiles assembled in the program, PCBTILES.BIN)
map_load:
                movem.l d0-d7/a0-a5,-(sp)
                move.w  cur_level,d0            ; LEVELn.MAP
                add.b   #'0',d0
                move.b  d0,map_name+5
                lea     pcbtiles_def,a0         ; default tiles
                lea     pcbtiles,a1
                move.w  #NB_TILES*TILE_PX*TILE_PX/2-1,d0
.dt:            move.l  (a0)+,(a1)+
                dbra    d0,.dt
                lea     chr2tile,a0             ; character -> tile number
                moveq   #0,d0
                move.w  #255,d1
.z:             move.b  d0,(a0)+                ; (unknown character : board)
                dbra    d1,.z
                lea     chr2tile,a0
                lea     tile_chars,a1
                moveq   #0,d1
.c:             moveq   #0,d0
                move.b  (a1)+,d0
                beq.s   .c1
                move.b  d1,(a0,d0.w)
                addq.w  #1,d1
                bra.s   .c
.c1:            clr.w   ncomps
                clr.w   naz                     ; (attack zones : ZONES.S)
                move.w  #1,map_err
                move.w  #MAP_DEFROWS,map_rows   ; (bare board if no file)
                move.w  #16,map_cols
                lea     mapbuf,a0
                move.w  #MAP_DEFROWS*MAP_MAXCOLS/4-1,d0
.cl:            clr.l   (a0)+
                dbra    d0,.cl
                clr.w   -(sp)                   ; Fopen (read)
                pea     map_name
                move.w  #$3d,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi     .done
                move.w  d0,d7
                pea     filebuf                 ; Fread
                move.l  #FILE_MAX-1,-(sp)
                move.w  d7,-(sp)
                move.w  #$3f,-(sp)
                trap    #1
                lea     12(sp),sp
                move.l  d0,d6
                move.w  d7,-(sp)                ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
                tst.l   d6
                ble     .done
                lea     filebuf,a0
                clr.b   (a0,d6.l)               ; end of the text
                ; --- header : SEU, THEME, SIZE
.hd:            bsr     map_line                ; a0 = line (comments skipped)
                beq     .done
                cmp.b   #'T',(a0)               ; THEME a8 / st / ste / falcon
                bne.s   .hs
                bsr     map_theme
                bsr     map_skip
                bra.s   .hd
.hs:            cmp.b   #'S',(a0)
                bne.s   .hn
                cmp.b   #'I',1(a0)
                bne.s   .hn
                addq.l  #4,a0                   ; SIZE cols rows
                bsr     map_num
                cmp.w   #MAP_MAXCOLS,d0
                bls.s   .c0
                move.w  #MAP_MAXCOLS,d0
.c0:            cmp.w   #16,d0
                bhs.s   .c2
                moveq   #16,d0
.c2:            move.w  d0,map_cols
                bsr     map_num
                cmp.w   #MAP_MAXROWS,d0
                bls.s   .r0
                move.w  #MAP_MAXROWS,d0
.r0:            tst.w   d0
                beq     .done
                move.w  d0,map_rows
                bsr     map_skip
                bra.s   .rows
.hn:            bsr     map_skip                ; (SEU 1 and others)
                bra.s   .hd
                ; --- rows of tiles
.rows:          lea     mapbuf,a2
                lea     chr2tile,a3
                move.w  map_rows,d5
                subq.w  #1,d5
.rw:            bsr     map_line
                beq.s   .rend
                move.l  a2,-(sp)
                move.w  map_cols,d4
                subq.w  #1,d4
.rc:            moveq   #0,d0
                move.b  (a0),d0
                cmp.b   #' ',d0                 ; (short line : board)
                bhs.s   .rc1
                moveq   #'.',d0
                subq.l  #1,a0
.rc1:           addq.l  #1,a0
                move.b  (a3,d0.w),(a2)+
                dbra    d4,.rc
                move.l  (sp)+,a2
                lea     MAP_MAXCOLS(a2),a2
                bsr     map_skip
                dbra    d5,.rw
.rend:          clr.w   map_err
                ; --- components
                lea     comps,a2
.cp:            bsr     map_line
                beq     .done
                cmp.b   #'E',(a0)               ; END
                beq     .done
                cmp.b   #'W',(a0)               ; W row [waves] : attack zone
                bne.s   .cw
                bsr     az_parse
                bra     .cn
.cw:            cmp.b   #'C',(a0)
                bne.s   .cn
                cmp.w   #MAXCOMP,ncomps
                bhs.s   .cn
                addq.l  #1,a0
.sp:            cmp.b   #' ',(a0)+
                beq.s   .sp
                moveq   #0,d0
                move.b  -1(a0),d0               ; type letter
                lea     comp_types,a1
                moveq   #0,d1
.ty:            tst.b   (a1)
                beq.s   .cn                     ; (unknown type : ignored)
                cmp.b   (a1)+,d0
                beq.s   .ty1
                addq.w  #1,d1
                bra.s   .ty
.ty1:           move.w  d1,(a2)+                ; type
                bsr     map_num
                move.w  d0,(a2)+                ; column
                bsr     map_num
                move.w  d0,(a2)+                ; row
                clr.w   (a2)+
                move.w  ncomps,d1               ; name (optional, after the row)
                mulu    #LBL_LEN,d1
                lea     comp_lbl,a1
                adda.l  d1,a1
                moveq   #LBL_LEN-2,d1
.ls:            cmp.b   #' ',(a0)
                bne.s   .lc
                addq.l  #1,a0
                bra.s   .ls
.lc:            move.b  (a0),d0
                cmp.b   #' ',d0
                bls.s   .le
                move.b  d0,(a1)+
                addq.l  #1,a0
                dbra    d1,.lc
.le:            clr.b   (a1)
                addq.w  #1,ncomps
.cn:            bsr     map_skip
                jmp   .cp
.done:          move.w  map_rows,d0             ; height of the level (pixels)
                mulu    #TILE_PX,d0
                move.l  d0,lvl_h
                move.w  map_cols,d0             ; width - screen : camera range
                mulu    #TILE_PX,d0
                sub.w   #SCR_W,d0
                bpl.s   .w
                moveq   #0,d0
.w:             move.w  d0,cam_max
                movem.l (sp)+,d0-d7/a0-a5
                rts

; map_theme : a0 = "THEME name" line -> tiles PCBTxxx.BIN loaded in pcbtiles
map_theme:
                movem.l d0-d2/a0-a2,-(sp)
                addq.l  #5,a0
.sp:            cmp.b   #' ',(a0)+
                beq.s   .sp
                subq.l  #1,a0
                lea     theme_tab,a1            ; name (3 letters compared) -> file
.t:             tst.b   (a1)
                beq.s   .x
                move.b  (a1),d0
                cmp.b   (a0),d0
                bne.s   .n
                move.b  1(a1),d0
                cmp.b   1(a0),d0
                bne.s   .n
                move.b  2(a0),d1                ; (end of a short name : space)
                cmp.b   #' ',d1
                bhi.s   .t3
                moveq   #' ',d1
.t3:            cmp.b   2(a1),d1
                bne.s   .n
                lea     4(a1),a2                ; file name
                bsr     tiles_load
                bra.s   .x
.n:             lea     16(a1),a1
                bra.s   .t
.x:             movem.l (sp)+,d0-d2/a0-a2
                rts

; tiles_load : a2 = file name -> pcbtiles (unchanged if missing)
tiles_load:
                movem.l d0-d2/a0-a2,-(sp)
                clr.w   -(sp)                   ; Fopen
                move.l  a2,-(sp)
                move.w  #$3d,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi.s   .x
                move.w  d0,d2
                pea     pcbtiles                ; Fread
                move.l  #NB_TILES*TILE_PX*TILE_PX*2,-(sp)
                move.w  d2,-(sp)
                move.w  #$3f,-(sp)
                trap    #1
                lea     12(sp),sp
                move.w  d2,-(sp)                ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
.x:             movem.l (sp)+,d0-d2/a0-a2
                rts

; map_line : a0 -> next useful line (blank lines and ; comments skipped)
;   Z = 1 : end of the text
map_line:
.l:             move.b  (a0),d0
                beq.s   .end
                cmp.b   #13,d0
                beq.s   .nl
                cmp.b   #10,d0
                beq.s   .nl
                cmp.b   #';',d0
                bne.s   .ok
                bsr.s   map_skip
                bra.s   .l
.nl:            addq.l  #1,a0
                bra.s   .l
.ok:            moveq   #1,d0                   ; Z = 0
                rts
.end:           moveq   #0,d0                   ; Z = 1
                rts

; map_skip : a0 -> start of the next line
map_skip:
.l:             move.b  (a0),d0
                beq.s   .x
                addq.l  #1,a0
                cmp.b   #10,d0
                bne.s   .l
.x:             rts

; map_num : decimal number after spaces -> d0.w (a0 after it)
map_num:
                moveq   #0,d0
.sp:            cmp.b   #' ',(a0)
                bne.s   .d
                addq.l  #1,a0
                bra.s   .sp
.d:             moveq   #0,d1
                move.b  (a0),d1
                sub.b   #'0',d1
                cmp.b   #9,d1
                bhi.s   .x
                mulu    #10,d0
                add.w   d1,d0
                addq.l  #1,a0
                bra.s   .d
.x:             rts

;---------------------------------------------------------------------
                section data
map_name:       dc.b    'LEVEL1.MAP',0          ; (the digit = cur_level)
                even
theme_tab:      dc.b    'a8 ',0,'PCBTA8.BIN',0,0          ; 16 bytes each : 3 letters,
                dc.b    'st ',0,'PCBTST.BIN',0,0          ;  0, file name
                dc.b    'ste',0,'PCBTSTE.BIN',0
                dc.b    'fal',0,'PCBTF30.BIN',0
                dc.b    0
tile_chars:     dc.b    '.-|+r7LJTWE3oOaip=#sthvk',0 ; = OUTILS\MKTILES.PY
comp_types:     dc.b    'PMRKXHQFDOAUZGNV',0        ; = COMPOS.S comp_mdl
                even
pcbtiles_def:   incbin  'PCBTILES.BIN'              ; 20 x 20 x 2 bytes each (default)
                even
                section bss
map_err:        ds.w    1                       ; 1 : LEVELn.MAP not read
map_cols:       ds.w    1
cam_max:        ds.w    1                       ; camera : 0 .. width - 320
pcbtiles:       ds.b    NB_TILES*TILE_PX*TILE_PX*2  ; tiles of the level (theme)
map_rows:       ds.w    1
lvl_h:          ds.l    1                       ; map_rows * TILE_PX
ncomps:         ds.w    1
comps:          ds.w    MAXCOMP*4               ; type, column, row, -
comp_lbl:       ds.b    MAXCOMP*LBL_LEN         ; names ("68030", "TOS"...), 0 = none
chr2tile:       ds.b    256
mapbuf:         ds.b    MAP_MAXROWS*MAP_MAXCOLS
filebuf:        ds.b    FILE_MAX
                even
                section text
