# [Playstation](https://en.wikipedia.org/wiki/PlayStation_(console)) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)


# HW Requirements/Features
SDRam of any size is required.

Second SDRam is required to boot iso/bin files for now(requirement will be removed later)

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

- Amidogs CPU test fully passed
- Amidogs GTE math test fully passed
- most rendering functions working
- MDEC logic finished

- some games working with savestate loading
- BIOS startup working
- booting of simple test CDs working(no games!)

--

CPU    : 90%
- exception for read in invalid instruction and data area missing
- scratchpad clear on reset?

GPU    : 80%
- dithering missing
- texture AND/OR mask missing
- mask bits not implemented for special modules(e.g. cpu2vram)
- vram2vram and vram2cpu line wraparound not implemented
- vram2vram read/modify/write race condition when copying to same line

Memory : 50%
- DMA write performance only 32bit/2 cycles, should be 32Bit/1 cycle
- SPU RAM not implemented
- rotate register read16/32 missing

IRQ    : 40%
- irq_GPU missing    
- irq_CDROM missing 
- irq_SIO missing     
- irq_SPU missing    
- irq_LIGHTPEN missing

PAD    : 30%
- memory card not implemented
- analog controller not implemented
- all other special controllers not supported

DMA    : 30%
- only Mem->GPU and OTC->Mem implemented
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
- writing to MDECControl -> reset
 
CD     : 20%

SPU    : 0%
