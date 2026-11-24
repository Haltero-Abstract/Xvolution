;=====================================================================
; PROFIL.S - PROFILER (key T) : time spent per part of the frame
;   (like RICK3D's PROFIL.S ; included twice by SHOTEMUP.S : at the top
;    for the PROF macro, near the end for the code)
;
;   Clock : MFP Timer D, 2.4576 MHz / 50 = 49152 Hz (1 tick = 20.3 us),
;   counter 256 -> interrupt -> pr_ovf + 1. Time = pr_ovf*256 + (256-TDDR).
;   Each PROF n adds the time since the previous PROF to the part n.
;   Every PR_NFR frames the averages (0.1 ms per frame ; 16.7 ms = one
;   VGA 60 Hz frame) go to the bottom bar (T) and to the log :
;   XVOLUTION.LOG : S starts a capture (bottom bar hidden), S again
;   or ESC stops it and writes the file ; L writes it at once.
;=====================================================================

                ifnd    PROF_DEF               ; 1st include : macro only
PROF_DEF        equ     1

PR_NSEC         equ     8               ; parts of the frame
PR_NFR          equ     32              ; frames per average
PR_LOG          equ     0               ; logic (input, moves, collisions)
PR_SOL          equ     1               ; ground : scroll + erasing (SOL.S)
PR_CMP          equ     2               ; components of the board (COMPOS.S)
PR_ENM          equ     3               ; enemies + bonus
PR_BUL          equ     4               ; bullets
PR_SHP          equ     5               ; ship
PR_HUD          equ     6               ; HUD + bottom bar
PR_VBL          equ     7               ; flip : waiting for the VBL (spare)

; PROF n : end of part n (all registers and flags kept)
PROF            macro
                tst.w   pr_run
                beq.s   .pf\@
                move.l  d1,-(sp)
                moveq   #\1,d1
                jsr     prof_mark
                move.l  (sp)+,d1
.pf\@:
                endm

                else                    ; 2nd include : code

prof_install:
                move.w  sr,-(sp)
                move.w  #$2700,sr
                move.l  $110.w,pr_oldvec
                move.b  $fffffa1d.w,pr_oldcd    ; TCDCR (D : bits 0-2)
                move.b  $fffffa25.w,pr_olddr
                move.b  $fffffa09.w,d0          ; IERB / IMRB bit 4 = Timer D
                and.b   #$10,d0
                move.b  d0,pr_oldie
                move.b  $fffffa15.w,d0
                and.b   #$10,d0
                move.b  d0,pr_oldim
                move.l  #prof_tdint,$110.w
                and.b   #$f0,$fffffa1d.w        ; Timer D stopped
                clr.b   $fffffa25.w             ; counter 256
                or.b    #4,$fffffa1d.w          ; prescaler 50
                bset    #4,$fffffa09.w
                bset    #4,$fffffa15.w
                clr.l   pr_ovf
                clr.l   pr_last
                bsr     prof_clear              ; log : header only
                move.w  #1,pr_run
                move.w  (sp)+,sr
                rts

prof_remove:
                tst.w   pr_run
                beq.s   .x
                move.w  sr,-(sp)
                move.w  #$2700,sr
                and.b   #$f0,$fffffa1d.w
                move.b  pr_olddr,$fffffa25.w
                move.b  pr_oldcd,d0
                and.b   #$0f,d0
                or.b    d0,$fffffa1d.w
                bclr    #4,$fffffa09.w
                bclr    #4,$fffffa15.w
                move.b  pr_oldie,d0
                or.b    d0,$fffffa09.w
                move.b  pr_oldim,d0
                or.b    d0,$fffffa15.w
                move.l  pr_oldvec,$110.w
                clr.w   pr_run
                move.w  (sp)+,sr
.x:             rts

prof_tdint:     addq.l  #1,pr_ovf
                move.b  #$ef,$fffffa11.w        ; ISRB : end of Timer D
                rte

; prof_now : d0 = time in ticks (d1 used)
prof_now:
.r:             move.l  pr_ovf,d0
                moveq   #0,d1
                move.b  $fffffa25.w,d1
                cmp.l   pr_ovf,d0
                bne.s   .r
                neg.w   d1
                and.w   #$ff,d1
                lsl.l   #8,d0
                add.l   d1,d0
                rts

; prof_mark : d1 = part ; adds (now - last) to it
prof_mark:
                move.w  sr,-(sp)
                movem.l d0/d2/a0-a1,-(sp)
                move.w  d1,d2
                bsr.s   prof_now
                move.l  d0,d1
                sub.l   pr_last,d1
                move.l  d0,pr_last
                lea     pr_acc,a0
                lsl.w   #2,d2
                add.l   d1,(a0,d2.w)
                cmp.w   #PR_VBL*4,d2            ; end of the frame
                bne.s   .x
                addq.w  #1,pr_fcnt
                cmp.w   #PR_NFR,pr_fcnt
                blo.s   .x
                clr.w   pr_fcnt
                lea     pr_acc,a0               ; averages in 0.1 ms :
                lea     pr_show,a1              ;  ticks * 20.345 us / 100 / 32
                moveq   #PR_NSEC-1,d2           ;  = ticks * 13 / 2048
.av:            move.l  (a0),d0
                clr.l   (a0)+
                tst.l   d0
                bpl.s   .av1
                moveq   #0,d0
.av1:           mulu.l  #13,d0
                moveq   #11,d1
                lsr.l   d1,d0
                move.w  d0,(a1)+
                dbra    d2,.av
                move.l  pr_dsp,d0               ; DSP waits per frame
                clr.l   pr_dsp
                lsr.l   #5,d0
                move.w  d0,(a1)+
                move.l  pr_box,d0               ; 3D boxes per frame
                clr.l   pr_box
                lsr.l   #5,d0
                move.w  d0,(a1)+
                move.w  fps,(a1)+
                tst.w   pr_rec                  ; S : capture running ?
                beq.s   .x
                bsr     prof_logrec
.x:             movem.l (sp)+,d0/d2/a0-a1
                move.w  (sp)+,sr
                rts

; prof_clear : log buffer = the header only
prof_clear:
                movem.l a0-a1,-(sp)
                move.l  #pr_logbuf,a0
                lea     pr_head,a1
.h:             move.b  (a1)+,(a0)+
                bne.s   .h
                subq.l  #1,a0
                move.l  a0,pr_logp
                movem.l (sp)+,a0-a1
                rts

; S key : prof_start = new capture (lines every PR_NFR frames from now) ;
;   prof_stop = end of the capture, XVOLUTION.LOG written
prof_start:
                bsr     prof_clear
                move.w  #1,pr_rec
                rts
prof_stop:
                tst.w   pr_rec
                beq.s   .x
                clr.w   pr_rec
                bsr     prof_save
.x:             rts

; one line of the log : the values of pr_show with their names
prof_logrec:
                movem.l d0-d3/a0-a2,-(sp)
                move.l  pr_logp,a0
                cmp.l   #pr_logend-200,a0       ; full : no more lines
                bhs.s   .x
                lea     pr_names,a2
                lea     pr_show,a1
                moveq   #PR_NSEC+3-1,d3
.l:             move.w  (a1)+,d0
                movem.l d3/a1,-(sp)
                move.l  a2,a1
.n:             move.b  (a1)+,d1
                beq.s   .n1
                move.b  d1,(a0)+
                bra.s   .n
.n1:            bsr     fmtnum
.d:             move.b  (a1)+,d1
                beq.s   .d1
                move.b  d1,(a0)+
                bra.s   .d
.d1:            move.b  #' ',(a0)+
                movem.l (sp)+,d3/a1
                addq.l  #5,a2
                dbra    d3,.l
                move.b  #13,(a0)+
                move.b  #10,(a0)+
                move.l  a0,pr_logp
.x:             movem.l (sp)+,d0-d3/a0-a2
                rts

; prof_save : writes SHOTEMUP.LOG (Z = 1 : ok)
prof_save:
                movem.l d0-d2/a0-a2,-(sp)
                tst.w   pr_run
                beq.s   .err
                clr.w   -(sp)                   ; Fcreate
                pea     pr_fname
                move.w  #$3c,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi.s   .err
                move.w  d0,d2
                move.l  pr_logp,d0
                sub.l   #pr_logbuf,d0
                pea     pr_logbuf               ; Fwrite
                move.l  d0,-(sp)
                move.w  d2,-(sp)
                move.w  #$40,-(sp)
                trap    #1
                lea     12(sp),sp
                move.w  d2,-(sp)                ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
                moveq   #0,d0
                bra.s   .x
.err:           moveq   #1,d0
.x:             movem.l (sp)+,d0-d2/a0-a2
                rts

; prof_lines : the 2 lines of the bottom bar (a0 = linebuf)
prof_lines:
                movem.l d2-d3/a2-a3,-(sp)
                lea     pr_names,a2
                lea     pr_show,a3
                moveq   #0,d3
                moveq   #PR_NSEC+3-1,d2
.l:             cmp.w   #6,d3                   ; 6 values per line
                bne.s   .s
                lea     linebuf+LINEW,a0
.s:             move.l  a0,-(sp)
                move.l  a2,a1
                bsr     puts
                addq.l  #5,a2
                move.w  (a3)+,d0
                bsr     fmtnum
                bsr     puts
                move.l  (sp)+,a0
                addq.l  #8,a0                   ; 8 characters per value
                addq.w  #1,d3
                dbra    d2,.l
                movem.l (sp)+,d2-d3/a2-a3
                rts

                section data
pr_names:       dc.b    'LOG ',0,'SOL ',0,'CMP ',0,'ENM ',0,'BUL ',0,'SHP ',0
                dc.b    'HUD ',0,'VBL ',0,'DSP ',0,'BOX ',0,'FPS ',0
pr_fname:       dc.b    'XVOLUTION.LOG',0
pr_head:        dc.b    'XVOLUTION LOG - one line every 32 frames (averages)',13,10
                dc.b    'capture : S = start, S again (or ESC) = stop + write ; bottom bar hidden',13,10
                dc.b    'LOG..VBL : 0.1 ms per frame (16.7 ms = 1 VGA frame) :',13,10
                dc.b    ' LOG logic, SOL ground scroll + erasing, CMP components, ENM enemies',13,10
                dc.b    ' + bonus, BUL bullets, SHP ship, HUD hud + bar, VBL spare (wait)',13,10
                dc.b    'DSP waits for the DSP per frame, BOX 3D boxes per frame',13,10,13,10,0
                even
                section bss
pr_run:         ds.w    1
pr_rec:         ds.w    1                       ; capture running (S)
prof_on:        ds.w    1
pr_fcnt:        ds.w    1
pr_ovf:         ds.l    1
pr_last:        ds.l    1
pr_box:         ds.l    1
pr_acc:         ds.l    PR_NSEC
pr_show:        ds.w    PR_NSEC+3
pr_oldvec:      ds.l    1
pr_oldcd:       ds.b    1
pr_olddr:       ds.b    1
pr_oldie:       ds.b    1
pr_oldim:       ds.b    1
pr_logp:        ds.l    1
pr_logbuf:      ds.b    65536
pr_logend:
                section text
                endc
