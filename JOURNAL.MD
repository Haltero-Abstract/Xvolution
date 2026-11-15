# XVOLUTION — journal résumé (shoot'em up 3D, Atari Falcon 030)

Dossier : `Documents\ChatGPT\Xvolution`. Le journal détaillé jusqu'au 14/11 16h40 est dans `JOURNAL_ARCHIVE.MD`.
Vue de dessus, défilement vertical, inspiré de Wings of Death. Niveaux = vraies cartes mères Atari : 800 XL, 520 ST, STE, Falcon 030.

## État actuel (2026-11-14)
- VGA 320x240 True Color, double écran, 30 images/s fixes (FPS_DIV 2, pas de jeu en plus si retard).
- Sol : défilement matériel (SOL.S) dans des tampons de 800 pixels de large (LINEB 1600) ; défilement horizontal par l'adresse vidéo (caméra suit le vaisseau). Composants 3D « cuits » une fois dans le sol (COMPOS.S, DSP), noms des puces écrits dessus.
- Cartes : LEVEL1..4.MAP (texte : THEME, SIZE, lignes de tuiles, `C type col ligne [nom]`, `*nom` = boss). Tuiles PCBTA8/ST/STE/F30.BIN. Outils : `outils\PCB2MAP.PY`, `GERB2MAP.PY`, `CHECKMAP.PY`, `MKTILES.PY`, éditeur `outils\EDITEUR.HTML`.
- Sources des cartes : 800 XL de Marek L (CC BY-SA 2.0), 520 ST et STE de sporniket (KiCad), Falcon = ReFalcon de Steve Suavek (licence non commerciale, attribution + licence jointe). Voir CREDITS.TXT, REFALCON.LIC.
- Menu (MENU.S) : 4 niveaux, musique YM PWRBOAT.ORG (Jochen Hippel, lecteur COSO corrigé pour le Falcon). En jeu : ELYSIUM.MOD (Jester / Sanity, à contacter avant diffusion) par le DSP (MGTK).
- Vaisseau = logo Atari en 3 formes (blanc / blanc + rouge / rouge), précalculé en sprites (EFFETS.S, 3 formes x 5 x 3 places). Ennemis : manette, cartouche, disquette (2 tirs).
- Boss : grosses puces (*6502C, *ANTIC, *SHIFTER, *68000, *VIDEL, *68030) ; le sol s'arrête, la puce tire ; gagnée = « xxx RECAPPED » (thème : on « recape » les vieux composants), halo vert + LED.
- Effets (EFFETS.S) : explosions, ombre du vaisseau, tirs lumineux, impulsions sur les pistes, puces recapées.
- Son (SFX.S) : bruitages YM (gain d'entrée +12 dB, toujours au maximum) ; + / - règlent la musique seule (0..64, départ 16, MUS_VOL 8).
- Bande noire du haut (score, forme, vies, volume, PAUSE, REC, DSP/030, FPS) dessinée dans l'image ; l'adresse exacte de l'écran est écrite à la VBL (COUPURE.S, vecteur $70). La coupure d'écran par Timer B (touche C, CUT_DEF 0) ne marche pas sur le vrai Falcon : laissée coupée.
- Profileur (PROFIL.S) : S = capture XVOLUTION.LOG (barre du bas cachée), H = barre du bas, D = 3D DSP / 030, P = pause.

## Touches
Flèches / manette, ESPACE = tir, P pause, D DSP/030, H barre du bas, S capture du log, L écrire le log, C coupure (essai), + / - volume, ESC menu / quitter.

## Fichiers sources
XVOLUTION.S (principal), PARAMS.S (tous les réglages), SOL.S, CARTE.S, COMPOS.S, BOSS.S, EFFETS.S, SFX.S, MUSIQUE.S, MENU.S, PROFIL.S, COUPURE.S, DSP3D.S, AMIGADSP.S (+ .P56), R3D.P56. rg-asm sur le PC : tous les .S dans le même dossier.

## Vitesse sur le vrai Falcon (≈ 2 fois plus lent que Hatari)
- Scène calme 28-30 FPS ; vagues d'ennemis 15-21 FPS (SOL 11-16 ms, ENM 9-17, pics SOL 23-38 ms = cuisson des composants) ; boss ~20 FPS (BUL 8-9 ms).
- À faire : A étaler la cuisson des composants sur plusieurs images ; B alléger les tirs du joueur ; cacher la barre du bas (H) fait gagner ~4 ms.

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
