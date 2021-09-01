library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library procbus;
use procbus.pProc_bus.all;
use procbus.pRegmap.all;

package pReg_tb is

   -- range 1048576 .. 2097151
   --                                                adr      upper    lower    size  default   accesstype)
   constant Reg_psx_on            : regmap_type := (1056768,   0,      0,        1,       0,   readwrite); -- on = 1
   
   constant Reg_psx_lockspeed     : regmap_type := (1056769,   0,      0,        1,       0,   readwrite); -- 1 = 100% speed
      
   constant Reg_psx_flash_1m      : regmap_type := (1056770,   0,      0,        1,       0,   readwrite);
                                               
   constant Reg_psx_CyclePrecalc  : regmap_type := (1056771,  15,      0,        1,     100,   readwrite);  
   constant Reg_psx_CyclesMissing : regmap_type := (1056772,  31,      0,        1,       0,   readonly);  
                                  
   constant Reg_psx_BusAddr       : regmap_type := (1056773,  27,      0,        1,       0,   readwrite);
   constant Reg_psx_BusRnW        : regmap_type := (1056773,  28,     28,        1,       0,   readwrite);
   constant Reg_psx_BusACC        : regmap_type := (1056773,  30,     29,        1,       0,   readwrite);
   constant Reg_psx_BusWriteData  : regmap_type := (1056774,  31,      0,        1,       0,   readwrite);
   constant Reg_psx_BusReadData   : regmap_type := (1056775,  31,      0,        1,       0,   readonly);
   
   constant Reg_psx_MaxPakAddr    : regmap_type := (1056776,  24,      0,        1,       0,   readwrite);
   
   constant Reg_psx_VsyncSpeed    : regmap_type := (1056777,  31,      0,        1,       0,   readwrite);                        
                                  
      -- joypad                          
   constant Reg_psx_KeyUp         : regmap_type := (1056778,   0,      0,        1,       0,   readwrite); 
   constant Reg_psx_KeyDown       : regmap_type := (1056778,   1,      1,        1,       0,   readwrite); 
   constant Reg_psx_KeyLeft       : regmap_type := (1056778,   2,      2,        1,       0,   readwrite); 
   constant Reg_psx_KeyRight      : regmap_type := (1056778,   3,      3,        1,       0,   readwrite); 
   constant Reg_psx_KeyA          : regmap_type := (1056778,   4,      4,        1,       0,   readwrite); 
   constant Reg_psx_KeyB          : regmap_type := (1056778,   5,      5,        1,       0,   readwrite); 
   constant Reg_psx_KeyL          : regmap_type := (1056778,   6,      6,        1,       0,   readwrite); 
   constant Reg_psx_KeyR          : regmap_type := (1056778,   7,      7,        1,       0,   readwrite); 
   constant Reg_psx_KeyStart      : regmap_type := (1056778,   8,      8,        1,       0,   readwrite); 
   constant Reg_psx_KeySelect     : regmap_type := (1056778,   9,      9,        1,       0,   readwrite); 
   
   -- special settings
   constant Reg_psx_cputurbo      : regmap_type := (1056780,   0,      0,        1,       0,   readwrite); -- 1 = cpu free running, all other 16 mhz
   constant Reg_psx_SramFlashEna  : regmap_type := (1056781,   0,      0,        1,       0,   readwrite); -- 1 = enabled, 0 = disable (disable for copy protection in some games)
   constant Reg_psx_MemoryRemap   : regmap_type := (1056782,   0,      0,        1,       0,   readwrite); -- 1 = enabled, 0 = disable (enable for copy protection in some games)
   constant Reg_psx_SaveState     : regmap_type := (1056783,   0,      0,        1,       0,   Pulse); 
   constant Reg_psx_LoadState     : regmap_type := (1056784,   0,      0,        1,       0,   Pulse); 
   constant Reg_psx_FrameBlend    : regmap_type := (1056785,   0,      0,        1,       0,   readwrite); -- mix last and current frame
   constant Reg_psx_Pixelshade    : regmap_type := (1056786,   2,      0,        1,       0,   readwrite); -- pixel shade 1..4, 0 = off
   constant Reg_psx_SaveStateAddr : regmap_type := (1056787,  25,      0,        1,       0,   readwrite); -- address to save/load savestate
   constant Reg_psx_Rewind_on     : regmap_type := (1056788,   0,      0,        1,       0,   readwrite);
   constant Reg_psx_Rewind_active : regmap_type := (1056789,   0,      0,        1,       0,   readwrite);
   constant Reg_psx_LoadExe       : regmap_type := (1056790,   0,      0,        1,       0,   readwrite);
   
   --debug
   constant Reg_psx_DEBUG_CPU_PC  : regmap_type := (1056800,  31,      0,        1,       0,   readonly);
   constant Reg_psx_DEBUG_CPU_MIX : regmap_type := (1056801,  31,      0,        1,       0,   readonly);
   constant Reg_psx_DEBUG_IRQ     : regmap_type := (1056802,  31,      0,        1,       0,   readonly);
   constant Reg_psx_DEBUG_DMA     : regmap_type := (1056803,  31,      0,        1,       0,   readonly);
   constant Reg_psx_DEBUG_MEM     : regmap_type := (1056804,  31,      0,        1,       0,   readonly);
   
   --cheats
   constant Reg_psx_CHEAT_FLAGS   : regmap_type := (1056810,  31,      0,        1,       0,   readwrite);
   constant Reg_psx_CHEAT_ADDRESS : regmap_type := (1056811,  31,      0,        1,       0,   readwrite);
   constant Reg_psx_CHEAT_COMPARE : regmap_type := (1056812,  31,      0,        1,       0,   readwrite);
   constant Reg_psx_CHEAT_REPLACE : regmap_type := (1056813,  31,      0,        1,       0,   readwrite);
   constant Reg_psx_CHEAT_RESET   : regmap_type := (1056814,   0,      0,        1,       0,   Pulse);
   
end package;
