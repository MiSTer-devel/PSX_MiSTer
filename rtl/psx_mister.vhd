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
      reset                 : in  std_logic;
      -- commands 
      pause                 : in  std_logic;
      loadExe               : in  std_logic;
      fastboot              : in  std_logic;
      FASTMEM               : in  std_logic;
      REPRODUCIBLEGPUTIMING : in  std_logic;
      REPRODUCIBLEDMATIMING : in  std_logic;
      DMABLOCKATONCE        : in  std_logic;
      INSTANTSEEK           : in  std_logic;
      ditherOff             : in  std_logic;
      fpscountOn            : in  std_logic;
      errorOn               : in  std_logic;
      noTexture             : in  std_logic;
      SPUon                 : in  std_logic;
      SPUSDRAM              : in  std_logic;
      REVERBOFF             : in  std_logic;
      REPRODUCIBLESPUDMA    : in  std_logic;
      -- RAM/BIOS interface      
      ram_refresh           : out std_logic;
      ram_dataWrite         : out std_logic_vector(31 downto 0);
      ram_dataRead          : in  std_logic_vector(127 downto 0);
      ram_dataRead32        : in  std_logic_vector(31 downto 0);
      ram_Adr               : out std_logic_vector(22 downto 0);
      ram_be                : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw               : out std_logic;
      ram_ena               : out std_logic;
      ram_128               : out std_logic;
      ram_done              : in  std_logic;  
      ram_reqprocessed      : in  std_logic;   
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
      hasCD                 : in  std_logic;
      fastCD                : in  std_logic;
      libcryptKey           : in  std_logic_vector(15 downto 0);
      cd_Size               : in  unsigned(29 downto 0);
      cd_req                : out std_logic := '0';
      cd_addr               : out std_logic_vector(26 downto 0) := (others => '0');
      cd_data               : in  std_logic_vector(31 downto 0);
      cd_done               : in  std_logic;
      cd_hps_on             : in  std_logic;
      cd_hps_req            : out std_logic := '0';
      cd_hps_lba            : out std_logic_vector(31 downto 0);
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
      memcard1_load         : in  std_logic;
      memcard2_load         : in  std_logic;
      memcard_save          : in  std_logic;
      memcard1_available    : in  std_logic;
      memcard1_rd           : out std_logic := '0';
      memcard1_wr           : out std_logic := '0';
      memcard1_lba          : out std_logic_vector(6 downto 0);
      memcard1_ack          : in  std_logic;
      memcard1_write        : in  std_logic;
      memcard1_addr         : in  std_logic_vector(8 downto 0);
      memcard1_dataIn       : in  std_logic_vector(15 downto 0);
      memcard1_dataOut      : out std_logic_vector(15 downto 0);
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
      -- Keys - all active high   
      PadPortEnable1        : in  std_logic;
      PadPortAnalog1        : in  std_logic;
      PadPortMouse1         : in  std_logic;
      PadPortEnable2        : in  std_logic;
      PadPortAnalog2        : in  std_logic;
      PadPortMouse2         : in  std_logic;
      KeyTriangle           : in  std_logic_vector(1 downto 0); 
      KeyCircle             : in  std_logic_vector(1 downto 0); 
      KeyCross              : in  std_logic_vector(1 downto 0); 
      KeySquare             : in  std_logic_vector(1 downto 0);
      KeySelect             : in  std_logic_vector(1 downto 0);
      KeyStart              : in  std_logic_vector(1 downto 0);
      KeyRight              : in  std_logic_vector(1 downto 0);
      KeyLeft               : in  std_logic_vector(1 downto 0);
      KeyUp                 : in  std_logic_vector(1 downto 0);
      KeyDown               : in  std_logic_vector(1 downto 0);
      KeyR1                 : in  std_logic_vector(1 downto 0);
      KeyR2                 : in  std_logic_vector(1 downto 0);
      KeyR3                 : in  std_logic_vector(1 downto 0);
      KeyL1                 : in  std_logic_vector(1 downto 0);
      KeyL2                 : in  std_logic_vector(1 downto 0);
      KeyL3                 : in  std_logic_vector(1 downto 0);
      Analog1XP1            : in  signed(7 downto 0);
      Analog1YP1            : in  signed(7 downto 0);
      Analog2XP1            : in  signed(7 downto 0);
      Analog2YP1            : in  signed(7 downto 0);         
      Analog1XP2            : in  signed(7 downto 0);
      Analog1YP2            : in  signed(7 downto 0);
      Analog2XP2            : in  signed(7 downto 0);
      Analog2YP2            : in  signed(7 downto 0);                  
      -- mouse
      MouseEvent            : in  std_logic;
      MouseLeft             : in  std_logic;
      MouseRight            : in  std_logic;
      MouseX                : in  signed(8 downto 0);
      MouseY                : in  signed(8 downto 0);

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
      rewind_active         : in  std_logic
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
      reset                 => reset, 
      -- commands 
      pause                 => pause,
      loadExe               => loadExe,
      fastboot              => fastboot,
      FASTMEM               => FASTMEM,
      REPRODUCIBLEGPUTIMING => REPRODUCIBLEGPUTIMING,
      REPRODUCIBLEDMATIMING => REPRODUCIBLEDMATIMING,
      DMABLOCKATONCE        => DMABLOCKATONCE,
      INSTANTSEEK           => INSTANTSEEK,
      ditherOff             => ditherOff,
      fpscountOn            => fpscountOn,
      errorOn               => errorOn,
      noTexture             => noTexture,
      SPUon                 => SPUon,
      SPUSDRAM              => SPUSDRAM,
      REVERBOFF             => REVERBOFF,
      REPRODUCIBLESPUDMA    => REPRODUCIBLESPUDMA,
      -- RAM/BIOS interface        
      ram_refresh           => ram_refresh,
      ram_dataWrite         => ram_dataWrite,
      ram_dataRead          => ram_dataRead, 
      ram_dataRead32        => ram_dataRead32, 
      ram_Adr               => ram_Adr, 
      ram_be                => ram_be,        
      ram_rnw               => ram_rnw,      
      ram_ena               => ram_ena,  
      ram_128               => ram_128,       
      ram_done              => ram_done,    
      ram_reqprocessed      => ram_reqprocessed,     
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
      hasCD                 => hasCD,
      fastCD                => fastCD,
      libcryptKey           => libcryptKey,
      cd_Size               => cd_Size,
      cd_req                => cd_req, 
      cd_addr               => cd_addr,
      cd_data               => cd_data,
      cd_done               => cd_done,
      cd_hps_on             => cd_hps_on,   
      cd_hps_req            => cd_hps_req,  
      cd_hps_lba            => cd_hps_lba,  
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
      memcard1_load         => memcard1_load,       
      memcard2_load         => memcard2_load,       
      memcard_save          => memcard_save,       
      memcard1_available    => memcard1_available, 
      memcard1_rd           => memcard1_rd,        
      memcard1_wr           => memcard1_wr,        
      memcard1_lba          => memcard1_lba,       
      memcard1_ack          => memcard1_ack,       
      memcard1_write        => memcard1_write,     
      memcard1_addr         => memcard1_addr,      
      memcard1_dataIn       => memcard1_dataIn,    
      memcard1_dataOut      => memcard1_dataOut,   
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
      -- Keys - all active high
      PadPortEnable1        => PadPortEnable1,
      PadPortAnalog1        => PadPortAnalog1,
      PadPortMouse1         => PadPortMouse1,
      PadPortEnable2        => PadPortEnable2,
      PadPortAnalog2        => PadPortAnalog2,
      PadPortMouse2         => PadPortMouse2, 
      KeyTriangle           => KeyTriangle,           
      KeyCircle             => KeyCircle,           
      KeyCross              => KeyCross,           
      KeySquare             => KeySquare,           
      KeySelect             => KeySelect,      
      KeyStart              => KeyStart,       
      KeyRight              => KeyRight,       
      KeyLeft               => KeyLeft,        
      KeyUp                 => KeyUp,          
      KeyDown               => KeyDown,        
      KeyR1                 => KeyR1,           
      KeyR2                 => KeyR2,           
      KeyR3                 => KeyR3,           
      KeyL1                 => KeyL1,           
      KeyL2                 => KeyL2,           
      KeyL3                 => KeyL3,           
      Analog1XP1            => Analog1XP1,       
      Analog1YP1            => Analog1YP1,       
      Analog2XP1            => Analog2XP1,       
      Analog2YP1            => Analog2YP1,
      Analog1XP2            => Analog1XP2,
      Analog1YP2            => Analog1YP2,
      Analog2XP2            => Analog2XP2,
      Analog2YP2            => Analog2YP2,     
      MouseEvent            => MouseEvent,
      MouseLeft             => MouseLeft,
      MouseRight            => MouseRight,
      MouseX                => MouseX,
      MouseY                => MouseY,
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
      rewind_active         => rewind_active
   );                          

end architecture;





