require("lib")

wait_ns(220000)

reg_set(0, psx.Reg_psx_on)

reg_set_file("scph1001.bin", 2097152, 0, 0)

wait_ns(1000)

reg_set(1, psx.Reg_psx_on)
print("psx ON")

wait_ns(100000)

reg_set(1, psx.Reg_psx_SaveState)
reg_set(0, psx.Reg_psx_SaveState)

brk()
