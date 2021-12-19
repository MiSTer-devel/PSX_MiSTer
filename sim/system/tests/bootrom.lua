require("lib")

wait_ns(220000)

reg_set(0, psx.Reg_psx_on)

reg_set_file("scph1001.bin", 2097152, 0, 0)

reg_set(1, psx.Reg_psx_on)

print("psx ON")

brk()