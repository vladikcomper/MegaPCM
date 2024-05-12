
; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM 2.0 - DAC Sound Driver
;
; Documentation, examples and source code are available at:
; - https://github.com/vladikcomper/MegaPCM/tree/2.x
;
; (c) 2012-2024, Vladikcomper
; ------------------------------------------------------------------------------

#include Constants.asm

#ifdef BUNDLE-ASM68K
#include Macros.ASM68K.asm
#endif
#ifdef BUNDLE-AS
#include Macros.AS.asm
#endif

#ifdef LINKABLE
; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM API
; ------------------------------------------------------------------------------
#include Refs.ASM68K.asm
#else
; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM library blob
; ------------------------------------------------------------------------------

MegaPCMLibraryBlob:
#include ../build/bundle/MegaPCM.Blob.asm

; ------------------------------------------------------------------------------
; Exported symbols
; ------------------------------------------------------------------------------

#include ../build/bundle/MegaPCM.Symbols.asm

#ifdef BUNDLE-ASM68K
	if def(__DEBUG__)
#else
	ifdef __DEBUG__
#endif
; ------------------------------------------------------------------------------
; Additional debuggers
; ------------------------------------------------------------------------------

#ifdef BUNDLE-ASM68K
#include Debuggers.ASM68K.asm
#else
#include Debuggers.AS.asm
#endif

	endif
#endif

; ------------------------------------------------------------------------------
; MIT License
;
; Copyright (c) 2012-2024 Vladikcomper
; 
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
; ------------------------------------------------------------------------------
