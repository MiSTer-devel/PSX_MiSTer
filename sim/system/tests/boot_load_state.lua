require("psx_lib")

wait_ns(220000)

reg_set(0, psx.Reg_psx_on)

--transmit_rom("test.psx", 65536+131072 + 0xC000000, nil)
print("Game transfered")

--reg_set_file("test.ss", 58720256 + 0xC000000, 0, 0)
print("Savestate transfered")

reg_set(1, psx.Reg_psx_on)

reg_set(1, psx.Reg_psx_LoadState)

print("psx ON")

brk()
