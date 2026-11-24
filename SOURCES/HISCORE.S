;---------------------------------------------------------------------
; HISCORE.S : high scores, one table per level (points made in the
;   level) + one for the 4 boards in a row (total score) ; saved in
;   XVOLUTIO.HI. The screen : black, like the screens between the
;   levels, with the X of the menu turning behind the table : wire
;   (level 1), flat faces (2), cel (3), Gouraud by the DSP (4, and the
;   4 boards). A new score : the name is typed (8 letters, RETURN).
;---------------------------------------------------------------------
KEY_ENT         equ     $72                     ; ENTER (keypad)
KEY_BS          equ     $0E                     ; backspace
HS_N            equ     8                       ; scores per table
HS_T            equ     5                       ; tables : levels 1..4, the 4 boards
HS_ESZ          equ     12                      ; entry : score.l, name 8 bytes
HS_TSZ          equ     HS_N*HS_ESZ
HSC_TITLE       equ     $FFE0                   ; colours : yellow
HSC_TEXT        equ     $FFFF                   ;  white
HSC_NEW         equ     $07E0                   ;  green : the new score
HSC_GREY        equ     $8C51                   ;  grey
HS_Y0           equ     54                      ; first line of the table
HS_DY           equ     17

; hs_load : XVOLUTIO.HI -> hs_tabs (else the tables of hs_dflt) ;
;   the keyboard tables of TOS (Keytbl) for the names
hs_load:
                movem.l d0-d2/a0-a2,-(sp)
                move.l  #-1,-(sp)               ; Keytbl(-1,-1,-1)
                move.l  #-1,-(sp)
                move.l  #-1,-(sp)
                move.w  #16,-(sp)
                trap    #14
                lea     14(sp),sp
                move.l  d0,a0
                move.l  (a0),hs_kun             ; unshifted, shifted
                move.l  4(a0),hs_ksh
                lea     hs_dflt,a0              ; defaults
                lea     hs_tabs,a1
                move.w  #HS_T*HS_TSZ-1,d0
.d:             move.b  (a0)+,(a1)+
                dbra    d0,.d
                clr.w   -(sp)                   ; Fopen(name, read)
                pea     hs_file
                move.w  #$3d,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi.s   .x
                move.w  d0,d2
                pea     hs_fbuf                 ; Fread(h, 4 + tables)
                move.l  #4+HS_T*HS_TSZ,-(sp)
                move.w  d2,-(sp)
                move.w  #$3f,-(sp)
                trap    #1
                lea     12(sp),sp
                move.l  d0,d1
                move.w  d2,-(sp)                ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
                cmp.l   #4+HS_T*HS_TSZ,d1       ; all of it, with its mark ?
                bne.s   .x
                cmp.l   #'XVH1',hs_fbuf
                bne.s   .x
                lea     hs_fbuf+4,a0
                lea     hs_tabs,a1
                move.w  #HS_T*HS_TSZ-1,d0
.c:             move.b  (a0)+,(a1)+
                dbra    d0,.c
.x:             movem.l (sp)+,d0-d2/a0-a2
                rts

; hs_save : hs_tabs -> XVOLUTIO.HI
hs_save:
                movem.l d0-d2/a0-a2,-(sp)
                move.l  #'XVH1',hs_fbuf
                lea     hs_tabs,a0
                lea     hs_fbuf+4,a1
                move.w  #HS_T*HS_TSZ-1,d0
.c:             move.b  (a0)+,(a1)+
                dbra    d0,.c
                clr.w   -(sp)                   ; Fcreate
                pea     hs_file
                move.w  #$3c,-(sp)
                trap    #1
                addq.l  #8,sp
                tst.l   d0
                bmi.s   .x
                move.w  d0,d2
                pea     hs_fbuf                 ; Fwrite
                move.l  #4+HS_T*HS_TSZ,-(sp)
                move.w  d2,-(sp)
                move.w  #$40,-(sp)
                trap    #1
                lea     12(sp),sp
                move.w  d2,-(sp)                ; Fclose
                move.w  #$3e,-(sp)
                trap    #1
                addq.l  #4,sp
.x:             movem.l (sp)+,d0-d2/a0-a2
                rts

; hs_screen : table d0 (0..3 : levels 1..4, 4 : the 4 boards), score
;   d1.l : the screen of the table, the new score typed in if it is in
hs_screen:
                movem.l d0-d7/a0-a6,-(sp)
                move.w  d0,hs_tb
                move.l  d1,hs_sc
                clr.w   cut_act                 ; as for the menu (game_menu)
                bsr     blank_on
                clr.b   $fffffa1b.w
                bsr     sfx_off
                bsr     mus_stop
                bsr     ymz_start
                st      vol_inmenu
                bsr     vol_apply
                move.w  #-1,hs_ed               ; the place of the new score
                lea     hs_tabs,a0
                mulu    #HS_TSZ,d0
                adda.w  d0,a0
                move.l  a0,hs_ta
                moveq   #0,d2
.f:             cmp.l   (a0),d1                 ; better than this one ?
                bgt.s   .in
                lea     HS_ESZ(a0),a0
                addq.w  #1,d2
                cmp.w   #HS_N,d2
                blt.s   .f
                bra.s   .no
.in:            move.w  d2,hs_ed                ; the ones under : one down
                move.l  hs_ta,a1
                lea     HS_TSZ(a1),a1           ; end of the table
                lea     -HS_ESZ(a1),a2
.mv:            cmp.l   a0,a2
                bls.s   .ins
                move.b  -(a2),-(a1)
                bra.s   .mv
.ins:           move.l  d1,(a0)+                ; the new one : no name yet
                moveq   #7,d0
.nb:            clr.b   (a0)+
                dbra    d0,.nb
                clr.w   hs_len
.no:            move.l  bufd0+BF_ADR,scr_show
                bsr     mx_init
                clr.w   mx_bgc                  ; black background
                move.w  hs_tb,d0
                cmp.w   #MXR_GOUR,d0
                bls.s   .r
                moveq   #MXR_GOUR,d0
.r:             move.w  d0,mx_rend
                cmp.w   #MXR_GOUR,d0            ; Gouraud : the DSP of 3Dreams
                bne.s   .r1
                bsr     mxd_on
.r1:            bsr     hs_redraw
                move.l  bufd2+BF_ADR,a1         ; -> D0 and D1
                move.l  bufd0+BF_ADR,a0
                bsr     mx_copyall
                move.l  bufd1+BF_ADR,a0
                bsr     mx_copyall
                clr.l   mx_full
                move.w  #-1,-(sp)               ; D0 shown
                move.l  bufd0+BF_ADR,-(sp)
                move.l  #-1,-(sp)
                move.w  #5,-(sp)
                trap    #14
                lea     12(sp),sp
                move.w  #37,-(sp)
                trap    #14
                addq.l  #2,sp
                move.w  #(LINEB-SCR_W*2)/2,$ffff820e.w
                bsr     hs_kclr
                move.b  joy1,hs_joy
                move.l  vbl_cnt,mx_vbl
.loop:          bsr     mx_frame                ; X turning + Vsync
                tst.w   hs_ed                   ; (not while typing : - = 6)
                bpl.s   .nv
                bsr     vol_keys_hs
.nv:
                move.b  joy1,d1                 ; joystick : new bits only
                move.b  hs_joy,d2
                move.b  d1,hs_joy
                not.b   d2
                and.b   d2,d1
                lea     keyhit,a0
                tst.w   hs_ed
                bpl.s   .typ
                tst.b   KEY_SPC(a0)             ; table only : SPACE, RETURN,
                bne     .out                    ;  ESC or fire : go on
                tst.b   KEY_RET(a0)
                bne     .out
                tst.b   KEY_ENT(a0)
                bne     .out
                tst.b   KEY_ESC(a0)
                bne     .out
                btst    #7,d1
                bne     .out
                bsr     hs_kclr
                bra.s   .loop
.typ:           tst.b   KEY_RET(a0)             ; the name : RETURN / ENTER / fire
                bne.s   .ok
                tst.b   KEY_ENT(a0)
                bne.s   .ok
                btst    #7,d1
                bne.s   .ok
                moveq   #0,d3                   ; changed ?
                tst.b   KEY_BS(a0)              ; backspace
                beq.s   .k0
                clr.b   KEY_BS(a0)
                tst.w   hs_len
                beq.s   .k0
                subq.w  #1,hs_len
                bsr     hs_name
                clr.b   (a1)
                moveq   #1,d3
.k0:            moveq   #1,d4                   ; the other keys : a character ?
.k1:            tst.b   (a0,d4.w)
                beq.s   .k2
                clr.b   (a0,d4.w)
                bsr     hs_char                 ; d4 -> d0 (0 : none)
                tst.b   d0
                beq.s   .k2
                cmp.w   #8,hs_len
                bhs.s   .k2
                bsr     hs_name
                move.b  d0,(a1)
                addq.w  #1,hs_len
                moveq   #1,d3
.k2:            addq.w  #1,d4
                cmp.w   #$60,d4
                blo.s   .k1
                tst.w   d3
                beq     .loop
                bsr     hs_redraw
                move.l  #$00010001,mx_full      ; both screens : the new M
                bra     .loop
.ok:            tst.w   hs_len                  ; no name : "-"
                bne.s   .ok1
                bsr     hs_name
                move.b  #'-',(a1)
.ok1:           move.w  #-1,hs_ed               ; written ; the table shown
                bsr     hs_save
                bsr     hs_kclr
                bsr     hs_redraw
                move.l  #$00010001,mx_full
                bra     .loop
.out:           cmp.w   #MXR_GOUR,mx_rend
                bne.s   .o1
                bsr     mxd_off                 ; DSP : R3D again (game)
.o1:            bsr     ymz_stop
                sf      vol_inmenu
                bsr     vol_apply
                bsr     hs_kclr
                movem.l (sp)+,d0-d7/a0-a6
                rts

; vol_keys_hs : + / - (volume of the YM tune) as in the menu
vol_keys_hs:
                movem.l d0-d2/a0,-(sp)
                lea     keyhit,a0
                bsr     vol_keys
                movem.l (sp)+,d0-d2/a0
                rts

; hs_kclr : old presses forgotten
hs_kclr:
                movem.l d0/a0,-(sp)
                lea     keyhit,a0
                moveq   #128/4-1,d0
.c:             clr.l   (a0)+
                dbra    d0,.c
                movem.l (sp)+,d0/a0
                rts

; hs_name : a1 = the next character of the name being typed
hs_name:
                move.l  hs_ta,a1
                move.w  hs_ed,d1
                mulu    #HS_ESZ,d1
                lea     4(a1,d1.w),a1
                adda.w  hs_len,a1
                rts

; hs_char : scan code d4 -> d0 = A..Z, 0..9, space (else 0) : the
;   keyboard tables of TOS (AZERTY or QWERTY : the letters where they are)
hs_char:
                move.l  a0,-(sp)
                moveq   #0,d0
                cmp.w   #KEY_SPC,d4
                bne.s   .a
                moveq   #' ',d0
                bra.s   .x
.a:             move.l  hs_kun,a0               ; a letter (unshifted) ?
                move.b  (a0,d4.w),d0
                cmp.b   #'a',d0
                blo.s   .b
                cmp.b   #'z',d0
                bhi.s   .b
                sub.b   #'a'-'A',d0
                bra.s   .x
.b:             cmp.b   #'0',d0                 ; a digit (QWERTY, keypad) ?
                blo.s   .c
                cmp.b   #'9',d0
                bls.s   .x
.c:             move.l  hs_ksh,a0               ;  (AZERTY : shifted)
                move.b  (a0,d4.w),d0
                cmp.b   #'0',d0
                blo.s   .z
                cmp.b   #'9',d0
                bls.s   .x
.z:             moveq   #0,d0
.x:             move.l  (sp)+,a0
                rts

; hs_redraw : the picture of the table in M (D2), its lines of text
hs_redraw:
                movem.l d0-d7/a0-a6,-(sp)
                move.l  bufd2+BF_ADR,a6
                move.l  a6,a0                   ; black
                move.w  #SCR_H-1,d7
.cy:            move.l  a0,a2
                move.w  #SCR_W/2-1,d0
.cx:            clr.l   (a2)+
                dbra    d0,.cx
                lea     LINEB(a0),a0
                dbra    d7,.cy
                lea     hs_t4,a0                ; title
                move.w  hs_tb,d0
                cmp.w   #4,d0
                beq.s   .t1
                lea     hs_tl,a0                ; "LEVEL n  HIGH SCORES"
                add.b   #'1',d0
                move.b  d0,hs_tl+6
.t1:            moveq   #14,d1
                move.w  #HSC_TITLE,d2
                moveq   #2,d3
                bsr     hs_ctext
                lea     hs_s4,a0                ; under it : the board(s)
                move.w  hs_tb,d0
                cmp.w   #4,d0
                beq.s   .t2
                mulu    #24,d0
                lea     lt_names,a0
                adda.w  d0,a0
.t2:            moveq   #32,d1
                move.w  #HSC_GREY,d2
                moveq   #1,d3
                bsr     hs_ctext
                move.l  hs_ta,a4                ; the lines
                moveq   #0,d6
.l:             move.w  d6,d1
                mulu    #HS_DY,d1
                add.w   #HS_Y0,d1
                move.w  #HSC_TEXT,d2
                cmp.w   hs_ed,d6
                bne.s   .l0
                move.w  #HSC_NEW,d2
.l0:            lea     hs_line,a1              ; "1." name score
                move.b  d6,d0
                add.b   #'1',d0
                move.b  d0,(a1)+
                move.b  #'.',(a1)+
                move.b  #' ',(a1)+
                move.b  #' ',(a1)+
                lea     4(a4),a0
                moveq   #7,d0
                moveq   #0,d4                   ; (end of the name met)
.n:             move.b  (a0)+,d5
                tst.w   d4
                bne.s   .n1
                tst.b   d5
                bne.s   .n2
                moveq   #1,d4
                cmp.w   hs_ed,d6                ; being typed : the cursor
                bne.s   .n1
                move.b  #'_',(a1)+
                bra.s   .n3
.n1:            move.b  #' ',(a1)+
                bra.s   .n3
.n2:            move.b  d5,(a1)+
.n3:            dbra    d0,.n
                move.b  #' ',(a1)+
                move.l  (a4),d0
                bsr     hs_num
                clr.b   (a1)
                lea     hs_line,a0
                moveq   #36,d0
                moveq   #2,d3
                bsr     big_text
                lea     HS_ESZ(a4),a4
                addq.w  #1,d6
                cmp.w   #HS_N,d6
                blt     .l
                lea     hs_line,a1              ; "YOUR SCORE 12345"
                lea     hs_your,a0
.y:             move.b  (a0)+,(a1)+
                bne.s   .y
                subq.l  #1,a1
                move.l  hs_sc,d0
                bsr     hs_num
                clr.b   (a1)
                lea     hs_line,a0
                move.w  #HS_Y0+HS_N*HS_DY+6,d1
                move.w  #HSC_TEXT,d2
                moveq   #1,d3
                bsr     hs_ctext
                lea     hs_kgo,a0               ; the keys
                tst.w   hs_ed
                bmi.s   .k
                lea     hs_kname,a0
.k:             move.w  #HS_Y0+HS_N*HS_DY+20,d1
                move.w  #HSC_GREY,d2
                moveq   #1,d3
                bsr     hs_ctext
                bsr     mx_scan
                movem.l (sp)+,d0-d7/a0-a6
                rts

; hs_ctext : string a0 centred at line d1 (big_text : scale d3)
hs_ctext:
                movem.l d0/a1,-(sp)
                move.l  a0,a1
                moveq   #0,d0
.l:             tst.b   (a1)+
                beq.s   .e
                addq.w  #1,d0
                bra.s   .l
.e:             mulu    #6,d0
                mulu    d3,d0
                neg.w   d0
                add.w   #SCR_W,d0
                asr.w   #1,d0
                bsr     big_text
                movem.l (sp)+,d0/a1
                rts

; hs_num : d0.l (0..9999999) -> 7 characters at a1+ (spaces in front)
hs_num:
                movem.l d0-d3/a0,-(sp)
                lea     hs_dig+7,a0
                moveq   #6,d3
.d:             move.l  d0,d1                   ; d0 / 10 (32 bits)
                clr.w   d1
                swap    d1                      ; high word
                divu    #10,d1                  ; rest : quotient high
                move.w  d1,d2
                swap    d2                      ; (quotient high)
                move.w  d0,d1                   ; rest : low word
                divu    #10,d1
                move.w  d1,d2                   ; quotient low
                swap    d1
                add.b   #'0',d1
                move.b  d1,-(a0)
                move.l  d2,d0
                dbra    d3,.d
                lea     hs_dig,a0               ; zeros in front -> spaces
                moveq   #5,d3
.z:             cmp.b   #'0',(a0)
                bne.s   .c
                move.b  #' ',(a0)+
                dbra    d3,.z
.c:             lea     hs_dig,a0
                moveq   #6,d3
.cp:            move.b  (a0)+,(a1)+
                dbra    d3,.cp
                movem.l (sp)+,d0-d3/a0
                rts


; gr_screen : the greetings, before quitting : black, the X in Gouraud
;   turning behind (as the last high scores), any key / fire to go
gr_screen:
                movem.l d0-d7/a0-a6,-(sp)
                move.l  bufd0+BF_ADR,scr_show
                bsr     mx_init
                clr.w   mx_bgc
                move.w  #MXR_GOUR,mx_rend
                bsr     mxd_on
                move.l  bufd2+BF_ADR,a6         ; the page in M
                move.l  a6,a0
                move.w  #SCR_H-1,d7
.cy:            move.l  a0,a2
                move.w  #SCR_W/2-1,d0
.cx:            clr.l   (a2)+
                dbra    d0,.cx
                lea     LINEB(a0),a0
                dbra    d7,.cy
                lea     gr_text,a4              ; lines : y.w colour.w scale.w text
.l:             move.w  (a4)+,d1
                bmi.s   .le
                move.w  (a4)+,d2
                move.w  (a4)+,d3
                move.l  a4,a0
                bsr     hs_ctext
.s:             tst.b   (a4)+
                bne.s   .s
                move.l  a4,d0
                addq.l  #1,d0
                and.b   #$fe,d0
                move.l  d0,a4
                bra.s   .l
.le:            bsr     mx_scan
                move.l  bufd2+BF_ADR,a1
                move.l  bufd0+BF_ADR,a0
                bsr     mx_copyall
                move.l  bufd1+BF_ADR,a0
                bsr     mx_copyall
                clr.l   mx_full
                move.w  #-1,-(sp)
                move.l  bufd0+BF_ADR,-(sp)
                move.l  #-1,-(sp)
                move.w  #5,-(sp)
                trap    #14
                lea     12(sp),sp
                move.w  #37,-(sp)
                trap    #14
                addq.l  #2,sp
                move.w  #(LINEB-SCR_W*2)/2,$ffff820e.w
                bsr     hs_kclr
                move.b  joy1,hs_joy
                move.l  vbl_cnt,mx_vbl
.loop:          bsr     mx_frame
                move.b  joy1,d1                 ; fire (new) or any key
                move.b  hs_joy,d2
                move.b  d1,hs_joy
                not.b   d2
                and.b   d2,d1
                btst    #7,d1
                bne.s   .out
                lea     keyhit,a0
                moveq   #1,d0
.k:             tst.b   (a0,d0.w)
                bne.s   .out
                addq.w  #1,d0
                cmp.w   #$73,d0
                blo.s   .k
                bra.s   .loop
.out:           bsr     mxd_off
                bsr     hs_kclr
                movem.l (sp)+,d0-d7/a0-a6
                rts

GRL             macro                           ; y, colour, scale, text
                dc.w    \1,\2,\3
                dc.b    \4,0
                even
                endm
GRC_T           equ     $FFE0                   ; yellow : title
GRC_H           equ     $07E0                   ; green : heads
GRC_W           equ     $FFFF                   ; white
GRC_G           equ     $8C51                   ; grey
gr_text:        GRL     8,GRC_T,2,'GREETINGS'
                GRL     30,GRC_H,1,'THE ATARI SCENE'
                GRL     40,GRC_W,1,'FOR ITS KINDNESS, EVEN IF THIS GAME'
                GRL     49,GRC_W,1,'WAS CODED WITH THE HELP OF AN AI'
                GRL     64,GRC_H,1,'SIMPLET AND SKYNET OF ABSTRACT'
                GRL     74,GRC_W,1,'FOR THE MEGAPLAYER ROUTINE'
                GRL     83,GRC_W,1,'AND SKYNET FOR HIS DSP OPTIMISATIONS OF THE PAST'
                GRL     98,GRC_H,1,'MUSIC'
                GRL     108,GRC_W,1,'TRANSLOGIC - JORA OF B.M.T (SVEN BAUER)'
                GRL     117,GRC_W,1,'RUNAWAY - HOBBY ONE OF ABSTRACT'
                GRL     126,GRC_W,1,'CYBERRIDE, ELYSIUM - JESTER OF SANITY'
                GRL     135,GRC_W,1,'POWER BOAT - JOCHEN HIPPEL (MAD MAX)'
                GRL     150,GRC_H,1,'THE MOTHERBOARDS'
                GRL     160,GRC_W,1,'800 XL - MAREK L (CC BY-SA 2.0)'
                GRL     169,GRC_W,1,'520 ST, STE - SPORNIKET (KICAD)'
                GRL     178,GRC_W,1,'FALCON 030 - REFALCON BY STEVE SUAVEK'
                GRL     196,GRC_T,1,'HALTERO / ABSTRACT - 2026'
                GRL     222,GRC_G,1,'PRESS A KEY'
                dc.w    -1

hs_file:        dc.b    'XVOLUTIO.HI',0
hs_tl:          dc.b    'LEVEL n  HIGH SCORES',0
hs_t4:          dc.b    'ALL BOARDS  HIGH SCORES',0
hs_s4:          dc.b    'THE 4 BOARDS IN A ROW',0
hs_your:        dc.b    'YOUR SCORE ',0
hs_kname:       dc.b    'TYPE YOUR NAME  -  RETURN : OK',0
hs_kgo:         dc.b    'SPACE / FIRE : CONTINUE',0
                even
HSD             macro                           ; score, name (8 letters)
                dc.l    \1
                dc.b    \2
                endm
hs_dflt:        rept    4
                HSD     30000,'HALTERO '
                HSD     25000,'ABSTRACT'
                HSD     20000,'SANITY  '
                HSD     16000,'JESTER  '
                HSD     12000,'3DREAMS '
                HSD     8000,'FALCON  '
                HSD     5000,'ATARI   '
                HSD     2000,'STE     '
                endr
                HSD     120000,'HALTERO '
                HSD     100000,'ABSTRACT'
                HSD     80000,'SANITY  '
                HSD     64000,'JESTER  '
                HSD     48000,'3DREAMS '
                HSD     32000,'FALCON  '
                HSD     20000,'ATARI   '
                HSD     8000,'STE     '
                even
hs_tb:          ds.w    1                       ; table shown
hs_ed:          ds.w    1                       ; place of the new score (-1 : none)
hs_len:         ds.w    1                       ; letters typed
hs_sc:          ds.l    1                       ; the score
hs_ta:          ds.l    1                       ; the table
hs_kun:         ds.l    1                       ; keyboard tables of TOS
hs_ksh:         ds.l    1
hs_joy:         ds.b    1
hs_dig:         ds.b    8
hs_line:        ds.b    48
                even
hs_fbuf:        ds.b    4+HS_T*HS_TSZ
hs_tabs:        ds.b    HS_T*HS_TSZ
                even
