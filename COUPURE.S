;=====================================================================
; COUPURE.S - SPLIT SCREEN (included by XVOLUTION.S, settings in PARAMS.S)
;   The top band (score, lives, FPS ...) is read by the VIDEL from its own
;   memory (bandb0 / bandb1, one per screen) : it never moves, whatever the
;   scroll and the camera do. At each VBL (VBL queue) :
;     video base = the band buffer, written straight into the VIDEL
;     ($FFFF8201/03/0D : the exact address, also the low byte) ;
;     Timer B (MFP, event count = lines shown) counts SPLIT lines ;
;   then the Timer B interrupt writes the video counter ($FFFF8205/07/09)
;   = picture of the board from its line TOP_H : the rest of the screen
;   comes from the scrolled buffer.
;   Without the split (key C, or cut_on = 0) : the base is written the
;   same way (exact address) and the band is drawn into the picture.
;   NOTE : Hatari draws a Falcon screen from the base address only (no
;   change in the middle of the screen) : there, press C to see the game.
;=====================================================================
                section text

; cut_install : vectors and MFP Timer B kept, our VBL routine queued
cut_install:
                movem.l d0/a0,-(sp)
                move.l  $120.w,cut_oldvec
                move.b  $fffffa1b.w,cut_oldcr   ; TBCR
                move.b  $fffffa21.w,cut_olddr   ; TBDR
                move.b  $fffffa07.w,cut_oldie   ; IERA (bit 0 = Timer B)
                move.b  $fffffa13.w,cut_oldim   ; IMRA
                clr.b   $fffffa1b.w             ; Timer B stopped
                move.l  #cut_timerb,$120.w
                bset    #0,$fffffa07.w
                bset    #0,$fffffa13.w
                moveq   #CUT_LPL,d0             ; Timer B : lines counted for the
                tst.w   isvga                   ;  band (VGA : every line twice)
                bne.s   .v
                moveq   #1,d0
.v:             mulu    #TOP_H,d0
                move.w  d0,cut_n
                move.w  #CUT_DEF,cut_on
                clr.w   cut_act
                move.w  sr,-(sp)                ; own VBL vector ($70) : the split is
                or.w    #$0700,sr               ;  set FIRST, before the TOS VBL
                move.l  $70.w,cut_oldvbl        ;  work (the VBL queue ran 33-43
                move.l  #cut_vbl70,$70.w        ;  lines too late on the Falcon)
                move.w  (sp)+,sr
                movem.l (sp)+,d0/a0
                rts

cut_remove:
                move.l  a0,-(sp)
                clr.w   cut_act
                move.l  cut_oldvbl,d0
                beq.s   .n
                move.l  d0,$70.w
                clr.l   cut_oldvbl
.n:             clr.b   $fffffa1b.w
                move.l  cut_oldvec,$120.w
                move.b  cut_olddr,$fffffa21.w
                bclr    #0,$fffffa07.w
                btst    #0,cut_oldie
                beq.s   .e
                bset    #0,$fffffa07.w
.e:             bclr    #0,$fffffa13.w
                btst    #0,cut_oldim
                beq.s   .m
                bset    #0,$fffffa13.w
.m:             move.b  cut_oldcr,$fffffa1b.w
                move.l  (sp)+,a0
                rts

; cut_show : the main loop gives the next picture (a6 = scr_show = top-left
;   of the board picture, a0 = band buffer) ; taken at the next VBL
cut_show:
                move.w  sr,-(sp)
                or.w    #$0700,sr
                move.l  scr_show,cut_pf
                move.l  cut_bnew,cut_band
                move.w  (sp)+,sr
                rts

; cut_vbl70 : VBL vector : split set at once, then the old VBL routine
cut_vbl70:
                bsr.s   cut_vbl
                move.l  cut_oldvbl,-(sp)
                rts

; cut_vbl : at the start of the VBL (supervisor)
cut_vbl:
                tst.w   cut_act
                beq.s   .x
                clr.b   $fffffa1b.w             ; Timer B stopped
                tst.w   cut_on
                bne.s   .c
                move.b  cut_pf+1,$ffff8201.w    ; no split : base = the picture
                move.b  cut_pf+2,$ffff8203.w    ;  (high, middle : they clear
                move.b  cut_pf+3,$ffff820d.w    ;  the low byte, then low)
.x:             rts
.c:             move.l  d0,-(sp)
                move.l  cut_pf,d0               ; after the band : the picture
                add.l   #TOP_H*LINEB,d0         ;  from its line TOP_H
                move.l  d0,cut_pfl
                move.l  cut_band,cut_bv         ; band shown in this frame (kept :
                move.l  (sp)+,d0                ;  cut_show can change cut_band)
                move.b  cut_band+1,$ffff8201.w  ; base = the band buffer
                move.b  cut_band+2,$ffff8203.w
                move.b  cut_band+3,$ffff820d.w
                move.b  cut_n+1,$fffffa21.w     ; TBDR : lines of the band
                move.b  #8,$fffffa1b.w          ; TBCR : event count mode
                rts

; cut_timerb : end of the band : the VIDEL now reads the board picture.
;   The interrupt can come a few lines late (other interrupts, masked
;   code) : the video counter is read and the picture goes on at the SAME
;   offset in the board picture (offset = counter - band base). So a late
;   interrupt never moves the picture : the band is only a few lines
;   taller (its buffer has CUT_MARG black lines more).
cut_timerb:
                movem.l d0/d1,-(sp)
.rd:            moveq   #0,d0
                move.b  $ffff8205.w,d0          ; counter (read until 2 reads
                swap    d0                      ;  give the same value)
                move.b  $ffff8207.w,d1
                lsl.w   #8,d1
                move.b  $ffff8209.w,d1
                move.w  d1,d0
                moveq   #0,d1
                move.b  $ffff8205.w,d1
                swap    d1
                move.b  $ffff8207.w,d1
                lsl.w   #8,d1
                move.b  $ffff8209.w,d1
                cmp.l   d0,d1
                bne.s   .rd
                sub.l   cut_bv,d0               ; offset in the band buffer
                bmi.s   .def
                cmp.l   #(TOP_H+CUT_MARG)*LINEB,d0
                bhs.s   .def
                move.l  d0,d1                   ; (test : lines late, max kept)
                divu    #LINEB,d1
                sub.w   #TOP_H,d1
                cmp.w   cut_lmax,d1
                ble.s   .lm
                move.w  d1,cut_lmax
.lm:            add.l   cut_pfl,d0              ; same offset in the picture
                sub.l   #TOP_H*LINEB,d0         ;  (shown in this frame)
                bra.s   .w
.def:           move.w  #99,cut_lmax            ; (test : counter out of range)
                move.l  cut_pfl,d0
.w:             swap    d0
                move.b  d0,$ffff8205.w          ; video counter : high, middle, low
                swap    d0
                move.w  d0,d1
                lsr.w   #8,d1
                move.b  d1,$ffff8207.w
                move.b  d0,$ffff8209.w
                clr.b   $fffffa1b.w             ; Timer B stopped (once per frame)
                movem.l (sp)+,d0/d1
                bclr    #0,$fffffa0f.w          ; ISRA : end of the interrupt
                rte

                section bss
cut_oldvec:     ds.l    1
cut_slot:       ds.l    1
cut_oldvbl:     ds.l    1                       ; TOS VBL vector
cut_pf:         ds.l    1                       ; picture (top-left) shown
cut_pfl:        ds.l    1                       ;  its line TOP_H
cut_band:       ds.l    1                       ; band buffer shown
cut_bv:         ds.l    1                       ; band of this frame (Timer B)
cut_bnew:       ds.l    1                       ; band buffer drawn this frame
cut_lmax:       ds.w    1                       ; test : max lines late (99 = bad)
cut_lshow:      ds.w    1                       ;  shown in the band
cut_n:          ds.w    1                       ; Timer B count
cut_on:         ds.w    1                       ; split wanted (key C)
cut_act:        ds.w    1                       ; in game (VBL routine works)
cut_new:        ds.b    1
cut_oldcr:      ds.b    1
cut_olddr:      ds.b    1
cut_oldie:      ds.b    1
cut_oldim:      ds.b    1
                even
bandb0:         ds.b    (TOP_H+CUT_MARG)*LINEB             ; the 2 band buffers (one per
bandb1:         ds.b    (TOP_H+CUT_MARG)*LINEB             ;  screen)
                even
                section text
