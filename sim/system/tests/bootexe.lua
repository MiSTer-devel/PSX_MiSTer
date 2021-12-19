require("lib")

wait_ns(220000)

reg_set(0, psx.Reg_psx_on)

reg_set_file("scph1001.bin", 2097152, 0, 0)
--reg_set_file("scph1001_tty.bin", 2097152, 0, 0)

reg_set_file("C:\\Projekte\\psx\\krom_testroms\\CPUTest\\CPU\\ADD\\CPUADD.exe", 4194304, 0, 0)
--reg_set_file("C:\\Users\\FPGADev\\Desktop\\Emu-Docs-master\\PlayStation\\PSXTests_krom\\all\\cpuor.exe", 4194304, 0, 0)

reg_set(1, psx.Reg_psx_LoadExe)
reg_set(1, psx.Reg_psx_on)
reg_set(0, psx.Reg_psx_LoadExe)

print("psx ON")

brk()