library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library tb;
library psx;

library procbus;
use procbus.pProc_bus.all;
use procbus.pRegmap.all;

library reg_map;
use reg_map.pReg_tb.all;

entity etb  is
end entity;

architecture arch of etb is

   constant clk_speed : integer := 100000000;
   constant baud      : integer := 25000000;
 
   signal clk33       : std_logic := '1';
   signal clk66       : std_logic := '1';
   signal clk100      : std_logic := '1';
   
   signal reset       : std_logic;
   
   signal command_in  : std_logic;
   signal command_out : std_logic;
   signal command_out_filter : std_logic;
   
   signal proc_bus_in : proc_bus_type;
   
   -- settings
   signal psx_on              : std_logic_vector(Reg_psx_on.upper             downto Reg_psx_on.lower)             := (others => '0');
   signal psx_LoadExe         : std_logic_vector(Reg_psx_LoadExe.upper        downto Reg_psx_LoadExe.lower)        := (others => '0');
   
   signal bus_out_Din         : std_logic_vector(31 downto 0);
   signal bus_out_Dout        : std_logic_vector(31 downto 0);
   signal bus_out_Adr         : std_logic_vector(25 downto 0);
   signal bus_out_rnw         : std_logic;
   signal bus_out_ena         : std_logic;
   signal bus_out_done        : std_logic;
      
   signal SAVE_out_Din        : std_logic_vector(63 downto 0);
   signal SAVE_out_Dout       : std_logic_vector(63 downto 0);
   signal SAVE_out_Adr        : std_logic_vector(25 downto 0);
   signal SAVE_out_be         : std_logic_vector(7 downto 0);
   signal SAVE_out_rnw        : std_logic;                    
   signal SAVE_out_ena        : std_logic;                    
   signal SAVE_out_active     : std_logic;                    
   signal SAVE_out_done       : std_logic;                    
      
   signal cpu_loopback        : std_logic_vector(31 downto 0);
      
   signal Cheat_written       : std_logic;
   signal cheats_vector       : std_logic_vector(127 downto 0);
   
   -- psx signals    
   signal pixel_out_x         : integer range 0 to 239;
   signal pixel_out_y         : integer range 0 to 159;
   signal pixel_out_data      : std_logic_vector(17 downto 0);  
   signal pixel_out_we        : std_logic;
      
   signal largeimg_out_addr   : std_logic_vector(25 downto 0);
   signal largeimg_out_data   : std_logic_vector(63 downto 0);
   signal largeimg_out_req    : std_logic;
   signal largeimg_out_done   : std_logic;
   signal largeimg_newframe   : std_logic;
                           
   signal sound_out_left      : std_logic_vector(15 downto 0);
   signal sound_out_right     : std_logic_vector(15 downto 0);
      
   --sdram access 
   signal ram_dataWrite       : std_logic_vector(31 downto 0);
   signal ram_dataRead        : std_logic_vector(127 downto 0);
   signal ram_Adr             : std_logic_vector(22 downto 0);
   signal ram_be              : std_logic_vector(3 downto 0);
   signal ram_rnw             : std_logic;
   signal ram_ena             : std_logic;
   signal ram_done            : std_logic;   
   signal ram_reqprocessed    : std_logic;   
   
   -- ddrram
   signal DDRAM_CLK           : std_logic;
   signal DDRAM_BUSY          : std_logic;
   signal DDRAM_BURSTCNT      : std_logic_vector(7 downto 0);
   signal DDRAM_ADDR          : std_logic_vector(28 downto 0);
   signal DDRAM_DOUT          : std_logic_vector(63 downto 0);
   signal DDRAM_DOUT_READY    : std_logic;
   signal DDRAM_RD            : std_logic;
   signal DDRAM_DIN           : std_logic_vector(63 downto 0);
   signal DDRAM_BE            : std_logic_vector(7 downto 0);
   signal DDRAM_WE            : std_logic;
                     
   signal ch1_addr            : std_logic_vector(27 downto 1);
   signal ch1_dout            : std_logic_vector(63 downto 0);
   signal ch1_din             : std_logic_vector(15 downto 0);
   signal ch1_req             : std_logic;
   signal ch1_rnw             : std_logic;
   signal ch1_ready           : std_logic;
                           
   signal ch2_addr            : std_logic_vector(27 downto 1);
   signal ch2_dout            : std_logic_vector(31 downto 0);
   signal ch2_din             : std_logic_vector(31 downto 0);
   signal ch2_req             : std_logic;
   signal ch2_rnw             : std_logic;
   signal ch2_ready           : std_logic;
                        
   signal ch3_addr            : std_logic_vector(25 downto 1);
   signal ch3_dout            : std_logic_vector(15 downto 0);
   signal ch3_din             : std_logic_vector(15 downto 0);
   signal ch3_req             : std_logic;
   signal ch3_rnw             : std_logic;
   signal ch3_ready           : std_logic;
                        
   signal ch4_addr            : std_logic_vector(27 downto 1);
   signal ch4_dout            : std_logic_vector(63 downto 0);
   signal ch4_din             : std_logic_vector(63 downto 0);
   signal ch4_be              : std_logic_vector(7 downto 0);
   signal ch4_req             : std_logic;
   signal ch4_rnw             : std_logic;
   signal ch4_ready           : std_logic;
   
   
begin

   clk33  <= not clk33  after 15 ns;
   clk66  <= not clk66  after 7500 ps;
   clk100 <= not clk100 after 5 ns;
   
   reset  <= not psx_on(0);
   
   -- registers
   iReg_psx_on            : entity procbus.eProcReg generic map (Reg_psx_on)       port map (clk100, proc_bus_in, psx_on     , psx_on);      
   iReg_psx_LoadExe       : entity procbus.eProcReg generic map (Reg_psx_LoadExe)  port map (clk100, proc_bus_in, psx_LoadExe, psx_LoadExe);      
     
   ipsx_mister : entity psx.psx_mister
   generic map
   (
      is_simu               => '1',
      REPRODUCIBLEGPUTIMING => '1'
   )
   port map
   (
      clk1x                 => clk33,          
      clk2x                 => clk66, 
      reset                 => reset,
      -- commands 
      loadExe               => psx_LoadExe(0),
      -- RAM/BIOS interface        
      ram_dataWrite         => ram_dataWrite,
      ram_dataRead          => ram_dataRead, 
      ram_Adr               => ram_Adr,      
      ram_be                => ram_be,      
      ram_rnw               => ram_rnw,      
      ram_ena               => ram_ena,      
      ram_done              => ram_done,
      ram_reqprocessed      => ram_reqprocessed,
      -- vram/ddr3 interface
      DDRAM_BUSY            => DDRAM_BUSY,      
      DDRAM_BURSTCNT        => DDRAM_BURSTCNT,  
      DDRAM_ADDR            => DDRAM_ADDR,      
      DDRAM_DOUT            => DDRAM_DOUT,      
      DDRAM_DOUT_READY      => DDRAM_DOUT_READY,
      DDRAM_RD              => DDRAM_RD,        
      DDRAM_DIN             => DDRAM_DIN,       
      DDRAM_BE              => DDRAM_BE,        
      DDRAM_WE              => DDRAM_WE,
      -- Keys - all active high
      KeyTriangle           => '0', --KeyTriangle,           
      KeyCircle             => '0', --KeyCircle,           
      KeyCross              => '0', --KeyCross,           
      KeySquare             => '0', --KeySquare,           
      KeySelect             => '0', --KeySelect,      
      KeyStart              => '0', --KeyStart,       
      KeyRight              => '0', --KeyRight,       
      KeyLeft               => '0', --KeyLeft,        
      KeyUp                 => '0', --KeyUp,          
      KeyDown               => '0', --KeyDown,        
      KeyR1                 => '0', --KeyR1,           
      KeyR2                 => '0', --KeyR2,           
      KeyR3                 => '0', --KeyR3,           
      KeyL1                 => '0', --KeyL1,           
      KeyL2                 => '0', --KeyL2,           
      KeyL3                 => '0', --KeyL3,           
      Analog1X              => x"00", --Analog1X,       
      Analog1Y              => x"00", --Analog1Y,       
      Analog2X              => x"00", --Analog2X,       
      Analog2Y              => x"00", --Analog2Y,      
      -- sound              => -- sound       
      sound_out_left        => sound_out_left, 
      sound_out_right       => sound_out_right
   );
   
   largeimg_newframe <= '1' when unsigned(largeimg_out_addr(19 downto 0)) = 0 else '0';
   
   ch1_req  <= '0';
   
   ch2_addr <= bus_out_Adr & "0";
   ch2_din  <= bus_out_Din;
   ch2_req  <= bus_out_ena;
   ch2_rnw  <= bus_out_rnw;
   bus_out_Dout <= ch2_dout;
   bus_out_done <= ch2_ready;
   
   ch4_addr <= SAVE_out_Adr(25 downto 0) & "0";
   ch4_din  <= SAVE_out_Din;
   ch4_req  <= SAVE_out_ena;
   ch4_rnw  <= SAVE_out_rnw;
   ch4_be   <= SAVE_out_be;
   SAVE_out_Dout <= ch4_dout;
   SAVE_out_done <= ch4_ready;
   
   --iddrram : entity psx.ddram
   --port map (
   --   DDRAM_CLK        => clk100,      
   --   DDRAM_BUSY       => DDRAM_BUSY,      
   --   DDRAM_BURSTCNT   => DDRAM_BURSTCNT,  
   --   DDRAM_ADDR       => DDRAM_ADDR,      
   --   DDRAM_DOUT       => DDRAM_DOUT,      
   --   DDRAM_DOUT_READY => DDRAM_DOUT_READY,
   --   DDRAM_RD         => DDRAM_RD,        
   --   DDRAM_DIN        => DDRAM_DIN,       
   --   DDRAM_BE         => DDRAM_BE,        
   --   DDRAM_WE         => DDRAM_WE,        
   --                              
   --   ch1_addr         => ch1_addr,        
   --   ch1_dout         => ch1_dout,        
   --   ch1_din          => ch1_din,         
   --   ch1_req          => ch1_req,         
   --   ch1_rnw          => ch1_rnw,         
   --   ch1_ready        => ch1_ready,       
   --                                     
   --   ch2_addr         => ch2_addr,       
   --   ch2_dout         => ch2_dout,        
   --   ch2_din          => ch2_din,         
   --   ch2_req          => ch2_req,         
   --   ch2_rnw          => ch2_rnw,         
   --   ch2_ready        => ch2_ready,       
   --                                  
   --   ch3_addr         => ch3_addr,        
   --   ch3_dout         => ch3_dout,        
   --   ch3_din          => ch3_din,         
   --   ch3_req          => ch3_req,         
   --   ch3_rnw          => ch3_rnw,         
   --   ch3_ready        => ch3_ready,       
   --                                
   --   ch4_addr         => ch4_addr,        
   --   ch4_dout         => ch4_dout,        
   --   ch4_din          => ch4_din,         
   --   ch4_req          => ch4_req,         
   --   ch4_rnw          => ch4_rnw,         
   --   ch4_be           => ch4_be,       
   --   ch4_ready        => ch4_ready,       
   --   
   --   ch5_addr         => (27 downto 1 => '0'),        
   --   ch5_din          => (63 downto 0 => '0'),               
   --   ch5_req          => largeimg_out_req,                
   --   ch5_ready        => largeimg_out_done  
   --);
   
   iddrram_model : entity tb.ddrram_model
   port map
   (
      DDRAM_CLK        => clk66,      
      DDRAM_BUSY       => DDRAM_BUSY,      
      DDRAM_BURSTCNT   => DDRAM_BURSTCNT,  
      DDRAM_ADDR       => DDRAM_ADDR,      
      DDRAM_DOUT       => DDRAM_DOUT,      
      DDRAM_DOUT_READY => DDRAM_DOUT_READY,
      DDRAM_RD         => DDRAM_RD,        
      DDRAM_DIN        => DDRAM_DIN,       
      DDRAM_BE         => DDRAM_BE,        
      DDRAM_WE         => DDRAM_WE        
   );
   
   isdram_model : entity tb.sdram_model 
   port map
   (
      clk          => clk33,
      addr         => ram_Adr,
      req          => ram_ena,
      rnw          => ram_rnw,
      be           => ram_be,
      di           => ram_dataWrite,
      do           => ram_dataRead,
      done         => ram_done,
      reqprocessed => ram_reqprocessed
   );
   
   --iframebuffer : entity work.framebuffer
   --generic map
   --(
   --   FRAMESIZE_X => 240,
   --   FRAMESIZE_Y => 160
   --)
   --port map
   --(
   --   clk100             => clk100,
   --                       
   --   pixel_in_x         => pixel_out_x,
   --   pixel_in_y         => pixel_out_y,
   --   pixel_in_data      => pixel_out_data,
   --   pixel_in_we        => pixel_out_we
   --);
   
   iTestprocessor : entity procbus.eTestprocessor
   generic map
   (
      clk_speed => clk_speed,
      baud      => baud,
      is_simu   => '1'
   )
   port map 
   (
      clk               => clk100,
      bootloader        => '0',
      debugaccess       => '1',
      command_in        => command_in,
      command_out       => command_out,
            
      proc_bus          => proc_bus_in,
      
      fifo_full_error   => open,
      timeout_error     => open
   );
   
   command_out_filter <= '0' when command_out = 'Z' else command_out;
   
   itb_interpreter : entity tb.etb_interpreter
   generic map
   (
      clk_speed => clk_speed,
      baud      => baud
   )
   port map
   (
      clk         => clk100,
      command_in  => command_in, 
      command_out => command_out_filter
   );
   
end architecture;


