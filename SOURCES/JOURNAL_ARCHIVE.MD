# XVOLUTION — journal (shoot'em up 3D Falcon 030, inspiré de Wings of Death ; ex-ShotEmUp)

Dossier : `Documents\ChatGPT\Xvolution` (sources à la racine). Vue de dessus, défilement vertical.

## 2026-11-13 — v0.1 squelette
- Repris de RICK3D : `DSP3D.S` (inchangé), `AMIGADSP.S` + `.P56` (Simplet), `OUTILS\R3D.A56` + `ASM56.PY` ; `R3D.P56` (950 mots DSP).
- VGA 320x240 True Color, double écran, manette port 1, ESC / P / D.
- Sol en tuiles de 20 px (rivière), piliers 3D (DSP). Robot-vaisseau 3 formes (sonde, chasseur, lourd), capsule tous les 8 ennemis ; drones et croiseurs ; HUD.

## 2026-11-13 — rg-asm, clavier, barre du bas, vitesse
- rg-asm sensible à la casse : `MGTK_FX_Voices` dans `AMIGADSP.S`.
- Clavier : interruption ACIA ($118), flèches + ESPACE, P / D / H à l'appui.
- Barre du bas (H) : police TOS 6x6 ; FPS, 3D DSP/030, forme, vies / X Y, ennemis, tirs, tués, capsule, rangée.
- `PARAMS.S` : SCROLL_SPD 2, SHIP_SPD 4, BUL_SPD 10, FIRE_T0/T2 6/8, WAVE_T 24, EN_SPD0 3, EN_SPD1 2, BON_SPD 2.

## 2026-11-13 — chaîne d'outils de Claude (conteneur Linux)
- vasm 2.0f, SDL 2.30 + Hatari compilés depuis GitHub ; EmuTOS etos512fr ; ASM56.PY.
- `tools/run.sh` (Hatari sans écran, fichier de commandes wait/key/down/up/shot/quit, captures + log), `tools/build.sh` (ASM56 + vasm, bsr/bra hors de portée → jsr/jmp).
- Vasm : 3 branches courtes trop loin dans SHOTEMUP.S → jsr/jmp.

## 2026-11-13 — défilement matériel (SOL.S) : 15 → 27-31 FPS
- Constat (Hatari) : barre du bas absente chez Haltero car `SHOTEMUP.PRG` datait de 14h22 (jamais réassemblé) ; mesure : 15 FPS normal, 35 sans le sol, 16 sans les boîtes 3D → réécrire 150 Ko de True Color par image était le goulot.
- Nouveau `SOL.S` : 3 buffers de 2 x 240 lignes (G = sol propre, D0 / D1 = écrans) ; la ligne du monde w est aux lignes (w mod 240) et +240 ; l'écran affiché commence à la ligne (gpos mod 240) (Setscreen) ; par image seules les SCROLL_SPD nouvelles lignes sont dessinées dans G puis copiées dans l'écran ; les objets notent leur rectangle (obj_begin / obj_end, bb_x0..bb_y1 mis à jour par fillrect et d3dbox) et le sol est recopié de G seulement dessous à la prochaine utilisation de cet écran (96 rectangles max, sinon copie entière). HUD, barre du bas et bande game over = rectangles fixes. Saut de gpos (nouvelle partie, bouclage) → tout redessiné.
- SHOTEMUP.S : draw_ground / clear_screens / scrbuf retirés ; `tallmem` 3 x 307 200 octets (passe aussi sur 4 Mo) ; draw_model, piliers, tirs entourés d'obj_begin / obj_end ; échange des écrans par `cur_bf`.
- Bug évité : `moveq #SCR_H-1` (239 > 127) bouclait à l'infini → `move.w`.
- Vérifié dans Hatari (captures regardées) : 27-31 FPS, pas de traînées, barre du bas visible.
- Écrit sur le disque : SHOTEMUP.S (71fa3c19…), SOL.S (cb1c1dbb…), SHOTEMUP.PRG assemblé par vasm (4509356d…), ShotEmUp.bat (lance Hatari ; -asm = rg-asm avant, -4 = 4 Mo), CLAUDE.md mis à jour.
- Suite : profileur Timer D (touche T, .LOG), découpage en .S, puis sprites précalculés pour viser 50-60 FPS.

## 2026-11-13 — profileur (PROFIL.S, touche T, SHOTEMUP.LOG)
- Comme RICK3D : Timer D 49152 Hz, macro `PROF n` ; parties LOG, SOL, PIL, ENM, BUL, SHP, HUD, VBL (0,1 ms par image, moyenne sur 32 images) + DSP (attentes), BOX (boîtes 3D par image), FPS. T = dans la barre du bas ; L = écrit SHOTEMUP.LOG ; écrit aussi en quittant (ESC).
- Touches : les appuis sont mémorisés dans l'interruption (`keyhit`) : un appui très court n'est plus perdu (ESC, P, D, H, T, L).
- SOL.S : recopie sous les objets par `movem.l` de 7 registres ; HUD = 2 petits rectangles (score ; forme + vies) au lieu de 22 lignes pleine largeur.
- Mesure Hatari (0,1 ms) : LOG 2, SOL 90, PIL 15, ENM 95, BUL 3, SHP 15, HUD 53, VBL 55, DSP ~360 attentes, 26 boîtes, 30 FPS. Restent : ENM (boîtes DSP des ennemis), SOL (recopie, barre du bas pleine largeur), HUD (barre du bas assombrie + texte).
- run.sh : une touche par code doit avoir 2 caractères ou plus (0x01 = ESC) ; 1 caractère = ASCII.
- Écrit sur le disque (md5 vérifiés) : SHOTEMUP.S ac71bea3…, SOL.S e49ddcd6…, PROFIL.S 838e78be…, SHOTEMUP.PRG 46575143…, tools\run.sh.

## 2026-11-13 — sol en circuit imprimé, composants 3D, éditeur de carte
- Demande : sol = carte électronique, processeurs / résistances en 3D comme les anciens piliers, éditeur de map ; composants = simple décor pour l'instant (tirs de certains composants peut-être plus tard).
- `outils\MKTILES.PY` → `PCBTILES.BIN` : 21 tuiles 20x20 RGB565 : carte `.`, pistes `- | +`, coudes `r 7 L J`, tés `T W E 3`, vias `o O a i`, pastille `p`, doigts dorés `=`, plan de cuivre `#`, sérigraphie `s t`.
- `LEVEL1.MAP` (texte) : `SEU 1`, `SIZE 16 300`, 300 lignes de 16 caractères (ligne 0 = fin en haut, dernière = départ en bas, doigts dorés), `C type col ligne` (P processeur 4x4, M mémoire 2x4, R résistance 2x1, K condensateur 1x1, X quartz 2x1, H connecteur 4x1), `END`. Carte de départ faite par `outils\MKLEVEL.PY` (2 bus de cuivre, 26 composants, vias, pistes).
- `CARTE.S` (nouveau) : lit LEVEL1.MAP au démarrage (Fopen/Fread, 64 Ko max, 1500 lignes, 400 composants) ; sans fichier : carte nue + « NO LEVEL1.MAP » dans la barre.
- `SOL.S` : `gnd_line` copie la ligne (w mod 20) des 16 tuiles de la ligne de carte ; la rivière, les joints et `rowline` sont retirés.
- `COMPOS.S` (nouveau) : modèles de boîtes par type (pixels du sol + hauteur Z), convertis en monde à GROUND_Z et dessinés par draw_box (DSP) ; résistance avec 4 bagues de couleur, processeur avec pattes et marquage, condensateur haut.
- `SHOTEMUP.S` : piliers et sol aléatoire retirés ; départ = bas de la carte (gpos = hauteur - 240), au bout on recommence au départ. `PARAMS.S` : MAP_MAXROWS, MAP_DEFROWS, MAXCOMP, FILE_MAX ; PIL_*, SEAM, WATER retirés. Profileur : PIL → CMP.
- `outils\EDITEUR.HTML` (+ source EDITEUR.SRC.HTML) : peindre les tuiles, « piste auto » (coudes et tés tout seuls), Maj+glisser = rectangle, poser / enlever les composants, perspective du jeu (aperçu 3D), lignes ajoutées en haut, ouvrir / enregistrer LEVEL1.MAP. Capture vérifiée dans Chrome.
- Vérifié dans Hatari : même image que l'éditeur, 30-31 FPS.
- Écrit sur le disque (md5 vérifiés) : SHOTEMUP.S f5b84b14…, SOL.S 34e3cb40…, PROFIL.S 4f6a4426…, PARAMS.S 471e1f28…, CARTE.S ff596abf…, COMPOS.S b35c637a…, PCBTILES.BIN e3cd8620…, LEVEL1.MAP 9e1c5af2…, SHOTEMUP.PRG 6edf0bc5…, outils\EDITEUR.HTML, EDITEUR.SRC.HTML, MKTILES.PY, MKLEVEL.PY, CLAUDE.md.
- Fichiers de test Hatari copiés dans `tools\tests\` (map.cmd, prof.cmd, st.cmd, fal.cmd). Règle : après chaque modification, tout est transféré dans `Documents\ChatGPT\ShotEmUp` (md5 vérifiés).

## 2026-11-13 — carte façon Falcon 030 (photo de Haltero) + composants cuits dans le sol
- Idée : les niveaux suivront l'évolution des Atari (130 XL, ST, STE, Falcon). Référence STE : conversion KiCad de la carte mère STE par sporniket (forum AtariAge 324499) — à récupérer pour un niveau STE fidèle.
- Tuiles thème « falcon » (vernis vert très foncé, pistes vues à travers le vernis) + `h` / `v` (bus de 4 pistes fines) et `k` (rangée de vias). `MKTILES.PY [dir] falcon|classic`. 24 tuiles.
- 10 composants de plus (COMPOS.S, éditeur, CARTE.S `comp_types` = PMRKXHQFDOAUZGNV) : Q QFP 4x4 (COMBEL/VIDEL), F 68030 radiateur + ventilateur 4x4, D DIP 2x5, O SOIC 2x2, A réseau de résistances rouge 1x4, U SIP bleu 1x1, Z condensateur chimique 2x2, G carte RAM 6x10 (surélevée, 4 puces), N ferrite 3x1, V prise D-sub 2x5.
- `MKLEVEL.PY ... falcon` : carte dense (350 composants sur 300 lignes) : carte RAM + 68030 au milieu, QFP, prises D-sub à gauche, bus de pistes fines, vias ; LEVEL1.MAP régénéré (seed 1992).
- Problème : 12 FPS (CMP 38 ms, ~100 boîtes par image). Solution : les composants sont « cuits » dans le sol G : `SOL.S` garde maintenant GM = 256 lignes préparées au-dessus de l'écran (anneau RING = 496 lignes, buffers de 736 lignes, 3 x 471 Ko) ; `bake_scan` (COMPOS.S) dessine une seule fois chaque composant entièrement entré dans G (dans `tmpbuf`, centré verticalement, puis copié pixel par pixel sauf la couleur clé BK_KEY $F81F dans les lignes de G et leurs copies) ; ensuite il défile gratuitement. Faces gauche/droite justes, haut/bas figées (celles du milieu de l'écran).
- Mesure Hatari : CMP 0, 30 à 57 FPS selon les ennemis (SOL ~8 ms, HUD ~5 ms, ennemis 0,5 à 10 ms).
- `PARAMS.S` : MAXCOMP 800, BK_KEY. Éditeur : nouveaux composants et tuiles, boutons agrandis.
- Écrit sur le disque (md5 vérifiés) : SHOTEMUP.S 516b4ccb…, SOL.S b72e9e89…, PARAMS.S eb14478a…, CARTE.S 0c15ac4b…, COMPOS.S 502141d3…, PCBTILES.BIN 8a05c975…, LEVEL1.MAP 35f45f4b…, SHOTEMUP.PRG 33780466…, outils\MKTILES.PY, MKLEVEL.PY, EDITEUR.HTML, EDITEUR.SRC.HTML, tools\tests\fal.cmd, CLAUDE.md.

## 2026-11-13 — cadence fixe 30 images/s
- Demande : 30 FPS fixes, pour que le jeu n'accélère / ne ralentisse plus selon le nombre d'objets.
- Boucle principale (SHOTEMUP.S) : nouvelle image toutes les FPS_DIV VBL (compteur `_frclock` $466) : on attend FPS_DIV-1 VBL depuis la dernière image, Setscreen, puis Vsync (l'image change à cette VBL). Si une image a été en retard, l'image suivante fait plusieurs pas de jeu (`gsteps`, au plus MAX_STEPS) : la vitesse du jeu reste la même.
- `PARAMS.S` : FPS_DIV 2 (30 / s en VGA 60 Hz ; 25 / s en RGB/TV 50 Hz), MAX_STEPS 3. Les vitesses (SCROLL_SPD, SHIP_SPD…) sont maintenant par image à 30 / s.
- Mesure Hatari : FPS 30 stable (21 un court moment avec beaucoup d'ennemis : rattrapé par les pas en plus).
- Lien du dépôt STE (KiCad, sporniket) : github.com/sporniket/kicad-conversions--atari-ste-motherboard--c300780-001 (tag 1.0.0).
- Écrit sur le disque (md5 vérifiés) : SHOTEMUP.S c9ad113f…, PARAMS.S a3a95548…, SHOTEMUP.PRG 3b0c9095….

## 2026-11-13 — niveaux = évolution des Atari : sources des cartes mères
- Choix de Haltero : 4 niveaux dans l'ordre 130 XL, ST, STE, Falcon ; option 2 = grande échelle + défilement horizontal (la carte plus large que l'écran).
- 130 XE : github.com/pmandes/atari-130xe-replica (réplique CA200519, licence CC BY-NC-ND) : pas de KiCad, mais `bom/ibom.html` (InteractiveHtmlBom) : décodé par un LZString écrit par Claude → 315 composants (contours + pastilles), carte 324 x 204 mm, pas de pistes.
- 520 ST : github.com/sporniket/kicad-conversions--atari-260-520-st-motherboard--c070231 : `motherboard.kicad_pcb` 352 composants, 13 570 segments (PCB pas fini mais suffisant pour un décor).
- STE : github.com/sporniket/kicad-conversions--atari-ste-motherboard--c300780-001 (1.0.0) : `motherboard.kicad_pcb` 576 composants, 12 443 segments, carte ~430 x 245 mm.
- Falcon 030 : Re-Falcon (re-falcon.com, Steve Suavek) : github.com/eskwadrat/ReFalcon : Gerbers (cuivre dessus GTL, sérigraphie GTO…) + Pick & Place (840 composants, positions en mil). Licence « ReFalcon Educational & Non-Commercial License v1.0 » : œuvres dérivées non commerciales permises, avec attribution « ReFalcon — Atari Falcon 030 Recreation Project, Created by Steve Suavek » et la licence jointe → à mettre dans le jeu (crédits) et LISEZMOI.
- Prochaine étape : défilement horizontal (VIDEL : lignes plus larges que l'écran) + convertisseur outils\PCB2MAP.PY (kicad_pcb / ibom / gerber + pick&place → LEVELn.MAP), puis LEVEL1..4.

## 2026-11-13 — menu des 4 niveaux + défilement horizontal (cartes plus larges que l'écran)
- Les 4 cartes (130 XE, 520 ST, STE, Falcon) sont confiées à un agent (copie séparée /root/w/maps : PCB2MAP.PY, thèmes de tuiles, LEVEL1..4.MAP, CREDITS.TXT) ; Claude les intègre et les transfère ensuite.
- Défilement horizontal matériel : les buffers ont des lignes de LINEB = 1600 octets (800 pixels) ; le VIDEL saute (LINEB-640)/2 mots après chaque ligne ($FFFF820E, 9 bits → 40 colonnes max = MAP_MAXCOLS) ; l'écran affiché = ligne (gpos mod RING) + colonne camx. Caméra : la place du vaisseau sur l'écran donne la place sur la carte (camx = (px + SHIP_XMAX) * cam_max / (2 * SHIP_XMAX)). Les ennemis, tirs, HUD restent en coordonnées écran. Remis à 0 en quittant.
- Mémoire : 3 buffers 736 x 1600 = 3,5 Mo + tmpbuf 384 Ko : le mode 4 Mo reste à faire (repli : moins de colonnes / moins de lignes préparées).
- CARTE.S : `SIZE <cols> <rows>` (16 à 40 colonnes, lignes rangées tous les MAP_MAXCOLS octets), `THEME a8|st|ste|falcon` → tuiles PCBTA8.BIN / PCBTST.BIN / PCBTSTE.BIN / PCBTF30.BIN lues sur le disque (sinon PCBTILES.BIN assemblé dans le programme) ; nom LEVELn.MAP selon cur_level ; cam_max = largeur - 320.
- COMPOS.S : cuisson avec la vue de la caméra du moment, décalée pour que tout le composant soit dans l'écran (bk_vx), puis copié à sa colonne dans G ; tmpbuf de LINEB x 240.
- SOL.S : copie de lignes de LINEB octets, gnd_line sur map_cols tuiles, rectangles d'effacement en colonnes absolues (+ camx).
- MENU.S (nouveau, comme MENUS.S de RICK3D) : titre, « THE EVOLUTION OF THE ATARI », 1 ATARI 130 XE 1985 / 2 ATARI 520 ST 1985 / 3 ATARI STE 1989 / 4 FALCON 030 1992 (gris + NO MAP si LEVELn.MAP absent, Fsfirst), flèches / manette, ESPACE / RETURN / feu = jouer, ESC = quitter ; crédits des cartes (pmandes, sporniket, ReFalcon / Steve Suavek). Police TOS 6x6 agrandie (big_text). Couleurs MNC_* (avec -nocase, un equ ne doit pas porter le nom d'un label : MN_TITLE / mn_title).
- Déroulé : menu → niveau choisi (game_new + level_reset) → fin de carte = niveau suivant (après le 4 : menu) ; game over → menu ; ESC en jeu → menu.
- Vérifié dans Hatari (captures regardées) avec LEVEL1.MAP (16 colonnes) et une carte de test de 40 colonnes : menu, choix du niveau 3, défilement horizontal à droite et à gauche, retour au menu par ESC ; 28-30 FPS.
- Écrit sur le disque (md5 vérifiés) : SHOTEMUP.S 28ac02d0…, SOL.S ca153e8e…, CARTE.S bbffb580…, COMPOS.S 44cf4242…, PARAMS.S 1d0bfd68…, MENU.S 56d272e1…, SHOTEMUP.PRG 44c155cd…, tools\tests\menu.cmd.

## 2026-11-13 — les 4 cartes réelles (agent) intégrées
- Agent (copie séparée /root/w/maps) : `outils\PCB2MAP.PY` (KiCad .kicad_pcb, iBOM .html/.json, Gerber + pick & place → .MAP ; options --scale --cols --max --png --tiles), `outils\CHECKMAP.PY` (vérifie le format), `outils\lzs.py`, `outils\MKTILES.PY` (thèmes a8, st, ste, falcon en plus de classic).
- LEVEL1.MAP 130 XE (thème a8, 40 x 82, 4 mm/tuile, 118 composants, pistes inventées : l'iBOM n'en a pas) ; LEVEL2.MAP 520 ST (st, 40 x 99, 4,5 mm, 143 composants, vraies pistes) ; LEVEL3.MAP STE (ste, 40 x 98, 4,5 mm, 141 composants, vraies pistes) ; LEVEL4.MAP Falcon 030 (falcon, 40 x 98, 4,5 mm, 141 composants dont 68030 F, DSP, 10 QFP ; pistes du Gerber GTL). Grand côté vertical, bande de 40 colonnes avec les grosses puces ; petits condensateurs omis (≈1,6 composant par ligne).
- Tuiles : PCBTA8.BIN (vert-beige 8 bits), PCBTST.BIN, PCBTSTE.BIN, PCBTF30.BIN.
- Vérifié dans Hatari (captures regardées) : les 4 niveaux se lancent depuis le menu, thèmes et composants corrects, défilement horizontal, 28-30 FPS.
- Ancienne carte générée (façon Falcon, 16 colonnes) gardée sous FALCGEN.MAP.
- Crédits : à la demande de Haltero, retirés de l'écran du menu ; CREDITS.TXT + REFALCON.LIC gardés dans le dossier (la licence ReFalcon demande l'attribution et la licence jointe si le jeu est diffusé ; la réplique 130 XE est en CC BY-NC-ND : pas d'œuvre dérivée diffusée sans l'accord de pmandes ; ce sont les fichiers de ces recréations récentes qui sont repris, pas les cartes d'Atari).
- Restes : LEVEL1 a une bande presque vide (lignes 45-50) ; beaucoup de vias sur ST/STE/Falcon ; 68030 collé au bord gauche ; mode 4 Mo à faire ; éditeur à mettre à jour (largeur 40, thèmes, LEVELn).
- Écrit sur le disque (md5 vérifiés) : LEVEL1..4.MAP, PCBTA8/ST/STE/F30.BIN, CREDITS.TXT, REFALCON.LIC, MENU.S 641cdcc3…, SHOTEMUP.PRG 1fc5f008…, outils\PCB2MAP.PY, CHECKMAP.PY, lzs.py, MKTILES.PY, tools\tests\lv3.cmd, FALCGEN.MAP.

## 2026-11-13 — le jeu s'appelle XVOLUTION
- MENU.S : titre « XVOLUTION » (recentré : 9 lettres). Vérifié dans Hatari (capture regardée).
- Les noms de fichiers (SHOTEMUP.S / .PRG / .LOG, dossier ShotEmUp) restent inchangés pour l'instant.
- Écrit sur le disque (md5 vérifiés) : MENU.S, SHOTEMUP.PRG.

## 2026-11-13 — tout renommé en XVOLUTION
- Dossier `Documents\ChatGPT\ShotEmUp` → `Documents\ChatGPT\Xvolution`.
- SHOTEMUP.S → XVOLUTION.S, .PRG, .LOG (nom écrit par PROFIL.S), .BAK ; ShotEmUp.bat → Xvolution.bat (lance XVOLUTION.PRG, -asm assemble XVOLUTION.S).
- CLAUDE.md, CREDITS.TXT, LISEZMOI.TXT : nom mis à jour. Journal du projet claude.ai : `XVOLUTION/JOURNAL.MD`.
- Vérifié dans Hatari (capture regardée) : jeu à 30 FPS, XVOLUTION.LOG écrit.
- Les commentaires de outils\*.PY / EDITEUR.HTML citent encore SHOTEMUP (sans effet).

## 2026-11-13 — éditeur de carte mis à jour (40 colonnes, thèmes, LEVEL1..4)
- `outils\EDITEUR.HTML` (+ EDITEUR.SRC.HTML) : lit et écrit `THEME` et `SIZE <colonnes> <lignes>` ; 16 à 40 colonnes (bouton Appliquer : ajoute / retire à droite) ; choix du thème a8 / st / ste / falcon / classique (tuiles PCBTA8/ST/STE/F30 intégrées, palette redessinée) ; enregistrer sous LEVEL1..4.MAP (le nom suit le fichier ouvert) ; cadre jaune = écran 320 x 240 du jeu, perspective 3D centrée sur la vue ; titre XVOLUTION. Ouvre LEVEL4.MAP par défaut.
- Vérifié dans Chrome (captures regardées) : LEVEL4 (falcon) et LEVEL1 (a8, 40 x 82, 118 composants) ; ouvrir puis enregistrer LEVEL1.MAP redonne exactement la même carte.
- Écrit sur le disque (md5 vérifiés) : outils\EDITEUR.HTML c9222152…, outils\EDITEUR.SRC.HTML 0c8b7cec….

## 2026-11-13 — cartes sans recadrage (option 2 : échelle agrandie)
- Constat de Haltero : 68030 invisible sur LEVEL4 (collé au bord gauche, la bande de 40 colonnes coupait 16 colonnes du PCB).
- Sens des cartes : PCB tourné de 90° dans le sens des aiguilles d'une montre : côté gauche du PCB = haut de la carte (fin du niveau), côté droit = bas (départ), bord haut du PCB = gauche, bord bas = droite.
- PCB2MAP.PY relancé avec une échelle qui fait tenir tout le circuit en largeur (plus de recadrage) : LEVEL1 130 XE 5,25 mm/tuile 39 x 62, 126 composants ; LEVEL2 520 ST 5,2 mm 40 x 86, 144 ; LEVEL3 STE 6,35 mm 40 x 70, 135 ; LEVEL4 Falcon 6,35 mm 40 x 70, 135 (68030 F colonne 11 ligne 15). --max relevé pour garder ~2 composants par ligne. CHECKMAP OK.
- Anciennes cartes gardées dans `anciennes_cartes\`. L'éditeur ouvre la nouvelle LEVEL4 par défaut.
- Vérifié dans Hatari (captures regardées) : cartes chargées, défilement horizontal, 28-30 FPS.
- Écrit sur le disque (md5 vérifiés) : LEVEL1.MAP 3dedf10f…, LEVEL2.MAP 3e5bf44a…, LEVEL3.MAP 73c5bef2…, LEVEL4.MAP f185a2a1…, outils\EDITEUR.HTML c7ad2f5b….

## 2026-11-13 — LEVEL2 (520 ST) à la même échelle que STE et Falcon
- Demande de Haltero : en vrai, la carte du ST a la même longueur que celles du STE et du Falcon.
- LEVEL2.MAP régénéré à 6,35 mm/tuile (comme LEVEL3 et LEVEL4) : 32 x 70 (même longueur, 70 lignes ; moins large, c'est sa vraie largeur), 135 composants. CHECKMAP OK.
- Vérifié dans Hatari (captures regardées) : 30 FPS, défilement horizontal.
- Écrit sur le disque (md5 vérifié) : LEVEL2.MAP dc0fe1de….

## 2026-11-13 — niveau 1 = Atari 800 XL (vraie carte avec pistes)
- Recherche : bit-preserve (baldengineer, CC BY 4.0) n'a que le schéma du 800XL (PCB vide) ; « Atari 800XL PCB remake » v1.1 de Marek L (ezcontents.org, github.com/marekl123/atari800xl, CC BY-SA 2.0) a les Gerbers (cuivre dessus, contour, perçages), sans fichier de placement.
- Nouveau `outils\GERB2MAP.PY` (utilise PCB2MAP.PY) : Gerbers KiCad + Excellon → .MAP ; composants trouvés par les trous : 2 rangées parallèles au pas de 2,54 mm (écart 7,62 / 10,16 / 15,24) = DIP, rangée seule = connecteur, 2 trous = résistance / condensateur, gros trous groupés = prises. Trouvé : 5 DIP-40 (6502 SALLY, ANTIC, GTIA, POKEY, PIA), 8 + 7 DIP-16 (RAM…), 28/24/20/14/8, 216 condensateurs, 70 résistances ; carte 391 x 232 mm.
- LEVEL1.MAP : thème a8, 6,35 mm/tuile (même échelle que ST, STE, Falcon), 37 x 62, 135 composants, vraies pistes. CHECKMAP OK.
- MENU.S : « 1  ATARI 800 XL   1983 ». CREDITS.TXT : section LEVEL1 = 800XL de Marek L (CC BY-SA 2.0) ; l'ancienne carte 130 XE (CC BY-NC-ND) n'est plus utilisée, gardée dans anciennes_cartes\LEVEL1_130XE.MAP.
- Vérifié dans Hatari (captures regardées) : menu, niveau 1, défilement horizontal, 28-30 FPS.
- Écrit sur le disque (md5 vérifiés) : LEVEL1.MAP 34d6a560…, MENU.S cf0b6069…, XVOLUTION.PRG a44814e8…, outils\GERB2MAP.PY c298c43d…, CREDITS.TXT 39cc2b68….

## 2026-11-13 — noms des processeurs, puces spéciales et ROM écrits sur les cartes
- Format .MAP : `C <type> <col> <ligne> [nom]` (11 caractères max, `_` = espace). CARTE.S les garde dans `comp_lbl` (MAXCOMP x LBL_LEN 12).
- COMPOS.S : `comp_label` (appelé après comp_draw dans bake_one) écrit le nom avec la police TOS 6x6 sur le dessus de la puce, sur une bande sombre (LBL_BG), au centre du dessus vu à la profondeur LBL_Z 386 (68030 : LBL_ZF 331, dessus du ventilateur) ; puce plus haute que large : écrit de bas en haut comme sur les vraies. PARAMS.S : LBL_LEN, LBL_COL, LBL_BG, LBL_Z, LBL_ZF.
- PCB2MAP.PY : `chip_name` (table NAMES) donne le nom d'après la valeur KiCad / le Comment du pick & place : 68000, 68030, 68882, DSP56001, BLITTER, GST_MCU, SHIFTER, MMU, GLUE, COMBEL, VIDEL, SDMA, DMA, YM2149, MFP_68901, WD1772, AJAX, TOS_ROM… ; GERB2MAP.PY : option `--names outils\800XL.NAMES` (x y nom, lus sur la sérigraphie : U17 GTIA, U7 ANTIC, U8 6502C, U23 PIA, U22 POKEY, U5 OS_ROM, U4 BASIC_ROM ; ordre confirmé par Antic juin 1984). CHECKMAP.PY accepte le 5e champ.
- Cartes régénérées (même géométrie, noms en plus) : LEVEL1 7 noms, LEVEL2 14, LEVEL3 10, LEVEL4 9.
- Éditeur : garde les noms, les affiche sur les puces (comme le jeu), double-clic sur un composant = changer son nom.
- Vérifié (captures regardées) : Hatari niveaux 1, 2, 4 (OS ROM, BASIC ROM, SHIFTER, DSP56001, SDMA, 68882, COMBEL, 68030) 28-31 FPS ; Chrome : éditeur, ouvrir / enregistrer LEVEL1 identique.
- Écrit sur le disque (md5 vérifiés) : CARTE.S d4269c10…, COMPOS.S 25722bbe…, PARAMS.S c80663e1…, XVOLUTION.PRG 510dcd88…, LEVEL1.MAP ac70d878…, LEVEL2.MAP e9642d88…, LEVEL3.MAP 6b54ad14…, LEVEL4.MAP 681abd50…, outils\PCB2MAP.PY 036e4278…, CHECKMAP.PY 2c8dc370…, GERB2MAP.PY 2c3f7cb7…, 800XL.NAMES 54916295…, EDITEUR.HTML 137759e7…, EDITEUR.SRC.HTML f39f9c10….

## 2026-11-13 — plus de marques grises en relief sur les puces
- Demande de Haltero : pas d'extrusion sur les composants = les parties grises (repère de la broche 1 et barre de marquage au milieu, petites boîtes col_mark en relief).
- COMPOS.S : les 8 boîtes col_mark retirées des modèles (processeur, mémoire, QFP, moyeu du ventilateur du 68030, DIP, SOIC) ; les pattes (col_tin) restent. Éditeur : boîtes 'mark' retirées aussi.
- Vérifié dans Hatari (captures regardées) : niveau Falcon, 29-31 FPS, noms toujours lisibles.
- Écrit sur le disque (md5 vérifiés) : COMPOS.S 8f7611ed…, XVOLUTION.PRG be6b6596…, outils\EDITEUR.HTML 2e0aeb16…, outils\EDITEUR.SRC.HTML 710b7bfb….

## 2026-11-13 — 68030 sans ventilateur
- Demande de Haltero : on ne voyait pas que c'était un ventilateur → le 68030 (type F) est maintenant une puce QFP noire avec ses pattes (même forme que Q), nom « 68030 » dessus. COMPOS.S mdl_fan ; PARAMS.S LBL_ZF 386 ; éditeur pareil (« 68030 » dans la palette).
- Vérifié dans Hatari (capture regardée) : niveau Falcon, 29 FPS.
- Écrit sur le disque (md5 vérifiés) : COMPOS.S 83c25ab3…, PARAMS.S c67f7417…, XVOLUTION.PRG eb180b36…, outils\EDITEUR.HTML cc768685…, outils\EDITEUR.SRC.HTML e108f397….

## 2026-11-13 — défilement ralenti + arrêts boss sur les grosses puces
- Demande de Haltero : niveaux trop courts ; garder le circuit entier ; choix : ralentissement + arrêts boss.
- Défilement : PARAMS.S `SCROLL_SPD8` (1/256 de pixel par image, 256 = 1 pixel ; avant 2 pixels) ; XVOLUTION.S `scr_acc` garde le reste. Niveau de 70 lignes : ~39 s de défilement (avant ~20 s), plus les combats.
- BOSS.S (nouveau) : un composant dont le nom commence par `*` dans LEVELn.MAP est un boss. Quand son centre arrive à la ligne BOSS_Y, le sol s'arrête (boss_check avant le défilement), plus de nouveaux ennemis, la puce tire (visé sur le vaisseau toutes les BOSS_FIRE_T images, éventail de 5 à chaque 3e salve ; tirs orange `ebuls`, monde x16) ; les tirs du joueur dans son rectangle (sol → plan du vaisseau) lui enlèvent 1 point sur BOSS_HP 60 (barre de vie rouge en haut avec son nom, flash blanc) ; détruit : +PTS_BOSS 5000, « xxx DESTROYED », le sol repart. Un tir boss = player_hit. PARAMS.S : MAXBOSS, BOSS_Y, BOSS_HP, BOSS_FIRE_T, PTS_BOSS, BOSS_MSG_T, MAXEB, EB_SPD, EB_R, EB_COL, BAR_X0, BAR_W, BAR_Y. (Avec -nocase : label boss_life, pas boss_hp = BOSS_HP.)
- COMPOS.S : le `*` n'est pas écrit sur la puce.
- Boss posés : LEVEL1 *6502C, *ANTIC ; LEVEL2 *SHIFTER, *68000 ; LEVEL3 *68000, *SHIFTER ; LEVEL4 *VIDEL, *68030 (pas le DSP : trop près du départ).
- Éditeur : `*` devant le nom = boss (cadre rouge « BOSS »), expliqué dans la fenêtre du double-clic.
- Vérifié dans Hatari (captures regardées ; version de test à 99 vies, non transférée) : arrêt sur le 6502C, barre qui descend, tirs orange, « 6502C DESTROYED », le sol repart, 2e boss ANTIC ; 30 FPS. Chrome : éditeur, cadre BOSS, ouvrir / enregistrer LEVEL4 identique.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 188a9cc2…, PARAMS.S 1c14a685…, COMPOS.S 7693b96a…, BOSS.S 4a4cba05…, XVOLUTION.PRG 14552125…, LEVEL1.MAP 42326f73…, LEVEL2.MAP 135775bd…, LEVEL3.MAP 2ef176a6…, LEVEL4.MAP 5e475255…, outils\EDITEUR.HTML c6aa572e…, outils\EDITEUR.SRC.HTML e574564c….
- Restes : rg-asm sur le PC doit trouver BOSS.S (même dossier) ; pas encore d'explosion ni de puce « brûlée » après la victoire ; réglage de la difficulté à faire en jouant.

## 2026-11-13 — « DEBUGGED » au lieu de « DESTROYED » + effets sonores YM2149
- Demande de Haltero : pas « DESTROYED » (pas positif pour les fans Atari ; c'est comme enlever un virus ou un bug) → BOSS.S : « xxx DEBUGGED ».
- SFX.S (nouveau) : effets sur le YM2149 (registres $FFFF8800/8802, interruptions coupées autour de chaque registre ; bits 6-7 du registre 7 gardés). Canal A = tirs du vaisseau, B = explosions / vaisseau touché, C = bonus et boss. Effet = canal, priorité, durée, période + variation (ou liste de notes = arpège), volume x16 + baisse, bruit. `sfx_update` une fois par pas de jeu (30 / s). Effets : SHOT (« piou »), BOOM (bruit), HIT (grondement + bruit), BONUS (arpège montant), ALARM (sirène à l'arrivée d'un boss), BHIT (tic sur la puce), BSHOT (tir du boss), FIXED (petit air quand la puce est « débuguée »).
- `sfx_init` (Soundcmd : ADCINPUT = PSG, ADDERIN = ADC + matrice, anciennes valeurs gardées) / `sfx_exit` (rendues en quittant) ; `sfx_off` au menu, en pause et en quittant.
- PARAMS.S : macro `SFX n` (garde les registres) + numéros SFX_SHOT..SFX_FIXED (avant leur usage). Appels : upd_player (tirs), kill_enemy, player_hit, ramassage du bonus, BOSS.S (arrivée, touché, tir, débugué).
- Vérifié dans Hatari avec le son enregistré en WAV (hatari-shortcut recsound) : tirs, explosions, combat de boss ; « 6502C DEBUGGED » vu (capture regardée) ; 30 FPS.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 7d76f806…, PARAMS.S 612f4e4b…, BOSS.S 204591de…, SFX.S 308b8ef2…, XVOLUTION.PRG 8e5bd7ef….
- Pour rg-asm sur le PC : SFX.S et BOSS.S dans le même dossier que XVOLUTION.S.

## 2026-11-13 — musiques : ELYSIUM.MOD (DSP) en jeu, PWRBOAT.ORG (YM) au menu
- Haltero a ajouté `ZIK\` (ELYSIUM.MOD : module 4 voies « elysium » de Jester / Sanity ; PWRBOAT.ORG : musique YM avec son code de lecture 68000). Choix : MOD en jeu, YM au menu.
- MUSIQUE.S (nouveau, d'après MUSIQUE.S de RICK3D) : `mus_init` (après d3dinit : MGTK_Save_Sound, MGTK_Init_Sound, REPFREQ 2 = 32780 Hz, module en boucle, ZIK\ELYSIUM.MOD chargé par Mxalloc + MGTK_Init_Module_Samples) ; `mus_play` au début d'un niveau (continue d'un niveau à l'autre), `mus_stop` au menu, `mus_exit` (MGTK_Restore_Sound) en quittant. Le DSP fait à la fois la musique et la 3D (comme RICK3D).
- Musique YM du menu : PWRBOAT.ORG lu dans `ymz_buf` (+0 init d0 = YMZ_TUNE, +4 arrêt, +8 lecture à 50 Hz, appelée dans la file VBL $456, 5 VBL sur 6 en VGA 60 Hz). Elle écrit le YM par `movem.l` vers $FFFF8800 et $FFFF8840 (registres miroirs du ST, absents sur Falcon : erreur de bus) → ces 2 endroits sont remplacés au chargement par `jmp ymw4` / `jmp ymw11` qui écrivent les mêmes paires registre / valeur une par une (vérifié avant de modifier).
- XVOLUTION.S : Mshrink au démarrage (comme RICK3D ; sans lui, Mxalloc du module échouait) ; mus_init avant sfx_init ; menu : mus_stop + ymz_start / ymz_stop ; level_start : mus_play ; sortie : sfx_exit puis mus_exit. SFX.S : `sfx_route` (YM remis dans la sortie après le démarrage du module). PARAMS.S : MUS_VOL 24, REPFREQ, WORKSZ, YMZ_MAX, YMZ_TUNE.
- Vérifié dans Hatari, son enregistré en WAV : YM au menu, module + bruitages en jeu, YM de nouveau au menu ; 30 FPS en jeu avec la 3D DSP (captures regardées).
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 44fe1966…, PARAMS.S 788048ab…, SFX.S d4dac8a2…, MUSIQUE.S c71c3fdf…, XVOLUTION.PRG c165655c….
- Droits : Elysium est de Jester (Volker Tripp, Sanity) ; le texte du module demande de le contacter pour l'utiliser dans une production. Auteur de PWRBOAT.ORG à identifier. À régler avant une diffusion publique.

## 2026-11-13 — PWRBOAT.ORG : infos de 3Dreams
- D'après 3Dreams (LISEZMOI.md, 3DREAMS.S) : PWRBOAT.ORG = bloc COSO de Jochen Hippel (Mad Max), lecteur + musique de l'intro Power Boat, copié de la mémoire ; +0 init (d0 = 1 : air 1, d0 = 0 : arrêt), +8 lecture à 50 Hz (3Dreams : Timer A ; ici : file VBL, 5 VBL sur 6 en VGA).
- MUSIQUE.S : l'arrêt se fait maintenant par init avec d0 = 0 (avant : appel de +4, qui n'est pas l'arrêt documenté) ; commentaires mis à jour.
- CREDITS.TXT : section MUSIC (Elysium de Jester / Sanity, demande de contact ; Power Boat de Jochen Hippel / Mad Max, lecteur COSO, corrigé pour le Falcon au chargement).
- Vérifié dans Hatari, son enregistré : menu YM → niveau (module + bruitages) → menu YM.
- Écrit sur le disque (md5 vérifiés) : MUSIQUE.S b5f4a37a…, XVOLUTION.PRG b601be48…, CREDITS.TXT aaf0c9d6….

## 2026-11-13 — menu sans « THE EVOLUTION OF THE ATARI »
- Demande de Haltero : phrase retirée du menu (MENU.S : appel big_text et chaîne mn_sub enlevés).
- Vérifié dans Hatari (capture regardée).
- Écrit sur le disque (md5 vérifiés) : MENU.S df6adf5e…, XVOLUTION.PRG b83acbbb….

## 2026-11-13 — vaisseau = logo Atari (comme l'objet ATARI de 3Dreams)
- Demande de Haltero : le vaisseau ressemble à l'objet Atari de 3Dreams (07ATARI.OBJ : logo Fuji, 62 sommets, 55 faces, 3 pièces) ; forme 1 tout blanc, forme 2 barre centrale blanche + 2 côtés rouges, forme 3 tout rouge ; moins de faces.
- XVOLUTION.S : mdl_f0 / mdl_f1 / mdl_f2 = même logo en 9 boîtes (barre centrale -3..3 x -22..22, z 1..10 ; chaque bras en 4 marches du haut étroit vers l'évasement à l'arrière, z 2..9), d'après les contours de 07ATARI.OBJ (÷ ~1,9) ; nouvelle couleur col_white ($FFFF, côtés plus sombres) ; col_red pour le rouge. Anciens modèles (sonde, chasseur, lourd) remplacés.
- Vérifié dans Hatari avec 3 versions de test qui commencent chacune avec une forme (non transférées) : blanc, centre blanc + bras rouges, tout rouge ; logo reconnaissable (captures regardées) ; 30 FPS.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S cfbebb7f…, XVOLUTION.PRG a374fb8c….

## 2026-11-13 — 6 effets graphiques (EFFETS.S)
- Demande de Haltero : toutes les idées proposées.
- EFFETS.S (nouveau) : `blend_rect` (rectangle mélangé à 50 % avec une couleur, 2 pixels par mot long ; couleur 0 = ombre) ; particules (MAXP 64 : débris + flash) ; ombre du vaisseau ; impulsions sur les pistes ; puces débuguées.
  1. Puce débuguée : flash blanc + SPARK_N étincelles bleues au centre ; ensuite halo vert (FIX_COL, mélangé) autour de la puce + LED verte qui clignote en haut à droite (`boss_fixed`, BOSS.S boss_kill). Petites étincelles à chaque tir qui touche le boss.
  2. Explosions : ennemi abattu = flash + 12 débris (orange, jaune, blanc, gris) ralentis ; vaisseau touché = 16 débris rouges.
  3. Ombre : le logo projeté sur la carte (décalage SH_DX / SH_DY, profondeur SH_Z), sol assombri à 50 %.
  4. Tirs lumineux : tirs du joueur = halo jaune + traînée orange ; tirs des boss = halo rouge, cœur orange, centre jaune.
  5. Ennemis Atari : drone = manette CX40 ou cartouche (une sur deux), croiseur = disquette 3,5" bleue (volet métal, étiquette). Couleurs col_black, col_disk.
  6. Impulsions : `pulse_init` note les pistes droites (`|` et `-`, PULSE_MIN tuiles ou plus, pas sous un composant) ; NPULSE impulsions (tête blanche + traînée cyan PULSE_LEN) partent au hasard sur les pistes visibles.
- SOL.S : MAXDR 200 rectangles à effacer par écran (au lieu de 96). PARAMS.S : section « graphic effects ».
- Vérifié dans Hatari (captures regardées, version de test à 9 vies et boss à 10 points, non transférée) : explosions, ombre, halos des tirs, manettes / cartouches / disquettes, impulsions, « 6502C DEBUGGED » avec flash + étincelles puis halo vert + LED qui suit le défilement. 27-30 FPS en scène calme, 20-23 dans les scènes chargées (sans les effets 28-31) : la vitesse du jeu reste la même (pas en plus).
- Note : une version de test à 99 vies dessine les carrés des vies hors du HUD (traînées vertes) : prendre 9 vies pour les tests.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 7299652a…, EFFETS.S dc8447a2… (nouveau), BOSS.S caad9a15…, PARAMS.S f4f01144…, SOL.S bfa1ed88…, XVOLUTION.PRG 3807669e…. Pour rg-asm : EFFETS.S dans le même dossier.

## 2026-11-14 — vaisseau plus petit, disquettes moins dures
- Demande de Haltero : vaisseau trop gros et trop pixelisé ; disquettes trop dures à tuer.
- XVOLUTION.S : logo des 3 formes réduit (~0,7 : 40 x 30 au lieu de 56 x 44, épaisseur z 2..7 / centre 1..8), mêmes 9 boîtes ; l'ombre suit.
- PARAMS.S : EN_HP1 3 → 2 (disquette : 2 tirs).
- Vérifié dans Hatari (captures regardées) : vaisseau plus petit, ombre, 30 FPS en scène calme.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 0f66711c…, PARAMS.S 9cdd3ea5…, XVOLUTION.PRG 5d2036a1….

## 2026-11-14 — log du vrai Falcon + capture par la touche S
- Log de Haltero sur un **vrai Falcon 030** (scène longue, 9 boîtes = le vaisseau seul) : SOL 17 ms, SHP 9, HUD 11,6, ENM 3, BUL 2,7, 20 FPS ; même scène dans Hatari (Xvolution.bat, 16 MHz cycle exact) : SOL 8-10, SHP 3,5, HUD 6, 30 FPS → le vrai Falcon est ~2 fois plus lent que Hatari : mesurer sur la vraie machine. Les effets (ENM / BUL) coûtent peu ; à gagner : HUD (barre du bas), SOL (recopie), SHP (9 boîtes).
- Demande : la capture se lance avec S ; barre du bas cachée pendant la capture.
- PROFIL.S : `prof_start` (log remis à l'en-tête, pr_rec = 1), `prof_stop` (pr_rec = 0 + XVOLUTION.LOG écrit), `prof_clear` ; une ligne toutes les 32 images seulement pendant la capture ; en-tête : ligne « capture : S = start… ». XVOLUTION.S : KEY_S $1F ; S = départ (txt_hidden gardé dans pr_bar puis barre cachée, son BONUS) / S de nouveau = arrêt (fichier écrit, barre remise, son FIXED) ; en quittant le programme : prof_stop (écrit seulement si une capture tourne) ; L = écrire tout de suite (inchangé).
- Vérifié dans Hatari (captures regardées) : barre cachée pendant la capture (HUD 3,8 → 0,5 ms), revenue après, XVOLUTION.LOG avec 6 lignes.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 70e3cbda…, PROFIL.S 3b7f4bb9…, XVOLUTION.PRG fd74df3e….

## 2026-11-14 — 2e log du vrai Falcon : vaisseau précalculé + volume + / -
- Log Falcon (capture S, barre cachée) : calme SOL 9-11 ms, SHP 3-4, 30 FPS ; vagues d'ennemis SOL 15-18, ENM 9-16, SHP 7-9, 17-21 FPS ; boss (vaisseau seul) SOL 13, BUL 6-10, SHP 7-9 → ~34 ms : juste au-dessus des 33 ms d'une image à 30 / s, d'où 20 FPS. Pics LOG 84 ms : changements de niveau.
- Vaisseau précalculé (EFFETS.S) : `ship_prerender` au démarrage dessine le modèle 3D (DSP) une fois par forme et par place (5 en x : SPR_DX 58, 3 en y : -70 / 0 / 80, SPR_Y01 / SPR_Y12) dans tmpbuf sur fond BK_KEY, garde le rectangle utile (spr_tab : ptr w h offx offy, spr_pool) ; `ship_sprite` copie le plus proche (pixels clé sautés, découpe aux bords, add_rect). Mode 030 (touche D) : le modèle comme avant. Hatari : SHP 3,5 → 0,7-1,4 ms (sur le Falcon on attend ~8 → ~3 ms).
- Volume comme 3Dreams (SFX.S) : touches + / - (pavé numérique $4E / $4A + les touches qui donnent + et - dans les tables du clavier, Keytbl), 17 niveaux 0..16, VOL_START 15 ; atténuation de sortie du codec $FFFF893A (16 - niveau, 1,5 dB par pas) sur tout (module DSP + YM) ; niveau 0 = module à 0 et bruitages YM coupés ; ancienne valeur rendue en quittant (vol_exit). En jeu : barre de 16 cases en haut pendant VOL_T images ; au menu aussi (sans barre). PARAMS.S : SPR_DX, SPR_Y01, SPR_Y12, VOL_START, VOL_T.
- Vérifié dans Hatari (captures regardées) : vaisseau à gauche / droite / en haut, ombre, barre de volume (15 → 13 après 2 fois -), 30 FPS.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S cc0401f9…, EFFETS.S e3c68510…, SFX.S 8bbed2d7…, MENU.S 33ffe47e…, PARAMS.S f6cd2ed3…, XVOLUTION.PRG 9704e36e….

## 2026-11-14 — volume sur l'échelle de 3Dreams (0..64)
- Précision de Haltero : 15 sur 64 (ou 16) → VOL_START 16, volume 0..64 par pas de 4 (+ / -) comme 3Dreams ; atténuation du codec (64 - volume) / 4 (16 → 12 = -18 dB) ; barre : case i pleine si volume > 4 i (16 → 4 cases).
- Vérifié dans Hatari (capture regardée) : 16 + 4 = 20 → 5 cases pleines.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S eea96830…, SFX.S 22e55bd8…, PARAMS.S 39818141…, XVOLUTION.PRG 9589c31b….

## 2026-11-14 — volume : bruitages jamais sous le niveau de départ
- Demande de Haltero : les bruitages ont une valeur fixe (sinon on ne les entend pas), mais montent avec le volume quand on l'augmente.
- SFX.S vol_apply : à partir de VOL_FLOOR 16 (le départ), atténuation du codec (64 - volume) / 4 sur toute la sortie : musique et bruitages montent / baissent ensemble ; sous 16 : le codec reste au niveau de 16 (bruitages fixes) et seule la musique baisse (MGTK = MUS_VOL x volume / 16 ; 0 = musique coupée, bruitages toujours là ; vol_mute retiré). Au menu (vol_inmenu, mis par MENU.S à l'entrée, enlevé à la sortie) : la musique YM suit (64 - volume) / 4. PARAMS.S : VOL_FLOOR.
- Vérifié dans Hatari, son enregistré (WAV) en tirant : volume 16 RMS ~250, 48 ~1000 (×4, +12 dB), 0 ~115 (tirs seuls, musique coupée).
- Écrit sur le disque (md5 vérifiés) : SFX.S eb14f5f4…, MENU.S 7bcbfe3e…, PARAMS.S 7e5e5cf7…, XVOLUTION.PRG 09461b9f….

## 2026-11-14 — bande noire d'informations en haut
- Demande de Haltero : bande noire en haut avec score, vies et infos importantes (FPS, mode : capture du log, DSP / 030) sans gêner l'image (comme RICK3D).
- XVOLUTION.S draw_hud : bande TOP_H 16 lignes noire redessinée à chaque image après tout le reste (le sol défile en matériel, donc pas de « dessinée une fois » comme dans RICK3D) ; score (x 4), forme (barres jaunes x 60), vies (carrés verts x 88, 8 au plus), barre de volume (x 156, pendant VOL_T), PAUSE, REC rouge clignotant pendant la capture S, DSP / 030, FPS (orange sous 28) + « FPS ». Nouvelle routine `btext` (police TOS 6x6, couleur au choix). Effacement : seulement les TOP_RS 8 dernières lignes de la bande (elle ne descend que du défilement). La barre du bas (H) reste pour le détail.
- PARAMS.S : TOP_H, TOP_RS.
- Mesure Hatari : HUD 0,5 → 2,3 ms (remplissage de la bande + textes), SOL -1 ms ; 30 FPS. Vérifié (captures regardées) : bande, REC, PAUSE, volume, pas de traînée sous la bande.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 20ff3c2d…, PARAMS.S 43246bb5…, XVOLUTION.PRG 36cad516….

## 2026-11-14 — bande du haut répétée sur le vrai Falcon : corrigé
- Constat de Haltero (vrai Falcon) : la bande noire apparaît plusieurs fois à l'écran.
- Cause : seules les 8 dernières lignes de la bande étaient effacées ; quand la caméra se décale (défilement horizontal), les morceaux de l'ancienne bande sortis de l'écran sur le côté restaient noirs et revenaient quand la caméra revenait.
- XVOLUTION.S : toute la bande (TOP_H lignes) est effacée à chaque fois ; PARAMS.S : TOP_RS retiré.
- Vérifié dans Hatari (captures regardées) : caméra à gauche, à droite puis de nouveau à gauche : une seule bande.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 0bd5e1c3…, PARAMS.S d091acea…, XVOLUTION.PRG fe413d6a….

## 2026-11-14 — 3e log du vrai Falcon ; bruitages à 50 % ; halos des tirs du boss plus petits
- Log Falcon : vaisseau précalculé SHP 2-3 ms (avant 7-9) ; bande du haut HUD ~4,2 ms ; boss : SOL 15-17, BUL 6-10, total ~35 ms → encore 20 FPS ; vagues : SOL 20-33, ENM 10-19, 15-20 FPS.
- Constat de Haltero : on n'entend pas les bruitages ; les mettre à 50 %.
- PARAMS.S : VOL_FLOOR 16 → 48 : sous 48 le codec reste à -6 dB (50 %) → bruitages fixes à 50 % ; au départ (16) la musique est à 16/48 de MUS_VOL.
- BOSS.S : tirs du boss : halo 7 x 7 au lieu de 11 x 11 (coeur 5 x 5, centre 3 x 3) → BUL plus léger.
- Vérifié dans Hatari : son enregistré (WAV) : volume 16 RMS ~900-1100 (avant ~250), tirs seuls (volume 0) ~450 (avant ~115) ; combat du 6502C (captures regardées) : tirs du boss visibles, 29 FPS.
- Écrit sur le disque (md5 vérifiés) : BOSS.S 68767a7f…, PARAMS.S 78d6a5cb…, XVOLUTION.PRG d268cef2….

## 2026-11-14 — bruitages vraiment plus forts que la musique
- 4e log Falcon : boss ~35 ms (SOL 16, BUL 8-10 : surtout les tirs du joueur + explosions, HUD 4,2) → 20 FPS ; vagues SOL 30-38 ms (cuisson des composants) → 14-17 FPS. Propositions : A étaler la cuisson, B alléger les tirs du joueur, C bande du haut par coupure d'écran (Timer B).
- Constat de Haltero : on n'entend pas les bruitages pendant la musique.
- SFX.S : sfx_init règle le gain d'entrée du codec (Soundcmd LTGAIN / RTGAIN = SFX_GAIN 8 = +12 dB) pour le YM (ADC), anciens gains rendus par sfx_exit ; vol_apply : en jeu codec à 0 dB (bruitages toujours au maximum), + / - règlent la musique seule (MGTK = MUS_VOL x volume / 64 ; 16 au départ = 1/4) ; au menu inchangé (musique YM, (64 - volume) / 4). PARAMS.S : SFX_GAIN (VOL_FLOOR retiré).
- Vérifié dans Hatari, son enregistré : tirs seuls RMS ~1900 (avant ~450), musique seule au volume 16 ~550-850 : bruitages 2 à 3 fois plus forts que la musique (avant 2 fois plus faibles) ; crête 15 783 (pas de saturation).
- Écrit sur le disque (md5 vérifiés) : SFX.S c0c95e94…, PARAMS.S 3fadeeb4…, XVOLUTION.PRG 74eb39b3….

## 2026-11-14 — écran coupé pour la bande du haut (Timer B) + « recap » au lieu de « debug »
- Constat de Haltero (vrai Falcon) : la bande du haut bouge latéralement avec le vaisseau → couper l'écran. Thème : on ne parle plus de virus / bug mais de « recap » des vieux composants.
- COUPURE.S (nouveau) : la bande est dessinée dans son propre tampon (bandb0 / bandb1, un par écran, lignes de LINEB) ; à chaque VBL (file VBL, cut_vbl) l'adresse de base est écrite directement dans le VIDEL ($FFFF8201/03/0D, octet bas compris, au lieu de Setscreen) = tampon de la bande, et le Timer B (MFP, mode comptage, cut_n = TOP_H x CUT_LPL en VGA) est armé ; son interruption (cut_timerb, vecteur $120) écrit le compteur vidéo $FFFF8205/07/09 = image du circuit à sa ligne TOP_H. Touche C : coupure oui / non (CUT_DEF 1 au départ) ; sans coupure, la base est aussi écrite directement et la bande est dessinée dans l'image (comme avant). cut_install / cut_remove (vecteur et registres MFP du Timer B gardés / rendus), cut_act = 0 au menu.
- XVOLUTION.S : isvga ; main loop : cut_show au lieu de Setscreen ; draw_hud dessine la bande dans bandb0/1 si coupure (cut_bnew) et ne demande plus d'effacer la bande dans l'image ; KEY_C $2E. PARAMS.S : CUT_DEF, CUT_LPL (2 : en VGA chaque ligne est affichée 2 fois, à vérifier sur le vrai Falcon).
- Hatari ne rend pas fidèlement un changement d'adresse en milieu d'écran : en mode coupé la bascule apparaît vers la ligne 75 (avec CUT_LPL 1 ou 2) → impossible à vérifier ici ; avec C (sans coupure) jeu normal, menu normal (captures regardées).
- BOSS.S : « xxx RECAPPED » au lieu de « DEBUGGED » ; commentaires (BOSS.S, EFFETS.S, SFX.S, XVOLUTION.S) : recap.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 47a9179f…, COUPURE.S dce26c18… (nouveau), BOSS.S 97593fe2…, EFFETS.S fe0ee192…, SFX.S 933bff21…, PARAMS.S 357f5f6b…, XVOLUTION.PRG fa9c0114…. Pour rg-asm : COUPURE.S dans le même dossier.

## 2026-11-14 — coupure d'écran : CUT_LPL 1 (vidéo du vrai Falcon)
- Vidéo de Haltero (vrai Falcon) : la bande apparaît 2 fois (~32 lignes : bandb0 puis bandb1), puis une ligne de bruit, puis le jeu ; le circuit dessous est juste → le Timer B compte 1 événement par ligne affichée sur le vrai Falcon, pas 2.
- PARAMS.S : CUT_LPL 2 → 1 (TBDR = 16). Une image « fantôme » vue une fois dans la vidéo : à surveiller.
- Hatari : menu normal (capture regardée) ; la coupure reste invérifiable dans Hatari.
- MUS_VOL 24 → 8 (réglage de Haltero, perdu dans son PARAMS.S : remis).
- Écrit sur le disque (md5 vérifiés) : PARAMS.S 849ca6ae…, XVOLUTION.PRG 0f2a39e4….

## 2026-11-14 — coupure : l'image ne saute plus quand le Timer B arrive en retard
- Vidéo IMG_3231 (vrai Falcon) : par moments toute l'image saute (décalée de quelques lignes), une ligne de bruit sous la bande, une image « fantôme ». Cause : l'interruption Timer B arrive parfois quelques lignes en retard (autres interruptions, code masqué) ; l'adresse écrite était celle de la ligne TOP_H → tout le circuit descendait de ces lignes et le VIDEL lisait la mémoire après la bande.
- COUPURE.S cut_timerb : lit le compteur vidéo (2 lectures identiques), décalage = compteur - bande de cette image (cut_bv, gardée dans cut_vbl), et écrit le compteur = image du circuit au même décalage → le circuit ne bouge plus jamais ; un retard rend juste la bande quelques lignes plus haute. Hors limites : comme avant (ligne TOP_H). Tampons de bande : TOP_H + CUT_MARG lignes noires (PARAMS.S CUT_MARG 48).
- Hatari : jeu normal avec C (capture regardée) ; la coupure reste à vérifier sur le vrai Falcon.
- Écrit sur le disque (md5 vérifiés) : COUPURE.S 1e4fb63b…, PARAMS.S 331ee81f…, XVOLUTION.PRG ccf112a8….

## 2026-11-14 — 5e log (avant correction) + vidéo IMG_3232 ; mesure du retard du Timer B
- Vidéo IMG_3232 (coupure à décalage relatif) : la bande du haut est stable ; le circuit dessous saute encore verticalement d'une image à l'autre (barre du boss pas toujours à la même hauteur), avec des images mêlées.
- Log XVOLUTIO (4) : calme 28-30 FPS ; vagues SOL 11-16 ms, ENM 9-17, DSP jusqu'à 17, 19-21 FPS ; boss BUL 8-9 ms ; pics SOL 23-32 ms (cuisson). HUD ~4,5 ms.
- Test : COUPURE.S note le retard du Timer B (lignes après la ligne TOP_H, max sur 32 images ; 99 = compteur vidéo hors limites) ; XVOLUTION.S l'affiche en cyan dans la bande (x 204) quand la coupure est active.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S b80aa1ac…, COUPURE.S 96ff78a6…, XVOLUTION.PRG e3f36dda….

## 2026-11-14 — Timer B armé dans le vecteur VBL ($70)
- Mesure de Haltero (vrai Falcon) : retard du Timer B 31 à 43 lignes (jamais 99). Cause : cut_vbl était dans la file VBL de TOS, exécutée après le travail du VBL de TOS → Timer B armé trop tard, déjà dans l'image.
- COUPURE.S : cut_install met son propre vecteur VBL $70 (cut_vbl70 : coupure réglée tout de suite, puis saut à l'ancien VBL) ; cut_remove le rend. PARAMS.S : CUT_MARG 64.
- Hatari : jeu normal avec C (capture regardée). Affichage du retard (cyan) gardé pour vérifier sur le vrai Falcon.
- Écrit sur le disque (md5 vérifiés) : COUPURE.S e39a91f8…, PARAMS.S 75751e49…, XVOLUTION.PRG 6560d96f….

## 2026-11-14 — coupure abandonnée par défaut : bande dans l'image, adresse exacte écrite à la VBL
- Vidéo IMG_3234 (vecteur $70) : bande juste (16 lignes) mais le circuit saute toujours de dizaines de lignes → l'écriture du compteur vidéo en milieu d'écran ne marche pas comme prévu sur le vrai Falcon.
- Vidéo IMG_3235 (touche C, sans coupure) : image stable, bande fixe en haut, plus de décalage latéral → le décalage venait sans doute de Setscreen (octet bas de l'adresse) ; maintenant l'adresse exacte ($8201/03/0D) est écrite à la VBL par COUPURE.S.
- PARAMS.S : CUT_DEF 0 (sans coupure au départ ; C la remet pour essai).
- Hatari : départ sans coupure, jeu normal (capture regardée). FPS vu sur la vidéo : 12-17 avec la barre du bas et beaucoup d'ennemis.
- Écrit sur le disque (md5 vérifiés) : PARAMS.S 52eaf4a0…, XVOLUTION.PRG 33aba17d….
