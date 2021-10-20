require("lib")

wait_ns(220000)

reg_set(0, psx.Reg_psx_on)

reg_set_file("scph1001.bin", 2097152, 0, 0)
--reg_set_file("scph1001_tty.bin", 2097152, 0, 0)

--filename = "C:\\Projekte\\psx\\FPSXApp\\GTEAVSZ.sst";
--filename = "C:\\Projekte\\psx\\FPSXApp\\PSXNICCC.sst";
--filename = "C:\\Projekte\\psx\\FPSXApp\\psxtest_gte.sst";
--filename = "C:\\Projekte\\psx\\FPSXApp\\Croc - Legend of the Gobbos (Europe) (Demo).sst";
filename = "C:\\Projekte\\psx\\FPSXApp\\Spyro the Dragon Speciale (France) (Track 1).sst";
--filename = "C:\\Projekte\\psx\\FPSXApp\\benchmark.sst";
--filename = "C:\\Projekte\\psx\\FPSXApp\\ImageLoad.sst";
--filename = "C:\\Projekte\\psx\\FPSXApp\\BIOS.sst";

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
