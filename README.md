# [Playstation](https://en.wikipedia.org/wiki/PlayStation_(console)) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)


# HW Requirements/Features
SDRam of any size is required.

# Bios
Only scph1001.bin tested.
Rename to boot.rom

# Video output
Core uses direct framebuffer mode to display VRAM content in DDR3 with scaler over HDMI.
This is done for bandwidth purposes and will not allow you to display via analog out/VGA, unless you use direct video!

Current output mode is full VRAM output with 1024x512 pixels, 
so you will see things that are not visible on a real PlayStation.

# Status

Work in progress, don't report any bugs!

- All CPU testroms in .exe format working: https://github.com/RobertPeip/PSX/tree/master/CPUTest/CPU
- HelloWorld in 16+24 bit working
- ImageLoad/LZ77/Huffman in 16+24 bit working
- polygon(triangle/quad), rectangle and line drawing working
- Gouraud Shading and transparency working, textures still missing

-- 

- No games working
- BIOS startup not working

--

- CPU    : 55%
- GPU    : 40%
- Memory : 20%

Everything else still missing
