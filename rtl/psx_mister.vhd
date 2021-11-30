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
      loadExe               : in  std_logic;
      fastboot              : in  std_logic;
      REPRODUCIBLEGPUTIMING : in  std_logic;
      REPRODUCIBLEDMATIMING : in  std_logic;
      CDDISABLE             : in  std_logic;
      ditherOff             : in  std_logic;
      -- RAM/BIOS interface      
      ram_refresh           : out std_logic;
      ram_dataWrite         : out std_logic_vector(31 downto 0);
      ram_dataRead          : in  std_logic_vector(127 downto 0);
      ram_Adr               : out std_logic_vector(22 downto 0);
      ram_be                : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw               : out std_logic;
      ram_ena               : out std_logic;
      ram_128               : out std_logic;
      ram_done              : in  std_logic;  
      ram_reqprocessed      : in  std_logic;  
      ram_idle              : in  std_logic;  
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
      fastCD                : in  std_logic;
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
      -- video
      videoout_on           : in  std_logic;
      isPal                 : in  std_logic;
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
      KeyTriangle           : in  std_logic; 
      KeyCircle             : in  std_logic; 
      KeyCross              : in  std_logic; 
      KeySquare             : in  std_logic;
      KeySelect             : in  std_logic;
      KeyStart              : in  std_logic;
      KeyRight              : in  std_logic;
      KeyLeft               : in  std_logic;
      KeyUp                 : in  std_logic;
      KeyDown               : in  std_logic;
      KeyR1                 : in  std_logic;
      KeyR2                 : in  std_logic;
      KeyR3                 : in  std_logic;
      KeyL1                 : in  std_logic;
      KeyL2                 : in  std_logic;
      KeyL3                 : in  std_logic;
      Analog1X              : in  signed(7 downto 0);
      Analog1Y              : in  signed(7 downto 0);
      Analog2X              : in  signed(7 downto 0);
      Analog2Y              : in  signed(7 downto 0);                  
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
      loadExe               => loadExe,
      fastboot              => fastboot,
      REPRODUCIBLEGPUTIMING => REPRODUCIBLEGPUTIMING,
      REPRODUCIBLEDMATIMING => REPRODUCIBLEDMATIMING,
      CDDISABLE             => CDDISABLE,
      ditherOff             => ditherOff,
      -- RAM/BIOS interface        
      ram_refresh           => ram_refresh,
      ram_dataWrite         => ram_dataWrite,
      ram_dataRead          => ram_dataRead, 
      ram_Adr               => ram_Adr, 
      ram_be                => ram_be,        
      ram_rnw               => ram_rnw,      
      ram_ena               => ram_ena,  
      ram_128               => ram_128,       
      ram_done              => ram_done,    
      ram_reqprocessed      => ram_reqprocessed,    
      ram_idle              => ram_idle,    
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
      fastCD                => fastCD,
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
      -- video
      videoout_on           => videoout_on,
      isPal                 => isPal,
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
      Analog1X              => Analog1X,       
      Analog1Y              => Analog1Y,       
      Analog2X              => Analog2X,       
      Analog2Y              => Analog2Y,      
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





