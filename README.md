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

# Status

Work in progress, don't report any bugs!

- only very few games working

--

CPU    : 90%
- exception for read in invalid instruction and data area missing

GPU    : 80%
- dithering missing
- mask bits not implemented for special modules(e.g. cpu2vram)
- vram2vram and vram2cpu line wraparound not implemented
- vram2vram read/modify/write race condition when copying to same line

Memory : 50%
- DMA write performance only 32bit/2 cycles, should be 32Bit/1 cycle
- SPU RAM not implemented
- rotate register read16 missing

IRQ    : 40%
- irq_SIO missing     
- irq_SPU missing    
- irq_LIGHTPEN missing

PAD    : 30%
- memory card not implemented
- analog controller not implemented
- all other special controllers not supported

DMA    : 30%
- DMA read prefetch must be fixed for long DMAs
- DMA pausing and chopping not implemented 

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
