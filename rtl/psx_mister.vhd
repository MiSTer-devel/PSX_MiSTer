library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

entity psx_mister is
   generic
   (
      is_simu               : std_logic := '0'
   );
   port 
   (
      clk1x                 : in  std_logic;  
      clk2x                 : in  std_logic;  
      clk3x                 : in  std_logic;  
      clkvid                : in  std_logic;  
      reset                 : in  std_logic;
      isPaused              : out std_logic;
      -- commands 
      pause                 : in  std_logic;
      hps_busy              : in  std_logic;
      loadExe               : in  std_logic;
      exe_initial_pc        : in  unsigned(31 downto 0);
      exe_initial_gp        : in  unsigned(31 downto 0);
      exe_load_address      : in  unsigned(31 downto 0);
      exe_file_size         : in  unsigned(31 downto 0);
      exe_stackpointer      : in  unsigned(31 downto 0);
      fastboot              : in  std_logic;
      ram8mb                : in  std_logic;
      TURBO_MEM             : in  std_logic;
      TURBO_COMP            : in  std_logic;
      TURBO_CACHE           : in  std_logic;
      TURBO_CACHE50         : in  std_logic;
      REPRODUCIBLEGPUTIMING : in  std_logic;
      DMABLOCKATONCE        : in  std_logic;
      INSTANTSEEK           : in  std_logic;
      FORCECDSPEED          : in  std_logic_vector(2 downto 0);
      LIMITREADSPEED        : in  std_logic;
      ditherOff             : in  std_logic;
      showGunCrosshairs     : in  std_logic;
      fpscountOn            : in  std_logic;
      cdslowOn              : in  std_logic;
      testSeek              : in  std_logic;
      pauseOnCDSlow         : in  std_logic;
      errorOn               : in  std_logic;
      LBAOn                 : in  std_logic;
      PATCHSERIAL           : in  std_logic;
      noTexture             : in  std_logic;
      textureFilter         : in  std_logic_vector(1 downto 0);
      textureFilterStrength : in  std_logic_vector(1 downto 0);
      textureFilter2DOff    : in  std_logic;
      dither24              : in  std_logic;
      render24              : in  std_logic;
      syncVideoOut          : in  std_logic;
      syncInterlace         : in  std_logic;
      rotate180             : in  std_logic;
      fixedVBlank           : in  std_logic;
      vCrop                 : in  std_logic_vector(1 downto 0);
      hCrop                 : in  std_logic;
      SPUon                 : in  std_logic;
      SPUSDRAM              : in  std_logic;
      REVERBOFF             : in  std_logic;
      REPRODUCIBLESPUDMA    : in  std_logic;
      WIDESCREEN            : in  std_logic_vector(1 downto 0);
      -- RAM/BIOS interface      
      biosregion            : in  std_logic_vector(1 downto 0);  
      ram_refresh           : out std_logic;
      ram_dataWrite         : out std_logic_vector(31 downto 0);
      ram_dataRead32        : in  std_logic_vector(31 downto 0);
      ram_Adr               : out std_logic_vector(24 downto 0);
      ram_be                : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw               : out std_logic;
      ram_ena               : out std_logic;
      ram_dma               : out std_logic;
      ram_cache             : out std_logic;
      ram_done              : in  std_logic;
      ram_dmafifo_adr       : out std_logic_vector(22 downto 0);
      ram_dmafifo_data      : out std_logic_vector(31 downto 0);
      ram_dmafifo_empty     : out std_logic;
      ram_dmafifo_read      : in  std_logic; 
      cache_wr              : in  std_logic_vector(3 downto 0);
      cache_data            : in  std_logic_vector(31 downto 0);
      cache_addr            : in  std_logic_vector(7 downto 0);  
      dma_wr                : in  std_logic;
      dma_reqprocessed      : in  std_logic;
      dma_data              : in  std_logic_vector(31 downto 0);      
      -- vram/ddr3 interface
      DDRAM_BUSY            : in  std_logic;                    
      DDRAM_BURSTCNT        : out std_logic_vector(7 downto 0); 
      DDRAM_ADDR            : out std_logic_vector(28 downto 0);
      DDRAM_DOUT            : in  std_logic_vector(63 downto 0);
      DDRAM_DOUT_READY      : in  std_logic;                    
      DDRAM_RD              : out std_logic;                    
      DDRAM_DIN             : out std_logic_vector(63 downto 0);
      DDRAM_BE              : out std_logic_vector(7 downto 0); 
      DDRAM_WE              : out std_logic;
      -- cd
      region                : in  std_logic_vector(1 downto 0);
      region_out            : out std_logic_vector(1 downto 0);
      hasCD                 : in  std_logic;
      LIDopen               : in  std_logic;
      fastCD                : in  std_logic;
      trackinfo_data        : in  std_logic_vector(31 downto 0);
      trackinfo_addr        : in  std_logic_vector(8 downto 0);
      trackinfo_write       : in  std_logic;
      resetFromCD           : out std_logic;
      cd_hps_req            : out std_logic := '0';
      cd_hps_lba            : out std_logic_vector(31 downto 0);
      cd_hps_lba_sim        : out std_logic_vector(31 downto 0);
      cd_hps_ack            : in  std_logic;
      cd_hps_write          : in  std_logic;
      cd_hps_data           : in  std_logic_vector(15 downto 0);
      -- spuram
      spuram_dataWrite      : out std_logic_vector(31 downto 0);
      spuram_Adr            : out std_logic_vector(18 downto 0);
      spuram_be             : out std_logic_vector(3 downto 0);
      spuram_rnw            : out std_logic;
      spuram_ena            : out std_logic;
      spuram_dataRead       : in  std_logic_vector(31 downto 0);
      spuram_done           : in  std_logic;
      -- memcard
      memcard_changed       : out std_logic;
      saving_memcard        : out std_logic;
      memcard1_load         : in  std_logic;
      memcard2_load         : in  std_logic;
      memcard_save          : in  std_logic;
      memcard1_mounted      : in  std_logic;
      memcard1_available    : in  std_logic;
      memcard1_rd           : out std_logic := '0';
      memcard1_wr           : out std_logic := '0';
      memcard1_lba          : out std_logic_vector(6 downto 0);
      memcard1_ack          : in  std_logic;
      memcard1_write        : in  std_logic;
      memcard1_addr         : in  std_logic_vector(8 downto 0);
      memcard1_dataIn       : in  std_logic_vector(15 downto 0);
      memcard1_dataOut      : out std_logic_vector(15 downto 0);
      memcard2_mounted      : in  std_logic;               
      memcard2_available    : in  std_logic;               
      memcard2_rd           : out std_logic := '0';
      memcard2_wr           : out std_logic := '0';
      memcard2_lba          : out std_logic_vector(6 downto 0);
      memcard2_ack          : in  std_logic;
      memcard2_write        : in  std_logic;
      memcard2_addr         : in  std_logic_vector(8 downto 0);
      memcard2_dataIn       : in  std_logic_vector(15 downto 0);
      memcard2_dataOut      : out std_logic_vector(15 downto 0);
      -- video
      videoout_on           : in  std_logic;
      isPal                 : in  std_logic;
      pal60                 : in  std_logic;
      hsync                 : out std_logic;
      vsync                 : out std_logic;
      hblank                : out std_logic;
      vblank                : out std_logic;
      DisplayWidth          : out unsigned( 9 downto 0);
      DisplayHeight         : out unsigned( 8 downto 0);
      DisplayOffsetX        : out unsigned( 9 downto 0);
      DisplayOffsetY        : out unsigned( 8 downto 0);
      video_ce              : out std_logic;
      video_interlace       : out std_logic;
      video_r               : out std_logic_vector(7 downto 0);
      video_g               : out std_logic_vector(7 downto 0);
      video_b               : out std_logic_vector(7 downto 0);
      video_isPal           : out std_logic;
      video_hResMode        : out std_logic_vector(2 downto 0);
      -- Keys - all active high   
      DSAltSwitchMode       : in  std_logic;
      PadPortEnable1        : in  std_logic;
      PadPortDigital1       : in  std_logic;
      PadPortAnalog1        : in  std_logic;
      PadPortMouse1         : in  std_logic;
      PadPortGunCon1        : in  std_logic;
      PadPortneGcon1        : in  std_logic;
      PadPortWheel1         : in  std_logic;
      PadPortDS1            : in  std_logic;
      PadPortJustif1        : in  std_logic;
      PadPortStick1         : in  std_logic;
      PadPortEnable2        : in  std_logic;
      PadPortDigital2       : in  std_logic;
      PadPortAnalog2        : in  std_logic;
      PadPortMouse2         : in  std_logic;
      PadPortGunCon2        : in  std_logic;
      PadPortneGcon2        : in  std_logic;
      PadPortWheel2         : in  std_logic;
      PadPortDS2            : in  std_logic;
      PadPortJustif2        : in  std_logic;
      PadPortStick2         : in  std_logic;
      KeyTriangle           : in  std_logic_vector(3 downto 0);
      KeyCircle             : in  std_logic_vector(3 downto 0);
      KeyCross              : in  std_logic_vector(3 downto 0);
      KeySquare             : in  std_logic_vector(3 downto 0);
      KeySelect             : in  std_logic_vector(3 downto 0);
      KeyStart              : in  std_logic_vector(3 downto 0);
      KeyRight              : in  std_logic_vector(3 downto 0);
      KeyLeft               : in  std_logic_vector(3 downto 0);
      KeyUp                 : in  std_logic_vector(3 downto 0);
      KeyDown               : in  std_logic_vector(3 downto 0);
      KeyR1                 : in  std_logic_vector(3 downto 0);
      KeyR2                 : in  std_logic_vector(3 downto 0);
      KeyR3                 : in  std_logic_vector(3 downto 0);
      KeyL1                 : in  std_logic_vector(3 downto 0);
      KeyL2                 : in  std_logic_vector(3 downto 0);
      KeyL3                 : in  std_logic_vector(3 downto 0);
      ToggleDS              : in  std_logic_vector(3 downto 0);
      Analog1XP1            : in  signed(7 downto 0);
      Analog1YP1            : in  signed(7 downto 0);
      Analog2XP1            : in  signed(7 downto 0);
      Analog2YP1            : in  signed(7 downto 0);         
      Analog1XP2            : in  signed(7 downto 0);
      Analog1YP2            : in  signed(7 downto 0);
      Analog2XP2            : in  signed(7 downto 0);
      Analog2YP2            : in  signed(7 downto 0);                  
      Analog1XP3            : in  signed(7 downto 0);
      Analog1YP3            : in  signed(7 downto 0);
      Analog2XP3            : in  signed(7 downto 0);
      Analog2YP3            : in  signed(7 downto 0);
      Analog1XP4            : in  signed(7 downto 0);
      Analog1YP4            : in  signed(7 downto 0);
      Analog2XP4            : in  signed(7 downto 0);
      Analog2YP4            : in  signed(7 downto 0);
      multitap              : in  std_logic;
      -- mouse
      MouseEvent            : in  std_logic;
      MouseLeft             : in  std_logic;
      MouseRight            : in  std_logic;
      MouseX                : in  signed(8 downto 0);
      MouseY                : in  signed(8 downto 0);
      RumbleDataP1          : out std_logic_vector(15 downto 0);
      RumbleDataP2          : out std_logic_vector(15 downto 0);
      RumbleDataP3          : out std_logic_vector(15 downto 0);
      RumbleDataP4          : out std_logic_vector(15 downto 0);
      padMode               : out std_logic_vector(1 downto 0);
      -- snac
      snacPort1             : in  std_logic;
      snacPort2             : in  std_logic;
      irq10Snac             : in  std_logic;
      actionNextSnac        : in  std_logic;
      receiveValidSnac      : in  std_logic;
      ackSnac               : in  std_logic;
      receiveBufferSnac	    : in  std_logic_vector(7 downto 0);
      transmitValueSnac     : out std_logic_vector(7 downto 0);		
      selectedPort1Snac     : out std_logic;
      selectedPort2Snac     : out std_logic;
      clk9Snac              : out std_logic;
      beginTransferSnac     : out std_logic;
		
      -- sound                          
      sound_out_left        : out std_logic_vector(15 downto 0) := (others => '0');
      sound_out_right       : out std_logic_vector(15 downto 0) := (others => '0');
      -- savestates
      increaseSSHeaderCount : in  std_logic;
      save_state            : in  std_logic;
      load_state            : in  std_logic;
      savestate_number      : in  integer range 0 to 3;
      state_loaded          : out std_logic;
      rewind_on             : in  std_logic;
      rewind_active         : in  std_logic;
      -- cheats
      cheat_clear           : in  std_logic;
      cheats_enabled        : in  std_logic;
      cheat_on              : in  std_logic;
      cheat_in              : in  std_logic_vector(127 downto 0);
      cheats_active         : out std_logic := '0';
      Cheats_BusAddr        : buffer std_logic_vector(20 downto 0);
      Cheats_BusRnW         : out    std_logic;
      Cheats_BusByteEnable  : out    std_logic_vector(3 downto 0);
      Cheats_BusWriteData   : out    std_logic_vector(31 downto 0);
      Cheats_Bus_ena        : out    std_logic := '0';
      Cheats_BusReadData    : in     std_logic_vector(31 downto 0);
      Cheats_BusDone        : in     std_logic
   );
end entity;

architecture arch of psx_mister is

   signal ddr3_ADDR : std_logic_vector(27 downto 0);
   
begin 

   -- vram is at 0x30000000
   DDRAM_ADDR(28 downto 25) <= "0011";
   DDRAM_ADDR(24 downto  0) <= ddr3_ADDR(27 downto 3);

   ipsx_top : entity work.psx_top
   generic map
   (
      is_simu               => is_simu
   )
   port map
   (
      clk1x                 => clk1x,          
      clk2x                 => clk2x,          
      clk3x                 => clk3x,          
      clkvid                => clkvid,          
      reset                 => reset, 
      isPaused              => isPaused, 
      -- commands 
      pause                 => pause,
      hps_busy              => hps_busy,
      loadExe               => loadExe,
      exe_initial_pc        => exe_initial_pc,  
      exe_initial_gp        => exe_initial_gp,  
      exe_load_address      => exe_load_address,
      exe_file_size         => exe_file_size,   
      exe_stackpointer      => exe_stackpointer,
      fastboot              => fastboot,
      ram8mb                => ram8mb,
      TURBO_MEM             => TURBO_MEM,
      TURBO_COMP            => TURBO_COMP,
      TURBO_CACHE           => TURBO_CACHE,
      TURBO_CACHE50         => TURBO_CACHE50,
      REPRODUCIBLEGPUTIMING => REPRODUCIBLEGPUTIMING,
      DMABLOCKATONCE        => DMABLOCKATONCE,
      INSTANTSEEK           => INSTANTSEEK,
      FORCECDSPEED          => FORCECDSPEED,
      LIMITREADSPEED        => LIMITREADSPEED,
      ditherOff             => ditherOff,
      showGunCrosshairs     => showGunCrosshairs,
      fpscountOn            => fpscountOn,
      cdslowOn              => cdslowOn,
      testSeek              => testSeek,
      pauseOnCDSlow         => pauseOnCDSlow,
      errorOn               => errorOn,
      LBAOn                 => LBAOn,
      PATCHSERIAL           => PATCHSERIAL,
      noTexture             => noTexture,
      textureFilter         => textureFilter,
      textureFilterStrength => textureFilterStrength,
      textureFilter2DOff    => textureFilter2DOff,
      dither24              => dither24,
      render24              => render24,
      syncVideoOut          => syncVideoOut,
      syncInterlace         => syncInterlace,
      rotate180             => rotate180,
      fixedVBlank           => fixedVBlank,
      vCrop                 => vCrop,      
      hCrop                 => hCrop,
      SPUon                 => SPUon,
      SPUSDRAM              => SPUSDRAM,
      REVERBOFF             => REVERBOFF,
      REPRODUCIBLESPUDMA    => REPRODUCIBLESPUDMA,
      WIDESCREEN            => WIDESCREEN,
      -- RAM/BIOS interface        
      biosregion            => biosregion,
      ram_refresh           => ram_refresh,
      ram_dataWrite         => ram_dataWrite,
      ram_dataRead32        => ram_dataRead32, 
      ram_Adr               => ram_Adr, 
      ram_be                => ram_be,        
      ram_rnw               => ram_rnw,      
      ram_ena               => ram_ena,  
      ram_dma               => ram_dma,       
      ram_cache             => ram_cache,       
      ram_done              => ram_done, 
      ram_dmafifo_adr       => ram_dmafifo_adr, 
      ram_dmafifo_data      => ram_dmafifo_data,
      ram_dmafifo_empty     => ram_dmafifo_empty,
      ram_dmafifo_read      => ram_dmafifo_read,   
      cache_wr              => cache_wr,  
      cache_data            => cache_data,
      cache_addr            => cache_addr,     
      dma_wr                => dma_wr,  
      dma_reqprocessed      => dma_reqprocessed,  
      dma_data              => dma_data,      
      -- vram interface
      ddr3_BUSY             => DDRAM_BUSY,      
      ddr3_DOUT             => DDRAM_DOUT,      
      ddr3_DOUT_READY       => DDRAM_DOUT_READY,
      ddr3_BURSTCNT         => DDRAM_BURSTCNT,  
      ddr3_ADDR             => ddr3_ADDR,      
      ddr3_DIN              => DDRAM_DIN,       
      ddr3_BE               => DDRAM_BE,        
      ddr3_WE               => DDRAM_WE,        
      ddr3_RD               => DDRAM_RD,
      -- cd
      region                => region,
      region_out            => region_out,
      hasCD                 => hasCD,
      LIDopen               => LIDopen,
      fastCD                => fastCD,
      trackinfo_data        => trackinfo_data,
      trackinfo_addr        => trackinfo_addr, 
      trackinfo_write       => trackinfo_write,
      resetFromCD           => resetFromCD,
      cd_hps_req            => cd_hps_req,  
      cd_hps_lba            => cd_hps_lba,  
      cd_hps_lba_sim        => cd_hps_lba_sim,  
      cd_hps_ack            => cd_hps_ack,
      cd_hps_write          => cd_hps_write,
      cd_hps_data           => cd_hps_data, 
      -- spuram
      spuram_dataWrite      => spuram_dataWrite, 
      spuram_Adr            => spuram_Adr,       
      spuram_be             => spuram_be,        
      spuram_rnw            => spuram_rnw,       
      spuram_ena            => spuram_ena,      
      spuram_dataRead       => spuram_dataRead,  
      spuram_done           => spuram_done,        
      --memcard
      memcard_changed       => memcard_changed,
      saving_memcard        => saving_memcard,
      memcard1_load         => memcard1_load,       
      memcard2_load         => memcard2_load,       
      memcard_save          => memcard_save,       
      memcard1_mounted      => memcard1_mounted, 
      memcard1_available    => memcard1_available, 
      memcard1_rd           => memcard1_rd,        
      memcard1_wr           => memcard1_wr,        
      memcard1_lba          => memcard1_lba,       
      memcard1_ack          => memcard1_ack,       
      memcard1_write        => memcard1_write,     
      memcard1_addr         => memcard1_addr,      
      memcard1_dataIn       => memcard1_dataIn,    
      memcard1_dataOut      => memcard1_dataOut,   
      memcard2_mounted      => memcard2_mounted, 
      memcard2_available    => memcard2_available, 
      memcard2_rd           => memcard2_rd,        
      memcard2_wr           => memcard2_wr,        
      memcard2_lba          => memcard2_lba,       
      memcard2_ack          => memcard2_ack,       
      memcard2_write        => memcard2_write,     
      memcard2_addr         => memcard2_addr,      
      memcard2_dataIn       => memcard2_dataIn,    
      memcard2_dataOut      => memcard2_dataOut,   
      -- video
      videoout_on           => videoout_on,
      isPal                 => isPal,
      pal60                 => pal60,
      hsync                 => hsync, 
      vsync                 => vsync, 
      hblank                => hblank,
      vblank                => vblank,
      DisplayWidth          => DisplayWidth, 
      DisplayHeight         => DisplayHeight,
      DisplayOffsetX        => DisplayOffsetX,
      DisplayOffsetY        => DisplayOffsetY,
      video_ce              => video_ce,
      video_interlace       => video_interlace,
      video_r               => video_r, 
      video_g               => video_g, 
      video_b               => video_b, 
      video_isPal           => video_isPal, 
      video_hResMode        => video_hResMode, 
      -- inputs
      DSAltSwitchMode       => DSAltSwitchMode,
      
      joypad1.PadPortEnable => PadPortEnable1,
      joypad1.PadPortDigital=> PadPortDigital1,
      joypad1.PadPortAnalog => PadPortAnalog1,
      joypad1.PadPortMouse  => PadPortMouse1,
      joypad1.PadPortGunCon => PadPortGunCon1,
      joypad1.PadPortNeGcon => PadPortNeGcon1,
      joypad1.PadPortJustif => PadPortJustif1,
      joypad1.WheelMap      => PadPortWheel1,
      joypad1.PadPortDS     => PadPortDS1,
      joypad1.PadPortStick  => PadPortStick1,

      joypad1.KeyTriangle   => KeyTriangle(0),
      joypad1.KeyCircle     => KeyCircle(0),
      joypad1.KeyCross      => KeyCross(0),
      joypad1.KeySquare     => KeySquare(0),
      joypad1.KeySelect     => KeySelect(0),
      joypad1.KeyStart      => KeyStart(0),
      joypad1.KeyRight      => KeyRight(0),
      joypad1.KeyLeft       => KeyLeft(0),
      joypad1.KeyUp         => KeyUp(0),
      joypad1.KeyDown       => KeyDown(0),
      joypad1.KeyR1         => KeyR1(0),
      joypad1.KeyR2         => KeyR2(0),
      joypad1.KeyR3         => KeyR3(0),
      joypad1.KeyL1         => KeyL1(0),
      joypad1.KeyL2         => KeyL2(0),
      joypad1.KeyL3         => KeyL3(0),
      joypad1.ToggleDS      => ToggleDS(0),
      joypad1.Analog1X      => Analog1XP1,
      joypad1.Analog1Y      => Analog1YP1,
      joypad1.Analog2X      => Analog2XP1,
      joypad1.Analog2Y      => Analog2YP1,
      joypad1_rumble        => RumbleDataP1,

      joypad2.PadPortEnable => PadPortEnable2,
      joypad2.PadPortDigital=> PadPortDigital2,
      joypad2.PadPortAnalog => PadPortAnalog2,
      joypad2.PadPortMouse  => PadPortMouse2,
      joypad2.PadPortGunCon => PadPortGunCon2,
      joypad2.PadPortNeGcon => PadPortNeGcon2,
      joypad2.PadPortJustif => PadPortJustif2,
      joypad2.WheelMap      => PadPortWheel2,
      joypad2.PadPortDS     => PadPortDS2,
      joypad2.PadPortStick  => PadPortStick2,

      joypad2.KeyTriangle   => KeyTriangle(1),
      joypad2.KeyCircle     => KeyCircle(1),
      joypad2.KeyCross      => KeyCross(1),
      joypad2.KeySquare     => KeySquare(1),
      joypad2.KeySelect     => KeySelect(1),
      joypad2.KeyStart      => KeyStart(1),
      joypad2.KeyRight      => KeyRight(1),
      joypad2.KeyLeft       => KeyLeft(1),
      joypad2.KeyUp         => KeyUp(1),
      joypad2.KeyDown       => KeyDown(1),
      joypad2.KeyR1         => KeyR1(1),
      joypad2.KeyR2         => KeyR2(1),
      joypad2.KeyR3         => KeyR3(1),
      joypad2.KeyL1         => KeyL1(1),
      joypad2.KeyL2         => KeyL2(1),
      joypad2.KeyL3         => KeyL3(1),
      joypad2.ToggleDS      => ToggleDS(1),
      joypad2.Analog1X      => Analog1XP2,
      joypad2.Analog1Y      => Analog1YP2,
      joypad2.Analog2X      => Analog2XP2,
      joypad2.Analog2Y      => Analog2YP2,
      joypad2_rumble        => RumbleDataP2,

      joypad3.PadPortEnable => '1',
      joypad3.PadPortDigital=> '1',
      joypad3.PadPortAnalog => '0',
      joypad3.PadPortMouse  => '0',
      joypad3.PadPortGunCon => '0',
      joypad3.PadPortNeGcon => '0',
      joypad3.PadPortJustif => '0',
      joypad3.WheelMap      => '0',
      joypad3.PadPortDS     => '0',
      joypad3.PadPortStick  => '0',

      joypad3.KeyTriangle   => KeyTriangle(2),
      joypad3.KeyCircle     => KeyCircle(2),
      joypad3.KeyCross      => KeyCross(2),
      joypad3.KeySquare     => KeySquare(2),
      joypad3.KeySelect     => KeySelect(2),
      joypad3.KeyStart      => KeyStart(2),
      joypad3.KeyRight      => KeyRight(2),
      joypad3.KeyLeft       => KeyLeft(2),
      joypad3.KeyUp         => KeyUp(2),
      joypad3.KeyDown       => KeyDown(2),
      joypad3.KeyR1         => KeyR1(2),
      joypad3.KeyR2         => KeyR2(2),
      joypad3.KeyR3         => KeyR3(2),
      joypad3.KeyL1         => KeyL1(2),
      joypad3.KeyL2         => KeyL2(2),
      joypad3.KeyL3         => KeyL3(2),
      joypad3.ToggleDS      => ToggleDS(2),
      joypad3.Analog1X      => Analog1XP3,
      joypad3.Analog1Y      => Analog1YP3,
      joypad3.Analog2X      => Analog2XP3,
      joypad3.Analog2Y      => Analog2YP3,
      joypad3_rumble        => RumbleDataP3,

      joypad4.PadPortEnable => '1',
      joypad4.PadPortDigital=> '1',
      joypad4.PadPortAnalog => '0',
      joypad4.PadPortMouse  => '0',
      joypad4.PadPortGunCon => '0',
      joypad4.PadPortNeGcon => '0',
      joypad4.PadPortJustif => '0',
      joypad4.WheelMap      => '0',
      joypad4.PadPortDS     => '0',
      joypad4.PadPortStick  => '0',

      joypad4.KeyTriangle   => KeyTriangle(3),
      joypad4.KeyCircle     => KeyCircle(3),
      joypad4.KeyCross      => KeyCross(3),
      joypad4.KeySquare     => KeySquare(3),
      joypad4.KeySelect     => KeySelect(3),
      joypad4.KeyStart      => KeyStart(3),
      joypad4.KeyRight      => KeyRight(3),
      joypad4.KeyLeft       => KeyLeft(3),
      joypad4.KeyUp         => KeyUp(3),
      joypad4.KeyDown       => KeyDown(3),
      joypad4.KeyR1         => KeyR1(3),
      joypad4.KeyR2         => KeyR2(3),
      joypad4.KeyR3         => KeyR3(3),
      joypad4.KeyL1         => KeyL1(3),
      joypad4.KeyL2         => KeyL2(3),
      joypad4.KeyL3         => KeyL3(3),
      joypad4.ToggleDS      => ToggleDS(3),
      joypad4.Analog1X      => Analog1XP4,
      joypad4.Analog1Y      => Analog1YP4,
      joypad4.Analog2X      => Analog2XP4,
      joypad4.Analog2Y      => Analog2YP4,
      joypad4_rumble        => RumbleDataP4,

      multitap              => multitap,

      padMode               => padMode,

      MouseEvent            => MouseEvent,
      MouseLeft             => MouseLeft,
      MouseRight            => MouseRight,
      MouseX                => MouseX,
      MouseY                => MouseY,

      snacPort1             => snacport1,
      snacPort2             => snacport2,
      selectedPort1Snac     => selectedPort1Snac,
      selectedPort2Snac     => selectedPort2Snac,
      irq10Snac             => irq10Snac,
      transmitValueSnac     => transmitValueSnac,
      clk9Snac              => clk9Snac,
      receiveBufferSnac	    => receiveBufferSnac,
      beginTransferSnac     => beginTransferSnac,
      actionNextSnac        => actionNextSnac,
      receiveValidSnac      => receiveValidSnac,
      ackSnac               => ackSnac,
		
      -- sound              => -- sound       
      sound_out_left        => sound_out_left, 
      sound_out_right       => sound_out_right,
      -- savestates         
      increaseSSHeaderCount => increaseSSHeaderCount,
      save_state            => save_state,           
      load_state            => load_state,           
      savestate_number      => savestate_number,     
      state_loaded          => state_loaded,
      rewind_on             => rewind_on,    
      -- cheats
      rewind_active         => rewind_active,
      cheat_clear           => cheat_clear,
      cheats_enabled        => cheats_enabled,
      cheat_on              => cheat_on,
      cheat_in              => cheat_in,
      cheats_active         => cheats_active,
      Cheats_BusAddr        => Cheats_BusAddr,
		--Cheats_BusAddr        => cheats_addr,
      Cheats_BusRnW         => Cheats_BusRnW,
      Cheats_BusByteEnable  => Cheats_BusByteEnable,
      Cheats_BusWriteData   => Cheats_BusWriteData,
      Cheats_Bus_ena        => Cheats_Bus_ena,
      Cheats_BusReadData    => Cheats_BusReadData,
      Cheats_BusDone        => Cheats_BusDone
   );                          

end architecture;





