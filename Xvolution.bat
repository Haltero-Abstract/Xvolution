@echo off
rem ==============================================================
rem  Xvolution.bat - runs XVOLUTION.PRG in Hatari like a real Falcon 030
rem    (68030 16 MHz cycle exact, DSP 56001, 14 MB, VGA, EmuTOS).
rem  Xvolution.bat -asm : assembles XVOLUTION.S with rg-asm first.
rem  Xvolution.bat -4   : 4 MB Falcon.
rem ==============================================================
setlocal
set "HERE=%~dp0"
set "HATARI=%HERE%outils\hatari-v2.6.1-586-g8f475ba2"
set "MEM=14"
cd /d "%HERE%"
if /i "%~1"=="-4" set "MEM=4"
if /i "%~1"=="-asm" (
  "%HERE%outils\rg-asm.exe" --dialect=devpac3 --cpu=68030 --prg -o XVOLUTION.PRG XVOLUTION.S
  if errorlevel 1 ( echo *** assembly error & pause & exit /b 1 )
)
start "" "%HATARI%\hatari.exe" ^
  --machine falcon --cpulevel 3 --cpuclock 16 --fpu none --cpu-exact on ^
  --dsp emu --memsize %MEM% --monitor vga ^
  --tos "%HATARI%\etos512fr.img" --fast-boot on ^
  --harddrive "%HERE%." --gemdos-drive C --protect-hd off ^
  --auto "C:\XVOLUTION.PRG" --confirm-quit off
endlocal
