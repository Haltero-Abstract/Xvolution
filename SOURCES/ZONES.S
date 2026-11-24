;=====================================================================
; ZONES.S - ATTACK ZONES (included by XVOLUTION.S ; settings in PARAMS.S)
;   LEVELn.MAP : "W row [waves]" (OUTILS\MKEXT.PY puts 3 per level).
;   When the row reaches the line AZ_Y of the screen the ground stops (as
;   for a boss) and waves of enemies come in formation (az_pat : lines,
;   V, columns aimed at the ship, diagonals) ; when all the waves are
;   gone the ground goes on : "ZONE CLEARED" + AZ_PTS points.
;=====================================================================

; az_parse : a0 = "W row [waves]" line (map_load) -> az_row / az_wv0
az_parse:
                movem.l d0-d1/a1,-(sp)
                cmp.w   #MAXAZ,naz
                bhs.s   .x
                addq.l  #1,a0
                bsr     map_num                 ; row
                move.w  d0,-(sp)                ; (map_num : d0, d1)
                bsr     map_num                 ; waves (none : AZ_WAVES)
                move.w  (sp)+,d1
                tst.w   d0
                bne.s   .w
                moveq   #AZ_WAVES,d0
.w:             lea     az_row,a1
                adda.w  naz,a1
                adda.w  naz,a1
                move.w  d1,(a1)
                move.w  d0,2*MAXAZ(a1)          ; (az_wv0)
                addq.w  #1,naz
.x:             movem.l (sp)+,d0-d1/a1
                rts

; az_init : no zone done yet (level_reset)
az_init:
                movem.l d0/a0,-(sp)
                clr.w   az_on
                clr.w   az_msg
                clr.w   az_pat
                lea     az_done,a0
                moveq   #MAXAZ-1,d0
.c:             clr.b   (a0)+
                dbra    d0,.c
                movem.l (sp)+,d0/a0
                rts

; az_check : (game_update, after boss_check) Z clear : the ground waits
az_check:
                movem.l d0-d4/a0-a1,-(sp)
                tst.w   az_on
                bne     .stop
                move.w  naz,d4
                beq     .go
                subq.w  #1,d4
                lea     az_row,a0
                lea     az_done,a1
.z:             tst.b   (a1)
                bne.s   .n
                moveq   #0,d1                   ; line of the row on the screen
                move.w  (a0),d1
                mulu    #TILE_PX,d1
                sub.l   gpos,d1
                cmp.l   #AZ_Y,d1
                blt.s   .n
                cmp.l   #SCR_H,d1               ; (already gone : forget it)
                blt.s   .start
                st      (a1)
                bra.s   .n
.start:         move.l  a1,az_flag              ; --- the zone begins
                move.w  2*MAXAZ(a0),az_wv        ; (az_wv0)
                move.w  #1,az_on
                move.w  #AZ_FIRST,az_t
                clr.l   az_ptr
                move.w  #AZ_MSG_T,az_msg
                move.l  #t_azin,az_txt
                SFX     SFX_ALARM
                bra.s   .stop
.n:             addq.l  #2,a0
                addq.l  #1,a1
                dbra    d4,.z
.go:            movem.l (sp)+,d0-d4/a0-a1
                moveq   #0,d0                   ; Z set : scroll
                rts
.stop:          movem.l (sp)+,d0-d4/a0-a1
                moveq   #1,d0
                rts

; az_update : (game_update, one step) the waves of the zone
az_update:
                tst.w   az_msg
                beq.s   .m
                subq.w  #1,az_msg
.m:             tst.w   az_on
                beq     .x
                movem.l d0-d3/a0-a1,-(sp)
                subq.w  #1,az_t
                bgt     .out
                move.l  az_ptr,d0               ; inside a wave : next enemy
                bne.s   .e
                tst.w   az_wv                   ; a new wave ?
                beq.s   .end
                subq.w  #1,az_wv
                move.w  az_pat,d0               ; its pattern
                addq.w  #1,az_pat
                cmp.w   #AZ_NPAT,az_pat
                blo.s   .p
                clr.w   az_pat
.p:             add.w   d0,d0
                add.w   d0,d0
                lea     az_pats,a0
                move.l  (a0,d0.w),d0
.e:             move.l  d0,a0                   ; entry : delay, x, type
.en:            move.w  2(a0),d1                ; x (999 : the ship's x)
                cmp.w   #999,d1
                bne.s   .e1
                move.w  px,d1
.e1:            move.w  4(a0),d2
                bsr     az_spawn
                addq.l  #6,a0
                move.w  (a0),d0                 ; next one : now, later, or end
                bmi.s   .we
                beq.s   .en
                move.w  d0,az_t
                move.l  a0,az_ptr
                bra.s   .out
.we:            clr.l   az_ptr                  ; end of the wave
                move.w  #AZ_GAP,az_t
                bra.s   .out
.end:           lea     enemies,a0              ; all waves out : wait until
                moveq   #MAXE-1,d0              ;  no enemy is left
.l:             tst.w   (a0)
                bne.s   .wt
                lea     16(a0),a0
                dbra    d0,.l
                clr.w   az_on                   ; --- zone cleared
                move.l  az_flag,a0
                st      (a0)
                add.l   #AZ_PTS,score
                move.w  #AZ_MSG_T,az_msg
                move.l  #t_azok,az_txt
                bra.s   .out
.wt:            move.w  #1,az_t
.out:           movem.l (sp)+,d0-d3/a0-a1
.x:             rts

; az_spawn : enemy of type d2 (0 LED/capacitor, 1 transistor) at x = d1
az_spawn:
                movem.l d0-d1/a0,-(sp)
                lea     enemies,a0
                moveq   #MAXE-1,d0
.l:             tst.w   (a0)
                beq.s   .f
                lea     16(a0),a0
                dbra    d0,.l
                bra.s   .x                      ; (full : this one is lost)
.f:             cmp.w   #-120,d1
                bge.s   .c0
                move.w  #-120,d1
.c0:            cmp.w   #120,d1
                ble.s   .c1
                moveq   #120,d1
.c1:            move.w  d2,6(a0)
                move.w  d1,2(a0)
                move.w  d1,12(a0)
                move.w  #-140,4(a0)
                clr.w   10(a0)
                move.w  #EN_HP0,8(a0)
                tst.w   d2
                beq.s   .h
                move.w  #EN_HP1,8(a0)
.h:             move.w  #1,(a0)
                addq.w  #1,lv_spawn             ; (for the recap %)
.x:             movem.l (sp)+,d0-d1/a0
                rts

; az_render : "INCOMING !" / "ZONE CLEARED" in the middle of the screen
az_render:
                tst.w   az_msg
                beq.s   .x
                movem.l d0-d7/a0-a2,-(sp)
                move.l  az_txt,a0
                moveq   #0,d0                   ; centred, 6 pixels per char
.ln:            tst.b   (a0,d0.w)
                beq.s   .l2
                addq.w  #1,d0
                bra.s   .ln
.l2:            mulu    #3,d0
                neg.w   d0
                add.w   #CX,d0
                move.w  #AZ_TY,d1
                movem.w d0-d1,-(sp)
                move.w  d0,d2                   ; erased next time
                neg.w   d2
                add.w   #2*CX+1,d2
                move.w  d1,d3
                addq.w  #6,d3
                bsr     add_rect
                movem.w (sp)+,d0-d1
                move.l  az_txt,a2
                move.w  #$FFE0,d6
                bsr     btext
                movem.l (sp)+,d0-d7/a0-a2
.x:             rts

;---------------------------------------------------------------------
                section data
; patterns : entries delay (frames before it ; -1 = end), x, type
az_pats:        dc.l    azp_line,azp_v,azp_col,azp_diag,azp_pair,azp_diag2
AZ_NPAT         equ     6
azp_line:       dc.w    0,-96,0, 0,-48,0, 0,0,0, 0,48,0, 0,96,0, -1
azp_v:          dc.w    0,0,1, 8,-40,1, 0,40,1, 8,-80,1, 0,80,1, -1
azp_col:        dc.w    0,999,0, 10,999,0, 10,999,0, 10,999,0, 10,999,0, -1
azp_diag:       dc.w    0,-100,0, 6,-50,0, 6,0,0, 6,50,0, 6,100,0, -1
azp_pair:       dc.w    0,-80,1, 0,80,1, 14,-80,1, 0,80,1, 14,-80,1, 0,80,1, -1
azp_diag2:      dc.w    0,100,0, 6,50,0, 6,0,0, 6,-50,0, 6,-100,0, -1
t_azin:         dc.b    'INCOMING !',0
t_azok:         dc.b    'ZONE CLEARED',0
                even
                section bss
naz:            ds.w    1                       ; zones of the level
az_row:         ds.w    MAXAZ                   ; their rows
az_wv0:         ds.w    MAXAZ                   ;  and waves (just after az_row)
az_done:        ds.b    MAXAZ
                even
az_on:          ds.w    1                       ; 1 : zone in progress (ground waits)
az_flag:        ds.l    1                       ; its az_done byte
az_wv:          ds.w    1                       ; waves left
az_t:           ds.w    1                       ; frames before the next enemy / wave
az_ptr:         ds.l    1                       ; next entry of the wave (0 : between waves)
az_pat:         ds.w    1                       ; next pattern
az_msg:         ds.w    1                       ; message : frames left
az_txt:         ds.l    1
                section text
