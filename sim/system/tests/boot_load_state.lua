require("lib")

wait_ns(220000)

reg_set(0, psx.Reg_psx_on)

reg_set_file("scph1001.bin", 2097152, 0, 0)
--reg_set_file("scph1001_tty.bin", 2097152, 0, 0)

--filename = "C:\\Projekte\\psx\\FPSXApp\\Croc - Legend of the Gobbos (Europe) (Demo)_ingame.sst";
--filename = "C:\\Projekte\\psx\\FPSXApp\\Croc - Legend of the Gobbos (Europe) (Demo)_fmv.sst";
--filename = "C:\\Projekte\\psx\\FPSXApp\\Ridge Racer (USA) (Track 01).sst";
--filename = "C:\\Projekte\\psx\\FPSXApp\\Colin McRae Rally 2.0 (USA) (En,Fr,Es) (Track 1).sst";
--filename = "C:\\Projekte\\psx\\FPSXApp\\Diablo (Europe) (En,Fr,De,Sv).sst";

--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\Castlevania - Symphony of the Night (Europe) (Track 1)_3.ss";
--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\Spyro the Dragon Speciale (France) (Track 1)_1.ss";
--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\Ridge Racer (USA) (Track 01)_1.ss";
--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\Azure_Dreams_USA_2.ss";
--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\Colin McRae Rally 2.0 (USA) (En,Fr,Es) (Track 1)_2.ss";
--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\Final Fantasy VIII (USA) (Disc 1)_2.ss";
--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\WipEout (Europe) (Rev 1) (Track 01)_2.ss";
--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\G. Darius (Europe) (Track 1)_2.ss";
--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\Gauntlet Legends (Germany)_3.ss";
--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\Resident Evil 2 (Europe) (Disc 1) (Track 1)_3.ss";
--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\Croc - Legend of the Gobbos (Europe) (Demo)_1.ss";
--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\Tony Hawk's Pro Skater 2 (USA)_4.ss";
--filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\Doom (USA) (Track 1)_2.ss";
filename = "C:\\Users\\FPGADev\\Desktop\\savestates_psxcore\\Bubsy 3D - Furbitten Planet (USA)_2.ss";

reg_set_file(filename, 0x800000, 0, 0)
print("Savestate transfered")

wait_ns(1000)

reg_set_file(filename, 0x0, 0, 0, 524288 * 4, 524288 * 4)
print("SDRAM loaded")

reg_set_file(filename, 0x0, 0, 0, 262144 * 4, 262144 * 4, 2)
print("VRAM loaded")

reg_set(1, psx.Reg_psx_on)

reg_set(1, psx.Reg_psx_LoadState)

print("psx ON")

brk()
