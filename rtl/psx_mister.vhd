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
      -- RAM/BIOS interface      
      ram_dataWrite         : out std_logic_vector(31 downto 0);
      ram_dataRead          : in  std_logic_vector(127 downto 0);
      ram_Adr               : out std_logic_vector(22 downto 0);
      ram_be                : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw               : out std_logic;
      ram_ena               : out std_logic;
      ram_128               : out std_logic;
      ram_done              : in  std_logic;  
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
      hsync                 : out std_logic;
      vsync                 : out std_logic;
      hblank                : out std_logic;
      vblank                : out std_logic;
      DisplayWidth         : out unsigned( 9 downto 0);
      DisplayHeight        : out unsigned( 8 downto 0);
      DisplayOffsetX       : out unsigned( 9 downto 0);
      DisplayOffsetY       : out unsigned( 8 downto 0);
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
      sound_out_right       : out std_logic_vector(15 downto 0) := (others => '0')
   );
end entity;

architecture arch of psx_mister is

   signal vram_ADDR : std_logic_vector(19 downto 0);
   
begin 

   -- vram is at 0x30000000
   DDRAM_ADDR(28 downto 25) <= "0011";
   DDRAM_ADDR(24 downto 17) <= (others => '0');
   
   DDRAM_ADDR(16 downto 0) <= vram_ADDR(19 downto 3);

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
      -- RAM/BIOS interface        
      ram_dataWrite         => ram_dataWrite,
      ram_dataRead          => ram_dataRead, 
      ram_Adr               => ram_Adr, 
      ram_be                => ram_be,        
      ram_rnw               => ram_rnw,      
      ram_ena               => ram_ena,  
      ram_128               => ram_128,       
      ram_done              => ram_done,    
      -- vram interface
      vram_BUSY             => DDRAM_BUSY,      
      vram_DOUT             => DDRAM_DOUT,      
      vram_DOUT_READY       => DDRAM_DOUT_READY,
      vram_BURSTCNT         => DDRAM_BURSTCNT,  
      vram_ADDR             => vram_ADDR,      
      vram_DIN              => DDRAM_DIN,       
      vram_BE               => DDRAM_BE,        
      vram_WE               => DDRAM_WE,        
      vram_RD               => DDRAM_RD,   
      hsync                 => hsync, 
      vsync                 => vsync, 
      hblank                => hblank,
      vblank                => vblank,
      DisplayWidth          => DisplayWidth, 
      DisplayHeight         => DisplayHeight,
      DisplayOffsetX        => DisplayOffsetX,
      DisplayOffsetY        => DisplayOffsetY,
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
      sound_out_right       => sound_out_right
   );

end architecture;





