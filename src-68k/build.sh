#!/usr/bin/sh

wine ../toolchain/asm68k.exe /k /m /o c+,ws+,op+,os+,ow+,oz+,oaq+,osq+,omq+,ae- /l megapcm.asm,megapcm.obj,,megapcm.lst

wine ../toolchain/asm68k.exe /k /m /o c+,ws+,op+,os+,ow+,oz+,oaq+,osq+,omq+,ae-,v+ /g /e __DEBUG__ /l megapcm.asm,megapcm.debug.obj,,megapcm.debug.lst
