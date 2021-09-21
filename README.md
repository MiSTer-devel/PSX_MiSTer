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

- All CPU testroms in .exe format working: https://github.com/RobertPeip/PSX/tree/master/CPUTest/CPU
- HelloWorld in 16+24 bit working
- ImageLoad/LZ77/Huffman in 16+24 bit working
- polygon(triangle/quad), rectangle and line drawing working
- Gouraud Shading and transparency working
- direct, masked and palette color texturing and texture cache working
- basic reading/writing DMA working

-- 

- No games working
- BIOS startup not working

--

- CPU    : 65%
- GPU    : 70%
- Memory : 50%
- IRQ    : 40%
- PAD    : 30% (Digital Pad without memory card 100%)
- DMA    : 30%
- Memctrl: 0%
- SIO    : 0%
- Timer  : 50%
- GTE    : 5%
- MDEC   : 0% 
- CD     : 0%
- SPU    : 0%
