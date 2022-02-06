# [Playstation](https://en.wikipedia.org/wiki/PlayStation_(console)) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)
by [Robert Peip](https://github.com/RobertPeip/)

## Hardware Requirements
SDRAM of any size is required.

## Features
* Savestates
* Memory Card file loading (.MCD)
* CUE+BIN format support
* Instant CD-ROM Seek (disables simulation of motor delay)
* Fast Boot
* Dithering On/Off Toggle
* Bob or Weave Deinterlacing

## Bios
Rename your playstation bios file (e.g. `scph-1001.bin`/`ps-22a.bin` ) to `boot.rom` and place it in the `./games/PSX/` folder.

You can also place a cd_bios.rom in the same directory as the CD or 1 directory above, to have it uses together with that CD. This can be used for games that depend on the BIOS region(US,EU,JP).

## Memory Card
One card can be mounted for each controller slot. Cards are in raw .mcd format. An empty formatted .mcd file is available for [download here](https://github.com/MiSTer-devel/PSX_MiSTer/raw/main/memcard/empty.mcd).

You need to save them either manually in the OSD or turn on autosave. Saving or loading a card will pause the core for a short time.

## Video output
Core uses either normal output or direct framebuffer mode.

In Framebuffer mode you can choose to view:
- normal drawing area without any overscan cutoff
- full VRAM as 1024x512 pixel image (debug mode)

Analog out is not supported yet. It requires either direct video or seperate build and is very experimental and buggy. Use at your own risks, no bug reports please.

## Libcrypt

Some games are secured with Libcrypt and will not work if it's not circumvented.

You can provide a .sbi file to do that.
If there is a .sbi file next to a .cue with the same name, it is loaded automatically when mounting the CD image.

## Error messages

If there is a recognized problem, an overlay is displayed, showing which error has occured.
You can hide these messages with an OSD option, by default they are on.

List of Errors:
- E2     - CPU exception
- E3..E6 - GPU hangs (e.g. corrupt display list)
- E7     - CPU2VRAM with mask-AND enabled
- E8     - DMA chopping enabled
- E9     - GPU FIFO overflow
- EA     - SPU timeout

## Debug Options

The debug menu is intended for use by developers only. They don't really serve any purpose for regular users so it's best to leave them at their default setting as a lot of undesirable behavior could occur.

## Status

Work in progress, don't report any bugs!

- some games working

--

CPU    : 90%
- exception for read in invalid instruction and data area missing

GPU    : 80%
- mask bits not implemented for cpu2vram
- vram2vram and vram2cpu line wraparound not implemented
- vram2vram read/modify/write race condition when copying to same line
- videoout using original, asynchronous timings not implemented

Memory : 80%
- rotate register not done for all busses

IRQ    : 80%
- irq_SIO missing        
- irq_LIGHTPEN missing

PAD    : 80%
- SNAC interface missing

DMA    : 80%
- DMA write performance only 32bit/2 cycles, should be 32Bit/1 cycle?

Memctrl: register stubs only

SIO    : register stubs only

Timer  : 50%
- dotclock base missing
- accuracy for start/wraparound not tested

GTE    : 80%
- timing not correct

MDEC   : 90%
- timing slightly too fast (4996/5376)
 
CD     : 60%
- single track only
- no Direct Audio

SPU    : 90%
- DDR3 version can be improved
