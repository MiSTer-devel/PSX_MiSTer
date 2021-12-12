# [Playstation](https://en.wikipedia.org/wiki/PlayStation_(console)) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)


# HW Requirements/Features
SDRam of any size is required.

# Bios
Only scph1001.bin tested.
Rename to boot.rom

# Video output
Core uses either normal output or direct framebuffer mode.

In Framebuffer mode you can choose to view:
- normal drawing area without any overscan cutoff
- full VRAM as 1024x512 pixel image (debug mode)

# Error messages

If there is a recognized problem, an overlay is displayed, showing which error has occured.
You can hide these messages with an OSD option, by default they are on.

List of Errors:
- E2     - CPU exception
- E3..E6 - GPU hangs (e.g. corrupt display list)


# Status

Work in progress, don't report any bugs!

- only very few games working

--

CPU    : 90%
- exception for read in invalid instruction and data area missing

GPU    : 80%
- mask bits not implemented for cpu2vram
- vram2vram and vram2cpu line wraparound not implemented
- vram2vram read/modify/write race condition when copying to same line

Memory : 50%
- SPU RAM not implemented
- rotate register not done for all busses

IRQ    : 40%
- irq_SIO missing     
- irq_SPU missing    
- irq_LIGHTPEN missing

PAD    : 40%
- memory card not implemented
- special controllers not supported
- second controller port not supported

DMA    : 60%
- DMA chopping not implemented 
- DMA write performance only 32bit/3 cycles, should be 32Bit/1 cycle?

Memctrl: register stubs only

SIO    : register stubs only

Timer  : 50%
- dotclock base missing
- accuracy for start/wraparound not tested

GTE    : 80%
- timing not correct

MDEC   : 90%
- timing slightly too fast (4996/5376)
- writing to MDECControl -> should reset
 
CD     : 30%
- single track only
- region only EU
- no audio yet

SPU    : 5%
