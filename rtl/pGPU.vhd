library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pGPU is

   type div_type is record
      start     : std_logic;
      done      : std_logic;
      dividend  : signed(44 downto 0);
      divisor   : signed(24 downto 0);
      quotient  : signed(44 downto 0);
      remainder : signed(24 downto 0);
   end record;
   
   type tvideoout_settings is record
      GPUSTAT_VerRes          : std_logic;
      GPUSTAT_PalVideoMode    : std_logic;
      GPUSTAT_VertInterlace   : std_logic;
      GPUSTAT_HorRes2         : std_logic;
      GPUSTAT_HorRes1         : std_logic_vector(1 downto 0);
      GPUSTAT_ColorDepth24    : std_logic;
      GPUSTAT_DisplayDisable  : std_logic;
      vramRange               : unsigned(18 downto 0);
      hDisplayRange           : unsigned(23 downto 0);
      vDisplayRange           : unsigned(19 downto 0);
      pal60                   : std_logic;
      syncInterlace           : std_logic;
      rotate180               : std_logic;
      fixedVBlank             : std_logic;
      vCrop                   : std_logic_vector(1 downto 0);
   end record;
   
   type tvideoout_reports is record
      vsync                   : std_logic;
      irq_VBLANK              : std_logic;
      hblank_tmr              : std_logic;
      GPUSTAT_InterlaceField  : std_logic;
      GPUSTAT_DrawingOddline  : std_logic;
      inVsync                 : std_logic;
      interlacedDisplayField  : std_logic;
      activeLineLSB           : std_logic;
   end record;
  
   type tvideoout_ss is record
      interlacedDisplayField  : std_logic;
      nextHCount              : std_logic_vector(11 downto 0);
      vpos                    : std_logic_vector(8 downto 0);
      vdisp                   : std_logic_vector(8 downto 0);
      inVsync                 : std_logic;
      activeLineLSB           : std_logic;
      GPUSTAT_InterlaceField  : std_logic;
      GPUSTAT_DrawingOddline  : std_logic;
   end record;
   
   type tvideoout_request is record
      fetch                   : std_logic;
      fetchsize               : unsigned(9 downto 0);
      lineInNext              : unsigned(8 downto 0);
      xpos                    : integer range 0 to 1023;
      lineDisp                : unsigned(8 downto 0);
   end record;    
   
   type tvideoout_out is record
      hsync          : std_logic;
      vsync          : std_logic;
      hblank         : std_logic;
      vblank         : std_logic;
      DisplayWidth   : unsigned( 9 downto 0);
      DisplayHeight  : unsigned( 8 downto 0);
      DisplayOffsetX : unsigned( 9 downto 0); 
      DisplayOffsetY : unsigned( 8 downto 0); 
      ce             : std_logic;
      interlace      : std_logic;
      r              : std_logic_vector(7 downto 0);
      g              : std_logic_vector(7 downto 0);
      b              : std_logic_vector(7 downto 0);
      isPal          : std_logic;
      hResMode       : std_logic_vector(2 downto 0);
   end record; 
   
end package;