;=====================================================================
; XVOLUTION.S - vertical shoot'em up, Falcon 030 + DSP (v0.1)
;   Inspired by Wings of Death (Thalion, 1990) : top view, vertical
;   scrolling, a little robot-ship that evolves (3 forms).
;   3D maths by the DSP : R3D.P56 (OUTILS\R3D.A56, from RICK3D), loaded
;   with Simplet's replay (AMIGADSP.P56) ; DSP3D.S = RICK3D's interface.
;   If the DSP does not answer, the 030 draws the top faces only.
;
;   Keys : joystick port 1 (left) or arrows + SPACE, ESC = quit, P = pause,
;          H = bottom bar (fps, mode, coordinates) on / off,
;          D = 3D by the DSP / by the 030
;   Settings : PARAMS.S
;=====================================================================

                ; (labels are case-sensitive)
                include 'PARAMS.S'
                include 'PROFIL.S'              ; (PROF macro)

                section text
start:
                move.l  4(sp),a5                ; Mshrink (like RICK3D) : the
                move.l  12(a5),d0               ;  memory not used goes back to
                add.l   20(a5),d0               ;  the TOS (Mxalloc of the module,
                add.l   28(a5),d0               ;  MUSIQUE.S)
                add.l   #$1100,d0               ; basepage + stack
                move.l  a5,d1
                add.l   d0,d1
                and.l   #-2,d1
                move.l  d1,sp
                move.l  d0,-(sp)
                move.l  a5,-(sp)
                clr.w   -(sp)
                move.w  #$4a,-(sp)
                trap    #1
                lea     12(sp),sp
                dc.w    $a000                   ; 6x6 TOS font (Line-A),
                move.l  (a1),a1                 ;  like RICK3D (bottom bar)
                move.w  36(a1),fontfirst
                move.l  72(a1),fontoff
                move.l  76(a1),fontdat
                move.w  80(a1),fontw
                clr.l   -(sp)                   ; Super
                move.w  #32,-(sp)
                trap    #1
                addq.l  #6,sp
                move.l  d0,oldssp


                move.w  #2,-(sp)                ; Physbase
                trap    #14
                addq.l  #2,sp
                move.l  d0,oldphys
                move.w  #3,-(sp)                ; Logbase
                trap    #14
                addq.l  #2,sp
                move.l  d0,oldlog
                move.w  #-1,-(sp)               ; Vsetmode(-1)
                move.w  #88,-(sp)
                trap    #14
                addq.l  #4,sp
                move.w  d0,oldmode
                move.w  #89,-(sp)               ; Montype : 2 = VGA
                trap    #14
                addq.l  #2,sp
                move.w  #VMODE_VGA,d1
                move.w  #1,isvga
                cmp.w   #2,d0
                beq.s   .vga
                move.w  #VMODE_RGB,d1
                clr.w   isvga
.vga:           move.w  d1,vmode

                move.w  #1,cur_level
                bsr     map_load                ; LEVEL1.MAP (CARTE.S)
                bsr     game_new
                bsr     level_reset
                bsr     bake_init               ; (COMPOS.S)
                bsr     gnd_init                ; ground + screens (SOL.S)
                move.l  #bufd0,cur_bf
                move.l  bufd0+BF_ADR,scr_show
                move.w  vmode,-(sp)             ; Setscreen(log,phys,3,mode) :
                move.w  #3,-(sp)                ;  a black picture is shown while
                pea     blackscr                ;  everything is prepared
                pea     blackscr
                move.w  #5,-(sp)
                trap    #14
                lea     14(sp),sp
                lea     blackscr,a0             ; black picture (cleared after Setscreen :
                                                ;  the TOS fills it with white)
                move.w  #SCR_W*SCR_H/2-1,d0
.bk:            clr.l   (a0)+
                dbra    d0,.bk
                bsr     blank_on                ; (black picture : 640-byte lines)
                bsr     d3dinit                 ; DSP : Simplet + R3D
                tst.w   d0
                bne.s   .nodsp
                move.w  #1,dspok
.nodsp:         bsr     d3dload                 ; R3D answers -> d3don = 1

                bsr     joy_install
                bsr     mus_init                ; music : DSP module, YM tune (MUSIQUE.S)
                bsr     sfx_init                ; YM sound effects (SFX.S)
                bsr     vol_init                ; volume + / - (SFX.S)
                bsr     prof_install            ; Timer D (PROFIL.S)
                bsr     cut_install             ; split screen : Timer B (COUPURE.S)

;---------------------------------------------------------------------
; game flow : menu (MENU.S) -> level -> next level ... ; ESC : menu
game_menu:
                clr.w   cut_act                 ; no split at the menu (COUPURE.S)
                bsr     blank_on                ; black while the menu is drawn
                clr.b   $fffffa1b.w             ; (Timer B stopped)
                bsr     sfx_off                 ; (SFX.S)
                bsr     mus_stop                ; level music off,
                bsr     ymz_start               ;  YM tune of the menu on (MUSIQUE.S)
                bsr     menu
                bsr     ymz_stop                    ; d0 = level 1..4, -1 = quit
                tst.w   d0
                bmi     game_exit
                move.w  d0,cur_level
                bsr     game_new                ; score, lives, form
level_start:
                bsr     blank_on                ; black while the level is prepared
                bsr     spr_prepare             ; 1st level : sprites (progress bar)
                bsr     map_load                ; LEVELn.MAP + its tiles
                bsr     level_reset
                bsr     mus_play                ; level music (MUSIQUE.S)
                bsr     gnd_full                ; (SOL.S)
                clr.w   quit
                clr.w   lvl_done
                clr.w   gover_end
                move.w  #1,gsteps
                move.l  $466.w,lastflip
                bsr     blank_off               ; the level picture, ready
                move.l  scr_show,cut_pf         ; split screen on (COUPURE.S)
                move.l  #bandb0,cut_band
                move.l  #bandb0,cut_bnew
                move.w  #1,cut_act

main_loop:
                move.w  gsteps,d7               ; game steps : 1, or more if the
                subq.w  #1,d7                   ;  last frame was late (constant
.st:            bsr     game_update             ;  speed of the game)
                dbra    d7,.st
                PROF    PR_LOG
                bsr     render                  ; (a6 = picture, scr_show)
                bsr     countfps
                ; --- fixed rate : a new picture every FPS_DIV VBL (VGA 60 Hz :
                ;     FPS_DIV 2 = 30 pictures / s, the same with few or many objects)
.wt:            move.l  $466.w,d0               ; (_frclock : VBL counter)
                sub.l   lastflip,d0
                cmp.l   #FPS_DIV-1,d0
                bge.s   .fl
                move.w  #37,-(sp)               ; Vsync
                trap    #14
                addq.l  #2,sp
                bra.s   .wt
.fl:            bsr     cut_show                ; picture + band : written into
                                                ;  the VIDEL at the next VBL
                move.w  #37,-(sp)               ; Vsync : the picture is shown
                trap    #14
                addq.l  #2,sp
                move.l  $466.w,d0
                move.l  d0,d1
                sub.l   lastflip,d0             ; VBL since the last picture
                move.l  d1,lastflip
                divu    #FPS_DIV,d0             ; -> game steps for next time
                cmp.w   #1,d0
                bge.s   .s1
                moveq   #1,d0
.s1:            cmp.w   #MAX_STEPS,d0
                ble.s   .s2
                move.w  #MAX_STEPS,d0
.s2:            move.w  d0,gsteps
                PROF    PR_VBL
                move.l  #bufd0,d0               ; swap : the other screen
                cmp.l   cur_bf,d0
                bne.s   .sw
                move.l  #bufd1,d0
.sw:            move.l  d0,cur_bf
                bsr     keys
                tst.w   quit                    ; ESC : back to the menu
                bne     game_menu
                tst.w   gover_end               ; game over : menu
                bne     game_menu
                tst.w   lvl_done
                beq     main_loop
                move.w  cur_level,d0            ; end of the level : next one
                addq.w  #1,d0
                cmp.w   #NB_LEVELS,d0
                bhi     game_menu
                move.w  d0,cur_level
                bra     level_start

game_exit:
                bsr     sfx_exit                ; silence, YM routing back
                bsr     vol_exit                ; output volume back
                bsr     mus_exit                ; DSP sound system back (MUSIQUE.S)
                bsr     prof_stop               ; capture running : XVOLUTION.LOG
                bsr     prof_remove
                bsr     cut_remove              ; (COUPURE.S)
                bsr     joy_remove
                clr.w   $ffff820e.w             ; (normal lines)
                move.w  oldmode,-(sp)           ; screen back
                move.w  #3,-(sp)
                move.l  oldphys,-(sp)
                move.l  oldlog,-(sp)
                move.w  #5,-(sp)
                trap    #14
                lea     14(sp),sp
                move.l  oldssp,-(sp)
                move.w  #32,-(sp)
                trap    #1
                addq.l  #6,sp
                clr.w   -(sp)
                trap    #1

;---------------------------------------------------------------------
; INPUT : our own keyboard interrupt (ACIA, vector $118) : held keys
;   (keys[scancode] = 1 while pressed) + joystick packets ($FF = port 1).
;   Port 0 = mouse, not read.
;   Keyboard : arrows = move, SPACE = fire (like the joystick)
KEY_ESC         equ     $01
KEY_P           equ     $19
KEY_D           equ     $20
KEY_H           equ     $23
KEY_T           equ     $14
KEY_L           equ     $26
KEY_S           equ     $1F
KEY_C           equ     $2E
KEY_SPC         equ     $39
KEY_UP          equ     $48
KEY_DN          equ     $50
KEY_LT          equ     $4B
KEY_RT          equ     $4D

joy_install:
                lea     keymap,a0
                moveq   #127/4,d0
.c:             clr.l   (a0)+
                dbra    d0,.c
                clr.w   pk_cnt
                pea     ikbd_joy                ; joystick events
                clr.w   -(sp)
                move.w  #25,-(sp)
                trap    #14
                addq.l  #8,sp
                move.w  sr,-(sp)
                move.w  #$2700,sr
                move.l  $118.w,old118
                move.l  #acia_it,$118.w
                move.w  (sp)+,sr
                rts
joy_remove:
                move.w  sr,-(sp)
                move.w  #$2700,sr
                move.l  old118,$118.w
                move.w  (sp)+,sr
                pea     ikbd_mouse              ; mouse back
                clr.w   -(sp)
                move.w  #25,-(sp)
                trap    #14
                addq.l  #8,sp
                rts

acia_it:
                movem.l d0-d1/a0,-(sp)
.nx:            btst    #0,$fffffc00.w          ; byte received ?
                beq     .done
                move.b  $fffffc02.w,d0
                tst.w   pk_cnt
                bne     .pk
                cmp.b   #$f6,d0
                bhs.s   .hdr
                moveq   #0,d1                   ; key : bit 7 = released
                move.b  d0,d1
                and.w   #$7f,d1
                lea     keymap,a0
                tst.b   d0
                smi     d0
                not.b   d0
                and.b   #1,d0
                move.b  d0,(a0,d1.w)
                beq     .nx                     ; pressed : latched in keyhit
                lea     keyhit,a0
                move.b  d0,(a0,d1.w)
                bra     .nx
.hdr:           move.b  d0,pk_type              ; packet : bytes to skip
                moveq   #0,d1
                move.b  d0,d1
                sub.w   #$f6,d1
                move.b  .len(pc,d1.w),d1
                move.w  d1,pk_cnt
                bra     .nx
.pk:            subq.w  #1,pk_cnt
                cmp.b   #$ff,pk_type            ; port 1
                beq.s   .j1
                cmp.b   #$fd,pk_type            ; (both ports : 2nd byte)
                bne     .nx
                tst.w   pk_cnt
                bne     .nx
.j1:            move.b  d0,joy1
                bra     .nx
.done:          btst    #0,$fffffc04.w          ; (MIDI : byte dropped)
                beq.s   .dn
                move.b  $fffffc06.w,d0
.dn:            movem.l (sp)+,d0-d1/a0
                bclr    #6,$fffffa11.w          ; end of the ACIA interrupt
                rte
.len:           dc.b    7,5,2,2,2,2,6,2,1,1     ; $F6..$FF
                even

; read_input : joystick port 1 + keyboard -> joyin (bits 0 up 1 down
;   2 left 3 right 7 fire)
read_input:
                lea     keymap,a0
                move.b  joy1,d0
                tst.b   KEY_UP(a0)
                beq.s   .1
                bset    #0,d0
.1:             tst.b   KEY_DN(a0)
                beq.s   .2
                bset    #1,d0
.2:             tst.b   KEY_LT(a0)
                beq.s   .3
                bset    #2,d0
.3:             tst.b   KEY_RT(a0)
                beq.s   .4
                bset    #3,d0
.4:             tst.b   KEY_SPC(a0)
                beq.s   .5
                bset    #7,d0
.5:             move.b  d0,joyin
                rts

; keys : ESC quit, P pause, D DSP / 030 (on the press only)
keys:
                lea     keyhit,a0               ; (presses latched by acia_it :
                tst.b   KEY_ESC(a0)             ;  a short tap is never lost)
                beq.s   .p
                move.w  #1,quit
.p:             tst.b   KEY_P(a0)
                beq.s   .d
                eor.w   #1,paused
.d:             tst.b   KEY_D(a0)
                beq.s   .h
                bsr     d3dkey
.h:             tst.b   KEY_H(a0)               ; H : bottom bar on / off
                beq.s   .t
                eor.w   #1,txt_hidden
.t:             tst.b   KEY_T(a0)               ; T : profiler in the bar
                beq.s   .l
                eor.w   #1,prof_on
.l:             tst.b   KEY_L(a0)               ; L : XVOLUTION.LOG now
                beq.s   .s
                bsr     prof_save
.s:             bsr     vol_keys                ; + / - : volume (SFX.S)
                tst.b   KEY_C(a0)               ; C : split screen on / off
                beq.s   .s0                     ;  (COUPURE.S ; off in Hatari)
                not.w   cut_on
                and.w   #1,cut_on
.s0:
                tst.b   KEY_S(a0)               ; S : capture start / stop
                beq.s   .c
                tst.w   pr_rec
                bne.s   .s1
                move.w  txt_hidden,pr_bar       ;  start : bottom bar hidden
                move.w  #1,txt_hidden
                bsr     prof_start
                SFX     SFX_BONUS
                bra.s   .c
.s1:            bsr     prof_stop               ;  stop : file written, bar back
                move.w  pr_bar,txt_hidden
                SFX     SFX_FIXED
.c:             lea     keyhit,a0
                moveq   #128/4-1,d0
.cl:            clr.l   (a0)+
                dbra    d0,.cl
                rts

;---------------------------------------------------------------------
; game_new : new game (score, lives, form) ; level_reset : start of a level
game_new:
                clr.l   score
                move.w  #NB_LIVES,lives
                clr.w   form
                clr.w   kills
                rts
; blank_on : a black picture (at the VBL : no half picture)
blank_on:
                movem.l d0-d2/a0-a2,-(sp)
                clr.w   cut_act
                move.w  #37,-(sp)               ; Vsync
                trap    #14
                addq.l  #2,sp
                move.l  #blackscr,d0
                bsr.s   set_base
                clr.w   $ffff820e.w             ; 640-byte lines
                movem.l (sp)+,d0-d2/a0-a2
                rts
; blank_off : the game picture scr_show again (lines of LINEB bytes)
blank_off:
                movem.l d0-d2/a0-a2,-(sp)
                move.w  #37,-(sp)
                trap    #14
                addq.l  #2,sp
                move.l  scr_show,d0
                bsr.s   set_base
                move.w  #(LINEB-SCR_W*2)/2,$ffff820e.w  ; (VIDEL : words skipped
                movem.l (sp)+,d0-d2/a0-a2       ;  after each line)
                rts
; set_base : video base = d0 (exact : high, middle, low)
set_base:
                swap    d0
                move.b  d0,$ffff8201.w
                swap    d0
                move.w  d0,d1
                lsr.w   #8,d1
                move.b  d1,$ffff8203.w
                move.b  d0,$ffff820d.w
                rts

level_reset:
                clr.w   px
                move.w  #80,py
                move.w  #INVUL_T,inv
                clr.w   firet
                clr.w   gover
                clr.w   camx
                clr.w   bon_act
                move.w  #60,wavet
                clr.w   scr_acc
                bsr     boss_init               ; (BOSS.S)
                bsr     fx_reset                ; (EFFETS.S)
                bsr     pulse_init
                move.l  lvl_h,d0                ; start : bottom of the map
                sub.l   #SCR_H,d0
                move.l  d0,gpos
                lea     bullets,a0
                move.w  #MAXB*4-1,d0
.b:             clr.w   (a0)+
                dbra    d0,.b
                lea     enemies,a0
                move.w  #MAXE*8-1,d0
.e:             clr.w   (a0)+
                dbra    d0,.e
                rts

game_update:
                tst.w   paused
                beq.s   .up
                bsr     sfx_off                 ; (pause : silence)
                bra     .x
.up:            bsr     sfx_update              ; YM : one frame of the effects (SFX.S)
                bsr     fx_update               ; particles, track pulses (EFFETS.S)
                bsr     pulse_update
                bsr     boss_check              ; boss fight : the ground waits
                bne.s   .g0
                move.w  scr_acc,d1              ; ground scrolls down
                add.w   #SCROLL_SPD8,d1         ;  (1/256 pixels)
                move.w  d1,d0
                lsr.w   #8,d0
                and.w   #$ff,d1
                move.w  d1,scr_acc
                ext.l   d0
                neg.l   d0
                add.l   gpos,d0
                bpl.s   .g                      ; end of the map : level done
                moveq   #0,d0
                move.w  #1,lvl_done
.g:             move.l  d0,gpos
.g0:
                tst.w   gover
                beq.s   .play
                subq.w  #1,gover
                bne     .x
                move.w  #1,gover_end            ; (back to the menu)
                bra     .x
.play:          bsr     upd_player
                move.w  cam_max,d1              ; camera : the ship's place on the
                beq.s   .c0                     ;  screen gives the place on the
                move.w  px,d0                   ;  board (horizontal scroll)
                add.w   #SHIP_XMAX,d0
                mulu    d1,d0
                divu    #2*SHIP_XMAX,d0
                move.w  d0,camx
.c0:
                bsr     upd_bullets
                bsr     upd_enemies
                bsr     upd_bonus
                bsr     collide
                bsr     boss_update             ; (BOSS.S)
.x:             rts

upd_player:
                bsr     read_input
                move.b  joyin,d0
                move.w  px,d1
                move.w  py,d2
                btst    #2,d0
                beq.s   .m1
                subq.w  #SHIP_SPD,d1
.m1:             btst    #3,d0
                beq.s   .m2
                addq.w  #SHIP_SPD,d1
.m2:             btst    #0,d0
                beq.s   .m3
                subq.w  #SHIP_SPD,d2
.m3:             btst    #1,d0
                beq.s   .m4
                addq.w  #SHIP_SPD,d2
.m4:             cmp.w   #-SHIP_XMAX,d1
                bge.s   .m5
                move.w  #-SHIP_XMAX,d1
.m5:             cmp.w   #SHIP_XMAX,d1
                ble.s   .m6
                move.w  #SHIP_XMAX,d1
.m6:             cmp.w   #-SHIP_YMAX,d2
                bge.s   .m7
                move.w  #-SHIP_YMAX,d2
.m7:             cmp.w   #SHIP_YMAX,d2
                ble.s   .m8
                move.w  #SHIP_YMAX,d2
.m8:             move.w  d1,px
                move.w  d2,py
                tst.w   inv
                beq.s   .i
                subq.w  #1,inv
.i:             tst.w   firet
                beq.s   .f
                subq.w  #1,firet
                rts
.f:             btst    #7,d0
                beq     .r
                move.w  form,d3
                cmp.w   #1,d3
                beq.s   .f1
                bgt.s   .f2
                move.w  px,d1                   ; form 0 : 1 bullet
                move.w  py,d2
                sub.w   #14,d2
                moveq   #0,d3
                bsr     add_bullet
                move.w  #FIRE_T0,firet
                SFX     SFX_SHOT
                rts
.f1:            move.w  px,d1                   ; form 1 : 2 bullets
                subq.w  #8,d1
                move.w  py,d2
                subq.w  #8,d2
                moveq   #0,d3
                bsr     add_bullet
                add.w   #16,d1
                bsr     add_bullet
                move.w  #FIRE_T0,firet
                SFX     SFX_SHOT
                rts
.f2:            move.w  px,d1                   ; form 2 : fan of 3
                move.w  py,d2
                sub.w   #16,d2
                moveq   #0,d3
                bsr     add_bullet
                sub.w   #12,d1
                addq.w  #6,d2
                moveq   #-2,d3
                bsr     add_bullet
                add.w   #24,d1
                moveq   #2,d3
                bsr     add_bullet
                move.w  #FIRE_T2,firet
                SFX     SFX_SHOT
.r:             rts

; add_bullet : d1 = x, d2 = y, d3 = dx (kept)
add_bullet:
                movem.l d0/a0,-(sp)
                lea     bullets,a0
                moveq   #MAXB-1,d0
.l:             tst.w   (a0)
                beq.s   .f
                addq.l  #8,a0
                dbra    d0,.l
                bra.s   .x
.f:             move.w  #1,(a0)
                movem.w d1-d3,2(a0)
.x:             movem.l (sp)+,d0/a0
                rts

upd_bullets:
                lea     bullets,a0
                moveq   #MAXB-1,d0
.l:             tst.w   (a0)
                beq.s   .n
                sub.w   #BUL_SPD,4(a0)
                move.w  6(a0),d1
                add.w   d1,2(a0)
                cmp.w   #-135,4(a0)
                bgt.s   .n
                clr.w   (a0)
.n:             addq.l  #8,a0
                dbra    d0,.l
                rts

; enemies : 16 bytes : act x y type hp t x0 -
upd_enemies:
                tst.w   boss_on                 ; (no new enemy during a boss)
                bne.s   .mv
                subq.w  #1,wavet
                bne.s   .mv
                move.w  #WAVE_T,wavet
                bsr     spawn_enemy
.mv:            lea     enemies,a0
                moveq   #MAXE-1,d0
.l:             tst.w   (a0)
                beq.s   .n
                tst.w   6(a0)
                bne.s   .t1
                addq.w  #EN_SPD0,4(a0)          ; drone : straight down
                bra.s   .chk
.t1:            addq.w  #EN_SPD1,4(a0)          ; cruiser : slow, zigzag
                addq.w  #1,10(a0)
                move.w  10(a0),d1
                and.w   #127,d1
                cmp.w   #63,d1
                ble.s   .k
                neg.w   d1
                add.w   #127,d1
.k:             sub.w   #32,d1
                add.w   12(a0),d1
                move.w  d1,2(a0)
.chk:           cmp.w   #140,4(a0)
                blt.s   .n
                clr.w   (a0)
.n:             lea     16(a0),a0
                dbra    d0,.l
                rts

spawn_enemy:
                lea     enemies,a0
                moveq   #MAXE-1,d0
.l:             tst.w   (a0)
                beq.s   .f
                lea     16(a0),a0
                dbra    d0,.l
                rts
.f:             bsr     rnd
                move.w  d0,d1
                lsr.w   #7,d1
                and.w   #1,d1
                move.w  d1,6(a0)
                bsr     rnd
                mulu    #240,d0
                swap    d0
                sub.w   #120,d0
                move.w  d0,2(a0)
                move.w  d0,12(a0)
                move.w  #-140,4(a0)
                clr.w   10(a0)
                move.w  #EN_HP0,8(a0)
                tst.w   d1
                beq.s   .h
                move.w  #EN_HP1,8(a0)
.h:             move.w  #1,(a0)
                rts

upd_bonus:
                tst.w   bon_act
                beq.s   .x
                addq.w  #BON_SPD,bon_y
                cmp.w   #140,bon_y
                blt.s   .x
                clr.w   bon_act
.x:             rts

rnd:            move.w  seed,d0                 ; -> d0.w
                mulu    #25173,d0
                add.l   #13849,d0
                move.w  d0,seed
                rts

;---------------------------------------------------------------------
collide:
                lea     bullets,a0              ; --- bullets / enemies
                moveq   #MAXB-1,d6
.b:             tst.w   (a0)
                beq     .bn
                lea     enemies,a1
                moveq   #MAXE-1,d5
.e:             tst.w   (a1)
                beq.s   .en
                move.w  2(a0),d0
                sub.w   2(a1),d0
                bpl.s   .k1
                neg.w   d0
.k1:             cmp.w   #BUL_R,d0
                bgt.s   .en
                move.w  4(a0),d0
                sub.w   4(a1),d0
                bpl.s   .k2
                neg.w   d0
.k2:             cmp.w   #BUL_R,d0
                bgt.s   .en
                clr.w   (a0)                    ; hit
                subq.w  #1,8(a1)
                bgt.s   .bn
                bsr     kill_enemy
                bra.s   .bn
.en:            lea     16(a1),a1
                dbra    d5,.e
.bn:            addq.l  #8,a0
                dbra    d6,.b

                tst.w   inv                     ; --- ship / enemies
                bne.s   .bon
                lea     enemies,a1
                moveq   #MAXE-1,d5
.p:             tst.w   (a1)
                beq.s   .pn
                move.w  px,d0
                sub.w   2(a1),d0
                bpl.s   .k3
                neg.w   d0
.k3:             cmp.w   #HIT_R,d0
                bgt.s   .pn
                move.w  py,d0
                sub.w   4(a1),d0
                bpl.s   .k4
                neg.w   d0
.k4:             cmp.w   #HIT_R,d0
                bgt.s   .pn
                clr.w   (a1)
                bsr     player_hit
                bra.s   .bon
.pn:            lea     16(a1),a1
                dbra    d5,.p

.bon:           tst.w   bon_act                 ; --- ship / bonus : evolves
                beq.s   .x
                move.w  px,d0
                sub.w   bon_x,d0
                bpl.s   .k5
                neg.w   d0
.k5:             cmp.w   #HIT_R+4,d0
                bgt.s   .x
                move.w  py,d0
                sub.w   bon_y,d0
                bpl.s   .k6
                neg.w   d0
.k6:             cmp.w   #HIT_R+4,d0
                bgt.s   .x
                clr.w   bon_act
                SFX     SFX_BONUS
                add.l   #PTS_BONUS,score
                cmp.w   #FORM_MAX,form
                bge.s   .x
                addq.w  #1,form
.x:             rts

; kill_enemy : a1 = enemy
kill_enemy:
                SFX     SFX_BOOM
                bsr     fx_boom                 ; debris + flash (EFFETS.S)
                clr.w   (a1)
                move.l  #PTS_EN0,d0
                tst.w   6(a1)
                beq.s   .s
                move.l  #PTS_EN1,d0
.s:             add.l   d0,score
                addq.w  #1,kills
                moveq   #0,d0
                move.w  kills,d0
                divu    #BONUS_EVERY,d0
                swap    d0
                tst.w   d0
                bne.s   .x
                tst.w   bon_act
                bne.s   .x
                move.w  #1,bon_act              ; bonus pod where it died
                move.w  2(a1),bon_x
                move.w  4(a1),bon_y
.x:             rts

; player_hit : the ship loses a form ; at form 0, a life
player_hit:
                SFX     SFX_HIT
                movem.l d2-d5/a1,-(sp)          ; red debris from the ship
                move.w  px,d2
                move.w  py,d3
                moveq   #16,d4
                moveq   #BOOM_SPD,d5
                lea     pal_hit,a1
                bsr     fx_burst
                movem.l (sp)+,d2-d5/a1
                move.w  #INVUL_T,inv
                tst.w   form
                beq.s   .l
                subq.w  #1,form
                rts
.l:             subq.w  #1,lives
                bgt.s   .x
                clr.w   lives
                move.w  #150,gover              ; game over : 2,5 s then restart
.x:             rts

;---------------------------------------------------------------------
; render : a6 = screen
render:
                bsr     ground_frame            ; scroll + erasing (SOL.S)
                PROF    PR_SOL
                PROF    PR_CMP                  ; (components : baked in the ground)
                bsr     pulse_render            ; on the board : pulses, recapped
                bsr     fx_fixed                ;  chips, shadow of the ship
                tst.w   gover
                bne.s   .ns
                move.w  inv,d0
                btst    #2,d0
                bne.s   .ns
                lea     forms,a0
                move.w  form,d0
                lsl.w   #2,d0
                move.l  (a0,d0.w),a0
                bsr     fx_shadow
.ns:            move.w  #SHIP_Z,mdl_z
                tst.w   bon_act
                beq.s   .ne
                lea     mdl_bonus,a0
                move.w  bon_x,d6
                move.w  bon_y,d7
                bsr     draw_model
.ne:            lea     enemies,a2
                moveq   #MAXE-1,d5
.e:             tst.w   (a2)
                beq.s   .en
                moveq   #0,d4                   ; LED / capacitor / transistor
                lea     mdl_en0,a0
                btst    #0,d5
                beq.s   .e0
                moveq   #1,d4
                lea     mdl_en2,a0
.e0:            tst.w   6(a2)
                beq.s   .e1
                moveq   #2,d4
                lea     mdl_en1,a0
.e1:            move.w  2(a2),d6
                move.w  4(a2),d7
                tst.w   d3don                   ; DSP : precomputed sprite (EFFETS.S)
                beq.s   .e2
                bsr     en_sprite
                bra.s   .en
.e2:            bsr     draw_model              ; 030 : the model itself
.en:            lea     16(a2),a2
                dbra    d5,.e
                PROF    PR_ENM
                lea     bullets,a2
                moveq   #MAXB-1,d5
.b:             tst.w   (a2)
                beq.s   .bn
                move.w  2(a2),d0
                muls    #FOC,d0
                divs    #SHIP_Z,d0
                add.w   #CX,d0
                move.w  4(a2),d1
                muls    #FOC,d1
                divs    #SHIP_Z,d1
                add.w   #CY,d1
                bsr     obj_begin
                move.w  d0,d2                   ; trail : solid, 2 wide (fast :
                move.w  d1,d3                   ;  no 50 % mix any more)
                add.w   #12,d3
                addq.w  #4,d1
                move.w  #TRAIL_B,d4
                bsr     fillrect
                subq.w  #1,d0                   ; core : 4 x 7, yellow edge
                addq.w  #2,d2
                sub.w   #9,d1
                sub.w   #6,d3
                move.w  #GLOW_B,d4
                bsr     fillrect
                addq.w  #1,d0                   ;  white centre
                subq.w  #1,d2
                addq.w  #1,d1
                subq.w  #1,d3
                move.w  #$FFF0,d4
                bsr     fillrect
                bsr     obj_end
.bn:            addq.l  #8,a2
                dbra    d5,.b
                bsr     boss_render             ; its bullets, life bar (BOSS.S)
                bsr     fx_render               ; explosions (EFFETS.S)
                PROF    PR_BUL
                tst.w   gover
                bne.s   .np
                move.w  inv,d0                  ; (blinks while invulnerable)
                btst    #2,d0
                bne.s   .np
                lea     forms,a0
                move.w  form,d0
                lsl.w   #2,d0
                move.l  (a0,d0.w),a0
                tst.w   d3don                   ; DSP : precomputed sprite (EFFETS.S)
                beq.s   .n3
                bsr     ship_sprite
                bra.s   .np
.n3:            move.w  px,d6                   ; 030 : the model itself
                move.w  py,d7
                bsr     draw_model
.np:            PROF    PR_SHP
                bsr     draw_hud
                bsr     draw_band               ; bottom bar (H)
                tst.w   cut_on                  ; (split : the band is not in the
                bne.s   .nt                     ;  picture)
                move.l  cur_bf,a0               ; top band : its place noted (SOL.S
                move.w  cur_b0,BF_BL(a0)        ;  band_fix puts back only the
                move.w  cur_camx,BF_BX(a0)      ;  lines it leaves)
.nt:            moveq   #0,d0
                move.w  #SCR_W-1,d2
                tst.w   txt_hidden
                bne.s   .nb
                move.w  #TXT_Y,d1
                move.w  #SCR_H-1,d3
                bsr     add_rect
.nb:            tst.w   gover                   ; (game over band)
                beq.s   .ng
                move.w  #110,d1
                move.w  #129,d3
                bsr     add_rect
.ng:            PROF    PR_HUD
                rts

; draw_model : a0 = model (x0 y0 x1 y1 z0 z1 .w, colours .l ; -99 = end),
;   d6 / d7 = position, mdl_z = depth
draw_model:
                movem.l d0-d7/a0-a1,-(sp)
                bsr     obj_begin
.l:             move.w  (a0)+,d0
                cmp.w   #-99,d0
                beq.s   .x
                move.w  (a0)+,d1
                move.w  (a0)+,d2
                move.w  (a0)+,d3
                move.w  (a0)+,d4
                move.w  (a0)+,d5
                move.l  (a0)+,a1
                add.w   d6,d0
                add.w   d6,d2
                add.w   d7,d1
                add.w   d7,d3
                add.w   mdl_z,d4
                add.w   mdl_z,d5
                bsr     draw_box
                bra.s   .l
.x:             bsr     obj_end
                            movem.l (sp)+,d0-d7/a0-a1
                rts

; draw_box : box d0=X0 d1=Y0 d2=X1 d3=Y1 d4=Z0 (near) d5=Z1, a1 = colours
;   (front, side, top, bottom), a6 = screen. All registers kept.
draw_box:
                addq.l  #1,pr_box               ; (profiler)
                movem.l d0-d7/a0-a6,-(sp)
                tst.w   d3don
                beq.s   .cpu
                bsr     d3dbox                  ; DSP : side faces drawn
                tst.w   d7
                bmi.s   .cpu                    ; (DSP lost : 030)
                beq.s   .x
                move.w  (a1),d4                 ; front face (projected)
                bsr     fillrect
                bra.s   .x
.cpu:           muls    #FOC,d0                 ; 030 : front face only
                divs    d4,d0
                add.w   #CX,d0
                muls    #FOC,d2
                divs    d4,d2
                add.w   #CX,d2
                muls    #FOC,d1
                divs    d4,d1
                add.w   #CY,d1
                muls    #FOC,d3
                divs    d4,d3
                add.w   #CY,d3
                move.w  (a1),d4
                bsr     fillrect
.x:             movem.l (sp)+,d0-d7/a0-a6
                rts

; fillrect : d0,d1 - d2,d3 (inclusive), d4.w = colour, a6 = screen
fillrect:
                movem.l d0-d7/a0-a1,-(sp)
                tst.w   d0
                bpl.s   .q1
                moveq   #0,d0
.q1:             cmp.w   #SCR_W-1,d2
                ble.s   .q2
                move.w  #SCR_W-1,d2
.q2:             cmp.w   d2,d0
                bgt.s   .x
                cmp.w   clip_y0,d1
                bge.s   .q3
                move.w  clip_y0,d1
.q3:             cmp.w   clip_y1,d3
                ble.s   .q4
                move.w  clip_y1,d3
.q4:             bsr     bb_add                  ; (erasing rectangle)
                sub.w   d1,d3                   ; lines - 1
                bmi.s   .x
                move.w  d4,d5
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
.ln:            move.l  a0,a1
                move.w  d2,d7
                btst    #1,d0                   ; (long words aligned)
                beq.s   .al
                move.w  d4,(a1)+
                subq.w  #1,d7
                beq.s   .nl
.al:            move.w  d7,d6
                lsr.w   #1,d6
                beq.s   .r
                subq.w  #1,d6
.lp:            move.l  d5,(a1)+
                dbra    d6,.lp
.r:             btst    #0,d7
                beq.s   .nl
                move.w  d4,(a1)+
.nl:            lea     LINEB(a0),a0
                dbra    d3,.ln
.x:             movem.l (sp)+,d0-d7/a0-a1
                rts

;---------------------------------------------------------------------
;---------------------------------------------------------------------
; draw_hud : score (6 digits), form of the ship, lives
draw_hud:
                movem.l d0-d7/a0-a6,-(sp)
                move.l  a6,-(sp)                ; (the picture : game over band)
                tst.w   cut_on                  ; split screen : the band is drawn
                beq.s   .bp                     ;  into its own buffer (one per
                lea     bandb0,a6               ;  screen), shown by the VIDEL
                cmp.l   #bufd0,cur_bf           ;  above the picture (COUPURE.S)
                beq.s   .b0
                lea     bandb1,a6
.b0:            move.l  a6,cut_bnew
.bp:            ; --- the black band at the top (TOP_H lines, drawn last)
                moveq   #0,d0
                moveq   #0,d1
                moveq   #0,d2
                moveq   #0,d3
                moveq   #0,d4
                moveq   #0,d5
                moveq   #0,d6
                moveq   #0,d7
                move.l  a6,a1
                move.w  #TOP_H-1,-(sp)
.bl:            lea     SCR_W*2(a1),a2          ; (from the end of the line)
                rept    SCR_W*2/32
                movem.l d0-d7,-(a2)
                endr
                lea     LINEB(a1),a1
                subq.w  #1,(sp)
                bpl.s   .bl
                addq.l  #2,sp
                ; --- score
                move.l  score,d0
                moveq   #4,d1
                moveq   #3,d2
                bsr     draw_num
                ; --- form : 1 to 3 yellow bars
                moveq   #0,d7
.f:             move.w  d7,d0
                lsl.w   #3,d0
                add.w   #60,d0
                move.w  d0,d2
                addq.w  #5,d2
                moveq   #3,d1
                moveq   #12,d3
                move.w  #$FFE0,d4
                bsr     fillrect
                addq.w  #1,d7
                cmp.w   form,d7
                ble.s   .f
                ; --- lives : green squares (8 at most)
                move.w  lives,d7
                beq.s   .nl
                cmp.w   #8,d7
                bls.s   .l0
                moveq   #8,d7
.l0:            subq.w  #1,d7
.l:             move.w  d7,d0
                lsl.w   #3,d0
                add.w   #88,d0
                move.w  d0,d2
                addq.w  #5,d2
                moveq   #5,d1
                moveq   #10,d3
                move.w  #$07E0,d4
                bsr     fillrect
                dbra    d7,.l
.nl:            ; --- + / - : volume bar (16 boxes, full if volume > 4 * box)
                tst.w   vol_show
                beq.s   .nv
                subq.w  #1,vol_show
                moveq   #0,d5
.vb:            move.w  d5,d0
                mulu    #6,d0
                add.w   #156,d0
                move.w  d0,d2
                addq.w  #3,d2
                moveq   #5,d1
                moveq   #10,d3
                move.w  #$4208,d4
                move.w  d5,d6
                lsl.w   #2,d6
                cmp.w   vol_lev,d6
                bhs.s   .vc
                move.w  #$FFE0,d4
.vc:            bsr     fillrect
                addq.w  #1,d5
                cmp.w   #16,d5
                blt.s   .vb
.nv:            ; --- level (x 118)
                move.w  cur_level,d0
                subq.w  #1,d0
                and.w   #3,d0
                lsl.w   #3,d0
                lea     t_lvls,a2
                add.w   d0,a2
                move.w  #118,d0
                moveq   #5,d1
                move.w  #$867F,d6
                bsr     btext
                ; --- right : DSP / 030, REC (capture S), PAUSE, FPS
                lea     t_dsp,a2
                tst.w   d3don
                bne.s   .m
                lea     t_030,a2
.m:             move.w  #256,d0
                moveq   #5,d1
                move.w  #$BDF7,d6
                bsr     btext
                tst.w   pr_rec
                beq.s   .nr
                btst    #3,fx_clock+1           ; (blinks)
                bne.s   .nr
                lea     t_rec,a2
                move.w  #234,d0
                move.w  #$F800,d6
                bsr     btext
.nr:            tst.w   paused
                beq.s   .np
                lea     t_paus2,a2
                move.w  #156,d0
                move.w  #$FFFF,d6
                bsr     btext
.np:            move.b  fx_clock+1,d0           ; (test : Timer B lines late,
                and.b   #31,d0                  ;  max over 32 frames, at x 204)
                bne.s   .lk
                move.w  cut_lmax,cut_lshow
                clr.w   cut_lmax
.lk:            tst.w   cut_on
                beq.s   .nlt
                move.w  cut_lshow,d0
                bpl.s   .lp
                moveq   #0,d0
.lp:            bsr     fmtnum
                lea     numbuf+6,a2
                move.w  #204,d0
                moveq   #5,d1
                move.w  #$07FF,d6
                bsr     btext
.nlt:           move.w  fps,d0
                bsr     fmtnum
                lea     numbuf+6,a2
                cmp.w   #10,fps
                bhs.s   .f2
                move.b  #' ',numbuf+6
.f2:            move.w  #282,d0
                moveq   #5,d1
                move.w  #$FFFF,d6
                cmp.w   #28,fps
                bhs.s   .f3
                move.w  #$FC00,d6               ; (orange : under 28)
.f3:            bsr     btext
                lea     t_fps2,a2
                move.w  #300,d0
                move.w  #$BDF7,d6
                bsr     btext
                move.l  (sp)+,a6                ; --- game over : red band
                tst.w   gover
                beq.s   .x
                move.w  gover,d0
                btst    #4,d0
                bne.s   .x
                moveq   #0,d0
                move.w  #110,d1
                move.w  #SCR_W-1,d2
                move.w  #129,d3
                move.w  #$F800,d4
                bsr     fillrect
.x:             movem.l (sp)+,d0-d7/a0-a6
                rts

; btext : string a2 (0 = end) at d0 = x, d1 = y, colour d6 (TOS 6x6 font)
btext:
                movem.l d0-d7/a0-a4,-(sp)
                moveq   #0,d2
                move.w  d1,d2
                mulu    #LINEB,d2
                lea     (a6,d2.l),a4
                add.w   d0,d0
                adda.w  d0,a4
.ch:            moveq   #0,d0
                move.b  (a2)+,d0
                beq.s   .x
                cmp.w   #' ',d0
                bls.s   .nc
                sub.w   fontfirst,d0
                bmi.s   .nc
                add.w   d0,d0
                move.l  fontoff,a1
                move.w  (a1,d0.w),d3
                move.w  d3,d0
                lsr.w   #3,d0
                move.l  fontdat,a1
                adda.w  d0,a1
                and.w   #7,d3
                move.l  a4,a3
                moveq   #5,d4
.fl:            move.b  (a1),d2
                lsl.w   #8,d2
                move.b  1(a1),d2
                lsl.w   d3,d2
                moveq   #5,d5
                move.l  a3,a0
.pb:            add.w   d2,d2
                bcc.s   .p0
                move.w  d6,(a0)
.p0:            addq.l  #2,a0
                dbra    d5,.pb
                lea     LINEB(a3),a3
                adda.w  fontw,a1
                dbra    d4,.fl
.nc:            lea     12(a4),a4
                bra.s   .ch
.x:             movem.l (sp)+,d0-d7/a0-a4
                rts

; draw_num : d0.l = value, d1 = x, d2 = y (digits 3x5, pixels 2x2, white)
draw_num:
                movem.l d0-d7/a0-a2,-(sp)
                cmp.l   #999999,d0
                bls.s   .c
                move.l  #999999,d0
.c:             divu    #1000,d0
                lea     digbuf+6,a0
                move.l  d0,d3
                clr.w   d3
                swap    d3
                jsr   .three
                moveq   #0,d3
                move.w  d0,d3
                jsr   .three
                lea     digbuf,a0
                moveq   #5,d7
.dg:            moveq   #0,d3
                move.b  (a0)+,d3
                mulu    #5,d3
                lea     font,a1
                adda.w  d3,a1
                move.w  d2,d5
                moveq   #4,d6
.row:           move.b  (a1)+,d3
                moveq   #0,d0
                move.w  d5,d0
                mulu    #LINEB,d0
                lea     (a6,d0.l),a2
                move.w  d1,d0
                add.w   d0,d0
                adda.w  d0,a2
                btst    #2,d3
                beq.s   .c1
                move.l  #-1,(a2)
                move.l  #-1,LINEB(a2)
.c1:            btst    #1,d3
                beq.s   .c2
                move.l  #-1,4(a2)
                move.l  #-1,LINEB+4(a2)
.c2:            btst    #0,d3
                beq.s   .c3
                move.l  #-1,8(a2)
                move.l  #-1,LINEB+8(a2)
.c3:            addq.w  #2,d5
                dbra    d6,.row
                addq.w  #8,d1
                dbra    d7,.dg
                movem.l (sp)+,d0-d7/a0-a2
                rts
.three:         moveq   #2,d4                   ; d3 = 0..999 -> 3 digits before a0
.t:             divu    #10,d3
                swap    d3
                move.b  d3,-(a0)
                clr.w   d3
                swap    d3
                dbra    d4,.t
                rts

;=====================================================================
; BOTTOM BAR (like RICK3D's TEXTE.S) : 2 lines of the 6x6 TOS font,
;   white on the darkened picture ; H hides it.
;   line 1 : FPS, 3D by DSP / 030, form, lives, pause
;   line 2 : ship X Y, enemies, bullets, kills, bonus, ground row
;=====================================================================
countfps:
                addq.w  #1,fpscnt
                move.l  $4ba.w,d0               ; 200 Hz clock
                move.l  d0,d1
                sub.l   fpsclk,d1
                cmp.l   #200,d1
                blo.s   .out
                move.l  d0,fpsclk
                move.w  fpscnt,fps
                clr.w   fpscnt
.out:           rts

build_lines:
                lea     linebuf,a0
                move.w  #2*LINEW-1,d0
.sp:            move.b  #' ',(a0)+
                dbra    d0,.sp
                lea     linebuf,a0              ; --- line 1
                tst.w   prof_on                 ; T : the profiler instead
                bne     prof_lines
                lea     t_fps,a1
                bsr     puts
                move.w  fps,d0
                bsr     fmtnum
                bsr     puts
                lea     t_mode,a1
                bsr     puts
                lea     t_m030,a1
                tst.w   d3don
                beq.s   .m
                lea     t_mdsp,a1
.m:             bsr     puts
                tst.w   dspok
                bne.s   .d
                lea     t_nodsp,a1
                bsr     puts
.d:             lea     t_form,a1
                bsr     puts
                move.w  form,d0
                lsl.w   #2,d0
                lea     t_forms,a1
                move.l  (a1,d0.w),a1
                bsr     puts
                lea     t_lives,a1
                bsr     puts
                move.w  lives,d0
                bsr     fmtnum
                bsr     puts
                tst.w   inv
                beq.s   .p
                lea     t_inv,a1
                bsr     puts
.p:             tst.w   paused
                beq.s   .l2
                lea     t_pause,a1
                bsr     puts
.l2:            lea     linebuf+LINEW,a0        ; --- line 2
                lea     t_x,a1
                bsr     puts
                move.w  px,d0
                bsr     fmtsnum
                bsr     puts
                lea     t_y,a1
                bsr     puts
                move.w  py,d0
                bsr     fmtsnum
                bsr     puts
                lea     enemies,a1              ; objects on screen
                moveq   #MAXE-1,d1
                moveq   #0,d0
.ce:            tst.w   (a1)
                beq.s   .ce1
                addq.w  #1,d0
.ce1:           lea     16(a1),a1
                dbra    d1,.ce
                lea     t_en,a1
                bsr     puts1
                lea     bullets,a1
                moveq   #MAXB-1,d1
                moveq   #0,d0
.cb:            tst.w   (a1)
                beq.s   .cb1
                addq.w  #1,d0
.cb1:           addq.l  #8,a1
                dbra    d1,.cb
                lea     t_bul,a1
                bsr     puts1
                move.w  kills,d0
                lea     t_kill,a1
                bsr     puts1
                lea     t_bon,a1
                bsr     puts
                move.b  #'-',d0
                tst.w   bon_act
                beq.s   .b
                move.b  #'*',d0
.b:             move.b  d0,(a0)+
                lea     t_row,a1                ; map row at the top of the screen
                bsr     puts
                move.l  gpos,d0
                divu    #TILE_PX,d0
                bsr     fmtnum
                bsr     puts
                tst.w   map_err
                beq.s   .mo
                lea     t_nomap,a1
                bra     puts
.mo:            rts

; puts1 : label a1 then the number d0
puts1:          move.w  d0,-(sp)
                bsr.s   puts
                move.w  (sp)+,d0
                bsr.s   fmtnum
                jmp   puts

; copies the string a1 (without the final 0) to a0
puts:           move.b  (a1)+,d0
                beq.s   .x
                move.b  d0,(a0)+
                bra.s   puts
.x:             rts

; d0.w -> decimal digits, a1 = start of the string (end = 0)
fmtnum:
                lea     numbuf+8,a1
                clr.b   (a1)
                and.l   #$ffff,d0
.d:             divu    #10,d0
                swap    d0
                add.b   #'0',d0
                move.b  d0,-(a1)
                clr.w   d0
                swap    d0
                tst.w   d0
                bne.s   .d
                rts
; fmtsnum : signed
fmtsnum:
                tst.w   d0
                bpl.s   fmtnum
                neg.w   d0
                bsr.s   fmtnum
                move.b  #'-',-(a1)
                rts

; draw_band : the bar at the bottom of the screen a6 (darkened + text)
draw_band:
                tst.w   txt_hidden
                bne     .out
                movem.l d0-d7/a0-a5,-(sp)
                bsr     build_lines
                move.l  #TXT_Y*LINEB,d0
                lea     (a6,d0.l),a1
                move.l  a1,a5                   ; top of the bar
                move.l  #$7bef7bef,d2
                moveq   #BAND_H-1,d3
.dl:            move.l  a1,a0
                move.w  #SCR_W/2-1,d0
.dk:            move.l  (a0),d1                 ; colour / 2 (2 pixels)
                lsr.l   #1,d1
                and.l   d2,d1
                move.l  d1,(a0)+
                dbra    d0,.dk
                lea     LINEB(a1),a1
                dbra    d3,.dl
                lea     linebuf,a2
                lea     LINEB+2(a5),a4          ; line 1 : y+1, x=1
                bsr.s   .line
                lea     linebuf+LINEW,a2
                lea     8*LINEB+2(a5),a4        ; line 2 : y+8
                bsr.s   .line
                movem.l (sp)+,d0-d7/a0-a5
.out:           rts
.line:          moveq   #COLS-1,d7
.ch:            moveq   #0,d0
                move.b  (a2)+,d0
                cmp.w   #' ',d0
                bls.s   .nc
                sub.w   fontfirst,d0
                bmi.s   .nc
                add.w   d0,d0
                move.l  fontoff,a1
                move.w  (a1,d0.w),d3            ; x of the character (bits)
                move.w  d3,d0
                lsr.w   #3,d0
                move.l  fontdat,a1
                adda.w  d0,a1
                and.w   #7,d3
                move.l  a4,a3
                moveq   #5,d4                   ; 6 lines
.fl:            move.b  (a1),d2
                lsl.w   #8,d2
                move.b  1(a1),d2
                lsl.w   d3,d2
                moveq   #5,d5                   ; 6 pixels : bits 15..10
                move.l  a3,a0
.pb:            add.w   d2,d2
                bcc.s   .p0
                move.w  #$ffff,(a0)
.p0:            addq.l  #2,a0
                dbra    d5,.pb
                lea     LINEB(a3),a3
                adda.w  fontw,a1
                dbra    d4,.fl
.nc:            lea     12(a4),a4               ; next column (6 pixels)
                dbra    d7,.ch
                rts

; (used by DSP3D.S : RICK3D's back view, not here)
bvx_add:        rts

                include 'SOL.S'
                include 'MENU.S'
                include 'CARTE.S'
                include 'COMPOS.S'
                include 'BOSS.S'
                include 'EFFETS.S'
                include 'COUPURE.S'
                include 'SFX.S'
                include 'MUSIQUE.S'
                include 'PROFIL.S'              ; (code)
                include 'DSP3D.S'
                include 'AMIGADSP.S'

;=====================================================================
                section data
                even
ikbd_joy:       dc.b    $14                     ; joystick events
ikbd_mouse:     dc.b    $08                     ; mouse back (relative)
                even
box_mask:       dc.w    15                      ; faces allowed (DSP3D.S)
clip_y0:        dc.w    0
clip_y1:        dc.w    SCR_H-1
seed:           dc.w    $1234
t_d3don:        dc.b    '3D : DSP',0
t_d3doff:       dc.b    '3D : 030',0
t_d3dno:        dc.b    'NO DSP',0
t_fps:          dc.b    'FPS ',0
t_mode:         dc.b    '  3D ',0
t_mdsp:         dc.b    'DSP',0
t_m030:         dc.b    '030',0
t_nodsp:        dc.b    ' (NO DSP)',0
t_form:         dc.b    '  FORM ',0
t_f0:           dc.b    'PROBE',0
t_f1:           dc.b    'FIGHTER',0
t_f2:           dc.b    'HEAVY',0
t_lives:        dc.b    '  LIVES ',0
t_inv:          dc.b    '  INVUL',0
t_pause:        dc.b    '  PAUSE',0
t_x:            dc.b    'X ',0
t_y:            dc.b    ' Y ',0
t_en:           dc.b    '  ENEMIES ',0
t_bul:          dc.b    '  BULLETS ',0
t_kill:         dc.b    '  KILLS ',0
t_bon:          dc.b    '  BONUS ',0
t_row:          dc.b    '  ROW ',0
t_nomap:        dc.b    '  NO LEVEL1.MAP',0
                even
t_forms:        dc.l    t_f0,t_f1,t_f2
                even

; colours : front (top of the object), side, top edge, bottom edge
col_hull:       dc.w    $587F,$2A1A,$3B3C,$18D0
col_cock:       dc.w    $FFE0,$C600,$E700,$8400
col_wing:       dc.w    $C618,$8410,$A514,$630C
col_eng:        dc.w    $FC00,$B260,$D340,$8180
col_red:        dc.w    $F800,$9800,$C000,$6000
col_white:      dc.w    $FFFF,$BDF7,$DEFB,$8410     ; ship (Atari logo)
col_dark:       dc.w    $8410,$4208,$630C,$2104
col_black:      dc.w    $2945,$1082,$18C3,$0841
col_disk:       dc.w    $2A7F,$110F,$19B7,$0868
col_purp:       dc.w    $C01F,$780F,$9013,$480A
col_bon:        dc.w    $FFE0,$C600,$E700,$8400
col_glow:       dc.w    $07FF,$03EF,$05F7,$0210
col_ledg:       dc.w    $07E0,$0320,$04A0,$01E0     ; LED : green
col_ledl:       dc.w    $AFF5,$4E89,$6F8D,$2A85     ;  lit dome
col_pil:        dc.w    $8C51,$528A,$738E,$4208

; models : x0 y0 x1 y1 z0 z1 (z0 = near face, relative to SHIP_Z),
;   colours ; the farthest boxes first ; -99 = end
forms:          dc.l    mdl_f0,mdl_f1,mdl_f2
;   ship = Atari logo (Fuji, like 07ATARI.OBJ of 3Dreams : 55 faces) in 9
;   boxes (scale ~0.7) : centre bar + 2 arms of 4 steps (top narrow, flare at the rear)
mdl_f0:         ; form 0 : all white
                dc.w    -6,-15,-4,-2,2,7
                dc.l    col_white
                dc.w    -8,-2,-4,6,2,7
                dc.l    col_white
                dc.w    -13,6,-7,12,2,7
                dc.l    col_white
                dc.w    -20,10,-13,15,2,7
                dc.l    col_white
                dc.w    4,-15,6,-2,2,7
                dc.l    col_white
                dc.w    4,-2,8,6,2,7
                dc.l    col_white
                dc.w    7,6,13,12,2,7
                dc.l    col_white
                dc.w    13,10,20,15,2,7
                dc.l    col_white
                dc.w    -2,-15,2,15,1,8
                dc.l    col_white
                dc.w    -99
mdl_f1:         ; form 1 : centre white, arms red
                dc.w    -6,-15,-4,-2,2,7
                dc.l    col_red
                dc.w    -8,-2,-4,6,2,7
                dc.l    col_red
                dc.w    -13,6,-7,12,2,7
                dc.l    col_red
                dc.w    -20,10,-13,15,2,7
                dc.l    col_red
                dc.w    4,-15,6,-2,2,7
                dc.l    col_red
                dc.w    4,-2,8,6,2,7
                dc.l    col_red
                dc.w    7,6,13,12,2,7
                dc.l    col_red
                dc.w    13,10,20,15,2,7
                dc.l    col_red
                dc.w    -2,-15,2,15,1,8
                dc.l    col_white
                dc.w    -99
mdl_f2:         ; form 2 : all red
                dc.w    -6,-15,-4,-2,2,7
                dc.l    col_red
                dc.w    -8,-2,-4,6,2,7
                dc.l    col_red
                dc.w    -13,6,-7,12,2,7
                dc.l    col_red
                dc.w    -20,10,-13,15,2,7
                dc.l    col_red
                dc.w    4,-15,6,-2,2,7
                dc.l    col_red
                dc.w    4,-2,8,6,2,7
                dc.l    col_red
                dc.w    7,6,13,12,2,7
                dc.l    col_red
                dc.w    13,10,20,15,2,7
                dc.l    col_red
                dc.w    -2,-15,2,15,1,8
                dc.l    col_red
                dc.w    -99
mdl_en0:                                        ; enemy 1 = green LED (5 mm)
                dc.w    -6,-6,6,6,6,14
                dc.l    col_ledg                ;  body
                dc.w    -4,-4,4,4,3,6
                dc.l    col_ledl                ;  dome (lit)
                dc.w    -1,-1,1,1,2,3
                dc.l    col_white               ;  (light spot)
                dc.w    -10,-1,-6,1,12,14
                dc.l    col_wing                ;  legs
                dc.w    6,-1,10,1,12,14
                dc.l    col_wing
                dc.w    -99
mdl_en2:                                        ; enemy 2 = blue capacitor
                dc.w    -7,-7,7,7,5,16
                dc.l    col_disk                ;  can
                dc.w    -5,-5,5,5,4,5
                dc.l    col_wing                ;  aluminium top
                dc.w    -1,-5,1,5,3,4
                dc.l    col_dark                ;  (vent cross)
                dc.w    -5,-1,5,1,3,4
                dc.l    col_dark
                dc.w    -7,-7,-4,7,4,6
                dc.l    col_white               ;  (- stripe)
                dc.w    -99
mdl_en1:                                        ; enemy 3 = TO-92 transistor
                dc.w    -7,-6,7,3,5,14
                dc.l    col_black               ;  body (flat side down)
                dc.w    -5,-4,5,1,4,5
                dc.l    col_dark                ;  (marking)
                dc.w    -6,3,-4,11,11,13
                dc.l    col_wing                ;  3 legs
                dc.w    -1,3,1,11,11,13
                dc.l    col_wing
                dc.w    4,3,6,11,11,13
                dc.l    col_wing
                dc.w    -99
mdl_bonus:                                      ; bonus pod : evolution
                dc.w    -6,-6,6,6,6,16
                dc.l    col_bon
                dc.w    -3,-3,3,3,2,6
                dc.l    col_glow
                dc.w    -99

font:           dc.b    7,5,5,5,7, 2,6,2,2,7, 7,1,7,4,7, 7,1,3,1,7
                dc.b    5,5,7,1,1, 7,4,7,1,7, 7,4,7,5,7, 7,1,1,2,2
                dc.b    7,5,7,5,7, 7,5,7,1,7
                even

;=====================================================================
                section data
t_dsp:          dc.b    'DSP',0
t_030:          dc.b    '030',0
t_rec:          dc.b    'REC',0
t_paus2:        dc.b    'PAUSE',0
t_fps2:         dc.b    'FPS',0
t_lvls:         dc.b    '800 XL',0,0            ; level names (8 bytes each)
                dc.b    '520 ST',0,0
                dc.b    'STE',0,0,0,0,0
                dc.b    'F030',0,0,0,0
                even
                even
                section bss
                even
oldssp:         ds.l    1
oldphys:        ds.l    1
oldlog:         ds.l    1
oldmode:        ds.w    1
vmode:          ds.w    1
scr_show:       ds.l    1                       ; picture shown (SOL.S)
cur_bf:         ds.l    1                       ; screen being drawn
cur_b0:         ds.w    1                       ; its 1st line in the tall buffer
gbuf:           ds.l    1                       ; clean ground
g_last:         ds.l    1
bufd0:          ds.b    BF_SZ
bufd1:          ds.b    BF_SZ
                even
blackscr:       ds.b    SCR_W*2*SCR_H           ; black picture (loading)
old118:         ds.l    1
joy1:           ds.w    1
joyin:          ds.w    1
pk_cnt:         ds.w    1
pk_type:        ds.w    1
keymap:         ds.b    128
keyhit:         ds.b    128
pr_bar:         ds.w    1
isvga:          ds.w    1                       ; VGA monitor                       ; (bottom bar before the capture)
quit:           ds.w    1
paused:         ds.w    1
dspok:          ds.w    1
pr_dsp:         ds.l    1                       ; (DSP3D.S : DSP waits)
view_back:      ds.w    1                       ; (DSP3D.S : always 0 here)
bv_nofront:     ds.w    1
bv_nf2:         ds.w    1
bvx_on:         ds.w    1
bb_x0:          ds.w    1                       ; (DSP3D.S : drawn box)
bb_y0:          ds.w    1
bb_x1:          ds.w    1
bb_y1:          ds.w    1
msg_ptr:        ds.l    1
msg_t:          ds.w    1

score:          ds.l    1
lives:          ds.w    1
form:           ds.w    1
px:             ds.w    1
py:             ds.w    1
inv:            ds.w    1
firet:          ds.w    1
kills:          ds.w    1
gover:          ds.w    1
gover_end:      ds.w    1
lvl_done:       ds.w    1
cur_level:      ds.w    1
camx:           ds.w    1                       ; camera : column of the screen
cur_camx:       ds.w    1
wavet:          ds.w    1
scr_acc:        ds.w    1                       ; scroll : 1/256 pixel left
bon_act:        ds.w    1
bon_x:          ds.w    1
bon_y:          ds.w    1
gpos:           ds.l    1
mdl_z:          ds.w    1
gsteps:         ds.w    1                       ; game steps per picture
lastflip:       ds.l    1                       ; VBL of the last picture
fps:            ds.w    1
fpscnt:         ds.w    1
fpsclk:         ds.l    1
txt_hidden:     ds.w    1
fontfirst:      ds.w    1
fontw:          ds.w    1
fontoff:        ds.l    1
fontdat:        ds.l    1
numbuf:         ds.b    10
linebuf:        ds.b    2*LINEW
                even
digbuf:         ds.b    6
                even
bullets:        ds.w    MAXB*4                  ; act x y dx
enemies:        ds.w    MAXE*8                  ; act x y type hp t x0 -
tallmem:        ds.b    3*TALLSZ+256            ; G, D0, D1
