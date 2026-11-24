;=====================================================================
; SFX.S - SOUND EFFECTS ON THE YM2149 (PSG) (included by XVOLUTION.S)
;
; 3 channels : A = shots of the ship, B = explosions / ship hit,
; C = bonus, boss (alarm, hits, its shots, "recapped" tune).
; An effect = a few numbers (table sfx_tab) : priority, length (game
; frames), period of the tone and its change per frame (or a list of
; notes : arpeggio), volume x16 and its decay, noise. sfx_update writes
; the YM registers once per game frame (30 / s), interrupts off around
; each register (TOS also uses the YM port A : floppy, printer).
; Use : SFX n (macro, all registers kept).
;=====================================================================
                section text

; (macro SFX and the effect numbers : PARAMS.S)

; effect record (words) and channel state (words)
FX_CH           equ     0               ; channel 0..2
FX_PRIO         equ     2
FX_DUR          equ     4               ; frames
FX_PER          equ     6               ; tone period (YM : 125000 / f)
FX_DPER         equ     8               ; + per frame
FX_VOL          equ     10              ; volume x16 (15*16 = loudest)
FX_DVOL         equ     12              ; - per frame
FX_NOISE        equ     14              ; 0 tone, 1 tone + noise, 2 noise only
FX_NPER         equ     16              ; noise period (0..31)
FX_DNPER        equ     18
FX_ARPN         equ     20              ; frames per note of the list (0 = none)
FX_ARP          equ     22              ; .l : list of periods, 0 = end (loops)
FX_LEN          equ     26

CH_DUR          equ     0
CH_PRIO         equ     2
CH_PER          equ     4
CH_DPER         equ     6
CH_VOL          equ     8
CH_DVOL         equ     10
CH_NOISE        equ     12
CH_NPER         equ     14
CH_DNPER        equ     16
CH_ARPN         equ     18
CH_ARPC         equ     20              ; frames left on this note
CH_ARP0         equ     22              ; .l list start
CH_ARPP         equ     26              ; .l next note
CH_LEN          equ     30

; ym_set : register d1 = value d2 (interrupts off)
ym_set:
                move.w  sr,-(sp)
                or.w    #$0700,sr
                move.b  d1,$ffff8800.w
                move.b  d2,$ffff8802.w
                move.w  (sp)+,sr
                rts

; sfx_init : save the sound matrix, PSG to the output, silence
sfx_init:
                movem.l d0-d2/a0-a2,-(sp)
                move.w  #-1,-(sp)               ; Soundcmd(ADDERIN,-1) : saved
                move.w  #4,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                move.w  d0,old_adder
                move.w  #-1,-(sp)               ; Soundcmd(ADCINPUT,-1)
                move.w  #5,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                move.w  d0,old_adcin
                move.w  #3,-(sp)                ; ADC input = PSG (left + right)
                move.w  #5,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                move.w  #3,-(sp)                ; adder = ADC + matrix
                move.w  #4,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                move.w  #-1,-(sp)               ; Soundcmd(LTGAIN / RTGAIN,-1) : saved
                move.w  #2,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                move.w  d0,old_lgain
                move.w  #-1,-(sp)
                move.w  #3,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                move.w  d0,old_rgain
                move.w  #SFX_GAIN<<4,-(sp)      ; YM (ADC input) gain : effects louder
                move.w  #2,-(sp)                ;  than the music
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                move.w  #SFX_GAIN<<4,-(sp)
                move.w  #3,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                movem.l (sp)+,d0-d2/a0-a2
                bsr     sfx_off
                rts

; sfx_route : PSG in the output again (the DSP music sets the matrix)
sfx_route:
                movem.l d0-d2/a0-a2,-(sp)
                move.w  #3,-(sp)                ; ADC input = PSG (left + right)
                move.w  #5,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                move.w  #3,-(sp)                ; adder = ADC + matrix
                move.w  #4,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                movem.l (sp)+,d0-d2/a0-a2
                rts

; sfx_exit : silence, sound matrix back
sfx_exit:
                movem.l d0-d2/a0-a2,-(sp)
                bsr     sfx_off
                move.w  old_adcin,-(sp)
                move.w  #5,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                move.w  old_adder,-(sp)
                move.w  #4,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                move.w  old_lgain,-(sp)         ; gains back
                move.w  #2,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                move.w  old_rgain,-(sp)
                move.w  #3,-(sp)
                move.w  #130,-(sp)
                trap    #14
                addq.l  #6,sp
                movem.l (sp)+,d0-d2/a0-a2
                rts

; sfx_off : the 3 channels stop (menu, pause, game exit)
sfx_off:
                movem.l d0-d2/a0,-(sp)
                lea     sfx_ch,a0
                move.w  #3*CH_LEN/2-1,d0
.c:             clr.w   (a0)+
                dbra    d0,.c
                moveq   #8,d1                   ; volumes 0
                moveq   #0,d2
                bsr     ym_set
                moveq   #9,d1
                bsr     ym_set
                moveq   #10,d1
                bsr     ym_set
                bsr     ym_mixer_off
                movem.l (sp)+,d0-d2/a0
                rts

; ym_mixer_off : tones and noises off (port bits 6-7 kept)
ym_mixer_off:
                move.w  sr,-(sp)
                or.w    #$0700,sr
                move.b  #7,$ffff8800.w
                move.b  $ffff8800.w,d2
                and.b   #$c0,d2
                or.b    #$3f,d2
                move.b  d2,$ffff8802.w
                move.w  (sp)+,sr
                rts

; sfx_play : effect d0 (if its channel is free or less important)
sfx_play:
                movem.l d0-d1/a0-a1,-(sp)
                mulu    #FX_LEN,d0
                lea     sfx_tab,a0
                adda.l  d0,a0
                move.w  FX_CH(a0),d0
                mulu    #CH_LEN,d0
                lea     sfx_ch,a1
                adda.l  d0,a1
                tst.w   CH_DUR(a1)
                beq.s   .ok
                move.w  FX_PRIO(a0),d1
                cmp.w   CH_PRIO(a1),d1
                blt.s   .x
.ok:            move.w  FX_DUR(a0),CH_DUR(a1)
                move.w  FX_PRIO(a0),CH_PRIO(a1)
                move.w  FX_PER(a0),CH_PER(a1)
                move.w  FX_DPER(a0),CH_DPER(a1)
                move.w  FX_VOL(a0),CH_VOL(a1)
                move.w  FX_DVOL(a0),CH_DVOL(a1)
                move.w  FX_NOISE(a0),CH_NOISE(a1)
                move.w  FX_NPER(a0),CH_NPER(a1)
                move.w  FX_DNPER(a0),CH_DNPER(a1)
                move.w  FX_ARPN(a0),CH_ARPN(a1)
                clr.w   CH_ARPC(a1)
                move.l  FX_ARP(a0),CH_ARP0(a1)
                move.l  FX_ARP(a0),CH_ARPP(a1)
.x:             movem.l (sp)+,d0-d1/a0-a1
                rts

; sfx_update : one game frame of the 3 channels -> YM registers
sfx_update:
                movem.l d0-d7/a0-a1,-(sp)
                moveq   #$3f,d6                 ; mixer : all off (1 = off)
                lea     sfx_ch,a0
                moveq   #0,d7                   ; channel
.ch:            tst.w   CH_DUR(a0)
                beq     .off
                subq.w  #1,CH_DUR(a0)
                move.w  CH_PER(a0),d3           ; --- period
                tst.w   CH_ARPN(a0)
                beq.s   .np
                subq.w  #1,CH_ARPC(a0)          ; arpeggio : next note ?
                bpl.s   .an
                move.w  CH_ARPN(a0),CH_ARPC(a0)
                subq.w  #1,CH_ARPC(a0)
                move.l  CH_ARPP(a0),a1
                move.w  (a1)+,d0
                bne.s   .a1
                move.l  CH_ARP0(a0),a1          ;  (end : again)
                move.w  (a1)+,d0
.a1:            move.l  a1,CH_ARPP(a0)
                move.w  d0,CH_PER(a0)
.an:            move.w  CH_PER(a0),d3
                bra.s   .pw
.np:            move.w  CH_DPER(a0),d0
                add.w   d0,CH_PER(a0)
.pw:            and.w   #$0fff,d3
                move.w  d7,d1                   ; regs 2c (fine), 2c+1 (coarse)
                add.w   d1,d1
                move.w  d3,d2
                bsr     ym_set
                addq.w  #1,d1
                lsr.w   #8,d2
                bsr     ym_set
                move.w  CH_VOL(a0),d2           ; --- volume
                bpl.s   .v0
                moveq   #0,d2
.v0:            lsr.w   #4,d2
                cmp.w   #15,d2
                ble.s   .v1
                moveq   #15,d2
.v1:            moveq   #8,d1
                add.w   d7,d1
                bsr     ym_set
                move.w  CH_DVOL(a0),d0
                sub.w   d0,CH_VOL(a0)
                move.w  CH_NOISE(a0),d0         ; --- mixer bits
                cmp.w   #2,d0
                beq.s   .nt
                bclr    d7,d6                   ; tone on
.nt:            tst.w   d0
                beq.s   .nx
                move.w  d7,d1
                addq.w  #3,d1
                bclr    d1,d6                   ; noise on
                moveq   #6,d1                   ; noise period (shared)
                move.w  CH_NPER(a0),d2
                and.w   #31,d2
                bsr     ym_set
                move.w  CH_DNPER(a0),d0
                add.w   d0,CH_NPER(a0)
.nx:            bra.s   .nc
.off:           moveq   #8,d1                   ; silent channel
                add.w   d7,d1
                moveq   #0,d2
                bsr     ym_set
.nc:            lea     CH_LEN(a0),a0
                addq.w  #1,d7
                cmp.w   #3,d7
                blt     .ch
                move.w  sr,-(sp)                ; mixer (port bits 6-7 kept)
                or.w    #$0700,sr
                move.b  #7,$ffff8800.w
                move.b  $ffff8800.w,d2
                and.b   #$c0,d2
                or.b    d6,d2
                move.b  d2,$ffff8802.w
                move.w  (sp)+,sr
                movem.l (sp)+,d0-d7/a0-a1
                rts

;---------------------------------------------------------------------
                section data
; ch prio dur per dper vol dvol noise nper dnper arpn arp.l
sfx_tab:
                dc.w    0,1, 5,  90,30,  12*16,36, 0, 0,0, 0       ; SHOT : short "pew"
                dc.l    0
                dc.w    1,2, 14, 0,0,    15*16,17, 2, 6,2, 0       ; BOOM : noise burst
                dc.l    0
                dc.w    1,3, 20, 1800,40, 15*16,12, 1, 20,1, 0     ; HIT : low growl + noise
                dc.l    0
                dc.w    2,2, 12, 0,0,    13*16,8,  0, 0,0, 2       ; BONUS : rising notes
                dc.l    arp_bonus
                dc.w    2,3, 40, 0,0,    12*16,0,  0, 0,0, 5       ; ALARM : boss arrives
                dc.l    arp_alarm
                dc.w    2,1, 2,  60,0,   9*16,32,  0, 0,0, 0       ; BHIT : tick on the chip
                dc.l    0
                dc.w    2,1, 4,  420,40, 9*16,30,  0, 0,0, 0       ; BSHOT : boss shot
                dc.l    0
                dc.w    2,4, 28, 0,0,    14*16,4,  0, 0,0, 4       ; FIXED : happy tune
                dc.l    arp_fixed

; periods (YM clock 2 MHz / 16 : period = 125000 / Hz)
arp_bonus:      dc.w    239,190,159,119,95,80,0                 ; C5 E5 G5 C6 E6 G6
arp_alarm:      dc.w    284,213,0                               ; A4 / D5 siren
arp_fixed:      dc.w    239,190,159,119,159,119,95,0            ; C E G C' G C' E'
                even

                section bss
sfx_ch:         ds.b    3*CH_LEN
old_adder:      ds.w    1
old_adcin:      ds.w    1
old_lgain:      ds.w    1
old_rgain:      ds.w    1
                even
                section text

;---------------------------------------------------------------------
; VOLUME (like 3Dreams) : + / - keys, 0 .. 64 by steps of 4 (VOL_START at
;   the start) : in game the music only (sound effects always at full
;   level), at the menu the YM tune (see vol_apply).
;   The + and - keys are found in the keyboard tables (Keytbl) : any
;   layout, main keys and keypad.
                section text
vol_init:
                movem.l d0-d2/a0-a2,-(sp)
                move.w  $ffff893a.w,vol_old
                move.w  #VOL_START,vol_lev
                lea     vol_kup,a1              ; keypad + and -
                move.b  #$4E,(a1)+
                lea     vol_kdn,a2
                move.b  #$4A,(a2)+
                move.l  #-1,-(sp)               ; Keytbl(-1,-1,-1)
                move.l  #-1,-(sp)
                move.l  #-1,-(sp)
                move.w  #16,-(sp)
                trap    #14
                lea     14(sp),sp
                move.l  d0,a0
                moveq   #1,d2                   ; unshifted, shifted tables
.t:             move.l  (a0)+,-(sp)
                movem.l a0,-(sp)
                move.l  4(sp),a0
                moveq   #0,d0
.k:             cmp.w   #$4A,d0                 ; (keypad : already there)
                beq.s   .n
                cmp.w   #$4E,d0
                beq.s   .n
                move.b  (a0,d0.w),d1
                cmp.b   #'+',d1
                bne.s   .m
                cmp.l   #vol_kup+3,a1
                bhs.s   .n
                move.b  d0,(a1)+
                bra.s   .n
.m:             cmp.b   #'-',d1
                bne.s   .n
                cmp.l   #vol_kdn+3,a2
                bhs.s   .n
                move.b  d0,(a2)+
.n:             addq.w  #1,d0
                cmp.w   #128,d0
                blt.s   .k
                movem.l (sp)+,a0
                addq.l  #4,sp
                dbra    d2,.t
                bsr     vol_apply
                movem.l (sp)+,d0-d2/a0-a2
                rts

vol_exit:
                move.w  vol_old,$ffff893a.w
                rts

; vol_keys : a0 = keyhit ; + / - pressed : level up / down (all kept)
vol_keys:
                movem.l d0-d1/a1,-(sp)
                lea     vol_kup,a1
.u:             move.b  (a1)+,d0
                beq.s   .d
                and.w   #$7F,d0
                tst.b   (a0,d0.w)
                beq.s   .u
                move.w  vol_lev,d0
                cmp.w   #64,d0
                bhs.s   .d
                addq.w  #4,d0
                cmp.w   #64,d0
                bls.s   .u1
                moveq   #64,d0
.u1:            move.w  d0,vol_lev
                bra.s   .a
.d:             lea     vol_kdn,a1
.d1:            move.b  (a1)+,d0
                beq.s   .x
                and.w   #$7F,d0
                tst.b   (a0,d0.w)
                beq.s   .d1
                move.w  vol_lev,d0
                beq.s   .x
                subq.w  #4,d0
                bpl.s   .d2
                moveq   #0,d0
.d2:            move.w  d0,vol_lev
.a:             bsr     vol_apply
                move.w  #VOL_T,vol_show         ; (shown in the HUD for a while)
.x:             movem.l (sp)+,d0-d1/a1
                rts

; vol_apply : in game the sound effects are always at full level (codec
;   0 dB, YM input gain SFX_GAIN) and + / - set the music only (MGTK master
;   volume = MUS_VOL * volume / 64) ; at the menu (vol_inmenu) : the YM
;   tune, codec attenuation (64 - volume) / 4.
vol_apply:
                movem.l d0-d1,-(sp)
                moveq   #0,d0                   ; in game : codec 0 dB
                tst.b   vol_inmenu
                beq.s   .a
                moveq   #64,d0
                sub.w   vol_lev,d0
                lsr.w   #2,d0
                cmp.w   #15,d0
                bls.s   .a
                moveq   #15,d0
.a:             move.w  d0,d1
                lsl.w   #4,d0                   ; right : bits 7-4
                lsl.w   #8,d1                   ; left : bits 11-8
                or.w    d1,d0
                move.w  $ffff893a.w,d1
                and.w   #$f00f,d1
                or.w    d0,d1
                move.w  d1,$ffff893a.w
                move.w  #MUS_VOL*1023,d0        ; module : MUS_VOL * volume / 64
                mulu    vol_lev,d0
                lsr.l   #6,d0
                move.w  d0,MGTK_Master_Volume_Left
                move.w  d0,MGTK_Master_Volume_Right
                movem.l (sp)+,d0-d1
                rts

                section bss
vol_lev:        ds.w    1
vol_old:        ds.w    1
vol_show:       ds.w    1
vol_inmenu:     ds.b    1                       ; menu : the volume acts on the YM tune
vol_kup:        ds.b    4                       ; scan codes of + (0 : end)
vol_kdn:        ds.b    4                       ;  and of -
                even
                section text
