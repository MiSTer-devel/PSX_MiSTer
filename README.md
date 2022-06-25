# [Playstation](https://en.wikipedia.org/wiki/PlayStation_(console)) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

## Hardware Requirements
SDRAM of any size is required.

## Features
* Savestates
* Option for core pause when OSD is open
* Optional manual Memory Card file loading (.MCD)
* CUE+BIN and CHD format support
* Multiple Disc Game support with automatic Lid open/close toggle
* Fast Boot (Skips BIOS)
* Dithering On/Off Toggle
* Bob or Weave Deinterlacing
* Texture Filtering
* Widescreen modes
* Screen roation by 180°
* Inputs: DualShock, Digital, Analog, Mouse, NeGcon, Wheel, Justifier and Guncon support.
* Native Input support through SNAC

## Bios
Rename your playstation bios file (e.g. `scph-1001.bin`/`ps-22a.bin` ) and place it in the `./games/PSX/` folder.

```
boot.rom  => US BIOS
boot1.rom => JP BIOS
boot2.rom => EU BIOS
```

You can also place a cd_bios.rom in the same directory as the CD or 1 directory above, to have it uses together with that CD. This can be used for games that depend on a special BIOS beyond usual US,EU,JP.

If you get a black screen with "ED" overlay in upper left corner, either your BIOS files are corrupt or missing or you have no SDRAM module installed.

## Region

Region settings (e.g. Clock, BIOS, CD check) are selected automatically when loading a CD. You can force a different Region in OSD.

## Memory Card

Games that are in their own folder will create it's own memory card in media/fat/saves/psx as <folder name>.sav 

One card can be mounted for each controller slot. Cards are in raw .mcd format. An empty formatted .mcd file is available for [download here](https://github.com/MiSTer-devel/PSX_MiSTer/raw/main/memcard/empty.mcd).

You need to save them either manually in the OSD or turn on autosave. Saving or loading a card will pause the core for a short time.

## Multiple Disc Games

To swap discs while the game is running, you will need have all of the disc files for the game placed in the same folder. Then when loading a new disc for most games you will need to toggle the Lid Open/Close option to tell the game you have opened the lid and closed it. Example folder structure of a multi disc game:

```
/media/fat/games/PSX/Final Fantasy VII (USA)/Final Fantasy VII (USA) (Disc 1).chd
/media/fat/games/PSX/Final Fantasy VII (USA)/Final Fantasy VII (USA) (Disc 2).chd
/media/fat/games/PSX/Final Fantasy VII (USA)/Final Fantasy VII (USA) (Disc 3).chd
```

## Video output

Core can output through HDMI and Analog out.

HDMI also offers a debugging framebuffer mode with support of full VRAM as 1024x512 pixel image(debug only)

## Libcrypt

Some games are secured with Libcrypt and will not work if it's not circumvented.

You can provide a .sbi file to do that.
If there is a .sbi file next to a .cue with the same name, it is loaded automatically when mounting the CD image.

## Error messages

If there is a recognized problem, an overlay is displayed, showing which error has occured.
You can hide these messages with an OSD option, by default they are on.

List of Errors:
- E2     - CPU exception(only relevant if game shows issues)
- E3..E6 - GPU hangs (e.g. corrupt display list)
- E7     - CPU2VRAM with mask-AND enabled
- E8     - DMA chopping enabled
- E9     - GPU FIFO overflow
- EA     - SPU timeout
- EB     - DMA and CPU interlock error 
- EC     - DMA FIFO overflow
- ED     - CPU Data/Bus request timeout -> will also appear if the BIOS is not found or corrupt or no SDRAM module is installed
- EE     - Dotclock used as timer report(only relevant if game shows issues)

## Debug Options

The debug menu is intended for use by developers only. They don't really serve any purpose for regular users so it's best to leave them at their default setting as a lot of undesirable behavior could occur.

## Pad Options
The following pad types are emulated by the core and can be independently assigned to each port:
- DualShock:
  Switch Digital/Analog mode with mouse/touchpad click or L3+R3+Up/Down or mapable button 
- Digital  
  (ID 0x41) Ten button digital pad.
- Analog  
  (ID 0x73) Twinstick pad.  
- Mouse  
  (ID 0x12) Two button mouse.
- Off  
  Pad unplugged from port.
- GunCon  
  (ID 0x62) GunCon compatible lightgun.
- Justifier  
- NeGcon  
  (ID 0x23) NeGcon compatible racing pad.  
  Primarily developed for dual analog stick usage with the following mapping (genuine NeGcons  
   may work if usb adapters map steering to Left Analog and I/II to Right Analog):
   - Steering -> Left Analog
   - Circle -> Circle
   - Triangle -> Triangle
   - I -> Right Analog Up, Cross (100% pressed), R2 (100% pressed)
   - II -> Right Analog Down, Rectangle (100% pressed), L2 (100% pressed)
   - L -> L1 (100% pressed)
   - R -> R1
   
SNAC can be selected for each port and will support gamepads and memory cards on the corresponding slot.
When SNAC is enabled for a slot, the emulated gamepad/memory for this slot is disconnected.

## Status

Many games working

--

CPU    : 90%
- exception for read in invalid instruction and data area missing

GPU    : 90%
- mask bits not implemented for cpu2vram -> nothing yet found that uses it
- vram2vram read/modify/write race condition when copying to same line

Memory : 80%
- sdram controller needs rewrite to support fast banked read

IRQ    : 90%
- irq_SIO missing because unused        

PAD    : 90%

DMA    : 80%
- DMA write performance only 32bit/2 cycles, should be 32Bit/1 cycle?

Memctrl: register stubs only

SIO    : register stubs only

Timer  : 80%
- dotclock base missing
- accuracy for start/wraparound not tested

GTE    : 90%
- CPU <-> GTE Transfer pipeline delay not fully correct

MDEC   : 90%
- timing slightly too fast (4996/5376)
 
CD     : 90%

SPU    : 90%
