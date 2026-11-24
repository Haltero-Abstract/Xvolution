# XVOLUTION — 3D vertical shoot'em up for the Atari Falcon 030 + DSP

**Haltero / Abstract — 2026**

A top-down vertical shoot'em up inspired by *Wings of Death*. The levels are real Atari
motherboards: you fly over the components of an **Atari 800 XL**, a **520 ST**, an **STE**
and a **Falcon 030**, and you "recap" the old chips (the bosses) instead of destroying them.

- VGA 320x240 True Color (RGB/TV: 320x200), 30 frames per second, triple buffering.
- 3D by the DSP 56001 (components, enemies, bosses); hardware scrolling in both directions.
- The ship is an Atari logo that evolves in 3 forms (1, 2, then 3 shots in a fan).
- Enemies are electronic parts: green LED, blue capacitor, transistor (with shadows).
- Each level: the motherboard, then an expansion board (1050 drive, SF314 drive, STE 4 MB RAM
  board, CT60), 3 attack zones and the boss chips: a chip is shot in its socket, then at 50 %
  it tears itself off the board (a ring of shots) and flies like the player.
- A machine is only "RECAPPED" if 80 % of its enemies were destroyed; otherwise the level
  is played again.
- High scores after each level (saved in `XVOLUTIO.HI`) with the X logo of the 3Dreams demo
  turning behind: wireframe, flat, cel, then Gouraud (DSP routines of 3Dreams).
- Greetings page when quitting.

## Running the game

Everything needed to play is at the root of the repository:

| File | |
|---|---|
| `XVOLUTION.PRG` | the game |
| `LEVEL1.MAP` … `LEVEL4.MAP` | the 4 levels (text files) |
| `PCBTA8.BIN`, `PCBTST.BIN`, `PCBTSTE.BIN`, `PCBTF30.BIN` | ground tiles of each board |
| `ZIK\` | music (4 DSP modules + the YM tune of the menu) |
| `CREDITS.TXT`, `REFALCON.LIC` | credits and the ReFalcon licence (to keep with the game) |
| `Xvolution.bat` | PC: runs the game in Hatari (Falcon 030, DSP, 14 MB, VGA) |

Copy these files to a folder of your Falcon 030 and run `XVOLUTION.PRG`
(Falcon 030 with DSP, VGA or RGB monitor; 14 MB recommended).

## Controls

Joystick port 1 or arrows + SPACE (fire). ESC: menu / quit, P: pause, + / -: music volume,
D: 3D by DSP / 030, H: bottom bar, S: performance log capture.
High score names: type up to 8 letters, RETURN to validate.

## Sources

All the sources are in `SOURCES\` (68030 assembly, Devpac 3 syntax):

- `XVOLUTION.S` main program (includes all the others), `PARAMS.S` all the settings.
- `SOL.S` ground, `CARTE.S` maps, `COMPOS.S` 3D components, `BOSS.S` bosses, `ZONES.S` attack
  zones, `EFFETS.S` effects and sprites, `SHIPGFX.S` pre-rendered ship, `MENU.S` menu and X logo,
  `XLOGO3D.S` the X object, `HISCORE.S` high scores and greetings, `MUSIQUE.S` / `SFX.S` sound,
  `COUPURE.S` VBL, `PROFIL.S` profiler, `DSP3D.S` + `R3D.P56` DSP 3D, `3DREAMS.P56` DSP program of
  3Dreams, `AMIGADSP.S` + `.P56` DSP MOD replay by Simplet.
- `SOURCES\outils\`: map tools (PCB2MAP.PY, GERB2MAP.PY, MKEXT.PY, MKTILES.PY, map editor
  EDITEUR.HTML), DSP assembler ASM56.PY + R3D.A56, generators SHIPGEN.PY / X3GEN.PY.
- `SOURCES\JOURNAL.MD`: development journal (French).

Building:

    cd SOURCES
    rg-asm --dialect=devpac3 --cpu=68030 --prg -o ..\XVOLUTION.PRG XVOLUTION.S

or `Xvolution.bat -asm` (expects `rg-asm.exe` and Hatari in `SOURCES\outils\`, not in the
repository), or Devpac 3 on the Falcon. The `.P56` and `PCBTILES.BIN` files must stay next to
the `.S` files (they are included at assembly time).

## Credits

- Code: Haltero / Abstract, with the help of an AI.
- MegaPlayer DSP routine: Simplet and Skynet of Abstract; DSP optimisations of the past: Skynet.
- Music: *Translogic* — Jora of B.M.T (Sven Bauer); *Runaway* — Hobby One of Abstract;
  *Cyberride*, *Elysium* — Jester of Sanity (Volker Tripp); *Power Boat* — Jochen Hippel (Mad Max).
- Motherboards: Atari 800 XL PCB remake by Marek L (CC BY-SA 2.0); 520 ST and STE KiCad
  conversions by Sporniket (CC0); Falcon 030: ReFalcon by Steve Suavek (non-commercial licence,
  see `REFALCON.LIC`). Details in `CREDITS.TXT`.

Atari, 800 XL, 520 ST, STE and Falcon 030 are trademarks of their owners.
