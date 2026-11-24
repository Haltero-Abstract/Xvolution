# XVOLUTION — shoot'em up vertical 3D (Wings of Death), Atari Falcon 030 + DSP

Assembleur 68030, syntaxe Devpac 3. Repondre en francais.
Sources dans Xvolution\SOURCES\ (avec outils\, tools\, journaux) ; a la racine seulement le jeu : XVOLUTION.PRG, LEVEL1-4.MAP, PCBT*.BIN, ZIK\, CREDITS.TXT, REFALCON.LIC, Xvolution.bat (XVOLUTIO.HI s'y cree). Construire dans SOURCES\, copier le PRG a la racine. Historique : projet claude.ai « Jeux Atari », `XVOLUTION/JOURNAL.MD`.

## Build / test
- Claude (conteneur Linux) : tools/build.sh (vasm -devpac -nocase -m68030 -Ftos -nosym + ASM56)
  et tools/run.sh (Hatari sans ecran, fichier de commandes, captures).
- PC : Xvolution.bat lance XVOLUTION.PRG dans Hatari (Falcon 030 16 MHz, DSP, 14 Mo, VGA, EmuTOS) ;
  -asm = assembler avant avec rg-asm ; -4 = Falcon 4 Mo.

## Regles
- Toujours repartir des fichiers sur le disque, ne changer que les lignes necessaires.
- Commandes : manette port 1 OU fleches + ESPACE ; ESC / P / D.
- Repris de RICK3D sans changement : DSP3D.S, R3D.A56, ASM56.PY, AMIGADSP.P56.
  AMIGADSP.S (Simplet) : seule retouche = casse de MGTK_FX_Voices (pour rg-asm).

## Sources
| Fichier | Role |
|---|---|
| XVOLUTION.S | init, entrees, jeu, rendu, HUD, barre du bas, modeles |
| SOL.S | sol : defilement materiel (3 buffers de 480 lignes), effacement par rectangles, lignes de tuiles PCB |
| CARTE.S | lecture de LEVEL1.MAP (tuiles + composants), PCBTILES.BIN (incbin) |
| COMPOS.S | composants du circuit en 3D (decor), "cuits" une fois dans le sol G avant d'entrer a l'ecran (bake_scan) |
| PROFIL.S | profileur Timer D (T, L, XVOLUTION.LOG) |
| PARAMS.S | tous les reglages |
| DSP3D.S + R3D.P56 | boites 3D par le DSP |

## Carte (circuit imprime)
- LEVEL1.MAP : texte, `SIZE 16 <lignes>`, lignes de 16 caracteres de tuiles (ligne 0 = fin, derniere = depart),
  `C <type> <col> <ligne>` (P M R K X H), `END`. Le jeu la lit au demarrage (sinon carte vide, "NO LEVEL1.MAP").
- Editeur : outils\EDITEUR.HTML (genere par EDITEUR.SRC.HTML + PCBTILES.JS + LEVEL1.MAP).
- Tuiles : outils\MKTILES.PY -> PCBTILES.BIN (20x20 RGB565) ; meme ordre de caracteres dans CARTE.S tile_chars.
- Carte de depart : outils\MKLEVEL.PY (argument falcon = carte dense facon Falcon 030 ; MKTILES.PY falcon|classic). Toujours repartir du LEVEL1.MAP du disque pour le modifier.
