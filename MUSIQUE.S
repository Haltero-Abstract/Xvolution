;=====================================================================
; MUSIQUE.S - MUSIC (included by XVOLUTION.S)
;   In the levels : a module ZIK\ELYSIUM.MOD played by the DSP (Simplet's
;   replay AMIGADSP.S, loaded with R3D by d3dinit, like RICK3D's
;   MUSIQUE.S) ; the YM stays free for the sound effects (SFX.S).
;   In the menu : the YM tune ZIK\PWRBOAT.ORG = a COSO block by Jochen
;   Hippel (Mad Max) as dumped from memory : player + music of the Power
;   Boat intro (same file as in 3Dreams) : +0 init (d0 = 1 : tune 1,
;   d0 = 0 : stop), +8 play at 50 Hz, called from the VBL queue. It was written for the ST : it writes the YM with
;   movem.l to $FFFF8800 / $FFFF8840 (shadow registers, absent on the
;   Falcon : bus error) -> those 2 places are patched to jump to ymw4 /
;   ymw11 which write the same register / value pairs one by one.
;   No DSP or no file : no music, the game goes on.
;=====================================================================
                section text

; mus_init : (after d3dinit) DSP sound set up, module loaded ; YM tune loaded
mus_init:
                movem.l d0-d7/a0-a6,-(sp)
                clr.w   musok
                clr.w   mus_on
                tst.w   dspok
                beq.s   .ym
                bsr     MGTK_Save_Sound
                bsr     MGTK_Init_Sound         ; matrix : DSP -> DAC
                moveq   #REPFREQ,d0
                bsr     MGTK_Set_Replay_Frequency
                st      MGTK_Restart_Loop       ; end of the module : again
                move.w  #1,mus_saved
                lea     mod_name,a0
                bsr     mus_load
.ym:            bsr     ymz_load
                movem.l (sp)+,d0-d7/a0-a6
                rts

; mus_exit : sound system back (end of the program)
mus_exit:
                movem.l d0-d7/a0-a6,-(sp)
                bsr     ymz_stop
                bsr     mus_stop
                tst.w   mus_saved
                beq.s   .x
                bsr     MGTK_Restore_Sound
.x:             movem.l (sp)+,d0-d7/a0-a6
                rts

; mus_play : the module plays (start of a level ; already playing : nothing)
mus_play:
                tst.w   musok
                beq.s   .x
                tst.w   mus_on
                bne.s   .x
                movem.l d0-d7/a0-a6,-(sp)
                sf      MGTK_Restart_Done
                bsr     MGTK_Play_Music         ; Timer A
                move.w  #MUS_VOL*1023,MGTK_Master_Volume_Left
                move.w  #MUS_VOL*1023,MGTK_Master_Volume_Right
                movem.l (sp)+,d0-d7/a0-a6
                move.w  #1,mus_on
                bsr     sfx_route               ; (YM still in the output)
.x:             rts

; mus_stop : the module stops (menu)
mus_stop:
                tst.w   mus_on
                beq.s   .x
                movem.l d0-d7/a0-a6,-(sp)
                bsr     MGTK_Stop_Music
                movem.l (sp)+,d0-d7/a0-a6
                clr.w   mus_on
.x:             rts

; mus_load : file a0 -> Mxalloc'ed memory, MGTK_Init_Module_Samples
mus_load:
                move.l  a0,mus_path
                clr.w   -(sp)                   ; Fopen
                move.l  a0,-(sp)
                move.w  #$3d,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi     .out
                move.w  d0,mus_fh
                move.w  #2,-(sp)                ; Fseek end -> size
                move.w  mus_fh,-(sp)
                clr.l   -(sp)
                move.w  #$42,-(sp)
                trap    #1
                lea     10(sp),sp
                move.l  d0,mod_len
                clr.w   -(sp)                   ; Fseek start
                move.w  mus_fh,-(sp)
                clr.l   -(sp)
                move.w  #$42,-(sp)
                trap    #1
                lea     10(sp),sp
                cmp.l   #2048,mod_len
                blo     .close
                move.w  #3,-(sp)                ; Mxalloc (any RAM) module + work
                move.l  mod_len,d0
                add.l   #WORKSZ+16,d0
                move.l  d0,-(sp)
                move.w  #$44,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                ble     .close
                move.l  d0,mod_base
                move.l  mod_base,-(sp)          ; Fread
                move.l  mod_len,-(sp)
                move.w  mus_fh,-(sp)
                move.w  #$3f,-(sp)
                trap    #1
                lea     12(sp),sp
                cmp.l   mod_len,d0
                bne.s   .close
                move.l  mod_base,a0
                move.l  mod_len,d0
                addq.l  #1,d0
                and.b   #$fe,d0
                add.l   #WORKSZ,d0
                move.l  a0,a1
                adda.l  d0,a1                   ; end of the work area
                bsr     MGTK_Init_Module_Samples
                tst.w   d0
                bmi.s   .close
                move.w  #1,musok
.close:         move.w  mus_fh,-(sp)            ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
.out:           rts

;---------------------------------------------------------------------
; YM TUNE OF THE MENU

; ymz_load : ZIK\PWRBOAT.ORG -> ymz_buf, the 2 movem writes patched
ymz_load:
                clr.w   ymz_ok
                clr.w   -(sp)                   ; Fopen
                pea     ymz_name
                move.w  #$3d,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi     .x
                move.w  d0,d7
                pea     ymz_buf                 ; Fread (YMZ_MAX bytes max)
                move.l  #YMZ_MAX,-(sp)
                move.w  d7,-(sp)
                move.w  #$3f,-(sp)
                trap    #1
                lea     12(sp),sp
                move.l  d0,d6
                move.w  d7,-(sp)                ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
                cmp.l   #$230,d6                ; (too short : not this tune)
                blt.s   .x
                lea     ymz_buf,a0
                cmp.l   #$48f8000f,$15c(a0)     ; movem.l d0-d3,$ffff8800.w
                bne.s   .p2
                cmp.w   #$8800,$160(a0)
                bne.s   .p2
                move.w  #$4ef9,$15c(a0)         ; -> jmp ymw4
                move.l  #ymw4,$15e(a0)
.p2:            cmp.l   #$48f807ff,$222(a0)     ; movem.l d0-a2,$ffff8840.w
                bne.s   .ok
                cmp.w   #$8840,$226(a0)
                bne.s   .ok
                move.w  #$4ef9,$222(a0)         ; -> jmp ymw11
                move.l  #ymw11,$224(a0)
.ok:            move.w  #1,ymz_ok
.x:             rts

; ymz_start : the YM tune starts (menu) ; ymz_stop : stops, YM silent
ymz_start:
                tst.w   ymz_ok
                beq.s   .x
                tst.w   ymz_on
                bne.s   .x
                movem.l d0-d7/a0-a6,-(sp)
                bsr     sfx_off
                moveq   #YMZ_TUNE,d0
                jsr     ymz_buf                 ; init
                clr.w   ymz_acc
                move.l  $456.w,a0               ; VBL queue : a free place
                move.w  $454.w,d0
                subq.w  #1,d0
                bmi.s   .n
.f:             tst.l   (a0)
                beq.s   .g
                addq.l  #4,a0
                dbra    d0,.f
                bra.s   .n
.g:             move.l  a0,ymz_slot
                move.l  #ymz_vbl,(a0)
                move.w  #1,ymz_on
.n:             movem.l (sp)+,d0-d7/a0-a6
.x:             rts

ymz_stop:
                tst.w   ymz_on
                beq.s   .x
                movem.l d0-d7/a0-a6,-(sp)
                move.l  ymz_slot,a0
                clr.l   (a0)                    ; out of the VBL queue
                clr.w   ymz_on
                moveq   #0,d0                   ; stop : init with d0 = 0
                jsr     ymz_buf
                bsr     sfx_off                 ; YM silent
                movem.l (sp)+,d0-d7/a0-a6
.x:             rts

; ymz_vbl : in the VBL queue : play at 50 / s (VGA 60 Hz : 5 out of 6 VBL)
ymz_vbl:
                movem.l d0-d7/a0-a6,-(sp)
                move.w  ymz_acc,d0
                add.w   #50,d0
                move.w  #60,d1
                cmp.w   #VMODE_VGA,vmode
                beq.s   .r
                moveq   #50,d1
.r:             cmp.w   d1,d0
                blt.s   .w
                sub.w   d1,d0
                move.w  d0,ymz_acc
                jsr     ymz_buf+8               ; play
                bra.s   .x
.w:             move.w  d0,ymz_acc
.x:             movem.l (sp)+,d0-d7/a0-a6
                rts

; ymw4 / ymw11 : replace movem.l d0-d3,$ffff8800.w / d0-a2,$ffff8840.w :
;   each long = register (high byte), value (3rd byte) -> written one by one
YMPAIR          macro
                move.b  \1(sp),$ffff8800.w
                move.b  \1+2(sp),$ffff8802.w
                endm
ymw4:           move.w  sr,-(sp)
                or.w    #$0700,sr
                movem.l d0-d3,-(sp)
                YMPAIR  0
                YMPAIR  4
                YMPAIR  8
                YMPAIR  12
                movem.l (sp)+,d0-d3
                move.w  (sp)+,sr
                rts
ymw11:          move.w  sr,-(sp)
                or.w    #$0700,sr
                movem.l d0-d7/a0-a2,-(sp)
                YMPAIR  0
                YMPAIR  4
                YMPAIR  8
                YMPAIR  12
                YMPAIR  16
                YMPAIR  20
                YMPAIR  24
                YMPAIR  28
                YMPAIR  32
                YMPAIR  36
                YMPAIR  40
                movem.l (sp)+,d0-d7/a0-a2
                move.w  (sp)+,sr
                rts

;---------------------------------------------------------------------
                section data
mod_name:       dc.b    'ZIK\ELYSIUM.MOD',0
ymz_name:       dc.b    'ZIK\PWRBOAT.ORG',0
                even

                section bss
musok:          ds.w    1                       ; module ready
mus_on:         ds.w    1                       ; module playing
mus_saved:      ds.w    1                       ; DSP sound saved (to give back)
mus_fh:         ds.w    1
mus_path:       ds.l    1
mod_len:        ds.l    1
mod_base:       ds.l    1
ymz_ok:         ds.w    1
ymz_on:         ds.w    1
ymz_acc:        ds.w    1
ymz_slot:       ds.l    1
ymz_buf:        ds.b    YMZ_MAX                 ; the YM tune (code + data)
                even
                section text
