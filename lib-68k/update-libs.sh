#!/bin/bash
set -e

cp ../../md-modules/build/modules/mdshell/asm68k-linkable/MDShell.obj mdshell.obj
cp ../../md-modules/build/modules/mdshell/asm68k-linkable/MDShell.asm mdshell.asm

cp ../../md-modules/build/modules/errorhandler/asm68k-linkable/Debugger.obj debugger.obj
cp ../../md-modules/build/modules/errorhandler/asm68k-linkable/Debugger.asm debugger.asm
