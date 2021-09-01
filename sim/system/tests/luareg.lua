--space.name = {address, upper, lower, size, default}
psx = {}
psx.Reg_psx_on = {1056768,0,0,1,0,"psx.Reg_psx_on"} -- on = 1
psx.Reg_psx_lockspeed = {1056769,0,0,1,0,"psx.Reg_psx_lockspeed"} -- 1 = 100% speed
psx.Reg_psx_flash_1m = {1056770,0,0,1,0,"psx.Reg_psx_flash_1m"}
psx.Reg_psx_CyclePrecalc = {1056771,15,0,1,100,"psx.Reg_psx_CyclePrecalc"}
psx.Reg_psx_CyclesMissing = {1056772,31,0,1,0,"psx.Reg_psx_CyclesMissing"}
psx.Reg_psx_BusAddr = {1056773,27,0,1,0,"psx.Reg_psx_BusAddr"}
psx.Reg_psx_BusRnW = {1056773,28,28,1,0,"psx.Reg_psx_BusRnW"}
psx.Reg_psx_BusACC = {1056773,30,29,1,0,"psx.Reg_psx_BusACC"}
psx.Reg_psx_BusWriteData = {1056774,31,0,1,0,"psx.Reg_psx_BusWriteData"}
psx.Reg_psx_BusReadData = {1056775,31,0,1,0,"psx.Reg_psx_BusReadData"}
psx.Reg_psx_MaxPakAddr = {1056776,24,0,1,0,"psx.Reg_psx_MaxPakAddr"}
psx.Reg_psx_VsyncSpeed = {1056777,31,0,1,0,"psx.Reg_psx_VsyncSpeed"}
psx.Reg_psx_KeyUp = {1056778,0,0,1,0,"psx.Reg_psx_KeyUp"}
psx.Reg_psx_KeyDown = {1056778,1,1,1,0,"psx.Reg_psx_KeyDown"}
psx.Reg_psx_KeyLeft = {1056778,2,2,1,0,"psx.Reg_psx_KeyLeft"}
psx.Reg_psx_KeyRight = {1056778,3,3,1,0,"psx.Reg_psx_KeyRight"}
psx.Reg_psx_KeyA = {1056778,4,4,1,0,"psx.Reg_psx_KeyA"}
psx.Reg_psx_KeyB = {1056778,5,5,1,0,"psx.Reg_psx_KeyB"}
psx.Reg_psx_KeyL = {1056778,6,6,1,0,"psx.Reg_psx_KeyL"}
psx.Reg_psx_KeyR = {1056778,7,7,1,0,"psx.Reg_psx_KeyR"}
psx.Reg_psx_KeyStart = {1056778,8,8,1,0,"psx.Reg_psx_KeyStart"}
psx.Reg_psx_KeySelect = {1056778,9,9,1,0,"psx.Reg_psx_KeySelect"}
psx.Reg_psx_cputurbo = {1056780,0,0,1,0,"psx.Reg_psx_cputurbo"} -- 1 = cpu free running, all other 16 mhz
psx.Reg_psx_SramFlashEna = {1056781,0,0,1,0,"psx.Reg_psx_SramFlashEna"} -- 1 = enabled, 0 = disable (disable for copy protection in some games)
psx.Reg_psx_MemoryRemap = {1056782,0,0,1,0,"psx.Reg_psx_MemoryRemap"} -- 1 = enabled, 0 = disable (enable for copy protection in some games)
psx.Reg_psx_SaveState = {1056783,0,0,1,0,"psx.Reg_psx_SaveState"}
psx.Reg_psx_LoadState = {1056784,0,0,1,0,"psx.Reg_psx_LoadState"}
psx.Reg_psx_FrameBlend = {1056785,0,0,1,0,"psx.Reg_psx_FrameBlend"} -- mix last and current frame
psx.Reg_psx_Pixelshade = {1056786,2,0,1,0,"psx.Reg_psx_Pixelshade"} -- pixel shade 1..4, 0 = off
psx.Reg_psx_SaveStateAddr = {1056787,25,0,1,0,"psx.Reg_psx_SaveStateAddr"} -- address to save/load savestate
psx.Reg_psx_Rewind_on = {1056788,0,0,1,0,"psx.Reg_psx_Rewind_on"}
psx.Reg_psx_Rewind_active = {1056789,0,0,1,0,"psx.Reg_psx_Rewind_active"}
psx.Reg_psx_LoadExe = {1056790,0,0,1,0,"psx.Reg_psx_LoadExe"}
psx.Reg_psx_DEBUG_CPU_PC = {1056800,31,0,1,0,"psx.Reg_psx_DEBUG_CPU_PC"}
psx.Reg_psx_DEBUG_CPU_MIX = {1056801,31,0,1,0,"psx.Reg_psx_DEBUG_CPU_MIX"}
psx.Reg_psx_DEBUG_IRQ = {1056802,31,0,1,0,"psx.Reg_psx_DEBUG_IRQ"}
psx.Reg_psx_DEBUG_DMA = {1056803,31,0,1,0,"psx.Reg_psx_DEBUG_DMA"}
psx.Reg_psx_DEBUG_MEM = {1056804,31,0,1,0,"psx.Reg_psx_DEBUG_MEM"}
psx.Reg_psx_CHEAT_FLAGS = {1056810,31,0,1,0,"psx.Reg_psx_CHEAT_FLAGS"}
psx.Reg_psx_CHEAT_ADDRESS = {1056811,31,0,1,0,"psx.Reg_psx_CHEAT_ADDRESS"}
psx.Reg_psx_CHEAT_COMPARE = {1056812,31,0,1,0,"psx.Reg_psx_CHEAT_COMPARE"}
psx.Reg_psx_CHEAT_REPLACE = {1056813,31,0,1,0,"psx.Reg_psx_CHEAT_REPLACE"}
psx.Reg_psx_CHEAT_RESET = {1056814,0,0,1,0,"psx.Reg_psx_CHEAT_RESET"}