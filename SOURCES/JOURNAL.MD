# XVOLUTION — journal résumé (shoot'em up 3D, Atari Falcon 030)

Dossier : `Documents\ChatGPT\Xvolution`. Le journal détaillé jusqu'au 14/11 16h40 est dans `JOURNAL_ARCHIVE.MD`.
Vue de dessus, défilement vertical, inspiré de Wings of Death. Niveaux = vraies cartes mères Atari : 800 XL, 520 ST, STE, Falcon 030.

## État actuel (2026-11-22)
- VGA 320x240 True Color, triple tampon (3 écrans : l'image attend sa VBL pendant que la suivante se dessine), 30 images/s au plus (FPS_DIV 2), pas de jeu selon les VBL écoulées (vitesse constante).
- Sol : défilement matériel (SOL.S) dans des tampons de 800 pixels de large (LINEB 1600) ; défilement horizontal par l'adresse vidéo (caméra suit le vaisseau). Composants 3D « cuits » une fois dans le sol (COMPOS.S, DSP), noms des puces écrits dessus.
- Cartes : LEVEL1..4.MAP (texte : THEME, SIZE, lignes de tuiles, `C type col ligne [nom]`, `*nom` = boss). Tuiles PCBTA8/ST/STE/F30.BIN. Outils : `outils\PCB2MAP.PY`, `GERB2MAP.PY`, `CHECKMAP.PY`, `MKTILES.PY`, éditeur `outils\EDITEUR.HTML`.
- Sources des cartes : 800 XL de Marek L (CC BY-SA 2.0), 520 ST et STE de sporniket (KiCad), Falcon = ReFalcon de Steve Suavek (licence non commerciale, attribution + licence jointe). Voir CREDITS.TXT, REFALCON.LIC.
- Menu (MENU.S) : 4 niveaux, musique YM PWRBOAT.ORG (Jochen Hippel, lecteur COSO corrigé pour le Falcon). En jeu : ELYSIUM.MOD (Jester / Sanity, à contacter avant diffusion) par le DSP (MGTK).
- Vaisseau = logo Atari en 3 formes (blanc / blanc + rouge / rouge), précalculé en sprites par segments (EFFETS.S, 3 formes x 5 x 3 places, au 1er niveau avec barre de progression), ombre précalculée. Ennemis : LED verte, condensateur bleu, transistor (2 tirs), précalculés aussi.
- Boss : grosses puces (*6502C, *ANTIC, *SHIFTER, *68000, *VIDEL, *68030) ; le sol s'arrête, la puce tire ; gagnée = « xxx RECAPPED » (thème : on « recape » les vieux composants), halo vert + LED.
- Effets (EFFETS.S) : explosions, ombre du vaisseau, tirs lumineux, impulsions sur les pistes, puces recapées.
- Son (SFX.S) : bruitages YM (gain d'entrée +12 dB, toujours au maximum) ; + / - règlent la musique seule (0..64, départ 16, MUS_VOL 8).
- Bande noire du haut (score, forme, vies, volume, PAUSE, REC, DSP/030, FPS) dessinée dans l'image ; l'adresse exacte de l'écran est écrite à la VBL (COUPURE.S, vecteur $70). La coupure d'écran par Timer B (touche C, CUT_DEF 0) ne marche pas sur le vrai Falcon : laissée coupée.
- Profileur (PROFIL.S) : S = capture XVOLUTION.LOG (barre du bas cachée), H = barre du bas (cachée au départ), D = 3D DSP / 030, P = pause.

## Touches
Flèches / manette, ESPACE = tir, P pause, D DSP/030, H barre du bas, S capture du log, L écrire le log, C coupure (essai), + / - volume, ESC menu / quitter.

## Fichiers sources
XVOLUTION.S (principal), PARAMS.S (tous les réglages), SOL.S, CARTE.S, COMPOS.S, BOSS.S, EFFETS.S, SFX.S, MUSIQUE.S, MENU.S, ZONES.S, PROFIL.S, COUPURE.S, DSP3D.S, AMIGADSP.S (+ .P56), R3D.P56, 3DREAMS.P56, XLOGO3D.S. rg-asm sur le PC : tous les .S dans le même dossier.

## Vitesse sur le vrai Falcon (≈ 2 fois plus lent que Hatari)
- Avant la revue du 22/11 (log 8) : calme 27-31 FPS ; vagues 21-28 ; boss 20-27. Depuis : travail par image −37 % dans Hatari + triple tampon : à mesurer sur le vrai Falcon (capture S).

## Leçons
- Toujours mesurer sur le vrai Falcon (Hatari plus rapide, ne montre pas les changements d'adresse en milieu d'écran).
- Setscreen n'écrit pas l'octet bas de l'adresse : écrire $FFFF8201/03/0D directement.
- La file VBL de TOS passe tard (31-43 lignes) : pour un timing précis, prendre le vecteur $70.
- Version de test : 9 vies (99 dessine hors du HUD).

## Restes
- Mode 4 Mo ; difficulté à régler ; droits des musiques avant diffusion.

## 2026-11-14 — derniers changements
- Coupure abandonnée par défaut (CUT_DEF 0) après les vidéos IMG_3230 à 3235 ; image stable sans coupure.
- Écrit sur le disque : PARAMS.S 52eaf4a0…, COUPURE.S e39a91f8…, XVOLUTION.S b80aa1ac…, XVOLUTION.PRG 33aba17d….

## 2026-11-14 — composants étalés, tirs allégés, écran noir au chargement, niveau dans la bande
- A (COMPOS.S) : bake_scan cuit au plus BAKE_MAX 1 composant par image (plus si un composant arrive à BAKE_NEAR 232 lignes du haut de l'écran) ; bake_all pour un sol redessiné entier (SOL.S gnd_full). Supprime les pics SOL de 23-38 ms.
- B (XVOLUTION.S) : tirs du joueur sans mélange 50 % : traînée orange pleine 2 px, cœur 4 x 7 jaune + centre blanc (fillrect).
- Demande de Haltero : plus de carte visible avant le menu ni avant un niveau → blank_on / blank_off : image noire (blackscr, effacée après Setscreen car le TOS la remplit de blanc) pendant les préparatifs ; menu : $820E remis après Setscreen.
- Demande de Haltero : nom du niveau dans la bande du haut (x 118, bleu clair) : 800 XL, 520 ST, STE, F030.
- Vérifié dans Hatari (captures regardées) : noir au chargement, menu, niveau 1 avec « 800 XL », composants entiers, tirs, 28-30 FPS.
- Écrit sur le disque (md5 vérifiés) : COMPOS.S ec360f56…, SOL.S e9b6922b…, MENU.S 524435c3…, PARAMS.S 58b1311b…, XVOLUTION.S 8d6d6ccf…, XVOLUTION.PRG 319a0fa9….

## 2026-11-14 — ennemis précalculés (comme le vaisseau)
- Log XVOLUTIO (5) : vagues ENM 10-17 ms dont presque tout en attente du DSP (DSP 100-170) → 18-21 FPS ; calme 28-31 ; SOL 14-21 ms (cuisson étalée).
- EFFETS.S : en_prerender (au démarrage, après ship_prerender, même réserve spr_pool) dessine manette / cartouche / disquette à EN_NX x EN_NY places (9 x 9, x -120..120 pas EN_DX 30, y -80..80 pas EN_DY 20) ; en_sprite copie le plus proche ; spr_blit = copie commune (vaisseau + ennemis). XVOLUTION.S : ennemis en sprites en mode DSP, modèle 3D en mode 030 (D). PARAMS.S : EN_NX, EN_DX, EN_NY, EN_DY.
- Démarrage ~2 s plus long dans Hatari (écran noir).
- Vérifié dans Hatari (captures regardées) : manettes, cartouches visibles, 31 FPS.
- Écrit sur le disque (md5 vérifiés) : EFFETS.S 1bd8d4ec…, PARAMS.S f6e45489…, XVOLUTION.S a9c1edf2…, XVOLUTION.PRG 30cc19c4….

## 2026-11-14 — précalcul au 1er niveau avec barre de progression ; 6e log
- Log XVOLUTIO (6) : ennemis précalculés → ENM 4-8 ms (avant 10-17), DSP ~0 ; vagues encore 19-22 FPS car SOL 16-21 ms ; calme 28-30.
- Demande de Haltero : précalcul seulement au choix du niveau (écran noir trop long au démarrage), avec barre de progression comme RICK3D. EFFETS.S spr_prepare (une seule fois, au 1er niveau lancé) : cadre gris + barre verte sur l'image noire (PB_X/Y/W/H, PB_N = 288 sprites), spr_tick après chaque sprite ; barre effacée à la fin. XVOLUTION.S : appelé dans level_start après blank_on.
- Piège : moveq #203 (> 127) bouclait 65 000 fois → move.w.
- Hatari : SOL ~8 ms dont ~4 ms pour gnd_restore (recopie du sol sous les objets) ; la cuisson des composants ne compte presque pas. Prochaine piste : alléger gnd_restore.
- Vérifié dans Hatari (captures regardées) : menu en ~9 s, barre qui avance, niveau normal, textes de la bande justes.
- Écrit sur le disque (md5 vérifiés) : EFFETS.S 2271bea1…, XVOLUTION.S 3705166c…, XVOLUTION.PRG d194d880….

## 2026-11-14 — 7e log ; bande du haut : on ne recopie que les lignes qu'elle quitte
- Log XVOLUTIO (7) : vagues ~20 FPS : SOL 17-21 + ENM 5-8 + BUL 3-5 + SHP 2,5 + HUD 5 ≈ 36 ms > 33 → on retombe à 3 VBL (20 FPS) ; boss 20-22 FPS (BUL 7-9). Il faut gagner ~4 ms.
- SOL.S band_fix : la bande noire (16 lignes) n'est plus recopiée en entier sous elle à chaque image ; on ne remet que les 1-2 lignes qu'elle quitte en défilant (toute la bande si la caméra a bougé de côté). Champs BF_BL / BF_BX par écran ; XVOLUTION.S les note au lieu d'add_rect.
- Hatari : SOL ~8 → ~6,5 ms (sur le Falcon ~3 ms de gagnés attendus). Captures regardées : caméra à gauche / droite, défilement, boss : pas de traînée noire.
- Écrit sur le disque (md5 vérifiés) : SOL.S c1c84026…, XVOLUTION.S 7eef4dd2…, XVOLUTION.PRG d27077ee….

## 2026-11-14 — ennemis = composants (LED verte, condensateur bleu, transistor)
- Demande de Haltero (photo de composants) : ennemi 1 = LED verte, 2 = condensateur bleu, 3 = transistor à 3 pattes ; plus petits (moins à effacer).
- XVOLUTION.S : mdl_en0 = LED (corps vert, dôme clair, point blanc, 2 pattes), mdl_en2 = condensateur chimique bleu (dessus alu avec croix, bande blanche « - »), mdl_en1 = transistor TO-92 noir à 3 pattes (2 tirs, ancien croiseur). ±7 au lieu de ±13. Couleurs col_ledg, col_ledl. PARAMS.S : BUL_R 9 → 8.
- Vérifié dans Hatari (captures regardées) : les 3 ennemis visibles, 28-30 FPS.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 1b5885be…, PARAMS.S 954604a8…, XVOLUTION.PRG 5ced5aaf….

## 2026-11-22 — revue complète du code : optimisation
- Mesure avant / après dans Hatari (niveau 1, 30 s en tirant, 99 vies) : travail par image 12,9 → 8,1 ms caméra fixe, 14,2 → 9,0 ms caméra qui bouge (−37 %). Hatari est ~2,4 fois plus rapide que le vrai Falcon (il ne simule pas la place que prend le VIDEL sur le bus en True Color VGA) : ce qui touche la mémoire coûte encore plus cher sur la vraie machine.
- **Triple tampon** (SOL.S, XVOLUTION.S, COUPURE.S) : 3 écrans D0/D1/D2 (+1,2 Mo). L'image finie attend sa VBL (pend_pf, prise par cut_vbl au plus tous les FPS_DIV VBL) pendant que le 030 dessine déjà la suivante : plus d'attente de VBL. Avant, une image à 34 ms retombait à 20 FPS ; maintenant ~29-30. Simulation (attente fixe ajoutée pour imiter le vrai Falcon) : 21 FPS → 30 FPS à travail égal. game_steps : pas de jeu = VBL écoulées / FPS_DIV (reste gardé), vitesse du jeu inchangée. next_bf, set_pic, vbl_cnt.
- **Effacement** (SOL.S gnd_restore) : chaque ligne d'un rectangle = saut dans 160 move.l (plus de divu, plus de movem par ligne). gnd_copyall ne copie plus que les 240 lignes de l'image (et leurs copies) au lieu des 736 ; copy_line : largeur de la carte seulement (map_cols x 40 octets, un movem de 10 registres par tuile). MAXDR 300.
- **Bande du haut** : band_fix ne remet plus toute la bande quand la caméra bouge (seulement les lignes et les colonnes qu'elle quitte) ; draw_hud ne redessine rien si la bande est au même endroit avec le même contenu (hud_sig, champs BF_HL/BF_HX/BF_HS) : rien à faire pendant les boss ; les objets ne dessinent jamais dans la bande (clip_y0 = TOP_H pendant le rendu).
- **Sprites par segments** (EFFETS.S rle_build, spr_blit) : vaisseau, ennemis, bonus copiés par suites de pixels (plus de test de couleur clé par pixel) ; SHP 1,3 → 0,5 ms. Bonus précalculé (bon_prerender) au lieu de 2 boîtes DSP par image.
- **Ombre du vaisseau** précalculée en segments (sh_prerender, une par forme), assombrie 2 pixels à la fois : 0,9 → 0,3 ms.
- **Tirs** : tirs du joueur (draw_pbul) et du boss (draw_ebul) écrits directement, débris (fill_small), impulsions (pulse_fast, et plus rien pour celles hors écran) ; halo des puces recapées : 4 bandes effacées au lieu de tout le rectangle de la puce ; nom du boss : btext (au lieu de big_text, 0,4 ms) et effacement de la largeur du texte seulement.
- **Texte** : btext avec la police pré-étendue (font_init : 6 lignes de 6 bits par caractère), cuisson des composants sans test par pixel inutile (COMPOS.S).
- Barre du bas cachée au départ (H pour l'afficher : elle coûte plusieurs ms).
- Vérifié dans Hatari (captures regardées) : niveaux 1 à 4, caméra gauche / droite, combat de boss (tirs, halo + LED « RECAPPED »), bande du haut, menu.
- Écrit sur le disque (md5 vérifiés) : BOSS.S 79dbcb0f…, COMPOS.S 8a4341d8…, COUPURE.S 475dd9a0…, EFFETS.S a71acf49…, SOL.S a0ce0d79…, XVOLUTION.S 0c551c97…, XVOLUTION.PRG 21bff060…. PARAMS.S inchangé.
- Restent (choix de design) : HUD ~1,4 ms (remplir la bande noire), effacement ~2,2 ms (surface des objets), musique MGTK à 32780 Hz (une fréquence plus basse soulagerait le 030).

## 2026-11-22 — logo X de 3Dreams derrière le menu
- Demande de Haltero : le X logo de la démo 3Dreams derrière le texte du menu, en 16 couleurs sans mapping.
- outils\XLOGO.PY : lit 3Dreams\OBJ\06XLOGO.OBJ, le tourne (−20° / 25°), éclairage plat avec la rampe de 16 couleurs de l'objet (lignes L), sur le vert foncé du menu -> XLOGO.BIN (320 x 240 RGB565, 153 600 octets).
- MENU.S : mn_draw copie XLOGO.BIN (incbin, dans le programme : rien à charger) au lieu du fond uni. Pour rg-asm : XLOGO.BIN dans le même dossier que les .S.
- Vérifié dans Hatari (captures regardées) : logo derrière le titre et la liste, sélection lisible.
- Écrit sur le disque (md5 vérifiés) : MENU.S 245a98e0…, XLOGO.BIN 60e81c55…, XVOLUTION.PRG 9a45a706…, outils\XLOGO.PY.

## 2026-11-22 — Menu : le X de 3Dreams tourne derrière le texte
- Plus d'image fixe (XLOGO.BIN n'est plus utilisé, -150 Ko) : le X est calculé en temps réel (MENU.S, mx_*).
- Même objet (XLOGO3D.S généré par outils\X3GEN.PY depuis 3Dreams OBJ\06XLOGO.OBJ : 82 sommets, 52 faces, arbre BSP 23 nœuds).
- Mêmes courbes que 3Dreams : ax = az = t, ay = 2t ; trajectoire x = 160 + 95 sin(3t/4), y = 112 + 15 cos(5t/4) (amplitudes du mode 16 couleurs, montée de 2 px/image au départ) ; projection x*256/(z+300) ; t = 1 par VBL.
- Même rendu 16 couleurs plat : 2 matières (C 5 5 6 et 9 5 10), 7 teintes chacune (matpal), niveau = |nz| avec hystérésis, ordre exact par l'arbre BSP.
- Double buffer D0/D1, image du menu sans X dans D2 (M) ; effacement = rectangle du X recopié de M ; sur les lignes avec texte le X n'est tracé que là où M est le fond → il passe derrière le texte.
- Testé dans Hatari (rotation, courbe, changement de niveau, pas de traces).
- Écrit sur le disque (md5 vérifiés) : MENU.S 84e78f57…, XLOGO3D.S 89dbb7b9… (nouveau, même dossier que les .S pour rg-asm), XVOLUTION.PRG af2a27cc…, outils\X3GEN.PY 62f94865…. Mode vidéo du menu = celui du jeu : VGA 320x240 True Color 16 bits ($0114), en RGB/TV 320x200 16 bits ($0024).
- Trop rapide (Haltero) : t avance d'un pas tous les MENU_XDIV VBL (PARAMS.S, 2 = moitié de la vitesse ; le reste des VBL est gardé). Écrit (md5 vérifiés) : MENU.S c7f71ac5…, PARAMS.S 6bde27d0… (MUS_VOL 8 gardé), XVOLUTION.PRG 6bd8b3db….

## 2026-11-22 — X du menu en Gouraud par le DSP (routines de 3Dreams)
- Demande de Haltero : routines de 3Dreams, Gouraud, DSP.
- À l'entrée du menu (mxd_on) : Simplet + 3DREAMS.P56 (le programme DSP de 3Dreams, copié tel quel dans le dossier) remplacent R3D par Dsp_ExecProg ; puis ping, tables 1/w et 2^23/d, sommets + normales aux sommets, rampes Gouraud des 2 matières (comme d3dload / d3dverts / d3dramps de 3Dreams).
- Chaque image : XFORM (le DSP tourne, projette et éclaire les 82 sommets, lumière de 3Dreams, ambiante 26, reflet blanc à partir de 104), puis pour chaque face vue (ordre BSP) FACE / LINES : le DSP suit les arêtes et envoie les pixels RGB565 (dspface de 3Dreams) ; sur les lignes avec texte, pixel écrit seulement où le menu est le fond.
- À la sortie du menu (mxd_off) : Simplet + R3D rechargés (d3dinit, d3dload) pour le jeu.
- Sans DSP ou si le DSP ne répond plus : X plat 16 couleurs par le 030 (comme avant).
- XLOGO3D.S : + x3_vn (normales des sommets), x3_ramp (2 x 224 couleurs, mkramp de 3Dreams). outils\X3GEN.PY mis à jour.
- Vérifié dans Hatari (captures regardées) : X en Gouraud avec reflets, derrière le texte ; niveau 1 lancé ensuite : « DSP 31 FPS » (R3D de retour) ; ESC : menu de nouveau en Gouraud. Musique du niveau après le rechargement du DSP : à écouter sur le vrai Falcon.
- Écrit sur le disque (md5 vérifiés) : MENU.S 0698f76d…, XLOGO3D.S 0cfda469…, 3DREAMS.P56 84783300… (nouveau, avec les .S pour rg-asm), XVOLUTION.PRG 520f0d75…, outils\X3GEN.PY 95b56239…. PARAMS.S inchangé (6bde27d0…).

## 2026-11-22 — chargement : une disquette qui monte
- Demande de Haltero : la barre de progression du précalcul (1er niveau) remplacée par une disquette, celle déjà utilisée dans le jeu (l'ancien croiseur mdl_en1 : disque bleu, volet métal + fenêtre, étiquette blanche avec trait rouge), qui apparaît de bas en haut.
- EFFETS.S : spr_prepare dessine l'image de la disquette (dk_box, x 4 : 104 x 104 pixels, centrée) dans dk_img ; spr_tick recopie sur l'image noire les nouvelles lignes depuis le bas (DK_W lignes pour PB_N sprites) ; effacée à la fin. PB_X/PB_Y/PB_W/PB_H supprimés.
- Vérifié dans Hatari (captures regardées) : disquette qui monte, puis niveau 1 normal.
- Écrit sur le disque (md5 vérifiés) : EFFETS.S 3b2b6af2…, XVOLUTION.PRG acce5eac….
- Ajout (Haltero) : « PLEASE WAIT, LOADING » sous la disquette (dk_text : police 6x6 en 2 x 2, blanc, centré, ligne DK_TY), effacé avec elle. Vérifié dans Hatari. Écrit (md5 vérifiés) : EFFETS.S 9c016855…, XVOLUTION.PRG db9598da….

## 2026-11-22 — écran de transition entre les niveaux
- Demande de Haltero : un écran avec le nom du niveau, pour que la fin d'un niveau n'enchaîne pas tout de suite sur le suivant.
- XVOLUTION.S lt_show / lt_wait : sur l'image noire, « 800 XL COMPLETE » (vert, si on vient de finir un niveau), « LEVEL n » (jaune, x 4), « ATARI 520 ST - 1985 » (blanc), « GET READY » (gris). Le niveau se prépare pendant l'écran (map_load, gnd_full) ; il reste LT_VBL VBL (PARAMS.S, 240 ≈ 4 s), ESPACE / tir pour passer. Après le Falcon 030 : « FALCON 030 COMPLETE » + « ALL BOARDS RECAPPED ! » puis menu. Depuis le menu : pas de ligne COMPLETE (lt_prev = 0).
- EFFETS.S : bs_text (texte centré sur l'image noire, pixels d x d) remplace dk_text.
- Vérifié dans Hatari (captures regardées ; version de test où chaque niveau finit tout de suite) : LEVEL 1, 800 XL COMPLETE / LEVEL 2, … , ALL BOARDS RECAPPED, menu ; version normale : niveau 1 joue normalement.
- Écrit sur le disque (md5 vérifiés) : EFFETS.S ae548d38…, XVOLUTION.S a8116643…, PARAMS.S a333f3e0… (MUS_VOL 8, MENU_XDIV gardés, + LT_VBL), XVOLUTION.PRG 4af9f15e….
- Idée pour rallonger les niveaux : voir plus bas (extensions + zones).

## 2026-11-22 — niveaux plus longs : cartes d'extension + zones d'attaque
- Choix de Haltero : « Carte d'extension » + « Zones d'attaque ».
- Cartes : les cartes mères d'origine sont gardées dans `cartes_base\LEVELn.MAP`. `outils\MKEXT.PY base.map out.map n` ajoute au-dessus (row 0 = fin du niveau) une carte d'extension inventée (40 lignes, pistes routées entre ses puces) + une nappe (6 lignes) : 1 = lecteur 1050 (*6507, RIOT_6532, FDC_2793, 6810_RAM, DOS_ROM), 2 = lecteur SF314 (*FDD_CTRL, READ_AMP, MOTOR_DRV…), 3 = carte RAM 4 Mo du STE (*DRAM_CTRL, 4 x SIMM_1MB), 4 = CT60 (*68060 avec ventilateur, CPLD, 4 x SDRAM, FLASH, ETHERNAT). Niveaux : 62-70 → 108-116 lignes. Un boss de plus par niveau.
- Zones d'attaque (nouveau ZONES.S, lignes `W row [vagues]` dans LEVELn.MAP, 3 par niveau placées par MKEXT.PY loin des boss) : quand la ligne arrive à AZ_Y le sol s'arrête, « INCOMING ! », AZ_WAVES vagues en formation (ligne de LED, V de transistors, colonne visant le vaisseau, diagonales, paires), puis « ZONE CLEARED » + AZ_PTS points et le sol repart. Réglages PARAMS.S : MAXAZ, AZ_Y, AZ_WAVES, AZ_FIRST, AZ_GAP, AZ_PTS, AZ_MSG_T, AZ_TY. CARTE.S lit les lignes W.
- Piège : map_num utilise d0 ET d1 (la ligne de la zone était perdue).
- Vérifié dans Hatari (captures regardées) : zone du niveau 1 (INCOMING, sol arrêté, V de transistors, +2000, le sol repart, boss 6502C ensuite) ; version de test rapide sans boss ni zones : carte mère → nappe → carte 1050 (FDC 2793, 74LS14, *6507) → écran LEVEL 2.
- EDITEUR.HTML ne connaît pas encore les lignes W (à garder si on réédite une carte).
- Écrit sur le disque (md5 vérifiés) : ZONES.S 92440bc6…, CARTE.S 34f42b13…, XVOLUTION.S 92e4049a…, PARAMS.S b3384fe4… (MUS_VOL 8, MENU_XDIV, LT_VBL gardés), XVOLUTION.PRG 41464b54…, LEVEL1.MAP 59f1f277…, LEVEL2.MAP 132ded13…, LEVEL3.MAP 9e0de3d0…, LEVEL4.MAP d77d6a6f…, outils\MKEXT.PY 1ded373f… ; cartes_base\LEVEL1-4.MAP = les anciennes (42326f73…, 135775bd…, 2ef176a6…, 5e475255…).

## 2026-11-22 — ennemis vus de profil
- Demande de Haltero : rotation de 90° des ennemis (vus de dessus on ne reconnaissait pas leur forme).
- XVOLUTION.S mdl_en0/en1/en2 redessinés de profil (haut de la pièce en haut de l'écran, pattes en bas) : LED = dôme clair + corps + collerette + 2 pattes (une plus longue) ; condensateur = boîtier bleu debout, dessus alu, bande blanche « - », 2 pattes ; transistor = corps noir arrondi en haut, marquage, 3 pattes. Les sprites précalculés suivent (en_prerender).
- Vérifié dans Hatari (captures regardées) : les 3 formes reconnaissables en jeu.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 399bc127…, XVOLUTION.PRG c388cd29….
- Ajout (Haltero) : encore 180° : pattes derrière (en haut de l'écran, la pièce avance tête en bas vers le joueur). Vérifié dans Hatari. Écrit (md5 vérifiés) : XVOLUTION.S 98168170…, XVOLUTION.PRG ff565f29….

## 2026-11-22 — dernière évolution : tirs resserrés, plus de lenteur
- Demande de Haltero : en forme 2 (3 balles) l'écart était trop grand et ça semblait très lent.
- XVOLUTION.S upd_player .f2 : éventail serré (balles de côté à ±7 pixels, 1 pixel de côté par pas au lieu de 2, partaient hors de l'écran). draw_pbul : rien n'est dessiné pour une balle hors de l'écran (avant : chemin lent avec fillrect pour chaque balle sortie sur le côté). PARAMS.S : FIRE_T2 8 → 6 (même cadence que les autres formes).
- Vérifié dans Hatari (version de test qui démarre en forme 2, captures regardées) : éventail serré, 30 FPS pendant une zone d'attaque.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 2475b1f5…, PARAMS.S f6cff07d…, XVOLUTION.PRG 4954ca20….

## 2026-11-22 — vies au-delà de 3 visibles dans la bande
- Haltero : on ne voyait pas les vies au-delà de 3 (les carrés verts 4 à 8 passaient sous le nom du niveau, x 118).
- XVOLUTION.S draw_hud : 3 carrés verts au plus, puis « +n » en vert (x 113, t_lplus) ; nom du niveau déplacé à x 128. Rappel : forme 2 + bonus = +1 vie (LIVES_MAX 9).
- Vérifié dans Hatari (version de test à 6 vies) : « ■■■+3 800 XL ».
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S 5538cd6a…, XVOLUTION.PRG bfc05f01….

## 2026-11-24 — vies en petits carrés, une musique par niveau
- Demande de Haltero : voir 6 petits carrés pour 6 vies (pas 3 + « +3 ») ; nom du niveau un peu plus à droite ; une musique par niveau : TRANSLOG (1), CRASH1 (2), CYBERIDE (3), ELYSIUM (4).
- XVOLUTION.S draw_hud : vies = petits carrés verts 3 x 10, tous les 4 pixels, jusqu'à LIVES_MAX (9) ; nom du niveau à x 136. t_lplus supprimé.
- MUSIQUE.S : mod_tab (ZIK\TRANSLOG.MOD, CRASH1.MOD, CYBERIDE.MOD, ELYSIUM.MOD) ; mus_level (appelé par level_start avec cur_level) : si le module en mémoire n'est pas celui du niveau → arrêt, Mfree, chargement du nouveau (pendant l'écran du niveau), puis lecture. mus_init ne charge plus de module.
- PARAMS.S : la ligne LIVES_MAX (9) manquait dans la version du disque (rajoutée).
- Vérifié dans Hatari (captures regardées) : bande « ■■■ » petits carrés, nom à droite ; enchaînement des 4 niveaux (version de test) sans plantage, retour au menu. Le son n'est pas audible dans les tests : à écouter sur le vrai Falcon.
- Écrit sur le disque (md5 vérifiés) : XVOLUTION.S bd021060…, MUSIQUE.S d8f99e1a…, PARAMS.S 778f9cad… (MUS_VOL 8 gardé), XVOLUTION.PRG a5b0379e….
- Ajout (Haltero) : 6 vies au maximum (PARAMS.S LIVES_MAX 9 → 6). Écrit (md5 vérifiés) : PARAMS.S 828d750e…, XVOLUTION.PRG 350eb8e0….

## 2026-11-24 — vaisseau lissé
- Demande de Haltero : vaisseau moins pixelisé.
- outils\SHIPGEN.PY → SHIPGFX.S : le logo Atari dessiné à part (sur-échantillonné x 8) : barre centrale + 2 bras courbes qui s'évasent vers l'arrière, relief (lumière en haut à gauche), bords adoucis vers un contour sombre (pas de transparence sur le Falcon). 3 formes (blanc / centre blanc + bras rouges / rouge), 46 x 36.
- EFFETS.S : ship_prerender copie cette image (ship_img) au lieu des 9 boîtes ; l'ombre (sh_prerender) prend la même silhouette (ship_mask). Les boîtes mdl_f0..2 restent pour le mode 030.
- Vérifié dans Hatari (capture regardée) : vaisseau lisse, ombre correcte, 30 FPS.
- Écrit sur le disque (md5 vérifiés) : EFFETS.S 37d0f487…, SHIPGFX.S f1c9a3a8… (nouveau, avec les .S pour rg-asm), XVOLUTION.PRG 28a7edb4…, outils\SHIPGEN.PY ba66be95….
- Haltero : « on ne voit plus qu'il est en 3D, recommence ». SHIPGEN.PY refait : le logo est EXTRUDÉ (épaisseur Z 1..9) et vu en perspective (FOC / z) depuis chacune des 5 x 3 places des sprites, + légère inclinaison (l'épaisseur se voit à droite et en bas, à l'opposé de la lumière) ; face avant en relief, parois ombrées selon leur direction (côté 0,70, dessus 0,85, dessous 0,50, plus sombres en profondeur), sur-échantillonné 4 x 4, bords adoucis. SHIPGFX.S = 45 images (3 formes x 15 places) w, h, offx, offy + pixels (~135 Ko : XVOLUTION.PRG passe à 221 Ko). EFFETS.S ship_img / ship_mask lisent ces entrées. Vérifié dans Hatari (capture regardée) : épaisseur visible, ombre correcte, 30 FPS. Écrit (md5 vérifiés) : EFFETS.S c85bb15e…, SHIPGFX.S 41771f69…, XVOLUTION.PRG 2aaa9a5b…, outils\SHIPGEN.PY 8ac5a98b….
- Haltero : à droite on voyait le même sprite qu'au milieu (la perspective seule ne décalait les parois que de 1-2 pixels). SHIPGEN.PY : inclinaison par place, l'épaisseur glisse vers le centre de l'écran (obx = 0,10 - 0,55 wx/116, oby = 0,40 - 0,25 wy/80) : à droite les parois gauches, à gauche les parois droites, en haut / en bas différentes. Vérifié dans Hatari (99 vies, vaisseau poussé à droite puis à gauche, captures regardées). Écrit (md5 vérifiés) : SHIPGFX.S c486e915…, XVOLUTION.PRG 8107acbd…, outils\SHIPGEN.PY 1a02a714….

## 2026-11-24 — boss qui s'arrachent de la carte mère
- Demande de Haltero : boss mobiles (« puce qui s'arrache », proposé, sans préférence → retenu).
- BOSS.S : le sol s'arrête comme avant, la puce reste BOSS_RIP_T images sur la carte, puis s'arrache (étincelles + bruit) : sur la carte un socle vide (sombre, bord gris, effacé/redessiné chaque image) ; la puce devient une boîte 3D (corps noir, broches argent : 2 côtés pour un DIP, 4 sinon, bande de marquage, son nom écrit dessus) qui rejoint en 32 images un huit en haut de l'écran : x = (BOSS_AX - demi-largeur) sin a, y = sous la bande + BOSS_AY sin 2a ; vitesse BOSS_SPD0 + BOSS_SPDK par coup reçu. Elle tire comme avant depuis sa position ; la toucher = un coup pour le joueur. Détruite : explosion là où elle vole, puis « recapée » dans son socle (halo vert comme avant). boss_rect : position volante ; boss_srect : rectangle écran sur la carte ; boss_move, boss_mkmdl, boss_draw (appelé par render avant le vaisseau).
- Piège : -nocase : boss_y = BOSS_Y → variables bm_x / bm_y.
- Vérifié dans Hatari (99 vies, captures regardées ; socle passé en magenta dans une copie de test pour le repérer) : puce 6502C sur la carte puis arrachée, socle, puce volante avec son nom, barre de vie qui baisse, tirs.
- Écrit sur le disque (md5 vérifiés) : BOSS.S b1d55a70…, XVOLUTION.S f563c905…, PARAMS.S 19c65214… (MUS_VOL 8, LIVES_MAX 6 gardés), XVOLUTION.PRG 7236f57b….
- Haltero : la puce volante est trop grosse, il faut de plus petits composants. BOSS.S : en l'air la puce fait BOSS_SCL/16 de sa taille sur la carte (PARAMS.S BOSS_SCL 6 : ~ la taille du vaisseau) ; le socle garde la taille de la puce. Vérifié dans Hatari (captures regardées). Écrit (md5 vérifiés) : BOSS.S cd36165c…, PARAMS.S 28153b95…, XVOLUTION.PRG ad842678….
- BOSS_SCL 6 -> 10 : boss volant un peu plus gros (~5/8 de la puce).

## 2026-11-24 — boss : d'abord sur la carte, arraché à 50 %
- Demande de Haltero : on tire d'abord sur la puce à sa place d'origine ; à 50 % de vie elle s'arrache ; à l'arrachage, des tirs tout autour d'elle.
- BOSS.S boss_move : la puce reste sur la carte (au moins BOSS_RIP_T images) tant que sa vie > BOSS_RIP_PC % (PARAMS.S 50) ; boss_burst : BOSS_RING (16) tirs en cercle, partant à BOSS_RINGR (34) du centre (hors du socle, sinon cachés par lui).
- Piège : -nocase, boss_ring = BOSS_RING → boss_burst.
- Vérifié dans Hatari (copie de test arrachée à 100 %, captures regardées) : cercle de tirs autour du socle, puis puce volante.

## 2026-11-24 — ombres des ennemis ; machine recapée seulement à 80 %
- Demande de Haltero : des ombres aux ennemis ; si on n'a pas détruit 80 % des ennemis, la machine n'est pas recapée (choix : 80 %, on rejoue le niveau).
- EFFETS.S en_sprite : avant le sprite, son ombre (sh_runs : les segments du sprite assombris de moitié sur le sol, décalés de SH_DX / SH_DY et projetés à SH_Z comme l'ombre du vaisseau ; rien si elle sort de l'écran). Mode DSP seulement (sprites).
- XVOLUTION.S / ZONES.S : lv_spawn (ennemis apparus : spawn_enemy, az_spawn), lv_kill (kill_enemy) remis à 0 par level_reset. Fin de niveau : % = tués x 100 / apparus ; < RECAP_PC (PARAMS.S 80) → écran « 800 XL NOT RECAPPED » (rouge) + « ENEMIES DESTROYED 66 %  -  NEEDED 80 % » puis le même niveau recommence (score et vies gardés) ; sinon « COMPLETE » + la même ligne en blanc. Les ennemis qui percutent le vaisseau ou sortent de l'écran comptent comme non détruits.
- Vérifié dans Hatari (captures regardées) : ombres sous les transistors, 30 FPS ; copies de test (niveau fini tout de suite) à 66 % → NOT RECAPPED + niveau 1 rejoué, à 100 % → COMPLETE jusqu'à ALL BOARDS RECAPPED.

## 2026-11-24 — high scores après chaque niveau, X logo en 4 rendus
- Demande de Haltero : un tableau de high scores après chaque niveau réussi, un pour les 4 niveaux d'affilée ; écran comme ceux entre les niveaux, avec le X logo du menu qui tourne : fil de fer (niveau 1), faces planes (2), cel en true color (3), Gouraud (4). Choix : points gagnés dans le niveau ; nom au clavier (8 lettres) ; sauvé sur disque ; tableau « 4 niveaux » en Gouraud.
- Nouveau HISCORE.S : 5 tables de 8 (score.l + nom 8 octets), XVOLUTIO.HI (marque 'XVH1', écrit après chaque nouveau nom ; absent → tables par défaut HALTERO, ABSTRACT, SANITY, JESTER, 3DREAMS, FALCON, ATARI, STE). hs_screen (table, score) : fond noir, « LEVEL n  HIGH SCORES » + nom de la machine, 8 lignes, « YOUR SCORE », nouvelle ligne en vert avec curseur ; lettres / chiffres / espace par les tables clavier du TOS (Keytbl : AZERTY ou QWERTY), Retour arrière, RETURN / ENTER / tir = valider (vide → « - ») ; puis ESPACE / tir / RETURN pour continuer. Musique : air YM du menu pendant l'écran ; Gouraud : DSP de 3Dreams chargé puis R3D rechargé (mxd_on / mxd_off), comme le menu.
- XVOLUTION.S : lv_sc0 (score au début de chaque essai du niveau, level_reset) ; run_ok (partie lancée au niveau 1, game_new) ; niveau recapé → hs_screen(niveau, points du niveau), après le niveau 4 si run_ok → hs_screen(4, score total). hs_load au démarrage.
- MENU.S : mx_bgc (couleur du fond de M : vert du menu / noir), mx_rend (0 fil de fer, 1 plat, 2 cel, 3 Gouraud) ; mx_edges / mx_line (Bresenham, derrière le texte) ; cel = 3 tons (mx_celt, mx_celc dans la section data) + arêtes noires.
- Piège : mx_celt / mx_celc d'abord mis après les ds.w (section bss) → tout à zéro, X invisible ; déplacés dans la section data.
- Vérifié dans Hatari (copie de test : niveau fini tout de suite avec 27 000 points ; captures regardées) : les 5 écrans, nom tapé « HAL », fil de fer / plat / cel / Gouraud, tableau des 4 niveaux (108 000) ; jeu normal ensuite.

## 2026-11-24 — page de greetings avant de quitter
- Demande de Haltero : avant de quitter le jeu, une page de greetings : la scène Atari pour sa bienveillance (même si le jeu est codé grâce à une IA), Simplet et Skynet pour la routine du MegaPlayer et les optimisations DSP faites par Skynet, les musiques, les sources des cartes mères.
- HISCORE.S gr_screen (appelé par game_menu quand le menu rend « quitter ») : fond noir, X en Gouraud (DSP) derrière, texte gr_text (GRL y, couleur, échelle, texte) : GREETINGS ; THE ATARI SCENE ; SIMPLET AND SKYNET ; MUSIC (TRANSLOGIC - JORA OF B.M.T (SVEN BAUER), RUNAWAY (CRASH1.MOD) - UNKNOWN ARTIST, CYBERRIDE / ELYSIUM - JESTER OF SANITY, POWER BOAT - JOCHEN HIPPEL) ; THE MOTHERBOARDS (MAREK L, SPORNIKET, REFALCON / STEVE SUAVEK) ; HALTERO / ABSTRACT - 2026 ; une touche / le tir pour quitter. Air YM du menu pendant la page.
- Auteurs lus dans les modules (noms d'instruments) ; CRASH1.MOD (« RUNAWAY ») sans auteur.
- Vérifié dans Hatari (captures regardées) : ESC au menu → page, une touche → bureau GEM.
- Haltero : RUNAWAY (CRASH1.MOD) est de Hobby One d'Abstract (demozoo.org/productions/64251) → « RUNAWAY - HOBBY ONE OF ABSTRACT ». Vérifié dans Hatari.
- Haltero : « SIMPLET AND SKYNET OF ABSTRACT ». Vérifié dans Hatari.

## 2026-11-24 — dossier rangé : le jeu à la racine, les sources dans SOURCES\
- Demande de Haltero : toutes les sources dans un dossier, à la racine seulement le PRG et ce qu'il faut pour lancer le jeu.
- Racine de Xvolution\ : XVOLUTION.PRG, LEVEL1-4.MAP, PCBTA8.BIN, PCBTST.BIN, PCBTSTE.BIN, PCBTF30.BIN, ZIK\ (5 musiques), CREDITS.TXT, REFALCON.LIC (licence à joindre), Xvolution.bat ; XVOLUTIO.HI (high scores) s'y crée.
- SOURCES\ : tous les .S, 3DREAMS.P56, R3D.P56, AMIGADSP.P56, PCBTILES.BIN (incbin), FALCGEN.MAP, .BAK, XVOLUTION.LOG, JOURNAL.MD, JOURNAL_ARCHIVE.MD, CLAUDE.md, LISEZMOI.TXT, Readme.txt, outils\ (Hatari, rg-asm, scripts), tools\, anciennes_cartes\, cartes_base\.
- Xvolution.bat : Hatari dans SOURCES\outils ; -asm assemble dans SOURCES\ et écrit XVOLUTION.PRG à la racine. CLAUDE.md mis à jour.
- Vérifié dans Hatari : dossier avec seulement les fichiers de la racine → menu, niveau 1 à 30 FPS.
