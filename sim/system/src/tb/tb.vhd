library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     
library STD;    
use STD.textio.all;

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
   signal clkvid      : std_logic := '1';
   
   signal reset       : std_logic;
   signal pause       : std_logic := '0';
   
   signal command_in  : std_logic;
   signal command_out : std_logic;
   signal command_out_filter : std_logic;
   
   signal proc_bus_in : proc_bus_type;
   
   -- settings
   signal psx_on              : std_logic_vector(Reg_psx_on.upper             downto Reg_psx_on.lower)             := (others => '0');
   signal psx_LoadExe         : std_logic_vector(Reg_psx_LoadExe.upper        downto Reg_psx_LoadExe.lower)        := (others => '0');
   signal psx_SaveState       : std_logic_vector(Reg_psx_SaveState.upper      downto Reg_psx_SaveState.lower)      := (others => '0');
   signal psx_LoadState       : std_logic_vector(Reg_psx_LoadState.upper      downto Reg_psx_LoadState.lower)      := (others => '0');
   
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
                           
   signal sound_out_left      : std_logic_vector(15 downto 0);
   signal sound_out_right     : std_logic_vector(15 downto 0);
      
   --sdram access 
   signal ram_dataWrite       : std_logic_vector(31 downto 0);
   signal ram_dataRead32      : std_logic_vector(31 downto 0);
   signal ram_Adr             : std_logic_vector(22 downto 0);
   signal ram_be              : std_logic_vector(3 downto 0);
   signal ram_rnw             : std_logic;
   signal ram_ena             : std_logic;
   signal ram_dma             : std_logic;
   signal ram_iscache         : std_logic;
   signal ram_done            : std_logic;   
   signal ram_reqprocessed    : std_logic;   
   signal ram_refresh         : std_logic;   
   signal ram_idle            : std_logic;   
   
   signal cache_wr            : std_logic_vector(3 downto 0);
   signal cache_data          : std_logic_vector(31 downto 0);
   signal cache_addr          : std_logic_vector(7 downto 0);
   
   signal dma_wr              : std_logic;
   signal dma_data            : std_logic_vector(31 downto 0);
   
   signal ram_dmafifo_adr     : std_logic_vector(20 downto 0);
   signal ram_dmafifo_data    : std_logic_vector(31 downto 0);
   signal ram_dmafifo_empty   : std_logic;
   signal ram_dmafifo_read    : std_logic;
   
   signal exe_initial_pc      : unsigned(31 downto 0);
   signal exe_initial_gp      : unsigned(31 downto 0);
   signal exe_load_address    : unsigned(31 downto 0);
   signal exe_file_size       : unsigned(31 downto 0);
   signal exe_stackpointer    : unsigned(31 downto 0);
   
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
   
   -- video
   signal hblank              : std_logic;
   signal vblank              : std_logic;
   signal video_ce            : std_logic;
   signal video_interlace     : std_logic;
   signal video_r             : std_logic_vector(7 downto 0);
   signal video_g             : std_logic_vector(7 downto 0);
   signal video_b             : std_logic_vector(7 downto 0);
   
   -- keys
   signal KeyTriangle         : std_logic_vector(3 downto 0) := (others => '0'); 
   signal KeyCircle           : std_logic_vector(3 downto 0) := (others => '0'); 
   signal KeyCross            : std_logic_vector(3 downto 0) := (others => '0'); 
   signal KeySquare           : std_logic_vector(3 downto 0) := (others => '0');
   signal KeySelect           : std_logic_vector(3 downto 0) := (others => '0');
   signal KeyStart            : std_logic_vector(3 downto 0) := (others => '0');
   signal KeyRight            : std_logic_vector(3 downto 0) := (others => '0');
   signal KeyLeft             : std_logic_vector(3 downto 0) := (others => '0');
   signal KeyUp               : std_logic_vector(3 downto 0) := (others => '0');
   signal KeyDown             : std_logic_vector(3 downto 0) := (others => '0');
   signal KeyR1               : std_logic_vector(3 downto 0) := (others => '0');
   signal KeyR2               : std_logic_vector(3 downto 0) := (others => '0');
   signal KeyR3               : std_logic_vector(3 downto 0) := (others => '0');
   signal KeyL1               : std_logic_vector(3 downto 0) := (others => '0');
   signal KeyL2               : std_logic_vector(3 downto 0) := (others => '0');
   signal KeyL3               : std_logic_vector(3 downto 0) := (others => '0');
   signal Analog1XP1          : signed(7 downto 0) := (others => '0');
   signal Analog1YP1          : signed(7 downto 0) := (others => '0');
   signal Analog2XP1          : signed(7 downto 0) := (others => '0');
   signal Analog2YP1          : signed(7 downto 0) := (others => '0');    
   signal Analog1XP2          : signed(7 downto 0) := (others => '0');
   signal Analog1YP2          : signed(7 downto 0) := (others => '0');
   signal Analog2XP2          : signed(7 downto 0) := (others => '0');
   signal Analog2YP2          : signed(7 downto 0) := (others => '0'); 
   
   signal MouseEvent          : std_logic := '0';
   signal MouseLeft           : std_logic := '0';
   signal MouseRight          : std_logic := '0';
   signal MouseX              : signed(8 downto 0) := to_signed(2, 9);
   signal MouseY              : signed(8 downto 0) := to_signed(-1,9);
   
   --cd
   type ttracknames is array(0 to 99) of string(1 to 255);
   signal tracknames : ttracknames;
   signal trackcount : integer;
   
   type filetype is file of integer;
   type t_data is array(0 to (2**28)-1) of integer;
   signal cdLoaded            : std_logic := '0';
   signal cdTrack             : std_logic_vector(7 downto 0) := x"FF";
   
   signal cd_req              : std_logic;
   signal cd_addr             : std_logic_vector(26 downto 0) := (others => '0');
   
   signal cd_hps_req          : std_logic := '0';
   signal cd_hps_lba          : std_logic_vector(31 downto 0);
   signal cd_hps_ack          : std_logic := '0';
   signal cd_hps_write        : std_logic := '0';
   signal cd_hps_data         : std_logic_vector(15 downto 0);
   
   signal trackinfo_data      : std_logic_vector(31 downto 0);
   signal trackinfo_addr      : std_logic_vector(8 downto 0);
   signal trackinfo_write     : std_logic := '0';
   
   -- spu
   signal spuram_dataWrite    : std_logic_vector(31 downto 0);
   signal spuram_Adr          : std_logic_vector(18 downto 0);
   signal spuram_be           : std_logic_vector(3 downto 0);
   signal spuram_rnw          : std_logic;
   signal spuram_ena          : std_logic;
   signal spuram_dataRead     : std_logic_vector(31 downto 0);
   signal spuram_done         : std_logic;
   
   -- memcard
   type t_memdata is array(0 to 32767) of integer;
   signal memcardLoaded       : std_logic := '0';
   signal memcard1_load       : std_logic := '0';
   signal memcard2_load       : std_logic := '0';
   signal memcard1_mounted    : std_logic := '0';
   signal memcard2_mounted    : std_logic := '0';
   signal memcard_save        : std_logic := '0';
   signal memcard1_rd         : std_logic;
   signal memcard1_wr         : std_logic;
   signal memcard1_lba        : std_logic_vector(6 downto 0);
   signal memcard1_ack        : std_logic := '0';
   signal memcard1_write      : std_logic := '0';
   signal memcard1_addr       : std_logic_vector(8 downto 0) := (others => '0');
   signal memcard1_dataIn     : std_logic_vector(15 downto 0);
   signal memcard1_dataOut    : std_logic_vector(15 downto 0);              
   signal memcard2_rd         : std_logic := '0';
   signal memcard2_wr         : std_logic := '0';
   signal memcard2_lba        : std_logic_vector(6 downto 0);
   signal memcard2_ack        : std_logic := '0';
   signal memcard2_write      : std_logic := '0';
   signal memcard2_addr       : std_logic_vector(8 downto 0) := (others => '0');
   signal memcard2_dataIn     : std_logic_vector(15 downto 0);
   signal memcard2_dataOut    : std_logic_vector(15 downto 0);
   
begin

   clk33  <= not clk33  after 15 ns;
   clk66  <= not clk66  after 7500 ps;
   clk100 <= not clk100 after 5 ns;
   
   MouseEvent <= not MouseEvent after 5 ms;
   
   reset  <= not psx_on(0);
   
   -- NTSC 53.693175 mhz => 18624.340989ps
   clkvid <= not clkvid after 9312 ps;
      
   -- PAL  53.203425 mhz => 18795.782414ps
   
   -- sync  = 2x => 67.7376 mhz
   --clkvid <= not clkvid  after 7500 ps;
   
   -- registers
   iReg_psx_on            : entity procbus.eProcReg generic map (Reg_psx_on)        port map (clk100, proc_bus_in, psx_on        , psx_on);      
   iReg_psx_LoadExe       : entity procbus.eProcReg generic map (Reg_psx_LoadExe)   port map (clk100, proc_bus_in, psx_LoadExe   , psx_LoadExe); 
   iReg_psx_SaveState     : entity procbus.eProcReg generic map (Reg_psx_SaveState) port map (clk100, proc_bus_in, psx_SaveState , psx_SaveState);      
   iReg_psx_LoadState     : entity procbus.eProcReg generic map (Reg_psx_LoadState) port map (clk100, proc_bus_in, psx_LoadState , psx_LoadState);   
   
   pause <= '0';
   --pause <= not pause after 1 ms;

   ipsx_mister : entity psx.psx_mister
   generic map
   (
      is_simu               => '1'
   )
   port map
   (
      clk1x                 => clk33,          
      clk2x                 => clk66, 
      clk3x                 => clk100, 
      clkvid                => clkvid,
      reset                 => reset,
      -- commands 
      pause                 => pause,
      hps_busy              => '0',
      loadExe               => psx_LoadExe(0),
      exe_initial_pc        => exe_initial_pc,  
      exe_initial_gp        => exe_initial_gp,  
      exe_load_address      => exe_load_address,
      exe_file_size         => exe_file_size,   
      exe_stackpointer      => exe_stackpointer,
      fastboot              => '1',
      FASTMEM               => '0',
      TURBO                 => '0',
      REPRODUCIBLEGPUTIMING => '0',
      DMABLOCKATONCE        => '0',
      INSTANTSEEK           => '0',
      FORCECDSPEED          => "000",
      LIMITREADSPEED        => '0',
      ditherOff             => '0',
      showGunCrosshairs     => '0',
      fpscountOn            => '0',
      cdslowOn              => '0',
      testSeek              => '0',
      pauseOnCDSlow         => '0',
      errorOn               => '0',
      LBAOn                 => '0',
      PATCHSERIAL           => '0',
      noTexture             => '0',
      textureFilter         => '0',
      dither24              => '0',
      syncVideoOut          => '0',
      syncInterlace         => '0',
      rotate180             => '0',
      fixedVBlank           => '0',
      vCrop                 => "00",
      hCrop                 => '0',
      SPUon                 => '1',
      SPUSDRAM              => '1',
      REVERBOFF             => '0',
      REPRODUCIBLESPUDMA    => '0',
      WIDESCREEN            => "00",
      -- RAM/BIOS interface        
      biosregion            => "00",
      ram_refresh           => ram_refresh,
      ram_dataWrite         => ram_dataWrite,
      ram_dataRead32        => ram_dataRead32, 
      ram_Adr               => ram_Adr,      
      ram_be                => ram_be,      
      ram_rnw               => ram_rnw,      
      ram_ena               => ram_ena,      
      ram_dma               => ram_dma,      
      ram_cache             => ram_iscache,      
      ram_done              => ram_done,
      ram_reqprocessed      => ram_reqprocessed,
      ram_dmafifo_adr       => ram_dmafifo_adr, 
      ram_dmafifo_data      => ram_dmafifo_data,
      ram_dmafifo_empty     => ram_dmafifo_empty,
      ram_dmafifo_read      => ram_dmafifo_read,  
      cache_wr              => cache_wr,  
      cache_data            => cache_data,
      cache_addr            => cache_addr,
      dma_wr                => dma_wr,  
      dma_data              => dma_data,
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
      -- cd
      region                => "00",
      region_out            => open,
      hasCD                 => '1',
      LIDopen               => '0',
      fastCD                => '0',
      trackinfo_data        => trackinfo_data,
      trackinfo_addr        => trackinfo_addr, 
      trackinfo_write       => trackinfo_write,
      cd_hps_req            => cd_hps_req,  
      cd_hps_lba_sim        => cd_hps_lba,  
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
      -- memcard
      memcard1_load         => memcard1_load,      
      memcard2_load         => memcard2_load,      
      memcard_save          => memcard_save,      
      memcard1_mounted      => memcard1_mounted,
      memcard1_available    => '1',
      memcard1_rd           => memcard1_rd,       
      memcard1_wr           => memcard1_wr,       
      memcard1_lba          => memcard1_lba,      
      memcard1_ack          => memcard1_ack,      
      memcard1_write        => memcard1_write,    
      memcard1_addr         => memcard1_addr,     
      memcard1_dataIn       => memcard1_dataIn,   
      memcard1_dataOut      => memcard1_dataOut,  
      memcard2_mounted      => memcard2_mounted,
      memcard2_available    => '0',
      memcard2_rd           => memcard2_rd,       
      memcard2_wr           => memcard2_wr,       
      memcard2_lba          => memcard2_lba,      
      memcard2_ack          => memcard2_ack,      
      memcard2_write        => memcard2_write,    
      memcard2_addr         => memcard2_addr,     
      memcard2_dataIn       => memcard2_dataIn,   
      memcard2_dataOut      => memcard2_dataOut,  
      -- video
      videoout_on           => '1',
      isPal                 => '0',
      pal60                 => '0',
      hblank                => hblank,  
      vblank                => vblank,  
      video_ce              => video_ce,
      video_interlace       => video_interlace,
      video_r               => video_r, 
      video_g               => video_g,    
      video_b               => video_b,   
      -- Keys - all active high
      DSAltSwitchMode       => '0',
      PadPortEnable1        => '1',
      PadPortDigital1       => '1',
      PadPortAnalog1        => '0',
      PadPortMouse1         => '0',
      PadPortGunCon1        => '0',
      PadPortneGcon1        => '0',
      PadPortWheel1         => '0',
      PadPortDS1            => '0',
      PadPortJustif1        => '0',
      PadPortStick1         => '0',
      PadPortEnable2        => '0',
      PadPortDigital2       => '1',
      PadPortAnalog2        => '0',
      PadPortMouse2         => '0', 
      PadPortGunCon2        => '0',
      PadPortneGcon2        => '0',
      PadPortWheel2         => '0',
      PadPortDS2            => '0',
      PadPortJustif2        => '0',
      PadPortStick2         => '0',
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
      ToggleDS              => "0000",           
      Analog1XP1            => Analog1XP1,       
      Analog1YP1            => Analog1YP1,       
      Analog2XP1            => Analog2XP1,       
      Analog2YP1            => Analog2YP1,
      Analog1XP2            => Analog1XP2,
      Analog1YP2            => Analog1YP2,
      Analog2XP2            => Analog2XP2,
      Analog2YP2            => Analog2YP2, 
      Analog1XP3            => Analog1XP2,
      Analog1YP3            => Analog1YP2,
      Analog2XP3            => Analog2XP2,
      Analog2YP3            => Analog2YP2, 
      Analog1XP4            => Analog1XP2,
      Analog1YP4            => Analog1YP2,
      Analog2XP4            => Analog2XP2,
      Analog2YP4            => Analog2YP2, 
      multitap              => '0',
      MouseEvent            => MouseEvent,
      MouseLeft             => MouseLeft,
      MouseRight            => MouseRight,
      MouseX                => MouseX,
      MouseY                => MouseY,
      -- snac
      snacPort1             => '0',
      snacPort2             => '0',
      irq10Snac             => '0',
      actionNextSnac        => '0',
      receiveValidSnac      => '0',
      ackSnac               => '0',
      receiveBufferSnac	    => x"00",
      -- sound              => -- sound       
      sound_out_left        => sound_out_left, 
      sound_out_right       => sound_out_right,
      -- savestates              
      increaseSSHeaderCount => '1',
      save_state            => psx_SaveState(0),
      load_state            => psx_LoadState(0),
      savestate_number      => 0,
      state_loaded          => open,
      rewind_on             => '0',
      rewind_active         => '0',
      -- cheats
      cheat_clear           => '0',
      cheats_enabled        => '0',
      cheat_on              => '0',
      cheat_in              => (127 downto 0 => '0'),
      Cheats_BusReadData    => (31 downto 0 => '0'),
      Cheats_BusDone        => '0'
   );
   
   iddrram_model : entity tb.ddrram_model
   generic map
   (
      SLOWTIMING   => 15,
      RANDOMTIMING => '0' 
   )
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
   
   isdram_model : entity tb.sdram_model3x 
   generic map
   (
      DOREFRESH     => '1',
      SCRIPTLOADING => '1',
      SLOWWRITE     => '0'
   )
   port map
   (
      clk                  => clk33,
      clk3x                => clk100,
      refresh              => ram_refresh,
      addr(26 downto 23)   => "0000",
      addr(22 downto  0)   => ram_Adr,
      req                  => ram_ena,
      ram_dma              => ram_dma,
      ram_iscache          => ram_iscache,
      rnw                  => ram_rnw,
      be                   => ram_be,
      di                   => ram_dataWrite,
      do                   => open,
      do32                 => ram_dataRead32,
      done                 => ram_done,
      cache_wr             => cache_wr,  
      cache_data           => cache_data,
      cache_addr           => cache_addr,
      dma_wr               => dma_wr,  
      dma_data             => dma_data,
      reqprocessed         => ram_reqprocessed,
      ram_idle             => open,
      ram_dmafifo_adr      => ram_dmafifo_adr, 
      ram_dmafifo_data     => ram_dmafifo_data,
      ram_dmafifo_empty    => ram_dmafifo_empty,
      ram_dmafifo_read     => ram_dmafifo_read,
      exe_initial_pc       => exe_initial_pc,  
      exe_initial_gp       => exe_initial_gp,  
      exe_load_address     => exe_load_address,
      exe_file_size        => exe_file_size,   
      exe_stackpointer     => exe_stackpointer    
   );
   
   ispu_ram : entity work.sdram_model3x 
   generic map
   (
      DOREFRESH     => '0',
      SCRIPTLOADING => '0',
      INITFILE      => "R:\spu_ram_FPSXA.bin",
      FILELOADING   => '0'
   )
   port map
   (
      clk                  => clk33,
      clk3x                => clk100,
      refresh              => '0',
      addr(26 downto 19)   => "00000000",
      addr(18 downto  0)   => spuram_Adr,
      req                  => spuram_ena,
      ram_dma              => '0',
      ram_iscache          => '0',
      rnw                  => spuram_rnw,
      be                   => spuram_be,
      di                   => spuram_dataWrite,
      do                   => open,
      do32                 => spuram_dataRead,
      done                 => spuram_done,
      reqprocessed         => open,
      ram_idle             => open,
      ram_dmafifo_adr      => (20 downto 0 => '0'),
      ram_dmafifo_data     => (31 downto 0 => '0'),
      ram_dmafifo_empty    => '1'
   );
   
      -- hps emulation
   process
      file infile          : text;
      variable f_status    : FILE_OPEN_STATUS;
      variable inLine      : LINE;
      variable count       : integer;
   begin

      file_open(f_status, infile, "R:\cdtracks.txt", read_mode);
      count := 1;
      if (f_status = open_ok) then 
         while (not endfile(infile)) loop
            readline(infile,inLine);
            tracknames(count) <= (others => ' ');
            tracknames(count)(1 to inLine'length) <= inLine(1 to inLine'length); 
            count := count + 1;
         end loop;
      end if;
      trackcount <= count;
      
      file_close(infile);
      
      wait;
   end process;
   
   process
      variable data           : t_data := (others => 0);
      file infile             : filetype;
      variable f_status       : FILE_OPEN_STATUS;
      variable read_byte0     : std_logic_vector(7 downto 0);
      variable read_byte1     : std_logic_vector(7 downto 0);
      variable read_byte2     : std_logic_vector(7 downto 0);
      variable read_byte3     : std_logic_vector(7 downto 0);
      variable next_vector    : bit_vector (2351 downto 0);
      variable next_int       : integer;
      variable actual_len     : natural;
      variable targetpos      : integer;
      variable cdData         : std_logic_vector(31 downto 0);
      
      -- copy from std_logic_arith, not used here because numeric std is also included
      function CONV_STD_LOGIC_VECTOR(ARG: INTEGER; SIZE: INTEGER) return STD_LOGIC_VECTOR is
        variable result: STD_LOGIC_VECTOR (SIZE-1 downto 0);
        variable temp: integer;
      begin
 
         temp := ARG;
         for i in 0 to SIZE-1 loop
 
         if (temp mod 2) = 1 then
            result(i) := '1';
         else 
            result(i) := '0';
         end if;
 
         if temp > 0 then
            temp := temp / 2;
         elsif (temp > integer'low) then
            temp := (temp - 1) / 2; -- simulate ASR
         else
            temp := temp / 2; -- simulate ASR
         end if;
        end loop;
 
        return result;  
      end;
   begin
      
      if (cdLoaded = '0') then
         file_open(f_status, infile, "R:\\cuedata.bin", read_mode);
         if (f_status = open_ok) then 
         
            targetpos := 0;
            
            while (not endfile(infile)) loop
               
               read(infile, next_int);  
               
               data(targetpos) := next_int;
               targetpos       := targetpos + 1;
   
            end loop;
            
            file_close(infile);
            
            wait for 10 us;
            for i in 0 to 400 loop
               trackinfo_data  <= std_logic_vector(to_signed(data(i), 32));
               trackinfo_addr  <= std_logic_vector(to_unsigned(i, 9));
               trackinfo_write <= '1';
               wait until rising_edge(clk33);
               trackinfo_write <= '0';
               wait until rising_edge(clk33);
            end loop;
   
            cdLoaded <= '1';
         end if; 
      end if;
   
   
      wait until rising_edge(clk33);
      if (cd_hps_req = '1') then
      
         -- load new track if required
         if (cdTrack /= cd_hps_lba(31 downto 24)) then
         
            cdTrack <= cd_hps_lba(31 downto 24);
            report "Loading new File";
            report tracknames(to_integer(unsigned(cd_hps_lba(31 downto 24))));
            file_open(f_status, infile, tracknames(to_integer(unsigned(cd_hps_lba(31 downto 24)))), read_mode);
            
            targetpos := 0;
            
            if (unsigned(cd_hps_lba(31 downto 24)) > 0 and unsigned(cd_hps_lba(31 downto 24)) < trackcount) then 
            
               while (not endfile(infile)) loop
                  
                  read(infile, next_int);  
                  
                  data(targetpos) := next_int;
                  targetpos       := targetpos + 1;
      
               end loop;
               
               file_close(infile);
            
            end if;
      
         end if;
      end if;
      
      if (cd_hps_req = '1') then
      
         for i in 0 to 100 loop
            wait until rising_edge(clk33);
         end loop;
         cd_hps_ack <= '1';
         wait until rising_edge(clk33);
         cd_hps_ack <= '0';
         wait until rising_edge(clk33);
         
         for i in 0 to 587 loop
            if (unsigned(cd_hps_lba(31 downto 24)) > 0 and unsigned(cd_hps_lba(31 downto 24)) < trackcount) then 
               cdData := std_logic_vector(to_signed(data(to_integer(unsigned(cd_hps_lba(23 downto 0))) * (2352 / 4) + i), 32));
            else
               cdData := (others => '0');
            end if;
            
            cd_hps_data  <= cdData(15 downto 0);
            cd_hps_write <= '1';
            wait until rising_edge(clk33);
            cd_hps_data  <= cdData(31 downto 16);
            wait until rising_edge(clk33);
            cd_hps_write <= '0';
         end loop;
         
      end if;
   end process;
   
   -- memcard testinterface
   process
   begin
      if (0 = 1) then
      
         wait for 2 ms;
         
         memcard1_mounted <= '1';
         --memcard2_mounted <= '1';
         memcard1_load      <= '1';
         --memcard2_load      <= '1';
         wait until rising_edge(clk33);
      
         memcard1_load      <= '0';
         memcard2_load      <= '0';
         wait until rising_edge(clk33);
      
         --wait for 25 ms;
         --
         --memcard_save       <= '1';
         --wait until rising_edge(clk33);
         --
         --memcard_save       <= '0';
         --wait until rising_edge(clk33);
      
         wait;
      else
         wait;
      end if;
   end process;
   
   process
      variable data           : t_memdata := (others => 0);
      file infile             : filetype;
      variable f_status       : FILE_OPEN_STATUS;
      variable next_int       : integer;
      variable targetpos      : integer;
      variable memdata        : std_logic_vector(31 downto 0);
   begin
   
      if (memcardLoaded = '0') then
      
         file_open(f_status, infile, "empty.mcd", read_mode);
         
         targetpos := 0;
         
         while (not endfile(infile)) loop
            
            read(infile, next_int);  
            
            data(targetpos) := next_int;
            targetpos       := targetpos + 1;

         end loop;
         
         file_close(infile);
         
         memcardLoaded <= '1';
      end if;
   
      wait until rising_edge(clk33);
   
      if (memcard1_rd = '1') then
         memcard1_ack <= '1';
         wait until rising_edge(clk33);
         
         for i in 0 to 255 loop
            memdata := std_logic_vector(to_signed(data(to_integer(unsigned(memcard1_lba)) * 256 + i), 32));
            
            memcard1_write  <= '1';
            memcard1_dataIn <= memdata(15 downto 0);
            memcard1_addr   <= std_logic_vector(to_unsigned(i * 2 + 0, 9));
            wait until rising_edge(clk33);
            memcard1_write  <= '0';
            wait until rising_edge(clk33);
            
            memcard1_write  <= '1';
            memcard1_dataIn <= memdata(31 downto 16);
            memcard1_addr   <= std_logic_vector(to_unsigned(i * 2 + 1, 9));
            wait until rising_edge(clk33);
            memcard1_write  <= '0';
            wait until rising_edge(clk33);
         end loop;
         
         memcard1_ack <= '0';
      end if;
      
      if (memcard1_wr = '1') then
         memcard1_ack <= '1';
         wait until rising_edge(clk33);
         
         for i in 0 to 255 loop
         
            memcard1_addr   <= std_logic_vector(to_unsigned(i * 2 + 0, 9));
            wait until rising_edge(clk33);
            memdata(15 downto 0) := memcard1_dataOut;
            wait until rising_edge(clk33);
            
            memcard1_addr   <= std_logic_vector(to_unsigned(i * 2 + 1, 9));
            wait until rising_edge(clk33);
            memdata(31 downto 16) := memcard1_dataOut;
            wait until rising_edge(clk33);
            
            data(to_integer(unsigned(memcard1_lba)) * 256 + i) := to_integer(signed(memdata));
            
         end loop;
         
         memcard1_ack <= '0';
      end if;
         
   end process;
   
   iframebuffer : entity work.framebuffer
   port map
   (
      clk               => clkvid,     
      hblank            => hblank,  
      vblank            => vblank,  
      video_ce          => video_ce,
      video_interlace   => video_interlace,
      video_r           => video_r, 
      video_g           => video_g,    
      video_b           => video_b  
   );
   
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


