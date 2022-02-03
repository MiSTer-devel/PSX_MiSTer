# [Playstation](https://en.wikipedia.org/wiki/PlayStation_(console)) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)


# HW Requirements/Features
SDRam of any size is required.

# Bios
Rename to boot.rom

You can also place a cd_bios.rom in the same directory as the CD or 1 directory above, to have it uses together with that CD.

This can be used for games that depend on the BIOS region(US,EU,J).

# Memory Card
One card can be mounted for each controller slot.

Cards are in raw .mcd format. An empty example card can be found in the memcard folder.

You need to save them either manually in OSD or activate autosave. 

Saving or loading a card will pause the core for a short time.

# Video output
Core uses either normal output or direct framebuffer mode.

In Framebuffer mode you can choose to view:
- normal drawing area without any overscan cutoff
- full VRAM as 1024x512 pixel image (debug mode)

Analog out is not supported yet. It requires either direct video or seperate build and is very experimental and buggy. Use at your own risks, no bug reports please.

# Error messages

If there is a recognized problem, an overlay is displayed, showing which error has occured.
You can hide these messages with an OSD option, by default they are on.

List of Errors:
- E2     - CPU exception
- E3..E6 - GPU hangs (e.g. corrupt display list)
- E7     - CPU2VRAM with mask-AND enabled
- E8     - DMA chopping enabled
- E9     - GPU FIFO overflow
- EA     - SPU timeout

# Status

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
