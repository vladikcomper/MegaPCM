@echo off

set USEANSI=n
as\asl -c -t 3 -L -A -xx MegaPCM.asm
as\p2bin MegaPCM.p MegaPCM.z80 -r 0x-0x

pause