library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;
use work.pexport.all;
use work.pJoypad.all;

entity psx_top is
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
      INSTANTSEEK           : in  std_logic;
      FORCECDSPEED          : in  std_logic_vector(2 downto 0);
      LIMITREADSPEED        : in  std_logic;
      IGNORECDDMATIMING     : in  std_logic;
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
      ram_cntDMA            : out std_logic_vector(1 downto 0);
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
      -- vram/savestate interface
      ddr3_BUSY             : in  std_logic;                    
      ddr3_DOUT             : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY       : in  std_logic;
      ddr3_BURSTCNT         : out std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_ADDR             : out std_logic_vector(27 downto 0) := (others => '0');                       
      ddr3_DIN              : out std_logic_vector(63 downto 0) := (others => '0');
      ddr3_BE               : out std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_WE               : out std_logic := '0';
      ddr3_RD               : out std_logic := '0'; 
      -- cd
      region                : in  std_logic_vector(1 downto 0);
      region_out            : out std_logic_vector(1 downto 0);
      hasCD                 : in  std_logic;
      fastCD                : in  std_logic;
      LIDopen               : in  std_logic;
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

      DSAltSwitchMode       : in  std_logic;
      joypad1               : in  joypad_t;
      joypad2               : in  joypad_t;
      joypad3               : in  joypad_t;
      joypad4               : in  joypad_t;
      multitap              : in  std_logic;
      joypad1_rumble        : out std_logic_vector(15 downto 0);
      joypad2_rumble        : out std_logic_vector(15 downto 0);
      joypad3_rumble        : out std_logic_vector(15 downto 0);
      joypad4_rumble        : out std_logic_vector(15 downto 0);
      padMode               : out std_logic_vector(1 downto 0);

      MouseEvent            : in  std_logic;
      MouseLeft             : in  std_logic;
      MouseRight            : in  std_logic;
      MouseX                : in  signed(8 downto 0);
      MouseY                : in  signed(8 downto 0);
      --snac
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

architecture arch of psx_top is

   signal reset_in               : std_logic := '0';
   signal reset_intern           : std_logic := '0';
   signal reset_exe              : std_logic;
   
   signal ce                     : std_logic := '0';
   signal clk1xToggle            : std_logic := '0';
   signal clk1xToggle2X          : std_logic := '0';
   signal clk2xIndex             : std_logic := '0';

   signal clk1xToggle3X          : std_logic := '0';
   signal clk1xToggle3X_1        : std_logic := '0';
   signal clk3xIndex             : std_logic := '0';
   
   signal Pause_Idle             : std_logic;
   signal pausing                : std_logic := '0';
   signal pausingSS              : std_logic := '0';
   signal allowunpause           : std_logic;
   
   signal pauseCD                : std_logic;
   signal Pause_idle_cd          : std_logic;
   
   -- ddr3 arbiter
   type tddr3State is
   (
      ARBITERIDLE,
      WAITGPUPAUSED,
      REQUEST,
      WAITDONE
   );
   signal ddr3state              : tddr3State := ARBITERIDLE;
   
   signal arbiter_active         : std_logic := '0';
   
   signal memDDR3card1_acknext   : std_logic := '0';
   signal memDDR3card2_acknext   : std_logic := '0';
   signal memHPScard1_acknext    : std_logic := '0';
   signal memHPScard2_acknext    : std_logic := '0';
   signal memSPU_acknext         : std_logic := '0';
   
   signal arbiter_BURSTCNT       : std_logic_vector(7 downto 0) := (others => '0'); 
   signal arbiter_ADDR           : std_logic_vector(27 downto 0) := (others => '0');                       
   signal arbiter_DIN            : std_logic_vector(63 downto 0) := (others => '0');
   signal arbiter_BE             : std_logic_vector(7 downto 0) := (others => '0'); 
   signal arbiter_WE             : std_logic := '0';
   signal arbiter_RD             : std_logic := '0';
   
   signal memDDR3card1_request   : std_logic;
   signal memDDR3card1_ack       : std_logic := '0';
   signal memDDR3card1_BURSTCNT  : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memDDR3card1_ADDR      : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memDDR3card1_DIN       : std_logic_vector(63 downto 0) := (others => '0');
   signal memDDR3card1_BE        : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memDDR3card1_WE        : std_logic := '0';
   signal memDDR3card1_RD        : std_logic := '0';
   
   signal memDDR3card2_request   : std_logic;
   signal memDDR3card2_ack       : std_logic := '0';
   signal memDDR3card2_BURSTCNT  : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memDDR3card2_ADDR      : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memDDR3card2_DIN       : std_logic_vector(63 downto 0) := (others => '0');
   signal memDDR3card2_BE        : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memDDR3card2_WE        : std_logic := '0';
   signal memDDR3card2_RD        : std_logic := '0';
   
   signal memSPU_request         : std_logic;
   signal memSPU_ack             : std_logic := '0';
   signal memSPU_BURSTCNT        : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memSPU_ADDR            : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memSPU_DIN             : std_logic_vector(63 downto 0) := (others => '0');
   signal memSPU_BE              : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memSPU_WE              : std_logic := '0';
   signal memSPU_RD              : std_logic := '0';

   -- Busses
   signal bios_memctrl           : unsigned(13 downto 0);
   
   signal ex1_memctrl            : unsigned(13 downto 0);
   --signal bus_exp1_addr          : unsigned(22 downto 0); 
   --signal bus_exp1_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_exp1_read          : std_logic;
   --signal bus_exp1_write         : std_logic;
   signal bus_exp1_dataRead      : std_logic_vector(7 downto 0);
   
   signal bus_memc_addr          : unsigned(5 downto 0); 
   signal bus_memc_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_memc_read          : std_logic;
   signal bus_memc_write         : std_logic;
   signal bus_memc_dataRead      : std_logic_vector(31 downto 0);
   
   signal bus_pad_addr           : unsigned(3 downto 0); 
   signal bus_pad_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_pad_read           : std_logic;
   signal bus_pad_write          : std_logic;
   signal bus_pad_writeMask      : std_logic_vector(3 downto 0);
   signal bus_pad_dataRead       : std_logic_vector(31 downto 0);   
   
   signal bus_sio_addr           : unsigned(3 downto 0); 
   signal bus_sio_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_sio_read           : std_logic;
   signal bus_sio_write          : std_logic;
   signal bus_sio_writeMask      : std_logic_vector(3 downto 0);
   signal bus_sio_dataRead       : std_logic_vector(31 downto 0);
   
   signal bus_memc2_addr         : unsigned(3 downto 0); 
   signal bus_memc2_dataWrite    : std_logic_vector(31 downto 0);
   signal bus_memc2_read         : std_logic;
   signal bus_memc2_write        : std_logic;
   signal bus_memc2_dataRead     : std_logic_vector(31 downto 0);
   
   signal bus_irq_addr           : unsigned(3 downto 0); 
   signal bus_irq_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_irq_read           : std_logic;
   signal bus_irq_write          : std_logic;
   signal bus_irq_dataRead       : std_logic_vector(31 downto 0);   
   
   signal bus_dma_addr           : unsigned(6 downto 0); 
   signal bus_dma_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_dma_read           : std_logic;
   signal bus_dma_write          : std_logic;
   signal bus_dma_dataRead       : std_logic_vector(31 downto 0);
   
   signal bus_tmr_addr           : unsigned(5 downto 0); 
   signal bus_tmr_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_tmr_read           : std_logic;
   signal bus_tmr_write          : std_logic;
   signal bus_tmr_dataRead       : std_logic_vector(31 downto 0);
   
   signal cd_memctrl             : unsigned(13 downto 0);
   signal bus_cd_addr            : unsigned(3 downto 0); 
   signal bus_cd_dataWrite       : std_logic_vector(7 downto 0);
   signal bus_cd_read            : std_logic;
   signal bus_cd_write           : std_logic;
   signal bus_cd_dataRead        : std_logic_vector(7 downto 0);
   
   signal bus_gpu_addr           : unsigned(3 downto 0); 
   signal bus_gpu_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_gpu_read           : std_logic;
   signal bus_gpu_write          : std_logic;
   signal bus_gpu_dataRead       : std_logic_vector(31 downto 0);
   signal bus_gpu_stall          : std_logic;
   
   signal bus_mdec_addr          : unsigned(3 downto 0); 
   signal bus_mdec_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_mdec_read          : std_logic;
   signal bus_mdec_write         : std_logic;
   signal bus_mdec_dataRead      : std_logic_vector(31 downto 0);
   
   signal spu_memctrl            : unsigned(13 downto 0);
   signal bus_spu_addr           : unsigned(9 downto 0); 
   signal bus_spu_dataWrite      : std_logic_vector(15 downto 0);
   signal bus_spu_read           : std_logic;
   signal bus_spu_write          : std_logic;
   signal bus_spu_dataRead       : std_logic_vector(15 downto 0);
   
   signal ex2_memctrl            : unsigned(13 downto 0);
   signal bus_exp2_addr          : unsigned(12 downto 0); 
   signal bus_exp2_dataWrite     : std_logic_vector(7 downto 0);
   signal bus_exp2_read          : std_logic;
   signal bus_exp2_write         : std_logic;
   signal bus_exp2_dataRead      : std_logic_vector(7 downto 0);  
   
   signal ex3_memctrl            : unsigned(13 downto 0);
   --signal bus_exp3_dataWrite     : std_logic_vector(7 downto 0);
   signal bus_exp3_read          : std_logic;
   --signal bus_exp3_write         : std_logic;
   signal bus_exp3_dataRead      : std_logic_vector(15 downto 0);
   
   signal com0_delay             : unsigned(3 downto 0);
   signal com1_delay             : unsigned(3 downto 0);
   signal com2_delay             : unsigned(3 downto 0);
   signal com3_delay             : unsigned(3 downto 0);
   
   signal dma_spu_timing_on      : std_logic;
   signal dma_spu_timing_value   : unsigned(3 downto 0);
   
   -- Memory mux
   signal memMuxIdle             : std_logic;
   
   signal mem_request            : std_logic;
   signal mem_rnw                : std_logic; 
   signal mem_isData             : std_logic; 
   signal mem_isCache            : std_logic; 
   signal mem_oldtagvalids       : std_logic_vector(3 downto 0);
   signal mem_addressInstr       : unsigned(31 downto 0); 
   signal mem_addressData        : unsigned(31 downto 0); 
   signal mem_reqsize            : unsigned(1 downto 0); 
   signal mem_writeMask          : std_logic_vector(3 downto 0);
   signal mem_dataWrite          : std_logic_vector(31 downto 0); 
   signal mem_dataRead           : std_logic_vector(31 downto 0); 
   signal mem_done               : std_logic;
   signal mem_fifofull           : std_logic;
   signal mem_tagvalids          : std_logic_vector(3 downto 0);
   
   signal ram_next_cpu           : std_logic;
   
   signal ram_cpu_dataWrite      : std_logic_vector(31 downto 0);
   signal ram_cpu_Adr            : std_logic_vector(24 downto 0);
   signal ram_cpu_be             : std_logic_vector(3 downto 0);
   signal ram_cpu_rnw            : std_logic;
   signal ram_cpu_ena            : std_logic;
   signal ram_cpu_cache          : std_logic;
   signal ram_cpu_done           : std_logic;
   
   -- gpu
   signal vblank_tmr             : std_logic;
   signal hblank_tmr             : std_logic;
   signal dotclock               : std_logic;
   
   signal vram_pause             : std_logic; 
   signal vram_paused            : std_logic; 
   signal vram_BURSTCNT          : std_logic_vector(7 downto 0) := (others => '0'); 
   signal vram_ADDR              : std_logic_vector(27 downto 0) := (others => '0');                       
   signal vram_DIN               : std_logic_vector(63 downto 0) := (others => '0');
   signal vram_BE                : std_logic_vector(7 downto 0) := (others => '0'); 
   signal vram_WE                : std_logic := '0';
   signal vram_RD                : std_logic := '0'; 
   
   -- irq
   signal irqRequest             : std_logic;
   signal irq_VBLANK             : std_logic;
   signal irq_GPU                : std_logic;
   signal irq_CDROM              : std_logic;
   signal irq_DMA                : std_logic;
   signal irq_TIMER0             : std_logic;
   signal irq_TIMER1             : std_logic;
   signal irq_TIMER2             : std_logic;
   signal irq_PAD                : std_logic;
   signal irq_SIO                : std_logic;
   signal irq_SPU                : std_logic;
   signal irq_LIGHTPEN           : std_logic;
   
   -- dma
   signal cpuPaused              : std_logic := '0';
   signal dmaOn                  : std_logic;
   signal dmaRequest             : std_logic;
   signal dmaStallCPU            : std_logic;
   signal canDMA                 : std_logic;
   signal ignoreDMACDTiming      : std_logic;
   
   signal ram_dma_Adr            : std_logic_vector(22 downto 0);
   signal ram_dma_ena            : std_logic;
   
   signal dma_cache_Adr          : std_logic_vector(20 downto 0);
   signal dma_cache_data         : std_logic_vector(31 downto 0);
   signal dma_cache_write        : std_logic;
   
   signal gpu_dmaRequest         : std_logic;
   signal DMA_GPU_waiting        : std_logic;
   signal DMA_GPU_writeEna       : std_logic;
   signal DMA_GPU_readEna        : std_logic;
   signal DMA_GPU_write          : std_logic_vector(31 downto 0);
   signal DMA_GPU_read           : std_logic_vector(31 downto 0);
   
   signal mdec_dmaWriteRequest   : std_logic;
   signal mdec_dmaReadRequest    : std_logic;
   signal DMA_MDEC_writeEna      : std_logic := '0';
   signal DMA_MDEC_readEna       : std_logic := '0';
   signal DMA_MDEC_write         : std_logic_vector(31 downto 0);
   signal DMA_MDEC_read          : std_logic_vector(31 downto 0);
   
   signal DMA_CD_readEna         : std_logic;
   signal DMA_CD_read            : std_logic_vector(7 downto 0);
   
   signal spu_dmaRequest         : std_logic;
   signal DMA_SPU_writeEna       : std_logic := '0';
   signal DMA_SPU_readEna        : std_logic := '0';
   signal DMA_SPU_write          : std_logic_vector(15 downto 0);
   signal DMA_SPU_read           : std_logic_vector(15 downto 0);
   
   -- SPU
   signal spu_tick               : std_logic;
   signal cd_left                : signed(15 downto 0);
   signal cd_right               : signed(15 downto 0);
   
   -- cpu
   signal ce_intern              : std_logic := '0';
   signal stallNext              : std_logic;
   
   -- GTE
   signal gte_busy               : std_logic;
   signal gte_readEna            : std_logic;
   signal gte_readAddr           : unsigned(5 downto 0);
   signal gte_readData           : unsigned(31 downto 0);
   signal gte_writeAddr          : unsigned(5 downto 0);
   signal gte_writeData          : unsigned(31 downto 0);
   signal gte_writeEna           : std_logic; 
   signal gte_cmdData            : unsigned(31 downto 0);
   signal gte_cmdEna             : std_logic; 

   -- overlay + error codes
   signal cdSlow                 : std_logic;
   signal cdslowEna              : std_logic;
   signal errorEna               : std_logic;
   signal errorCode              : unsigned(3 downto 0) := (others => '0');
   signal LBAdisplay             : unsigned(19 downto 0);
   
   signal errorCD                : std_logic;
   signal errorCPU               : std_logic;
   signal errorCPU2              : std_logic;
   signal errorLINE              : std_logic;
   signal errorRECT              : std_logic;
   signal errorPOLY              : std_logic;
   signal errorGPU               : std_logic;
   signal errorMASK              : std_logic;
   signal errorCHOP              : std_logic;
   signal errorGPUFIFO           : std_logic;
   signal errorSPUTIME           : std_logic;
   signal errorDMACPU            : std_logic;
   signal errorDMAFIFO           : std_logic;
   signal errorTimer             : std_logic;
   signal errorBuswidth          : std_logic;
   
   signal debugmodeOn            : std_logic;

   signal Gun1CrosshairOn        : std_logic;
   signal Gun2CrosshairOn        : std_logic;
   signal Gun1X                  : unsigned(7 downto 0);
   signal Gun1Y                  : unsigned(7 downto 0);
   signal Gun2X                  : unsigned(7 downto 0);
   signal Gun2Y                  : unsigned(7 downto 0);
   signal Gun1Y_scanlines        : unsigned(8 downto 0);
   signal Gun2Y_scanlines        : unsigned(8 downto 0);
   signal Gun1AimOffscreen       : std_logic;
   signal Gun2AimOffscreen       : std_logic;
   signal Gun1IRQ10              : std_logic;
   signal Gun2IRQ10              : std_logic;

   -- memcard
   signal memcard1_pause         : std_logic;
   signal memcard2_pause         : std_logic;
   
   signal MemCard_changePending1 : std_logic;
   signal MemCard_changePending2 : std_logic;   
   
   signal MemCard_saving_memcard1: std_logic;
   signal MemCard_saving_memcard2: std_logic;
   
   signal memHPScard1_request    : std_logic;
   signal memHPScard1_ack        : std_logic := '0';
   signal memHPScard1_BURSTCNT   : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memHPScard1_ADDR       : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memHPScard1_DIN        : std_logic_vector(63 downto 0) := (others => '0');
   signal memHPScard1_BE         : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memHPScard1_WE         : std_logic := '0';
   signal memHPScard1_RD         : std_logic := '0';
                                 
   signal memHPScard2_request    : std_logic;
   signal memHPScard2_ack        : std_logic := '0';
   signal memHPScard2_BURSTCNT   : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memHPScard2_ADDR       : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memHPScard2_DIN        : std_logic_vector(63 downto 0) := (others => '0');
   signal memHPScard2_BE         : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memHPScard2_WE         : std_logic := '0';
   signal memHPScard2_RD         : std_logic := '0';

   -- savestates
   signal loading_savestate      : std_logic;
   signal savestate_pause        : std_logic;
   signal ddr3_savestate         : std_logic;
   
   signal SS_reset               : std_logic;
   
   signal savestate_savestate    : std_logic; 
   signal savestate_loadstate    : std_logic; 
   signal savestate_address      : integer; 
   signal savestate_busy         : std_logic; 
   
   signal SS_DataWrite           : std_logic_vector(31 downto 0);
   signal SS_Adr                 : unsigned(18 downto 0);
   signal SS_wren                : std_logic_vector(16 downto 0);
   signal SS_rden                : std_logic_vector(16 downto 0);
   signal SS_DataRead_CPU        : std_logic_vector(31 downto 0);
   signal SS_DataRead_GPU        : std_logic_vector(31 downto 0);
   signal SS_DataRead_GPUTiming  : std_logic_vector(31 downto 0);
   signal SS_DataRead_DMA        : std_logic_vector(31 downto 0);
   signal SS_DataRead_GTE        : std_logic_vector(31 downto 0);
   signal SS_DataRead_JOYPAD     : std_logic_vector(31 downto 0);
   signal SS_DataRead_MDEC       : std_logic_vector(31 downto 0);
   signal SS_DataRead_MEMORY     : std_logic_vector(31 downto 0);
   signal SS_DataRead_TIMER      : std_logic_vector(31 downto 0);
   signal SS_DataRead_SOUND      : std_logic_vector(31 downto 0);
   signal SS_DataRead_IRQ        : std_logic_vector(31 downto 0);
   signal SS_DataRead_SIO        : std_logic_vector(31 downto 0);
   signal SS_DataRead_SCP        : std_logic_vector(31 downto 0);
   signal SS_DataRead_CD         : std_logic_vector(31 downto 0);
   
   signal ss_ram_BUSY            : std_logic;                    
   signal ss_ram_DOUT            : std_logic_vector(63 downto 0);
   signal ss_ram_DOUT_READY      : std_logic;
   signal ss_ram_BURSTCNT        : std_logic_vector(7 downto 0) := (others => '0'); 
   signal ss_ram_ADDR            : std_logic_vector(25 downto 0) := (others => '0');                       
   signal ss_ram_DIN             : std_logic_vector(63 downto 0) := (others => '0');
   signal ss_ram_BE              : std_logic_vector(7 downto 0) := (others => '0'); 
   signal ss_ram_WE              : std_logic := '0';
   signal ss_ram_RD              : std_logic := '0'; 
   
   signal SS_SPURAM_dataWrite    : std_logic_vector(15 downto 0);
   signal SS_SPURAM_Adr          : std_logic_vector(18 downto 0);
   signal SS_SPURAM_request      : std_logic;
   signal SS_SPURAM_rnw          : std_logic;
   signal SS_SPURAM_dataRead     : std_logic_vector(15 downto 0);
   signal SS_SPURAM_done         : std_logic;
   
   signal SS_Idle                : std_logic; 
   signal SS_Idle_gpu            : std_logic; 
   signal SS_Idle_mdec           : std_logic; 
   signal SS_Idle_cd             : std_logic; 
   signal SS_Idle_spu            : std_logic; 
   signal SS_idle_pad            : std_logic; 
   signal SS_idle_irq            : std_logic; 
   signal SS_idle_cpu            : std_logic; 
   signal SS_idle_gte            : std_logic; 
   signal SS_idle_dma            : std_logic; 

-- synthesis translate_off
   -- export
   signal cpu_done               : std_logic; 
   signal new_export             : std_logic; 
   signal cpu_export             : cpu_export_type;
   signal export_8               : std_logic_vector(7 downto 0);
   signal export_16              : std_logic_vector(15 downto 0);
   signal export_32              : std_logic_vector(31 downto 0);
   signal export_irq             : unsigned(15 downto 0);
   signal export_gtm             : unsigned(11 downto 0);
   signal export_line            : unsigned(11 downto 0);
   signal export_gpus            : unsigned(31 downto 0);
   signal export_gobj            : unsigned(15 downto 0);
   signal export_t_current0      : unsigned(15 downto 0);
   signal export_t_current1      : unsigned(15 downto 0);
   signal export_t_current2      : unsigned(15 downto 0);
-- synthesis translate_on
   
   signal debug_firstGTE         : std_logic;
   
begin 
   
   -- reset
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         reset_in <= reset or reset_exe;
      end if;
   end process;
   

   -- clock index
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         clk1xToggle <= not clk1xToggle;
      end if;
   end process;
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         clk1xToggle2x <= clk1xToggle;
         clk2xIndex    <= '0';
         if (clk1xToggle2x = clk1xToggle) then
            clk2xIndex <= '1';
         end if;
      end if;
   end process;
   
   process (clk3x)
   begin
      if rising_edge(clk3x) then
         clk1xToggle3x   <= clk1xToggle;
         clk1xToggle3X_1 <= clk1xToggle3X;
         clk3xIndex    <= '0';
         if (clk1xToggle3X_1 = clk1xToggle) then
            clk3xIndex <= '1';
         end if;
      end if;
   end process;

   -- busses
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         bus_exp1_dataRead <= (others => '0');
         if (bus_exp1_read = '1') then
            bus_exp1_dataRead <= (others => '1');
         end if;
      
         bus_exp3_dataRead <= (others => '0');
         if (bus_exp3_read = '1') then
            bus_exp3_dataRead <= (others => '1');
         end if;
      
      end if;
   end process;
 
   SS_idle    <= SS_Idle_gpu and SS_Idle_mdec and SS_Idle_cd and SS_idle_spu and SS_idle_pad and SS_idle_irq and SS_idle_cpu and SS_idle_gte and SS_idle_dma;
   
   Pause_Idle <= SS_Idle_gpu and SS_Idle_mdec and Pause_idle_cd and SS_idle_spu and SS_idle_pad and SS_idle_irq and SS_idle_cpu and SS_idle_gte and SS_idle_dma; 
   
   -- ce generation
   canDMA <= memMuxIdle;
   
   isPaused <= pausing;
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1' or pausing = '1') then
         
            ce        <= '0';
            if (reset_intern = '1') then
               cpuPaused <= '0';
            end if;
            
            if (pause = '1') then
               pausing   <= '1';
            end if;
            
            if (pause = '0' and savestate_pause = '0' and memcard1_pause = '0' and memcard2_pause = '0' and pauseCD = '0' and allowunpause = '1') then
               pausing   <= '0';
               pausingSS <= '0';
            end if;
            
            if (savestate_pause = '1' and pausingSS = '0' and allowunpause = '1') then -- must go out of pause for savestate if not in a saveable state
               pausing <= '0';
            end if;
         
         else
      
            ce        <= '1';
         
            if (reset_intern = '1') then
               cpuPaused <= '0';
            else
         
               -- switch to pause when CD data fetch is slow
               if ((pauseCD = '1') and cpuPaused = '0' and dmaRequest = '0' and canDMA = '1' and stallNext = '0' and Pause_Idle = '1') then
                  pausing   <= '1';
                  ce        <= '0';
               -- switch to pause/savestate pausing
               elsif ((pause = '1' or savestate_pause = '1' or memcard1_pause = '1' or memcard2_pause = '1') and cpuPaused = '0' and dmaRequest = '0' and canDMA = '1' and stallNext = '0' and SS_idle = '1') then
                  pausing   <= '1';
                  pausingSS <= '1';
                  ce        <= '0';
               elsif ((cpuPaused = '1' and dmaOn = '1') or (dmaRequest = '1' and canDMA = '1')) then -- switch to dma
                  cpuPaused <= '1';
               elsif (dmaOn = '0') then -- switch to CPU
                  cpuPaused <= '0';
               end if;
               
            end if;
            
         end if;   
         
         if (reset_in = '1') then
            pausing   <= '0';
            pausingSS <= '0';
         end if;
         
      end if;
   end process;
   
   -- error codes
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         if (reset_intern = '1') then
            errorEna  <= '0';
            errorCode <= x"0";
         else
         
            if (errorEna = '0') then
               if (errorCD       = '1') then errorEna  <= '1'; errorCode <= x"1"; end if;
               if (errorCPU      = '1') then errorEna  <= '1'; errorCode <= x"2"; end if;
               if (errorGPU      = '1') then errorEna  <= '1'; errorCode <= x"3"; end if;
               if (errorMASK     = '1') then errorEna  <= '1'; errorCode <= x"7"; end if;
               if (errorCHOP     = '1') then errorEna  <= '1'; errorCode <= x"8"; end if;
               if (errorGPUFIFO  = '1') then errorEna  <= '1'; errorCode <= x"9"; end if;
               if (errorSPUTIME  = '1') then errorEna  <= '1'; errorCode <= x"A"; end if;
               if (errorDMACPU   = '1') then errorEna  <= '1'; errorCode <= x"B"; end if;
               if (errorDMAFIFO  = '1') then errorEna  <= '1'; errorCode <= x"C"; end if;
               if (errorCPU2     = '1') then errorEna  <= '1'; errorCode <= x"D"; end if;
               if (errorTimer    = '1') then errorEna  <= '1'; errorCode <= x"E"; end if;
               if (errorBuswidth = '1') then errorEna  <= '1'; errorCode <= x"F"; end if;
            end if;
            
            if (errorEna = '0' or errorCode = x"3") then
               if (errorLINE = '1') then errorEna  <= '1'; errorCode <= x"4"; end if;
               if (errorRECT = '1') then errorEna  <= '1'; errorCode <= x"5"; end if;
               if (errorPOLY = '1') then errorEna  <= '1'; errorCode <= x"6"; end if;
            end if;
            
         end if;
         
         debugmodeOn <= '0';
         if (REPRODUCIBLEGPUTIMING = '1') then debugmodeOn <= '1'; end if;
         if (noTexture             = '1') then debugmodeOn <= '1'; end if;
         if (SPUon                 = '0') then debugmodeOn <= '1'; end if;
         if (REVERBOFF             = '1') then debugmodeOn <= '1'; end if;
         if (REPRODUCIBLESPUDMA    = '1') then debugmodeOn <= '1'; end if;
         if (videoout_on           = '0') then debugmodeOn <= '1'; end if;
         if (PATCHSERIAL           = '1') then debugmodeOn <= '1'; end if;
         
      end if;
   end process;
   
   -- DDR3 arbiter
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         memDDR3card1_ack    <= '0';
         memDDR3card2_ack    <= '0';         
         memHPScard1_ack     <= '0';
         memHPScard2_ack     <= '0';
         memSPU_ack          <= '0';
      
         if (reset_intern = '1') then
            arbiter_active    <= '0';
            vram_pause        <= '0';
            ddr3state         <= ARBITERIDLE;
            
            memDDR3card1_acknext  <= '0';
            memDDR3card2_acknext  <= '0';            
            memHPScard1_acknext   <= '0';
            memHPScard2_acknext   <= '0';
            memSPU_acknext        <= '0';
         else
         
            case (ddr3state) is
            
               when ARBITERIDLE =>
                  memDDR3card1_acknext  <= '0';
                  memDDR3card2_acknext  <= '0';                  
                  memHPScard1_acknext   <= '0';
                  memHPScard2_acknext   <= '0';
                  memSPU_acknext        <= '0';
                  if (memDDR3card1_request = '1' or memDDR3card2_request = '1' or memHPScard1_request = '1' or memHPScard2_request = '1' or memSPU_request = '1') then
                     vram_pause <= '1';
                     ddr3state  <= WAITGPUPAUSED;
                  end if;
                  
               when WAITGPUPAUSED =>
                  if (vram_paused = '1' and ddr3_savestate = '0') then
                     ddr3state      <= REQUEST; 
                     arbiter_active <= '1';
                     if (memDDR3card1_request = '1') then
                        memDDR3card1_acknext <= '1';
                        arbiter_BURSTCNT     <= memDDR3card1_BURSTCNT;
                        arbiter_ADDR         <= x"01" & memDDR3card1_ADDR;    
                        arbiter_DIN          <= memDDR3card1_DIN;     
                        arbiter_BE           <= memDDR3card1_BE;      
                        arbiter_WE           <= memDDR3card1_WE;      
                        arbiter_RD           <= memDDR3card1_RD;
                     elsif (memDDR3card2_request = '1') then
                        memDDR3card2_acknext <= '1';
                        arbiter_BURSTCNT     <= memDDR3card2_BURSTCNT;
                        arbiter_ADDR         <= x"02" & memDDR3card2_ADDR;    
                        arbiter_DIN          <= memDDR3card2_DIN;     
                        arbiter_BE           <= memDDR3card2_BE;      
                        arbiter_WE           <= memDDR3card2_WE;      
                        arbiter_RD           <= memDDR3card2_RD;
                     elsif (memHPScard1_request = '1') then
                        memHPScard1_acknext <= '1';
                        arbiter_BURSTCNT     <= memHPScard1_BURSTCNT;
                        arbiter_ADDR         <= x"01" & memHPScard1_ADDR;    
                        arbiter_DIN          <= memHPScard1_DIN;     
                        arbiter_BE           <= memHPScard1_BE;      
                        arbiter_WE           <= memHPScard1_WE;      
                        arbiter_RD           <= memHPScard1_RD;
                     elsif (memHPScard2_request = '1') then
                        memHPScard2_acknext <= '1';
                        arbiter_BURSTCNT     <= memHPScard2_BURSTCNT;
                        arbiter_ADDR         <= x"02" & memHPScard2_ADDR;    
                        arbiter_DIN          <= memHPScard2_DIN;     
                        arbiter_BE           <= memHPScard2_BE;      
                        arbiter_WE           <= memHPScard2_WE;      
                        arbiter_RD           <= memHPScard2_RD;
                     elsif (memSPU_request = '1') then
                        memSPU_acknext       <= '1';
                        arbiter_BURSTCNT     <= memSPU_BURSTCNT;
                        arbiter_ADDR         <= x"03" & memSPU_ADDR;    
                        arbiter_DIN          <= memSPU_DIN;     
                        arbiter_BE           <= memSPU_BE;      
                        arbiter_WE           <= memSPU_WE;      
                        arbiter_RD           <= memSPU_RD;
                     end if;
                  end if;
               
               when REQUEST =>
                  if (ddr3_BUSY = '0') then
                     ddr3state  <= WAITDONE; 
                     arbiter_WE <= '0';     
                     arbiter_RD <= '0';
                     if (memDDR3card1_acknext = '1') then memDDR3card1_ack <= '1'; end if;
                     if (memDDR3card2_acknext = '1') then memDDR3card2_ack <= '1'; end if;                    
                     if (memHPScard1_acknext  = '1') then memHPScard1_ack <= '1';  end if;
                     if (memHPScard2_acknext  = '1') then memHPScard2_ack <= '1';  end if;
                     if (memSPU_acknext       = '1') then memSPU_ack <= '1';       end if;
                  end if;
               
               when WAITDONE =>
                  if (
                      (memDDR3card1_request and memDDR3card1_acknext) = '0' and 
                      (memDDR3card2_request and memDDR3card2_acknext) = '0' and 
                      (memHPScard1_request  and memHPScard1_acknext ) = '0' and 
                      (memHPScard2_request  and memHPScard2_acknext ) = '0' and
                      (memSPU_request       and memSPU_acknext      ) = '0'
                     ) then
                     ddr3state      <= ARBITERIDLE;
                     arbiter_active <= '0';
                     vram_pause     <= '0';
                  end if;
               
            end case;
         end if;
      end if;
   end process;
   
   
   imemctrl : entity work.memctrl
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,

      bus_addr             => bus_memc_addr,     
      bus_dataWrite        => bus_memc_dataWrite,
      bus_read             => bus_memc_read,     
      bus_write            => bus_memc_write,    
      bus_dataRead         => bus_memc_dataRead,      
      
      bus2_addr            => bus_memc2_addr,     
      bus2_dataWrite       => bus_memc2_dataWrite,
      bus2_read            => bus_memc2_read,     
      bus2_write           => bus_memc2_write,    
      bus2_dataRead        => bus_memc2_dataRead,
      
      errorBuswidth        => errorBuswidth,
      
      spu_memctrl          => spu_memctrl, 
      cd_memctrl           => cd_memctrl, 
      bios_memctrl         => bios_memctrl, 
      ex1_memctrl          => ex1_memctrl, 
      ex2_memctrl          => ex2_memctrl, 
      ex3_memctrl          => ex3_memctrl, 
      
      com0_delay           => com0_delay,
      com1_delay           => com1_delay,
      com2_delay           => com2_delay,
      com3_delay           => com3_delay,
      
      dma_spu_timing_on    => dma_spu_timing_on,   
      dma_spu_timing_value => dma_spu_timing_value,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(4 downto 0),      
      SS_wren              => SS_wren(7),     
      SS_rden              => SS_rden(7),     
      SS_DataRead          => SS_DataRead_MEMORY      
   );

   -- Gun coordinate mapping is toplevel so that the gun's
   -- coordinates can be passed to both joypad
   -- and GPU (for crosshair overlays)
   Gun1X <= to_unsigned(to_integer(joypad1.Analog1X + 128), 8);
   Gun2X <= to_unsigned(to_integer(joypad2.Analog1X + 128), 8);

   Gun1Y <= to_unsigned(to_integer(joypad1.Analog1Y + 128), 8);
   Gun2Y <= to_unsigned(to_integer(joypad2.Analog1Y + 128), 8);

   Gun1AimOffscreen <= '1' when Gun1X = x"00" or Gun1X = x"FF" or Gun1Y = x"00" or Gun1Y = x"FF" else '0';
   Gun2AimOffscreen <= '1' when Gun2X = x"00" or Gun2X = x"FF" or Gun2Y = x"00" or Gun2Y = x"FF" else '0';

   Gun1CrosshairOn <= '1' when
                      showGunCrosshairs = '1' and
                      (joypad1.PadPortGunCon = '1' or joypad1.PadPortJustif = '1') and
                      Gun1AimOffscreen = '0'
                   else '0';
   Gun2CrosshairOn <= '1' when
                      showGunCrosshairs = '1' and
                      (joypad2.PadPortGunCon = '1' or joypad2.PadPortJustif = '1') and
                      Gun2AimOffscreen = '0'
                   else '0';

   -- Map the gun's Y coordinate to 240 scanlines
   Gun1Y_scanlines <= resize(Gun1Y, 9) - resize(Gun1Y(7 downto 4), 9); -- Gun1Y * 240 / 256
   Gun2Y_scanlines <= resize(Gun2Y, 9) - resize(Gun2Y(7 downto 4), 9); -- Gun1Y * 240 / 256

   ijoypad: entity work.joypad
   port map 
   (
      clk1x                => clk1x,
      clk2x                => clk2x,
      clk2xIndex           => clk2xIndex,
      ce                   => ce,   
      reset                => reset_intern,

      isPal                => isPal, -- passed through for GunCon
      
      DSAltSwitchMode      => DSAltSwitchMode,
      joypad1              => joypad1,
      joypad2              => joypad2,
      joypad3              => joypad3,
      joypad4              => joypad4,
      multitap             => multitap,
      joypad1_rumble       => joypad1_rumble,
      joypad2_rumble       => joypad2_rumble,
      joypad3_rumble       => joypad3_rumble,
      joypad4_rumble       => joypad4_rumble,
      padMode              => padMode,

      memcard1_available   => memcard1_available,
      memcard2_available   => memcard2_available,
      
      irqRequest           => irq_PAD,
      
      MouseEvent           => MouseEvent,
      MouseLeft            => MouseLeft,
      MouseRight           => MouseRight,
      MouseX               => MouseX,
      MouseY               => MouseY,
      Gun1X                => Gun1X,
      Gun2X                => Gun2X,
      Gun1Y_scanlines      => Gun1Y_scanlines,
      Gun2Y_scanlines      => Gun2Y_scanlines,
      Gun1AimOffscreen     => Gun1AimOffscreen,
      Gun2AimOffscreen     => Gun2AimOffscreen,
      
      snacPort1_in         => snacport1,
      snacPort2_in         => snacport2,      
      selectedPort1Snac    => selectedPort1Snac,
      selectedPort2Snac    => selectedPort2Snac,
      transmitValueSnac    => transmitValueSnac,
      clk9Snac             => clk9Snac,
      receiveBufferSnac	   => receiveBufferSnac,
      beginTransferSnac    => beginTransferSnac,
      actionNextSnac       => actionNextSnac,
      receiveValidSnac     => receiveValidSnac,
      ackSnac              => ackSnac,
      
      mem1_request         => memDDR3card1_request,   
      mem1_BURSTCNT        => memDDR3card1_BURSTCNT,  
      mem1_ADDR            => memDDR3card1_ADDR,      
      mem1_DIN             => memDDR3card1_DIN,       
      mem1_BE              => memDDR3card1_BE,        
      mem1_WE              => memDDR3card1_WE,        
      mem1_RD              => memDDR3card1_RD,       
      mem1_ack             => memDDR3card1_ack,       
      
      mem2_request         => memDDR3card2_request,   
      mem2_BURSTCNT        => memDDR3card2_BURSTCNT,  
      mem2_ADDR            => memDDR3card2_ADDR,      
      mem2_DIN             => memDDR3card2_DIN,       
      mem2_BE              => memDDR3card2_BE,        
      mem2_WE              => memDDR3card2_WE,        
      mem2_RD              => memDDR3card2_RD,       
      mem2_ack             => memDDR3card2_ack,  
      
      mem_DOUT             => ddr3_DOUT,      
      mem_DOUT_READY       => ddr3_DOUT_READY,
      
      bus_addr             => bus_pad_addr,     
      bus_dataWrite        => bus_pad_dataWrite,
      bus_read             => bus_pad_read,     
      bus_write            => bus_pad_write,    
      bus_writeMask        => bus_pad_writeMask,   
      bus_dataRead         => bus_pad_dataRead,
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(2 downto 0),      
      SS_wren              => SS_wren(5),     
      SS_rden              => SS_rden(5),     
      SS_DataRead          => SS_DataRead_JOYPAD,
      SS_idle              => SS_idle_pad
   );
   
   icheats : entity work.cheats
   port map
   (
      clk1x          => clk1x,
      ce             => ce,
      reset          => reset_intern,

      dmaOn          => dmaOn,

      cheat_clear    => cheat_clear,
      cheats_enabled => cheats_enabled,
      cheat_on       => cheat_on,
      cheat_in       => cheat_in,
      cheats_active  => cheats_active,

      vsync          => IRQ_VBlank,

      --bus_ena_in     => mem_bus_ena,

      BusAddr        => Cheats_BusAddr,
      BusRnW         => Cheats_BusRnW,
      BusByteEnable  => Cheats_BusByteEnable,
      BusWriteData   => Cheats_BusWriteData,
      Bus_ena        => Cheats_Bus_ena,
      BusReadData    => Cheats_BusReadData,
      BusDone        => Cheats_BusDone
   );

   isio : entity work.sio
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      bus_addr             => bus_sio_addr,     
      bus_dataWrite        => bus_sio_dataWrite,
      bus_read             => bus_sio_read,     
      bus_write            => bus_sio_write,    
      bus_writeMask        => bus_sio_writeMask,
      bus_dataRead         => bus_sio_dataRead,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(2 downto 0),      
      SS_wren              => SS_wren(11),     
      SS_rden              => SS_rden(11),     
      SS_DataRead          => SS_DataRead_SIO
   );
   
   irq_SIO       <= '0'; -- todo
   irq_LIGHTPEN  <= '1' when
                    (Gun1IRQ10 = '1' and joypad1.PadPortJustif = '1') or
                    (Gun2IRQ10 = '1' and joypad2.PadPortJustif = '1')
                 else '0';

   iirq : entity work.irq
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      irq_VBLANK           => irq_VBLANK,
      irq_GPU              => irq_GPU,     
      irq_CDROM            => irq_CDROM,   
      irq_DMA              => irq_DMA,     
      irq_TIMER0           => irq_TIMER0,  
      irq_TIMER1           => irq_TIMER1,  
      irq_TIMER2           => irq_TIMER2,  
      irq_PAD              => irq_PAD,     
      irq_SIO              => irq_SIO,     
      irq_SPU              => irq_SPU,     
      irq_LIGHTPEN         => irq_LIGHTPEN,
      irq10Snac            => irq10Snac,
      
      bus_addr             => bus_irq_addr,     
      bus_dataWrite        => bus_irq_dataWrite,
      bus_read             => bus_irq_read,     
      bus_write            => bus_irq_write,    
      bus_dataRead         => bus_irq_dataRead,
      
      irqRequest           => irqRequest,

-- synthesis translate_off
      export_irq           => export_irq,
-- synthesis translate_on
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(0 downto 0),      
      SS_wren              => SS_wren(10),     
      SS_rden              => SS_rden(10),     
      SS_DataRead          => SS_DataRead_IRQ,
      SS_idle              => SS_idle_irq
   );
   
   ignoreDMACDTiming <= '1' when (TURBO_MEM = '1' or IGNORECDDMATIMING = '1' or unsigned(FORCECDSPEED) >= 3) else '0';
   
   idma : entity work.dma
   port map
   (
      clk1x                => clk1x,
      clk3x                => clk3x,
      clk3xIndex           => clk3xIndex,
      ce                   => ce,   
      reset                => reset_intern,
      
      errorCHOP            => errorCHOP, 
      errorDMACPU          => errorDMACPU, 
      errorDMAFIFO         => errorDMAFIFO, 
      
      TURBO                => TURBO_COMP,
      TURBO_CACHE          => TURBO_CACHE,
      ram8mb               => ram8mb,
      ignoreCDTiming       => ignoreDMACDTiming,
      
      canDMA               => canDMA,
      cpuPaused            => cpuPaused,
      dmaRequest           => dmaRequest,
      dmaStallCPU          => dmaStallCPU,
      dmaOn                => dmaOn,
      irqOut               => irq_DMA,
      
      ram_Adr              => ram_dma_Adr,  
      ram_cnt              => ram_cntDMA,  
      ram_ena              => ram_dma_ena,
      
      dma_wr               => dma_wr, 
      dma_reqprocessed     => dma_reqprocessed,      
      dma_data             => dma_data,
      
      ram_dmafifo_adr      => ram_dmafifo_adr, 
      ram_dmafifo_data     => ram_dmafifo_data,
      ram_dmafifo_empty    => ram_dmafifo_empty,
      ram_dmafifo_read     => ram_dmafifo_read, 

      dma_cache_Adr        => dma_cache_Adr,  
      dma_cache_data       => dma_cache_data, 
      dma_cache_write      => dma_cache_write,      
      
      gpu_dmaRequest       => gpu_dmaRequest,  
      DMA_GPU_waiting      => DMA_GPU_waiting,
      DMA_GPU_writeEna     => DMA_GPU_writeEna,
      DMA_GPU_readEna      => DMA_GPU_readEna, 
      DMA_GPU_write        => DMA_GPU_write,   
      DMA_GPU_read         => DMA_GPU_read,   
      
      mdec_dmaWriteRequest => mdec_dmaWriteRequest,
      mdec_dmaReadRequest  => mdec_dmaReadRequest, 
      DMA_MDEC_writeEna    => DMA_MDEC_writeEna,   
      DMA_MDEC_readEna     => DMA_MDEC_readEna,    
      DMA_MDEC_write       => DMA_MDEC_write,      
      DMA_MDEC_read        => DMA_MDEC_read,   

      cd_memctrl           => cd_memctrl,
      com0_delay           => com0_delay,
      DMA_CD_readEna       => DMA_CD_readEna,
      DMA_CD_read          => DMA_CD_read,   
      
      spu_timing_on        => dma_spu_timing_on,   
      spu_timing_value     => dma_spu_timing_value,
      spu_dmaRequest       => spu_dmaRequest, 
      DMA_SPU_writeEna     => DMA_SPU_writeEna,   
      DMA_SPU_readEna      => DMA_SPU_readEna,    
      DMA_SPU_write        => DMA_SPU_write,    
      DMA_SPU_read         => DMA_SPU_read,
      
      bus_addr             => bus_dma_addr,     
      bus_dataWrite        => bus_dma_dataWrite,
      bus_read             => bus_dma_read,     
      bus_write            => bus_dma_write,    
      bus_dataRead         => bus_dma_dataRead,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(5 downto 0),      
      SS_wren              => SS_wren(3),     
      SS_rden              => SS_rden(3),     
      SS_DataRead          => SS_DataRead_DMA,
      SS_idle              => SS_idle_dma
   );
   
   ram_refresh   <= reset_intern;
   
   ram_dataWrite <=                                                ram_cpu_dataWrite;
   ram_be        <=                                                ram_cpu_be;       
   ram_rnw       <= '1'                when (cpuPaused = '1') else ram_cpu_rnw;      
   ram_ena       <= ram_dma_ena        when (cpuPaused = '1') else ram_cpu_ena;      
   ram_dma       <= '1'                when (cpuPaused = '1') else '0';      
   ram_cache     <= '0'                when (cpuPaused = '1') else ram_cpu_cache;    
   
   ram_Adr       <=   "00" & ram_dma_Adr(22 downto 0) when (cpuPaused = '1' and ram8mb = '1') else 
                    "0000" & ram_dma_Adr(20 downto 0) when (cpuPaused = '1' and ram8mb = '0') else 
                    ram_cpu_Adr(24 downto 23) &        ram_cpu_Adr(22 downto 0) when (ram8mb = '1') else
                    ram_cpu_Adr(24 downto 23) & "00" & ram_cpu_Adr(20 downto 0);
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (ram_ena = '1') then
            ram_next_cpu <= '0';
            if (cpuPaused = '0') then
               ram_next_cpu <= '1';
            end if;
         end if;
      
      end if;
   end process;
   
   ram_cpu_done <= ram_done and ram_next_cpu;
   
   itimer : entity work.timer
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      error                => errorTimer,
      
      dotclock             => dotclock,
      hblank               => hblank_tmr,
      vblank               => vblank_tmr,
      
      irqRequest0          => irq_TIMER0,
      irqRequest1          => irq_TIMER1,
      irqRequest2          => irq_TIMER2,
      
      bus_addr             => bus_tmr_addr,     
      bus_dataWrite        => bus_tmr_dataWrite,
      bus_read             => bus_tmr_read,     
      bus_write            => bus_tmr_write,       
      bus_dataRead         => bus_tmr_dataRead,
      
-- synthesis translate_off
      export_t_current0    => export_t_current0,
      export_t_current1    => export_t_current1,
      export_t_current2    => export_t_current2,
-- synthesis translate_on
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(3 downto 0),      
      SS_wren              => SS_wren(8),     
      SS_rden              => SS_rden(8),     
      SS_DataRead          => SS_DataRead_TIMER
   );
   
   icd_top : entity work.cd_top
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
     
      INSTANTSEEK          => INSTANTSEEK,
      FORCECDSPEED         => FORCECDSPEED,
      LIMITREADSPEED       => LIMITREADSPEED,
      hasCD                => hasCD,
      fastCD               => fastCD,
      testSeek             => testSeek,
      pauseOnCDSlow        => pauseOnCDSlow,
      LIDopen              => LIDopen,
      region               => region,
      region_out           => region_out,
      
      pauseCD              => pauseCD,
      Pause_idle_cd        => Pause_idle_cd,
      cdSlow               => cdSlow,
      error                => errorCD,
      LBAdisplay           => LBAdisplay,
          
      irqOut               => irq_CDROM,
      
      spu_tick             => spu_tick,
      cd_left              => cd_left,
      cd_right             => cd_right,
      
      mdec_idle            => SS_Idle_mdec,
                            
      bus_addr             => bus_cd_addr,     
      bus_dataWrite        => bus_cd_dataWrite,
      bus_read             => bus_cd_read,     
      bus_write            => bus_cd_write,     
      bus_dataRead         => bus_cd_dataRead,
                            
      dma_read             => DMA_CD_readEna,
      dma_readdata         => DMA_CD_read,
      
      cd_hps_req           => cd_hps_req,  
      cd_hps_lba           => cd_hps_lba,
      cd_hps_lba_sim       => cd_hps_lba_sim,
      cd_hps_ack           => cd_hps_ack,
      cd_hps_write         => cd_hps_write,
      cd_hps_data          => cd_hps_data, 
      
      trackinfo_data       => trackinfo_data,
      trackinfo_addr       => trackinfo_addr, 
      trackinfo_write      => trackinfo_write,
      resetFromCD          => resetFromCD,
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(13 downto 0),      
      SS_wren              => SS_wren(13),     
      SS_rden              => SS_rden(13),     
      SS_DataRead          => SS_DataRead_CD,
      SS_Idle              => SS_Idle_cd
   );

   cdslowEna <= cdSlow and cdslowOn;

   igpu : entity work.gpu
   port map
   (
      clk1x                => clk1x,
      clk2x                => clk2x,
      clk2xIndex           => clk2xIndex,
      clkvid               => clkvid,
      ce                   => ce,   
      reset                => reset_intern,
      
      allowunpause         => allowunpause,
      savestate_busy       => savestate_busy,
      system_paused        => pausing,
      
      ditherOff            => ditherOff,
      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,
      videoout_on          => videoout_on,
      isPal                => isPal,
      pal60                => pal60,
      fpscountOn           => fpscountOn,
      noTexture            => noTexture,
      textureFilter        => textureFilter,
      textureFilterStrength=> textureFilterStrength,
      textureFilter2DOff   => textureFilter2DOff,
      dither24             => dither24,
      render24             => render24,
      debugmodeOn          => debugmodeOn,
      syncVideoOut         => syncVideoOut,
      syncInterlace        => syncInterlace,
      rotate180            => rotate180,
      fixedVBlank          => fixedVBlank,
      vCrop                => vCrop,   
      hCrop                => hCrop,   
      
      Gun1CrosshairOn      => Gun1CrosshairOn,
      Gun1X                => Gun1X,
      Gun1Y_scanlines      => Gun1Y_scanlines,
      Gun1IRQ10            => Gun1IRQ10,

      Gun2CrosshairOn      => Gun2CrosshairOn,
      Gun2X                => Gun2X,
      Gun2Y_scanlines      => Gun2Y_scanlines,
      Gun2IRQ10            => Gun2IRQ10,

      cdSlow               => cdslowEna,
      
      errorOn              => errorOn,  
      errorEna             => errorEna, 
      errorCode            => errorCode,
      
      LBAOn                => LBAOn,
      LBAdisplay           => LBAdisplay,
      
      errorLINE            => errorLINE,
      errorRECT            => errorRECT,
      errorPOLY            => errorPOLY,
      errorGPU             => errorGPU, 
      errorMASK            => errorMASK, 
      errorFIFO            => errorGPUFIFO,
      
      bus_addr             => bus_gpu_addr,     
      bus_dataWrite        => bus_gpu_dataWrite,
      bus_read             => bus_gpu_read,     
      bus_write            => bus_gpu_write,    
      bus_dataRead         => bus_gpu_dataRead, 
      bus_stall            => bus_gpu_stall, 
      
      dmaOn                => dmaOn,
      gpu_dmaRequest       => gpu_dmaRequest,  
      DMA_GPU_waiting      => DMA_GPU_waiting,
      DMA_GPU_writeEna     => DMA_GPU_writeEna,
      DMA_GPU_readEna      => DMA_GPU_readEna, 
      DMA_GPU_write        => DMA_GPU_write,   
      DMA_GPU_read         => DMA_GPU_read,  
      
      irq_VBLANK           => irq_VBLANK,
      irq_GPU              => irq_GPU,
      
      vram_pause           => vram_pause, 
      vram_paused          => vram_paused,
      vram_BUSY            => ddr3_BUSY,       
      vram_DOUT            => ddr3_DOUT,       
      vram_DOUT_READY      => ddr3_DOUT_READY,
      vram_BURSTCNT        => vram_BURSTCNT,  
      vram_ADDR            => vram_ADDR,      
      vram_DIN             => vram_DIN,       
      vram_BE              => vram_BE,        
      vram_WE              => vram_WE,        
      vram_RD              => vram_RD, 

      hblank_tmr           => hblank_tmr,
      vblank_tmr           => vblank_tmr,
      dotclock             => dotclock,
      
      video_hsync          => hsync, 
      video_vsync          => vsync, 
      video_hblank         => hblank,
      video_vblank         => vblank,
      video_DisplayWidth   => DisplayWidth, 
      video_DisplayHeight  => DisplayHeight,
      video_DisplayOffsetX => DisplayOffsetX,
      video_DisplayOffsetY => DisplayOffsetY,
      video_ce             => video_ce,
      video_interlace      => video_interlace,
      video_r              => video_r, 
      video_g              => video_g, 
      video_b              => video_b, 
      video_isPal          => video_isPal, 
      video_hResMode       => video_hResMode, 
      
-- synthesis translate_off
      export_gtm           => export_gtm,
      export_line          => export_line,
      export_gpus          => export_gpus,
      export_gobj          => export_gobj,
-- synthesis translate_on
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(2 downto 0),
      SS_wren_GPU          => SS_wren(1),     
      SS_wren_Timing       => SS_wren(2),      
      SS_rden_GPU          => SS_rden(1),     
      SS_rden_Timing       => SS_rden(2),
      SS_DataRead_GPU      => SS_DataRead_GPU,
      SS_DataRead_Timing   => SS_DataRead_GPUTiming,
      SS_Idle              => SS_Idle_gpu
   );
   
   imdec : entity work.mdec
   port map
   (
      clk1x                => clk1x,     
      clk2x                => clk2x,    
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => reset_intern,     
      
      bus_addr             => bus_mdec_addr,     
      bus_dataWrite        => bus_mdec_dataWrite,
      bus_read             => bus_mdec_read,     
      bus_write            => bus_mdec_write,    
      bus_dataRead         => bus_mdec_dataRead, 
      
      dmaWriteRequest      => mdec_dmaWriteRequest,
      dmaReadRequest       => mdec_dmaReadRequest, 
      dma_write            => DMA_MDEC_writeEna,   
      dma_writedata        => DMA_MDEC_write,    
      dma_read             => DMA_MDEC_readEna,      
      dma_readdata         => DMA_MDEC_read,

      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(6 downto 0),      
      SS_wren              => SS_wren(6),     
      SS_rden              => SS_rden(6),     
      SS_DataRead          => SS_DataRead_MDEC,
      SS_Idle              => SS_Idle_mdec
   );

   ispu : entity work.spu
   port map
   (
      clk1x                => clk1x,   
      clk2x                => clk2x,    
      clk2xIndex           => clk2xIndex,      
      ce                   => ce,        
      reset                => reset_intern,     
      
      SPUon                => SPUon,
      useSDRAM             => SPUSDRAM,
      REPRODUCIBLESPUIRQ   => '1',
      REPRODUCIBLESPUDMA   => REPRODUCIBLESPUDMA,
      REVERBOFF            => REVERBOFF,
      
      cpuPaused            => cpuPaused,
      
      spu_tick             => spu_tick,
      cd_left              => cd_left,
      cd_right             => cd_right,
      
      irqOut               => irq_SPU,
      
      sound_timeout        => errorSPUTIME,
      
      sound_out_left       => sound_out_left, 
      sound_out_right      => sound_out_right,
      
      bus_addr             => bus_spu_addr,     
      bus_dataWrite        => bus_spu_dataWrite,
      bus_read             => bus_spu_read,     
      bus_write            => bus_spu_write,    
      bus_dataRead         => bus_spu_dataRead, 
      
      spu_dmaRequest       => spu_dmaRequest, 
      dma_read             => DMA_SPU_readEna,      
      dma_readdata         => DMA_SPU_read, 
      dma_write            => DMA_SPU_writeEna, 
      dma_writedata        => DMA_SPU_write,
          
      sdram_dataWrite      => spuram_dataWrite,
      sdram_dataRead       => spuram_dataRead, 
      sdram_Adr            => spuram_Adr,      
      sdram_be             => spuram_be,      
      sdram_rnw            => spuram_rnw,      
      sdram_ena            => spuram_ena,           
      sdram_done           => spuram_done,
      
      mem_request          => memSPU_request,  
      mem_BURSTCNT         => memSPU_BURSTCNT, 
      mem_ADDR             => memSPU_ADDR,     
      mem_DIN              => memSPU_DIN,      
      mem_BE               => memSPU_BE,       
      mem_WE               => memSPU_WE,       
      mem_RD               => memSPU_RD,       
      mem_ack              => memSPU_ack,      
      mem_DOUT             => ddr3_DOUT,      
      mem_DOUT_READY       => ddr3_DOUT_READY,
      
      SS_reset             => SS_reset,
      loading_savestate    => loading_savestate,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(8 downto 0),  
      SS_wren              => SS_wren(9),     
      SS_rden              => SS_rden(9),     
      SS_DataRead          => SS_DataRead_SOUND,
      SS_idle              => SS_idle_spu,
      
      SS_RAM_dataWrite     => SS_SPURAM_dataWrite,
      SS_RAM_Adr           => SS_SPURAM_Adr,      
      SS_RAM_request       => SS_SPURAM_request,  
      SS_RAM_rnw           => SS_SPURAM_rnw,      
      SS_RAM_dataRead      => SS_SPURAM_dataRead, 
      SS_RAM_done          => SS_SPURAM_done     
   );
   
   iexp2 : entity work.exp2
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      bus_addr             => bus_exp2_addr,     
      bus_dataWrite        => bus_exp2_dataWrite,
      bus_read             => bus_exp2_read,     
      bus_write            => bus_exp2_write,    
      bus_dataRead         => bus_exp2_dataRead
   );

   imemorymux : entity work.memorymux
   port map
   (
      clk1x                => clk1x,
      clk2x                => clk2x,
      ce                   => ce,   
      reset                => reset_intern,
      
      pauseNext            => cpuPaused or (dmaRequest and canDMA),
      isIdle               => memMuxIdle,
         
      loadExe              => loadExe,
      exe_initial_pc       => exe_initial_pc,  
      exe_initial_gp       => exe_initial_gp,  
      exe_load_address     => exe_load_address,
      exe_file_size        => exe_file_size,   
      exe_stackpointer     => exe_stackpointer,
      reset_exe            => reset_exe,
      
      fastboot             => fastboot,
      TURBO                => TURBO_MEM,
      region_in            => biosregion,
      PATCHSERIAL          => PATCHSERIAL,
            
      ram_dataWrite        => ram_cpu_dataWrite,
      ram_dataRead         => ram_dataRead32,  
      ram_Adr              => ram_cpu_Adr,  
      ram_be               => ram_cpu_be,        
      ram_rnw              => ram_cpu_rnw,      
      ram_ena              => ram_cpu_ena,   
      ram_cache            => ram_cpu_cache,      
      ram_done             => ram_cpu_done,
      
      mem_in_request       => mem_request,  
      mem_in_rnw           => mem_rnw,      
      mem_in_isData        => mem_isData,      
      mem_in_isCache       => mem_isCache,      
      mem_in_oldtagvalids  => mem_oldtagvalids,  
      mem_in_addressInstr  => mem_addressInstr,  
      mem_in_addressData   => mem_addressData,  
      mem_in_reqsize       => mem_reqsize,  
      mem_in_writeMask     => mem_writeMask,
      mem_in_dataWrite     => mem_dataWrite,
      mem_dataRead         => mem_dataRead, 
      mem_done             => mem_done,
      mem_fifofull         => mem_fifofull,  
      mem_tagvalids        => mem_tagvalids,

      bios_memctrl         => bios_memctrl,

      ex1_memctrl          => ex1_memctrl,
      --bus_exp1_addr        => bus_exp1_addr,   
      --bus_exp1_dataWrite   => bus_exp1_dataWrite,
      bus_exp1_read        => bus_exp1_read,   
      --bus_exp1_write       => bus_exp1_write,  
      bus_exp1_dataRead    => bus_exp1_dataRead,
      
      bus_memc_addr        => bus_memc_addr,     
      bus_memc_dataWrite   => bus_memc_dataWrite,
      bus_memc_read        => bus_memc_read,     
      bus_memc_write       => bus_memc_write,    
      bus_memc_dataRead    => bus_memc_dataRead,   
      
      bus_pad_addr         => bus_pad_addr,     
      bus_pad_dataWrite    => bus_pad_dataWrite,
      bus_pad_read         => bus_pad_read,     
      bus_pad_write        => bus_pad_write,    
      bus_pad_writeMask    => bus_pad_writeMask,
      bus_pad_dataRead     => bus_pad_dataRead,       
      
      bus_sio_addr         => bus_sio_addr,     
      bus_sio_dataWrite    => bus_sio_dataWrite,
      bus_sio_read         => bus_sio_read,     
      bus_sio_write        => bus_sio_write,    
      bus_sio_writeMask    => bus_sio_writeMask,
      bus_sio_dataRead     => bus_sio_dataRead, 

      bus_memc2_addr       => bus_memc2_addr,     
      bus_memc2_dataWrite  => bus_memc2_dataWrite,
      bus_memc2_read       => bus_memc2_read,     
      bus_memc2_write      => bus_memc2_write,    
      bus_memc2_dataRead   => bus_memc2_dataRead, 

      bus_irq_addr         => bus_irq_addr,     
      bus_irq_dataWrite    => bus_irq_dataWrite,
      bus_irq_read         => bus_irq_read,     
      bus_irq_write        => bus_irq_write,    
      bus_irq_dataRead     => bus_irq_dataRead,       
      
      bus_dma_addr         => bus_dma_addr,     
      bus_dma_dataWrite    => bus_dma_dataWrite,
      bus_dma_read         => bus_dma_read,     
      bus_dma_write        => bus_dma_write,    
      bus_dma_dataRead     => bus_dma_dataRead,     

      bus_tmr_addr         => bus_tmr_addr,     
      bus_tmr_dataWrite    => bus_tmr_dataWrite,
      bus_tmr_read         => bus_tmr_read,     
      bus_tmr_write        => bus_tmr_write,    
      bus_tmr_dataRead     => bus_tmr_dataRead,  

      cd_memctrl           => cd_memctrl,
      bus_cd_addr          => bus_cd_addr,     
      bus_cd_dataWrite     => bus_cd_dataWrite,
      bus_cd_read          => bus_cd_read,     
      bus_cd_write         => bus_cd_write,    
      bus_cd_dataRead      => bus_cd_dataRead,      
      
      bus_gpu_addr         => bus_gpu_addr,     
      bus_gpu_dataWrite    => bus_gpu_dataWrite,
      bus_gpu_read         => bus_gpu_read,     
      bus_gpu_write        => bus_gpu_write,    
      bus_gpu_dataRead     => bus_gpu_dataRead,
      bus_gpu_stall        => bus_gpu_stall,
      
      bus_mdec_addr        => bus_mdec_addr,     
      bus_mdec_dataWrite   => bus_mdec_dataWrite,
      bus_mdec_read        => bus_mdec_read,     
      bus_mdec_write       => bus_mdec_write,    
      bus_mdec_dataRead    => bus_mdec_dataRead, 
      
      spu_memctrl          => spu_memctrl, 
      bus_spu_addr         => bus_spu_addr,     
      bus_spu_dataWrite    => bus_spu_dataWrite,
      bus_spu_read         => bus_spu_read,     
      bus_spu_write        => bus_spu_write,    
      bus_spu_dataRead     => bus_spu_dataRead, 
      
      ex2_memctrl          => ex2_memctrl,
      bus_exp2_addr        => bus_exp2_addr,     
      bus_exp2_dataWrite   => bus_exp2_dataWrite,
      bus_exp2_read        => bus_exp2_read,     
      bus_exp2_write       => bus_exp2_write,    
      bus_exp2_dataRead    => bus_exp2_dataRead,
      
      ex3_memctrl          => ex3_memctrl,
      --bus_exp3_dataWrite   => bus_exp3_dataWrite,
      bus_exp3_read        => bus_exp3_read,     
      --bus_exp3_write       => bus_exp3_write,    
      bus_exp3_dataRead    => bus_exp3_dataRead, 
      
      com0_delay           => com0_delay,
      com1_delay           => com1_delay,
      com2_delay           => com2_delay,
      com3_delay           => com3_delay,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(18 downto 0),
      SS_wren_SDRam        => SS_wren(16),
      SS_rden_SDRam        => SS_rden(16)
   );
   
   icpu : entity work.cpu
   port map
   (
      clk1x             => clk1x,
      clk2x             => clk2x,
      clk3x             => clk3x,
      ce                => ce,   
      reset             => reset_intern,
      
      TURBO             => TURBO_COMP,
      TURBO_CACHE       => TURBO_CACHE,
      TURBO_CACHE50     => TURBO_CACHE50,
         
      irqRequest        => irqRequest,
      dmaStallCPU       => dmaStallCPU,
      cpuPaused         => cpuPaused,
      
      error             => errorCPU,
      error2            => errorCPU2,
         
      mem_request       => mem_request,  
      mem_rnw           => mem_rnw,      
      mem_isData        => mem_isData,      
      mem_isCache       => mem_isCache, 
      mem_oldtagvalids  => mem_oldtagvalids,      
      mem_addressInstr  => mem_addressInstr,  
      mem_addressData   => mem_addressData,  
      mem_reqsize       => mem_reqsize,  
      mem_writeMask     => mem_writeMask,
      mem_dataWrite     => mem_dataWrite,
      mem_dataRead      => mem_dataRead, 
      mem_done          => mem_done,
      mem_fifofull      => mem_fifofull,
      mem_tagvalids     => mem_tagvalids,
      
      cache_wr          => cache_wr,  
      cache_data        => cache_data,
      cache_addr        => cache_addr,
      
      stallNext         => stallNext,
      
      dma_cache_Adr     => dma_cache_Adr,  
      dma_cache_data    => dma_cache_data, 
      dma_cache_write   => dma_cache_write,  
      
      ram_dataRead      => ram_dataRead32,    
      ram_done          => ram_cpu_done,
      
      gte_busy          => gte_busy, 
      gte_readEna       => gte_readEna,
      gte_readAddr      => gte_readAddr, 
      gte_readData      => gte_readData, 
      gte_writeAddr     => gte_writeAddr,
      gte_writeData     => gte_writeData,
      gte_writeEna      => gte_writeEna, 
      gte_cmdData       => gte_cmdData,  
      gte_cmdEna        => gte_cmdEna, 

      SS_reset          => SS_reset,
      SS_DataWrite      => SS_DataWrite,
      SS_Adr            => SS_Adr(7 downto 0),   
      SS_wren_CPU       => SS_wren(0),     
      SS_wren_SCP       => SS_wren(12),  
      SS_rden_CPU       => SS_rden(0),     
      SS_rden_SCP       => SS_rden(12),        
      SS_DataRead_CPU   => SS_DataRead_CPU,
      SS_DataRead_SCP   => SS_DataRead_SCP,
      SS_idle           => SS_idle_cpu,
      
-- synthesis translate_off
      cpu_done          => cpu_done,  
      cpu_export        => cpu_export,
-- synthesis translate_on
      
      debug_firstGTE    => debug_firstGTE
   );
   
   igte : entity work.gte
   port map
   (
      clk1x                => clk1x,     
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => reset_intern,     
      
      WIDESCREEN           => WIDESCREEN,
      TURBO                => TURBO_COMP,
      
      gte_busy             => gte_busy,     
      gte_readAddr         => gte_readAddr, 
      gte_readData         => gte_readData, 
      gte_readEna          => gte_readEna,
      gte_writeAddr_in     => gte_writeAddr,
      gte_writeData_in     => gte_writeData,
      gte_writeEna_in      => gte_writeEna, 
      gte_cmdData          => gte_cmdData,  
      gte_cmdEna           => gte_cmdEna,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(5 downto 0),
      SS_wren              => SS_wren(4),     
      SS_rden              => SS_rden(4),     
      SS_DataRead          => SS_DataRead_GTE,
      SS_idle              => SS_idle_gte,
      
      debug_firstGTE       => debug_firstGTE
   );
   
   ddr3_BURSTCNT <= ss_ram_BURSTCNT     when (ddr3_savestate = '1') else arbiter_BURSTCNT when (arbiter_active = '1') else  vram_BURSTCNT;  
   ddr3_ADDR     <= ss_ram_ADDR & "00"  when (ddr3_savestate = '1') else arbiter_ADDR     when (arbiter_active = '1') else  vram_ADDR;      
   ddr3_DIN      <= ss_ram_DIN          when (ddr3_savestate = '1') else arbiter_DIN      when (arbiter_active = '1') else  vram_DIN;       
   ddr3_BE       <= ss_ram_BE           when (ddr3_savestate = '1') else arbiter_BE       when (arbiter_active = '1') else  vram_BE;        
   ddr3_WE       <= ss_ram_WE           when (ddr3_savestate = '1') else arbiter_WE       when (arbiter_active = '1') else  vram_WE;        
   ddr3_RD       <= ss_ram_RD           when (ddr3_savestate = '1') else arbiter_RD       when (arbiter_active = '1') else  vram_RD;        
   
   memcard_changed <= MemCard_changePending1 or MemCard_changePending2;
   saving_memcard  <= MemCard_saving_memcard1 or MemCard_saving_memcard2;
   
   imemcard1 : entity work.memcard
   port map
   (
      clk2x                => clk2x, 
      ce                   => ce,    
      reset                => reset, 
      
      save                 => memcard_save,
      load                 => memcard1_load,
                            
      pause                => memcard1_pause,
      system_paused        => pausing,
                           
      mounted              => memcard1_mounted,
      anyChange            => memDDR3card1_WE,
      
      changePending        => MemCard_changePending1,
      saving_memcard       => MemCard_saving_memcard1,
                            
      mem_request          => memHPScard1_request, 
      mem_BURSTCNT         => memHPScard1_BURSTCNT,      
      mem_ADDR             => memHPScard1_ADDR,                     
      mem_DIN              => memHPScard1_DIN,    
      mem_BE               => memHPScard1_BE,      
      mem_WE               => memHPScard1_WE,      
      mem_RD               => memHPScard1_RD,   
      mem_ack              => memHPScard1_ack,   
      mem_DOUT             => ddr3_DOUT,      
      mem_DOUT_READY       => ddr3_DOUT_READY,
                           
      memcard_rd           => memcard1_rd,     
      memcard_wr           => memcard1_wr,     
      memcard_lba          => memcard1_lba,    
      memcard_ack          => memcard1_ack,    
      memcard_write        => memcard1_write,  
      memcard_addr         => memcard1_addr,   
      memcard_dataIn       => memcard1_dataIn, 
      memcard_dataOut      => memcard1_dataOut
   );
   
   imemcard2 : entity work.memcard
   port map
   (
      clk2x                => clk2x, 
      ce                   => ce,    
      reset                => reset, 
      
      save                 => memcard_save,
      load                 => memcard2_load,
                            
      pause                => memcard2_pause,
      system_paused        => pausing,
                           
      mounted              => memcard2_mounted,
      anyChange            => memDDR3card2_WE,
      
      changePending        => MemCard_changePending2,
      saving_memcard       => MemCard_saving_memcard2,
                            
      mem_request          => memHPScard2_request, 
      mem_BURSTCNT         => memHPScard2_BURSTCNT,      
      mem_ADDR             => memHPScard2_ADDR,                     
      mem_DIN              => memHPScard2_DIN,    
      mem_BE               => memHPScard2_BE,      
      mem_WE               => memHPScard2_WE,      
      mem_RD               => memHPScard2_RD,   
      mem_ack              => memHPScard2_ack,   
      mem_DOUT             => ddr3_DOUT,      
      mem_DOUT_READY       => ddr3_DOUT_READY,
                           
      memcard_rd           => memcard2_rd,     
      memcard_wr           => memcard2_wr,     
      memcard_lba          => memcard2_lba,    
      memcard_ack          => memcard2_ack,    
      memcard_write        => memcard2_write,  
      memcard_addr         => memcard2_addr,   
      memcard_dataIn       => memcard2_dataIn, 
      memcard_dataOut      => memcard2_dataOut
   );
   
   isavestates : entity work.savestates
   generic map
   (
      FASTSIM => is_simu
   )
   port map
   (
      clk1x                   => clk1x,
      clk2x                   => clk2x,
      clk2xIndex              => clk2xIndex,
      ce                      => ce,
      reset_in                => reset_in,
      reset_out               => reset_intern,
      ss_reset                => SS_reset,
      
      hps_busy                => hps_busy,
      loadExe                 => loadExe,
           
      load_done               => state_loaded,
            
      increaseSSHeaderCount   => increaseSSHeaderCount,
      save                    => savestate_savestate,
      load                    => savestate_loadstate,
      savestate_address       => savestate_address,  
      savestate_busy          => savestate_busy,    

      SS_idle                 => SS_idle,
      system_paused           => pausingSS,
      savestate_pause         => savestate_pause,
      ddr3_savestate          => ddr3_savestate,
      
      useSPUSDRAM             => SPUSDRAM,
      
      SS_DataWrite            => SS_DataWrite,   
      SS_Adr                  => SS_Adr,         
      SS_wren                 => SS_wren,       
      SS_rden                 => SS_rden,       
      SS_DataRead_CPU         => SS_DataRead_CPU,
      SS_DataRead_GPU         => SS_DataRead_GPU,
      SS_DataRead_GPUTiming   => SS_DataRead_GPUTiming,
      SS_DataRead_DMA         => SS_DataRead_DMA,
      SS_DataRead_GTE         => SS_DataRead_GTE,
      SS_DataRead_JOYPAD      => SS_DataRead_JOYPAD,
      SS_DataRead_MDEC        => SS_DataRead_MDEC,
      SS_DataRead_MEMORY      => SS_DataRead_MEMORY,
      SS_DataRead_TIMER       => SS_DataRead_TIMER,
      SS_DataRead_SOUND       => SS_DataRead_SOUND,
      SS_DataRead_IRQ         => SS_DataRead_IRQ,
      SS_DataRead_SIO         => SS_DataRead_SIO,
      SS_DataRead_SCP         => SS_DataRead_SCP,
      SS_DataRead_CD          => SS_DataRead_CD,

      sdram_done              => ram_done,
      
      loading_savestate       => loading_savestate,
      saving_savestate        => open,
            
      ddr3_BUSY               => ddr3_BUSY,      
      ddr3_DOUT               => ddr3_DOUT,      
      ddr3_DOUT_READY         => ddr3_DOUT_READY,
      ddr3_BURSTCNT           => ss_ram_BURSTCNT,
      ddr3_ADDR               => ss_ram_ADDR,    
      ddr3_DIN                => ss_ram_DIN,     
      ddr3_BE                 => ss_ram_BE,      
      ddr3_WE                 => ss_ram_WE,      
      ddr3_RD                 => ss_ram_RD,

      ram_done                => ram_cpu_done,   
      ram_data                => ram_dataRead32,
      
      SS_SPURAM_dataWrite     => SS_SPURAM_dataWrite,
      SS_SPURAM_Adr           => SS_SPURAM_Adr,      
      SS_SPURAM_request       => SS_SPURAM_request,  
      SS_SPURAM_rnw           => SS_SPURAM_rnw,      
      SS_SPURAM_dataRead      => SS_SPURAM_dataRead, 
      SS_SPURAM_done          => SS_SPURAM_done     
   );  

   istatemanager : entity work.statemanager
   generic map
   (
      Softmap_SaveState_ADDR   => 58720256,
      Softmap_Rewind_ADDR      => 33554432
   )
   port map
   (
      clk                 => clk2x,  
      ce                  => ce,  
      reset               => reset_in,
                         
      rewind_on           => rewind_on,    
      rewind_active       => rewind_active,
                        
      savestate_number    => savestate_number,
      save                => save_state,
      load                => load_state,
                       
      sleep_rewind        => open,
      vsync               => IRQ_VBlank,
      system_idle         => '1',
                 
      request_savestate   => savestate_savestate,
      request_loadstate   => savestate_loadstate,
      request_address     => savestate_address,  
      request_busy        => savestate_busy    
   );
   
   -- export
-- synthesis translate_off
   gexport : if is_simu = '1' generate
   begin
   
      new_export <= cpu_done; 
      
      iexport : entity work.export
      port map
      (
         clk               => clk1x,
         ce                => ce,
         reset             => reset_intern,
            
         new_export        => cpu_done,
         export_cpu        => cpu_export,
            
         export_irq        => export_irq,
            
         export_gtm        => export_gtm,
         export_line       => export_line,
         export_gpus       => export_gpus,
         export_gobj       => export_gobj,
         
         export_t_current0 => export_t_current0,
         export_t_current1 => export_t_current1,
         export_t_current2 => export_t_current2,
            
         export_8          => export_8,
         export_16         => export_16,
         export_32         => export_32
      );
   
   
   end generate;
-- synthesis translate_on
   
end architecture;





