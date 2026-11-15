XVOLUTION v0.1 — 3D vertical shoot’em up for Falcon 030 + DSP — Haltero / Abstract
FILES

    XVOLUTION.S — main program (game, scenery, HUD)
    PARAMS.S — all settings (speeds, lives, enemies, ground colors)
    DSP3D.S — 030 ↔ DSP interface (reused as-is from RICK3D)
    AMIGADSP.S — Simplet’s DSP MOD player + AMIGADSP.P56
    R3D.P56 — DSP 3D maths routines (assembled from OUTILS\R3D.A56)
    OUTILS\ — ASM56.PY (DSP assembler), R3D.A56

BUILDING

    DSP: python OUTILS\ASM56.PY OUTILS\R3D.A56 R3D.P56
    030: rg-asm --dialect=devpac3 --cpu=68030 --prg -o XVOLUTION.PRG XVOLUTION.S
    (or use Devpac 3 under Hatari: select XVOLUTION.S and build an executable)

R3D.P56 and AMIGADSP.P56 must be in the same folder as XVOLUTION.S.
CONTROLS

    Joystick port 1 (left): move; button: fire
    ESC quit · P pause · D DSP / 030 3D maths
    H show the bottom bar (FPS, 3D mode, shape, lives, X/Y, enemies, shots...)

GAMEPLAY (LEVEL 1)

The robot spaceship has three forms: probe (1 shot), fighter (2 shots), and heavy (3-shot spread). A yellow capsule falls after every 8 enemies destroyed. Collecting it upgrades the ship (+500 points). When hit, the ship reverts to its previous form; when hit in probe form, it loses a life.

    Red drone: 100 points (1 hit)
    Purple cruiser: 200 points (3 hits)

v0.1 LIMITATIONS

    No music yet (the player is loaded but not started).
    VGA: 320 × 240; in RGB/TV mode the screen is 320 × 200 (bottom cropped).
    The scenery is redrawn in full every frame (to be optimized later).