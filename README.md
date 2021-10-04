# [Playstation](https://en.wikipedia.org/wiki/PlayStation_(console)) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)


# HW Requirements/Features
SDRam of any size is required.

# Bios
Only scph1001.bin tested.
Rename to boot.rom

# Video output
Core uses direct framebuffer mode to display VRAM content in DDR3 with scaler over HDMI.
This is done for bandwidth purposes and will not allow you to display via analog out/VGA, unless you use direct video!

Also vsync_adjust=2 (low latency mode) in the mister.ini is required or it will lead to screen drawing being in the visible area!

You can choose to view
- normal drawing area without any overscan cutoff
- full VRAM as 1024x512 pixel image (debug mode)

# Status

Work in progress, don't report any bugs!

- Amidogs CPU test fully passed
- All CPU testroms in .exe format working: https://github.com/RobertPeip/PSX/tree/master/CPUTest/CPU
- HelloWorld in 16+24 bit working
- ImageLoad/LZ77/Huffman in 16+24 bit working
- polygon(triangle/quad), rectangle and line drawing working
- Gouraud Shading and transparency working
- direct, masked and palette color texturing and texture cache working
- basic reading/writing DMA working
- first GTE test working

-- 

- No games working
- BIOS startup not working

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

- MDEC   : 0% 
- CD     : 0%
- SPU    : 0%
