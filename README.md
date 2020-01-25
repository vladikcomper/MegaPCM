# Mega PCM

Mega PCM is a sound driver for the Sega Mega-Drive / Genesis console that exclusively plays digitized audio samples through an YM2612 sound chip's DAC channel.

The drivers primarily works on the "Zilog Z80" CPU and is intended to be used in conjunction the game's own "main" sound driver, which is expected to run on the Motorola 68000C (M68K) CPU and send commands to the Mega PCM in order for it to operate.

Mega PCM is generally used to play digitized drum samples in game. 
It was initially designed to be used in modifications of Sonic the Hedgehog (1991) game and released in 2012.

For demonstration, please see the example of in-game implementation:
https://www.youtube.com/watch?v=LCDx7YUzFZ4


## Features

* __Automatic bank-switching__

    Forget about the banks, put your samples where you like, how you like. You no longer have to align samples on 32 KB boundary and care if they cross the boundary.

* __Unlimited sample size__

    Samples are no more limited to 32 KB. "Mega PCM" is capable of playing samples of absolutely any size, as long as it can fit your ROM space.

* __Two sound formats supported__

    These are 4-bit DPCM and 8-bit PCM.
    
    The first format was widely used by Sonic 1 to Sonic 3K for DAC samples as it takes only half of the space a normal PCM sound would. 8-bit PCM, however, is the 'native' format for Sega's YM2612 chip, it takes more space but provides a better sound quality.

* __Extended playback controls: Stop, Pause, Loop, Priority__

    "Mega PCM" can pause and continue sample playback, so if you play a long sample it won't be cut off after you pause the game.
    
    You can also loop samples (good for DAC-songs) and can tell "Mega PCM" not to overwrite some samples (good for in-game voice clips).
    
* __DAC panning__

    You can store your sample to play in Left or Right headphone only.

* __Up to $5F DAC samples allowed__

    In reality DAC table size is only limited by the RAM size, but the SMPS only allows up $5F different DAC samples (slots $81-$CF).


## Installation and how to use

For guides on installation and using the driver, please visit the initial release topic on the Sonic Retro forums: 
https://forums.sonicretro.org/index.php?threads/sonic-1-mega-pcm-driver.29057/
