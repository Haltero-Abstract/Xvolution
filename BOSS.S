;=====================================================================
; BOSS.S - BOSS STOPS ON THE BIG CHIPS (included by XVOLUTION.S)
;
; A component whose name starts with '*' in LEVELn.MAP ("C F 11 15 *68030")
; is a boss : when its centre comes down to the line BOSS_Y of the screen,
; the ground stops, the chip shoots at the ship (aimed shots, and a fan of
; 5 every 3rd volley) and must take BOSS_HP hits ; then the ground goes on.
; Its bullets : ebuls (world units of the ship plane, x 16).
;=====================================================================
                section text

; boss_init : list of the bosses of the level (level_reset)
boss_init:
                movem.l d0-d2/a0-a2,-(sp)
                clr.w   boss_on
                clr.w   nboss
                lea     ebuls,a0
                move.w  #MAXEB*5-1,d0
.c:             clr.w   (a0)+
                dbra    d0,.c
                move.w  ncomps,d0
                beq.s   .x
                subq.w  #1,d0
                lea     comp_lbl,a0
                lea     boss_list,a1
                moveq   #0,d1                   ; component index
.l:             cmp.b   #'*',(a0)
                bne.s   .n
                cmp.w   #MAXBOSS,nboss
                bhs.s   .n
                move.w  d1,(a1)+
                addq.w  #1,nboss
.n:             lea     LBL_LEN(a0),a0
                addq.w  #1,d1
                dbra    d0,.l
                lea     boss_done,a0            ; none beaten yet
                lea     boss_fixed,a1
                moveq   #MAXBOSS-1,d0
.d:             clr.b   (a0)+
                clr.b   (a1)+
                dbra    d0,.d
.x:             movem.l (sp)+,d0-d2/a0-a2
                rts

; boss_check : called before the scroll ; Z set = the ground may scroll
boss_check:
                movem.l d0-d4/a0-a2,-(sp)
                tst.w   boss_on
                bne     .stop
                move.w  nboss,d4
                beq     .go
                subq.w  #1,d4
                lea     boss_list,a1
                lea     boss_done,a2
.b:             tst.b   (a2)
                bne   .bn
                move.w  (a1),d0                 ; centre line of the chip on the
                lsl.w   #3,d0                   ;  screen : row*20 + h*10 - gpos
                lea     comps,a0
                adda.w  d0,a0
                move.w  (a0),d2                 ; type
                lea     comp_h,a0
                moveq   #0,d3
                move.b  (a0,d2.w),d3
                mulu    #TILE_PX/2,d3
                move.w  (a1),d0
                lsl.w   #3,d0
                lea     comps,a0
                moveq   #0,d1
                move.w  4(a0,d0.w),d1
                mulu    #TILE_PX,d1
                add.l   d3,d1
                sub.l   gpos,d1
                cmp.l   #BOSS_Y,d1
                blt.s   .bn
                cmp.l   #SCR_H,d1               ; (already gone : forget it)
                blt.s   .start
                st      (a2)
                bra.s   .bn
.start:         move.w  (a1),boss_idx           ; --- the fight begins
                move.l  a2,boss_flag
                move.w  #1,boss_on
                SFX     SFX_ALARM
                move.w  #BOSS_HP,boss_life
                move.w  #BOSS_FIRE_T,boss_t
                clr.w   boss_vol
                clr.w   boss_flash
                bra.s   .stop
.bn:            addq.l  #2,a1
                addq.l  #1,a2
                dbra    d4,.b
.go:            movem.l (sp)+,d0-d4/a0-a2
                moveq   #0,d0                   ; Z set : scroll
                rts
.stop:          movem.l (sp)+,d0-d4/a0-a2
                moveq   #1,d0                   ; Z clear : the ground waits
                rts

; boss_rect : world rectangle of the boss chip (ship plane) -> d0..d3
boss_rect:
                movem.l d4-d5/a0,-(sp)
                move.w  boss_idx,d4
                lsl.w   #3,d4
                lea     comps,a0
                adda.w  d4,a0
                move.w  (a0),d5                 ; type -> size
                move.w  2(a0),d0                ; screen x = col*20 - camx
                mulu    #TILE_PX,d0
                sub.w   camx,d0
                moveq   #0,d1                   ; screen y = row*20 - gpos
                move.w  4(a0),d1
                mulu    #TILE_PX,d1
                sub.l   gpos,d1
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
                sub.w   #CX,d0                  ; -> world : (s - C) * SHIP_Z / FOC
                sub.w   #CX,d2
                sub.w   #CY,d1
                sub.w   #CY,d3
                muls    #SHIP_Z,d0
                divs    #FOC,d0
                muls    #SHIP_Z,d2
                divs    #FOC,d2
                muls    #SHIP_Z,d1
                divs    #FOC,d1
                muls    #SHIP_Z,d3
                divs    #FOC,d3
                movem.l (sp)+,d4-d5/a0
                rts

; boss_update : fight (shots, hits) + its bullets ; in game_update
boss_update:
                movem.l d0-d7/a0-a1,-(sp)
                bsr     ebul_move
                tst.w   boss_on
                beq     .x
                tst.w   boss_flash
                beq.s   .f0
                subq.w  #1,boss_flash
.f0:            bsr     boss_rect               ; --- player bullets on the chip
                lea     bullets,a0
                moveq   #MAXB-1,d7
.b:             tst.w   (a0)
                beq.s   .bn
                move.w  2(a0),d4
                cmp.w   d0,d4
                blt.s   .bn
                cmp.w   d2,d4
                bgt.s   .bn
                move.w  4(a0),d4
                cmp.w   d1,d4
                blt.s   .bn
                cmp.w   d3,d4
                bgt.s   .bn
                clr.w   (a0)
                move.w  #3,boss_flash
                SFX     SFX_BHIT
                movem.l d0-d5/a1,-(sp)          ; small sparks where it hit
                move.w  2(a0),d2
                move.w  4(a0),d3
                moveq   #2,d4
                moveq   #32,d5
                lea     pal_spark,a1
                bsr     fx_burst
                movem.l (sp)+,d0-d5/a1
                subq.w  #1,boss_life
                bgt.s   .bn
                bsr     boss_kill
                bra     .x
.bn:            addq.l  #8,a0
                dbra    d7,.b
                subq.w  #1,boss_t               ; --- it shoots
                bgt     .x
                move.w  #BOSS_FIRE_T,boss_t
                SFX     SFX_BSHOT
                add.w   d0,d2                   ; from its centre
                asr.w   #1,d2
                add.w   d1,d3
                asr.w   #1,d3
                addq.w  #1,boss_vol
                cmp.w   #3,boss_vol
                blt.s   .aim
                clr.w   boss_vol
                moveq   #-2,d5                  ; fan of 5, straight down
.fan:           move.w  d5,d0
                muls    #12,d0                  ; dx = -24..24 /16
                move.w  #EB_SPD*16,d1
                bsr     ebul_add
                addq.w  #1,d5
                cmp.w   #2,d5
                ble.s   .fan
                bra.s   .x
.aim:           move.w  px,d0                   ; aimed at the ship :
                sub.w   d2,d0                   ;  (dx, dy) * EB_SPD*16 / max
                move.w  py,d1
                sub.w   d3,d1
                move.w  d0,d4
                bpl.s   .a1
                neg.w   d4
.a1:            move.w  d1,d5
                bpl.s   .a2
                neg.w   d5
.a2:            cmp.w   d5,d4
                bge.s   .a3
                move.w  d5,d4
.a3:            tst.w   d4
                bne.s   .a4
                moveq   #1,d4
.a4:            muls    #EB_SPD*16,d0
                divs    d4,d0
                muls    #EB_SPD*16,d1
                divs    d4,d1
                bsr     ebul_add
.x:             movem.l (sp)+,d0-d7/a0-a1
                rts

; boss_kill : the old chip is recapped (its old parts renewed, like a
;   recap of an old computer) : score, message, the
;   ground goes on
boss_kill:
                clr.w   boss_on
                move.l  boss_flag,a0
                st      (a0)
                suba.l  #boss_done,a0           ; -> recapped : green halo (EFFETS.S)
                add.l   #boss_fixed,a0
                st      (a0)
                movem.l d0-d5/a1,-(sp)          ; flash + blue sparks from its centre
                bsr     boss_rect
                add.w   d0,d2
                asr.w   #1,d2
                add.w   d1,d3
                asr.w   #1,d3
                moveq   #24,d4
                bsr     fx_flash
                moveq   #SPARK_N,d4
                moveq   #SPARK_SPD,d5
                lea     pal_spark,a1
                bsr     fx_burst
                movem.l (sp)+,d0-d5/a1
                add.l   #PTS_BOSS,score
                SFX     SFX_FIXED
                move.w  #BOSS_MSG_T,boss_msg
                rts

; ebul_add : bullet at d2,d3 (world) with speed d0,d1 (/16)
ebul_add:
                movem.l d4/a0,-(sp)
                lea     ebuls,a0
                moveq   #MAXEB-1,d4
.l:             tst.w   (a0)
                beq.s   .f
                lea     10(a0),a0
                dbra    d4,.l
                bra.s   .x
.f:             move.w  #1,(a0)
                move.w  d2,d4
                lsl.w   #4,d4
                move.w  d4,2(a0)
                move.w  d3,d4
                lsl.w   #4,d4
                move.w  d4,4(a0)
                move.w  d0,6(a0)
                move.w  d1,8(a0)
.x:             movem.l (sp)+,d4/a0
                rts

; ebul_move : boss bullets move, hit the ship
ebul_move:
                lea     ebuls,a0
                moveq   #MAXEB-1,d7
.l:             tst.w   (a0)
                beq.s   .n
                move.w  6(a0),d0
                add.w   d0,2(a0)
                move.w  8(a0),d0
                add.w   d0,4(a0)
                move.w  2(a0),d0                ; out of the screen ?
                asr.w   #4,d0
                cmp.w   #-160,d0
                blt.s   .k
                cmp.w   #160,d0
                bgt.s   .k
                move.w  4(a0),d1
                asr.w   #4,d1
                cmp.w   #-125,d1
                blt.s   .k
                cmp.w   #125,d1
                bgt.s   .k
                tst.w   inv                     ; the ship ?
                bne.s   .n
                tst.w   gover
                bne.s   .n
                sub.w   px,d0
                bpl.s   .h1
                neg.w   d0
.h1:            cmp.w   #EB_R,d0
                bgt.s   .n
                sub.w   py,d1
                bpl.s   .h2
                neg.w   d1
.h2:            cmp.w   #EB_R,d1
                bgt.s   .n
                clr.w   (a0)
                bsr     player_hit
                bra.s   .n
.k:             clr.w   (a0)
.n:             lea     10(a0),a0
                dbra    d7,.l
                rts

; boss_render : its bullets, its life bar and the messages ; a6 = picture
boss_render:
                movem.l d0-d7/a0-a2,-(sp)
                lea     ebuls,a2
                moveq   #MAXEB-1,d5
.b:             tst.w   (a2)
                beq.s   .bn
                move.w  2(a2),d0                ; world /16 -> screen
                asr.w   #4,d0
                muls    #FOC,d0
                divs    #SHIP_Z,d0
                add.w   #CX,d0
                move.w  4(a2),d1
                asr.w   #4,d1
                muls    #FOC,d1
                divs    #SHIP_Z,d1
                add.w   #CY,d1
                move.w  d0,d2
                addq.w  #3,d2
                subq.w  #3,d0
                move.w  d1,d3
                addq.w  #3,d3
                subq.w  #3,d1
                bsr     obj_begin
                move.w  #GLOW_EB,d4             ; red halo (7 x 7 : cheap enough
                bsr     blend_rect              ;  for 24 bullets on a real Falcon)
                addq.w  #1,d0
                addq.w  #1,d1
                subq.w  #1,d2
                subq.w  #1,d3
                move.w  #EB_COL,d4              ; orange core
                bsr     fillrect
                addq.w  #1,d0
                addq.w  #1,d1
                subq.w  #1,d2
                subq.w  #1,d3
                move.w  #$FFE0,d4               ; hot centre
                bsr     fillrect
                bsr     obj_end
.bn:            lea     10(a2),a2
                dbra    d5,.b
                tst.w   boss_on
                beq     .m
                move.w  #BAR_X0,d0              ; --- life bar (top of the screen)
                moveq   #BAR_Y,d1
                move.w  #BAR_X0+BAR_W+1,d2
                moveq   #BAR_Y+5,d3
                move.w  #$0000,d4
                bsr     fillrect
                bsr     add_rect
                move.w  boss_life,d2
                mulu    #BAR_W,d2
                divu    #BOSS_HP,d2
                add.w   #BAR_X0,d2
                move.w  #BAR_X0+1,d0
                moveq   #BAR_Y+1,d1
                moveq   #BAR_Y+4,d3
                move.w  #$F800,d4
                tst.w   boss_flash
                beq.s   .bc
                move.w  #$FFFF,d4
.bc:            bsr     fillrect
                bsr     boss_name               ; name above the bar
                move.w  #BAR_Y-8,d1
                bra.s   .t
.m:             tst.w   boss_msg                ; --- "xxx RECAPPED"
                beq     .x
                subq.w  #1,boss_msg
                bsr     boss_name
                lea     t_dest,a1               ; name + " RECAPPED"
.cp:            move.b  (a1)+,(a0)+
                bne.s   .cp
                move.w  #BAR_Y,d1
.t:             lea     boss_txt,a0             ; centred, 6 pixels per char
                moveq   #0,d0
.ln:            tst.b   (a0,d0.w)
                beq.s   .l2
                addq.w  #1,d0
                bra.s   .ln
.l2:            mulu    #3,d0
                neg.w   d0
                add.w   #CX,d0
                movem.w d0-d1,-(sp)
                move.w  #SCR_W-1,d2             ; erased next time
                move.w  d1,d3
                addq.w  #6,d3
                moveq   #0,d0
                bsr     add_rect
                movem.w (sp)+,d0-d1
                move.w  #$FFE0,d2
                moveq   #1,d3
                bsr     big_text
.x:             movem.l (sp)+,d0-d7/a0-a2
                rts

; boss_name : boss_txt = name of the boss (without * , _ -> space) ;
;   a0 = end of it (the 0)
boss_name:
                movem.l d0/a1,-(sp)
                move.w  boss_idx,d0
                mulu    #LBL_LEN,d0
                lea     comp_lbl+1,a1           ; (after the *)
                adda.l  d0,a1
                lea     boss_txt,a0
.c:             move.b  (a1)+,d0
                beq.s   .e
                cmp.b   #'_',d0
                bne.s   .s
                moveq   #' ',d0
.s:             move.b  d0,(a0)+
                bra.s   .c
.e:             clr.b   (a0)
                movem.l (sp)+,d0/a1
                rts

;---------------------------------------------------------------------
                section data
t_dest:         dc.b    ' RECAPPED',0
                even

                section bss
boss_on:        ds.w    1                       ; fight in progress
boss_idx:       ds.w    1                       ; its component
boss_flag:      ds.l    1                       ; -> its boss_done byte
boss_life:        ds.w    1
boss_t:         ds.w    1                       ; next volley
boss_vol:       ds.w    1                       ; volley counter (3rd = fan)
boss_flash:     ds.w    1
boss_msg:       ds.w    1                       ; "RECAPPED" time left
nboss:          ds.w    1
boss_list:      ds.w    MAXBOSS                 ; component indexes
boss_done:      ds.b    MAXBOSS
boss_txt:       ds.b    32
                even
ebuls:          ds.w    MAXEB*5                 ; act x*16 y*16 dx dy
                section text
