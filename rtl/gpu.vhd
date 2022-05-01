library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;
use work.pGPU.all;

entity gpu is
   port 
   (
      clk1x                : in  std_logic;
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      clkvid               : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      allowunpause         : out std_logic;
      
      ditherOff            : in  std_logic;
      REPRODUCIBLEGPUTIMING: in  std_logic;
      videoout_on          : in  std_logic;
      isPal                : in  std_logic;
      pal60                : in  std_logic;
      fpscountOn           : in  std_logic;
      noTexture            : in  std_logic;
      textureFilter        : in  std_logic;
      debugmodeOn          : in  std_logic;
      syncVideoOut         : in  std_logic;
      syncInterlace        : in  std_logic;

      Gun1CrosshairOn      : in  std_logic;
      Gun1X                : in  unsigned(7 downto 0);
      Gun1Y_scanlines      : in  unsigned(8 downto 0);
      Gun1IRQ10            : out std_logic;

      Gun2CrosshairOn      : in  std_logic;
      Gun2X                : in  unsigned(7 downto 0);
      Gun2Y_scanlines      : in  unsigned(8 downto 0);
      Gun2IRQ10            : out std_logic;
      
      cdSlow               : in  std_logic;
      
      errorOn              : in  std_logic;
      errorEna             : in  std_logic;
      errorCode            : in  unsigned(3 downto 0);
      
      errorLINE            : out std_logic;
      errorRECT            : out std_logic;
      errorPOLY            : out std_logic;
      errorGPU             : out std_logic;
      errorMASK            : out std_logic;
      errorFIFO            : out std_logic;
      
      bus_addr             : in  unsigned(3 downto 0); 
      bus_dataWrite        : in  std_logic_vector(31 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(31 downto 0);
      bus_stall            : out std_logic := '0';
      
      dmaOn                : in  std_logic;
      gpu_dmaRequest       : out std_logic;
      DMA_GPU_waiting      : in  std_logic;
      DMA_GPU_writeEna     : in  std_logic;
      DMA_GPU_readEna      : in  std_logic;
      DMA_GPU_write        : in  std_logic_vector(31 downto 0);
      DMA_GPU_read         : out std_logic_vector(31 downto 0);
      
      irq_VBLANK           : out std_logic := '0';
      irq_GPU              : out std_logic := '0';
           
      vram_pause           : in  std_logic;
      vram_paused          : out std_logic := '0';
      vram_BUSY            : in  std_logic;                    
      vram_DOUT            : in  std_logic_vector(63 downto 0);
      vram_DOUT_READY      : in  std_logic;
      vram_BURSTCNT        : out std_logic_vector(7 downto 0) := (others => '0'); 
      vram_ADDR            : out std_logic_vector(19 downto 0) := (others => '0');                       
      vram_DIN             : out std_logic_vector(63 downto 0) := (others => '0');
      vram_BE              : out std_logic_vector(7 downto 0) := (others => '0'); 
      vram_WE              : out std_logic := '0';
      vram_RD              : out std_logic := '0';     

      hblank_tmr           : out std_logic := '0';
      vblank_tmr           : out std_logic := '0';
      
      video_hsync          : out std_logic := '0';
      video_vsync          : out std_logic := '0';
      video_hblank         : out std_logic := '0';
      video_vblank         : out std_logic := '0';
      video_DisplayWidth   : out unsigned( 9 downto 0);
      video_DisplayHeight  : out unsigned( 8 downto 0);
      video_DisplayOffsetX : out unsigned( 9 downto 0) := (others => '0'); 
      video_DisplayOffsetY : out unsigned( 8 downto 0) := (others => '0'); 
      video_ce             : out std_logic;
      video_interlace      : out std_logic;
      video_r              : out std_logic_vector(7 downto 0);
      video_g              : out std_logic_vector(7 downto 0);
      video_b              : out std_logic_vector(7 downto 0);
      video_isPal          : out std_logic;
      video_hResMode       : out std_logic_vector(2 downto 0);
      
-- synthesis translate_off
      export_gtm           : out unsigned(11 downto 0);
      export_line          : out unsigned(11 downto 0);
      export_gpus          : out unsigned(31 downto 0);
      export_gobj          : out unsigned(15 downto 0) := (others => '0');
-- synthesis translate_on
      
      loading_savestate    : in  std_logic;
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(2 downto 0);
      SS_wren_GPU          : in  std_logic;
      SS_wren_Timing       : in  std_logic;
      SS_rden_GPU          : in  std_logic;
      SS_rden_Timing       : in  std_logic;
      SS_DataRead_GPU      : out std_logic_vector(31 downto 0);
      SS_DataRead_Timing   : out std_logic_vector(31 downto 0);
      SS_Idle              : out std_logic
   );
end entity;

architecture arch of gpu is
  
   signal softReset                 : std_logic := '0';
   signal drawer_reset              : std_logic := '0';
   
   signal videoout_settings         : tvideoout_settings;
   signal videoout_reports          : tvideoout_reports;
   signal videoout_out              : tvideoout_out;
   
   signal GPUREAD                   : std_logic_vector(31 downto 0) := (others => '0');
   signal GPUSTAT                   : std_logic_vector(31 downto 0) := (others => '0');
   signal GPUSTAT_TextPageX         : std_logic_vector(3 downto 0);
   signal GPUSTAT_TextPageY         : std_logic;
   signal GPUSTAT_Transparency      : std_logic_vector(1 downto 0);
   signal GPUSTAT_TextPageColors    : std_logic_vector(1 downto 0);
   signal GPUSTAT_Dither            : std_logic;
   signal GPUSTAT_DrawToDisplay     : std_logic;
   signal GPUSTAT_SetMask           : std_logic;
   signal GPUSTAT_DrawPixelsMask    : std_logic;
   signal GPUSTAT_ReverseFlag       : std_logic;
   signal GPUSTAT_TextureDisable    : std_logic;
   signal GPUSTAT_HorRes2           : std_logic := '0';
   signal GPUSTAT_HorRes1           : std_logic_vector(1 downto 0) := "00";
   signal GPUSTAT_VerRes            : std_logic := '0';
   signal GPUSTAT_PalVideoMode      : std_logic := '0';
   signal GPUSTAT_ColorDepth24      : std_logic := '0';
   signal GPUSTAT_VertInterlace     : std_logic := '0';
   signal GPUSTAT_DisplayDisable    : std_logic := '1';
   signal GPUSTAT_IRQRequest        : std_logic;
   signal GPUSTAT_DMADataRequest    : std_logic;
   signal GPUSTAT_ReadyRecCmd       : std_logic;
   signal GPUSTAT_ReadySendVRAM     : std_logic;
   signal GPUSTAT_ReadyRecDMA       : std_logic;
   signal GPUSTAT_DMADirection      : std_logic_vector(1 downto 0);
      
   signal vramRange                 : unsigned(18 downto 0) := (others => '0');
   signal hDisplayRange             : unsigned(23 downto 0) := (others => '0');
   signal vDisplayRange             : unsigned(19 downto 0) := (others => '0');
      
   signal drawMode                  : unsigned(13 downto 0) := (others => '0');
      
   signal textureWindow             : unsigned(19 downto 0) := (others => '0');
   signal textureWindow_AND_X       : unsigned(7 downto 0) := (others => '0');
   signal textureWindow_AND_Y       : unsigned(7 downto 0) := (others => '0');   
   signal textureWindow_OR_X        : unsigned(7 downto 0) := (others => '0');
   signal textureWindow_OR_Y        : unsigned(7 downto 0) := (others => '0');
      
   signal drawingAreaLeft           : unsigned(9 downto 0) := (others => '0');
   signal drawingAreaRight          : unsigned(9 downto 0) := (others => '0');
   signal drawingAreaTop            : unsigned(8 downto 0) := (others => '0');
   signal drawingAreaBottom         : unsigned(8 downto 0) := (others => '0');
   signal drawingOffsetX            : signed(10 downto 0) := (others => '0');
   signal drawingOffsetY            : signed(10 downto 0) := (others => '0');
   signal interlacedDrawing         : std_logic;
      
   -- FIFO IN  
   signal fifoIn_reset              : std_logic; 
   signal fifoIn_Din                : std_logic_vector(31 downto 0);
   signal fifoIn_Wr                 : std_logic; 
   signal fifoIn_Dout               : std_logic_vector(31 downto 0);
   signal fifoIn_Rd                 : std_logic;
   signal fifoIn_Empty              : std_logic;
   signal fifoIn_Valid              : std_logic;
      
   -- Processing  
   signal proc_idle                 : std_logic;
   signal proc_done                 : std_logic;
   --signal proc_CmdDone              : std_logic;
   signal proc_requestFifo          : std_logic;
   signal timeout                   : integer range 0 to 67108863 := 0;
   
   signal pixelStall                : std_logic;
   signal pixelColor                : std_logic_vector(15 downto 0);
   signal pixelAddr                 : unsigned(19 downto 0);
   signal pixelWrite                : std_logic;
      
   signal pixel64data               : std_logic_vector(63 downto 0) := (others => '0');
   signal pixel64wordEna            : std_logic_vector(3 downto 0) := (others => '0');
   signal pixel64addr               : std_logic_vector(16 downto 0) := (others => '0');
   signal pixel64filled             : std_logic := '0';
   signal pixel64timeout            : integer range 0 to 15;
      
   -- workers  
   type t_div_array is array(0 to 5) of div_type;
   signal div_array                 : t_div_array;
   
   signal vramFill_requestFifo      : std_logic; 
   signal vramFill_done             : std_logic; 
   --signal vramFill_CmdDone          : std_logic; 
   signal vramFill_pixelColor       : std_logic_vector(15 downto 0);
   signal vramFill_pixelAddr        : unsigned(19 downto 0);
   signal vramFill_pixelWrite       : std_logic;   
      
   signal cpu2vram_requestFifo      : std_logic; 
   signal cpu2vram_done             : std_logic; 
   --signal cpu2vram_CmdDone          : std_logic; 
   signal cpu2vram_pixelColor       : std_logic_vector(15 downto 0);
   signal cpu2vram_pixelAddr        : unsigned(19 downto 0);
   signal cpu2vram_pixelWrite       : std_logic;
      
   signal vram2vram_requestFifo     : std_logic; 
   signal vram2vram_done            : std_logic; 
   --signal vram2vram_CmdDone         : std_logic; 
   signal vram2vram_pixelColor      : std_logic_vector(15 downto 0);
   signal vram2vram_pixelAddr       : unsigned(19 downto 0);
   signal vram2vram_pixelWrite      : std_logic;
   signal vram2vram_reqVRAMEnable   : std_logic;
   signal vram2vram_reqVRAMXPos     : unsigned(9 downto 0);
   signal vram2vram_reqVRAMYPos     : unsigned(8 downto 0);
   signal vram2vram_reqVRAMSize     : unsigned(10 downto 0);
   signal vram2vram_vramLineEna     : std_logic;
   signal vram2vram_vramLineAddr    : unsigned(9 downto 0);
   
   signal vram2cpu_requestFifo      : std_logic; 
   signal vram2cpu_done             : std_logic; 
   --signal vram2cpu_CmdDone          : std_logic; 
   signal vram2cpu_reqVRAMEnable    : std_logic;
   signal vram2cpu_reqVRAMXPos      : unsigned(9 downto 0);
   signal vram2cpu_reqVRAMYPos      : unsigned(8 downto 0);
   signal vram2cpu_reqVRAMSize      : unsigned(10 downto 0);
   signal vram2cpu_vramLineEna      : std_logic;
   signal vram2cpu_vramLineAddr     : unsigned(9 downto 0);
   signal vram2cpu_Fifo_Dout        : std_logic_vector(31 downto 0);
   signal vram2cpu_Fifo_Rd          : std_logic;
   signal vram2cpu_Fifo_Empty       : std_logic;
   signal vram2cpu_Fifo_ready       : std_logic;
   
   signal line_requestFifo          : std_logic; 
   signal line_done                 : std_logic;
   --signal line_CmdDone              : std_logic;
   signal line_div                  : t_div_array;
   signal line_pipeline_new         : std_logic;
   signal line_pipeline_transparent : std_logic;
   signal line_pipeline_x           : unsigned(9 downto 0);
   signal line_pipeline_y           : unsigned(8 downto 0);
   signal line_pipeline_cr          : unsigned(7 downto 0);
   signal line_pipeline_cg          : unsigned(7 downto 0);
   signal line_pipeline_cb          : unsigned(7 downto 0);
   signal line_reqVRAMEnable        : std_logic;
   signal line_reqVRAMXPos          : unsigned(9 downto 0);
   signal line_reqVRAMYPos          : unsigned(8 downto 0);
   signal line_reqVRAMSize          : unsigned(10 downto 0);
   signal line_vramLineEna          : std_logic;
   signal line_vramLineAddr         : unsigned(9 downto 0);
   
   signal rect_requestFifo          : std_logic; 
   signal rect_done                 : std_logic;
   --signal rect_CmdDone              : std_logic;
   signal rect_pipeline_new         : std_logic;
   signal rect_pipeline_texture     : std_logic;
   signal rect_pipeline_transparent : std_logic;
   signal rect_pipeline_rawTexture  : std_logic;
   signal rect_pipeline_x           : unsigned(9 downto 0);
   signal rect_pipeline_y           : unsigned(8 downto 0);
   signal rect_pipeline_cr          : unsigned(7 downto 0);
   signal rect_pipeline_cg          : unsigned(7 downto 0);
   signal rect_pipeline_cb          : unsigned(7 downto 0);
   signal rect_pipeline_u           : unsigned(7 downto 0);
   signal rect_pipeline_v           : unsigned(7 downto 0);
   signal rect_reqVRAMEnable        : std_logic;
   signal rect_reqVRAMXPos          : unsigned(9 downto 0);
   signal rect_reqVRAMYPos          : unsigned(8 downto 0);
   signal rect_reqVRAMSize          : unsigned(10 downto 0);
   signal rect_vramLineEna          : std_logic;
   signal rect_vramLineAddr         : unsigned(9 downto 0);
   signal rect_textPalNew           : std_logic;
   signal rect_textPalX             : unsigned(9 downto 0);   
   signal rect_textPalY             : unsigned(8 downto 0); 
   
   signal poly_requestFifo          : std_logic; 
   signal poly_done                 : std_logic;
   --signal poly_CmdDone              : std_logic;
   signal poly_div                  : t_div_array;
   signal poly_pipeline_new         : std_logic;
   signal poly_pipeline_texture     : std_logic;
   signal poly_pipeline_transparent : std_logic;
   signal poly_pipeline_rawTexture  : std_logic;
   signal poly_pipeline_dithering   : std_logic;
   signal poly_pipeline_x           : unsigned(9 downto 0);
   signal poly_pipeline_y           : unsigned(8 downto 0);
   signal poly_pipeline_cr          : unsigned(7 downto 0);
   signal poly_pipeline_cg          : unsigned(7 downto 0);
   signal poly_pipeline_cb          : unsigned(7 downto 0);
   signal poly_pipeline_u           : unsigned(7 downto 0);
   signal poly_pipeline_v           : unsigned(7 downto 0);
   signal poly_reqVRAMEnable        : std_logic;
   signal poly_reqVRAMXPos          : unsigned(9 downto 0);
   signal poly_reqVRAMYPos          : unsigned(8 downto 0);
   signal poly_reqVRAMSize          : unsigned(10 downto 0);
   signal poly_vramLineEna          : std_logic;
   signal poly_vramLineAddr         : unsigned(9 downto 0);
   signal poly_drawModeRec          : unsigned(11 downto 0);
   signal poly_drawModeNew          : std_logic;
   signal poly_textPalNew           : std_logic;
   signal poly_textPalX             : unsigned(9 downto 0);   
   signal poly_textPalY             : unsigned(8 downto 0); 
   
   signal pipeline_pixelColor       : std_logic_vector(15 downto 0);
   signal pipeline_pixelAddr        : unsigned(19 downto 0);
   signal pipeline_pixelWrite       : std_logic;
   signal pipeline_reqVRAMEnable    : std_logic;
   signal pipeline_reqVRAMXPos      : unsigned(9 downto 0);
   signal pipeline_reqVRAMYPos      : unsigned(8 downto 0);
   signal pipeline_reqVRAMSize      : unsigned(10 downto 0);
   
   signal pipeline_busy             : std_logic;
   signal pipeline_stall            : std_logic;
   signal pipeline_new              : std_logic;
   signal pipeline_texture          : std_logic;
   signal pipeline_transparent      : std_logic;
   signal pipeline_rawTexture       : std_logic;
   signal pipeline_dithering        : std_logic;
   signal pipeline_x                : unsigned(9 downto 0);
   signal pipeline_y                : unsigned(8 downto 0);
   signal pipeline_cr               : unsigned(7 downto 0);
   signal pipeline_cg               : unsigned(7 downto 0);
   signal pipeline_cb               : unsigned(7 downto 0);
   signal pipeline_u                : unsigned(7 downto 0);
   signal pipeline_v                : unsigned(7 downto 0);
   
   signal pipeline_clearCache       : std_logic;
   
   signal pipeline_textPalNew       : std_logic;
   signal pipeline_textPalX         : unsigned(9 downto 0);   
   signal pipeline_textPalY         : unsigned(8 downto 0); 
      
   -- FIFO OUT 
   signal fifoOut_reset             : std_logic; 
   signal fifoOut_Din               : std_logic_vector(84 downto 0);
   signal fifoOut_Wr                : std_logic; 
   signal fifoOut_Full              : std_logic;
   signal fifoOut_NearFull          : std_logic;
   signal fifoOut_Dout              : std_logic_vector(84 downto 0);
   signal fifoOut_Rd                : std_logic;
   signal fifoOut_Empty             : std_logic;
   signal fifoOut_Valid             : std_logic;
   
   -- vram access
   type tvramState is
   (
      IDLE,
      READVRAM
   );
   signal vramState : tvramState := IDLE;
   
   signal VRAMIdle                  : std_logic;
   signal reqVRAMIdle               : std_logic;
   signal reqVRAMDone               : std_logic;
   signal vram_pauseCnt             : integer range 0 to 3;
   
   signal reqVRAMEnable             : std_logic;
   signal reqVRAMXPos               : unsigned(9 downto 0);
   signal reqVRAMYPos               : unsigned(8 downto 0);
   signal reqVRAMSize               : unsigned(10 downto 0);
   signal reqVRAMremain             : unsigned(7 downto 0);
   signal reqVRAMwrap               : unsigned(7 downto 0);
   signal reqVRAMnext               : unsigned(7 downto 0);
   signal reqVRAMaddr               : unsigned(7 downto 0) := (others => '0');
   signal reqVRAMStore              : std_logic;        
   
   signal vramLineAddr              : unsigned(9 downto 0);
   
   signal vramLineData              : std_logic_vector(15 downto 0);
   
   -- videoout
   signal videoout_reqVRAMEnable    : std_logic;
   signal videoout_reqVRAMXPos      : unsigned(9 downto 0);
   signal videoout_reqVRAMYPos      : unsigned(8 downto 0);
   signal videoout_reqVRAMSize      : unsigned(10 downto 0);
   
   -- fps counter
   signal fpscountBCD               : unsigned(7 downto 0) := (others => '0');
   signal fpscountBCD_next          : unsigned(7 downto 0) := (others => '0');
   signal fps_SecondCounter         : integer range 0 to 33868799 := 0;
   signal fps_vramRange_last        : unsigned(18 downto 0) := (others => '0');
   
   -- savestates
   type t_ssarray is array(0 to 7) of std_logic_vector(31 downto 0);
   signal ss_gpu_in     : t_ssarray := (others => (others => '0'));
   signal ss_timing_in  : t_ssarray := (others => (others => '0'));   
   signal ss_gpu_out    : t_ssarray := (others => (others => '0'));
   signal ss_timing_out : t_ssarray := (others => (others => '0'));
   
   signal videoout_ss_in  : tvideoout_ss;
   signal videoout_ss_out : tvideoout_ss;
   
begin 

-- synthesis translate_off
   export_gtm  <= unsigned(videoout_ss_out.nextHCount);
   export_line <= "000" & unsigned(videoout_ss_out.vpos);
   export_gpus <= unsigned(GPUSTAT);
-- synthesis translate_on
   
   gpu_dmaRequest <= GPUSTAT_DMADataRequest;

   GPUSTAT(3 downto 0)     <= GPUSTAT_TextPageX;
   GPUSTAT(4)              <= GPUSTAT_TextPageY;
   GPUSTAT(6 downto 5)     <= GPUSTAT_Transparency;
   GPUSTAT(8 downto 7)     <= GPUSTAT_TextPageColors;
   GPUSTAT(9)              <= GPUSTAT_Dither;
   GPUSTAT(10)             <= GPUSTAT_DrawToDisplay;
   GPUSTAT(11)             <= GPUSTAT_SetMask;
   GPUSTAT(12)             <= GPUSTAT_DrawPixelsMask;
   GPUSTAT(13)             <= videoout_reports.GPUSTAT_InterlaceField;
   GPUSTAT(14)             <= GPUSTAT_ReverseFlag;
   GPUSTAT(15)             <= GPUSTAT_TextureDisable;
   GPUSTAT(16)             <= GPUSTAT_HorRes2;
   GPUSTAT(18 downto 17)   <= GPUSTAT_HorRes1;
   GPUSTAT(19)             <= GPUSTAT_VerRes;
   GPUSTAT(20)             <= GPUSTAT_PalVideoMode;
   GPUSTAT(21)             <= GPUSTAT_ColorDepth24;
   GPUSTAT(22)             <= GPUSTAT_VertInterlace;
   GPUSTAT(23)             <= GPUSTAT_DisplayDisable;
   GPUSTAT(24)             <= GPUSTAT_IRQRequest;
   GPUSTAT(25)             <= GPUSTAT_DMADataRequest;
   GPUSTAT(26)             <= GPUSTAT_ReadyRecCmd and ((not gpu_dmaRequest) or (not DMA_GPU_waiting));
   GPUSTAT(27)             <= GPUSTAT_ReadySendVRAM;
   GPUSTAT(28)             <= GPUSTAT_ReadyRecDMA;
   GPUSTAT(30 downto 29)   <= GPUSTAT_DMADirection;
   GPUSTAT(31)             <= videoout_reports.GPUSTAT_DrawingOddline;

   GPUSTAT_DMADataRequest <= '0' when (GPUSTAT_DMADirection = "00") else
                             GPUSTAT_ReadyRecDMA when (GPUSTAT_DMADirection = "01") else
                             GPUSTAT_ReadyRecDMA when (GPUSTAT_DMADirection = "10") else
                             not vram2cpu_Fifo_Empty; -- GPUSTAT_ReadySendVRAM cannot be used, because data is read earlier                

   -- video out
   irq_VBLANK             <= videoout_reports.irq_VBLANK;
   hblank_tmr             <= videoout_reports.hblank_tmr;

   -- savestates

   ss_gpu_out(0)  <= GPUREAD;                
   ss_gpu_out(1)  <= GPUSTAT;                

   ss_timing_out(4)(19)            <= videoout_ss_out.interlacedDisplayField;
   ss_timing_out(2)(18 downto 0)   <= std_logic_vector(vramRange);    
   ss_timing_out(1)(23 downto 0)   <= std_logic_vector(hDisplayRange);
   ss_timing_out(0)(19 downto 0)   <= std_logic_vector(vDisplayRange);
   ss_timing_out(4)(11 downto 0)   <= videoout_ss_out.nextHCount;
   ss_timing_out(3)(24 downto 16)  <= videoout_ss_out.vpos;      
   ss_timing_out(4)(17)            <= videoout_ss_out.inVsync;      
   ss_timing_out(4)(20)            <= videoout_ss_out.activeLineLSB;
   ss_timing_out(4)(29 downto 21)  <= videoout_ss_out.vdisp;

   process (clk1x)
      variable cmdNew                    : unsigned(7 downto 0);
   begin
      if rising_edge(clk1x) then
      
         fifoIn_reset  <= '0';
         fifoOut_reset <= '0';
         
         drawer_reset  <= '0';
         
         vblank_tmr <= videoout_reports.inVsync;

         if (reset = '1') then
               
            softReset               <= not loading_savestate;
            bus_stall               <= '0';
            
            fifoIn_reset            <= '1';
            fifoOut_reset           <= '1';
            
            vramRange               <= unsigned(ss_timing_in(2)(18 downto 0));
            hDisplayRange           <= unsigned(ss_timing_in(1)(23 downto 0)); -- x"C60260";
            vDisplayRange           <= unsigned(ss_timing_in(0)(19 downto 0)); -- x"3FC10";
      
            GPUSTAT_ReverseFlag     <= ss_gpu_in(1)(14);
            GPUSTAT_HorRes2         <= ss_gpu_in(1)(16);
            GPUSTAT_HorRes1         <= ss_gpu_in(1)(18 downto 17);
            GPUSTAT_VerRes          <= ss_gpu_in(1)(19);
            GPUSTAT_PalVideoMode    <= ss_gpu_in(1)(20); --isPal;
            GPUSTAT_ColorDepth24    <= ss_gpu_in(1)(21);
            GPUSTAT_VertInterlace   <= ss_gpu_in(1)(22);
            GPUSTAT_DisplayDisable  <= ss_gpu_in(1)(23);
            GPUSTAT_IRQRequest      <= ss_gpu_in(1)(24);
            GPUSTAT_DMADirection    <= ss_gpu_in(1)(30 downto 29);
            GPUREAD                 <= ss_gpu_in(0);       
            
            fpscountBCD_next        <= (others => '0');

         elsif (ce = '1') then
         
            bus_dataRead <= (others => '0');
            softReset    <= '0';
            
            -- bus read
            if (bus_read = '1') then
               if (bus_addr(3 downto 2) = "00") then
               
                  if (vram2cpu_Fifo_Empty = '0') then
                     bus_dataRead <= vram2cpu_Fifo_Dout;
                     GPUREAD      <= vram2cpu_Fifo_Dout;
                  else
                     bus_dataRead <= GPUREAD;
                  end if;
                  
                  if (vram2cpu_Fifo_ready = '0') then
                     bus_stall <= '1';
                  end if;
                  
               elsif (bus_addr(3 downto 2) = "01") then
                  bus_dataRead <= GPUSTAT;
               else
                  bus_dataRead <= x"FFFFFFFF";
               end if;
            end if;
            
            if (bus_stall = '1' and vram2cpu_Fifo_ready = '1') then
               bus_dataRead <= vram2cpu_Fifo_Dout;
               GPUREAD      <= vram2cpu_Fifo_Dout;
               bus_stall    <= '0';
            end if;

            -- bus write
            if (bus_write = '1') then
            
               if (bus_addr = 4) then
                  
                  case (to_integer(unsigned(bus_dataWrite(29 downto 24)))) is
                     when 16#00# => -- reset
                        softReset    <= '1';
                        fifoIn_reset <= '1'; 
                        
                     when 16#01# => -- clear fifo
                        fifoIn_reset <= '1';   
                        drawer_reset <= '1';
                        -- todo: must reset drawing units to idle? -> ridge racer triggers that in the middle of a rectangle command clearing the screen
                        -- reset CLUT cache?
                        
                     when 16#02# => -- ack irq
                        GPUSTAT_IRQRequest <= '0';
                        
                     when 16#03# => -- display on/off
                        GPUSTAT_DisplayDisable <= bus_dataWrite(0);
                        
                     when 16#04# => -- DMA direction
                        GPUSTAT_DMADirection <= bus_dataWrite(1 downto 0);
                        
                     when 16#05# => -- Start of Display area (in VRAM)
                        vramRange <= unsigned(bus_dataWrite(18 downto 1)) & '0';
                        
                     when 16#06# => -- horizontal diplay range
                        hDisplayRange <= unsigned(bus_dataWrite(23 downto 0));
                        
                     when 16#07# => -- vertical diplay range
                        vDisplayRange <= unsigned(bus_dataWrite(19 downto 0));
                        
                     when 16#08# => -- Set display mode
                        GPUSTAT_HorRes1       <= bus_dataWrite(1 downto 0);
                        GPUSTAT_VerRes        <= bus_dataWrite(2);
                        GPUSTAT_PalVideoMode  <= bus_dataWrite(3);
                        GPUSTAT_ColorDepth24  <= bus_dataWrite(4);
                        GPUSTAT_VertInterlace <= bus_dataWrite(5);
                        GPUSTAT_HorRes2       <= bus_dataWrite(6);
                        GPUSTAT_ReverseFlag   <= bus_dataWrite(7);
                        
                     when 16#09# => -- Allow texture disable
                        -- todo
                          
                     when 16#10# | 16#11# | 16#12# | 16#13# | 16#14# | 16#15# | 16#16# | 16#17# | 16#18# | 16#19# | 16#1A# | 16#1B# | 16#1C# | 16#1D# | 16#1E# | 16#1F# => -- GPUInfo
                        case (to_integer(unsigned(bus_dataWrite(2 downto 0)))) is
                           when 2 => --Get Texture Window
                              GPUREAD <= x"000" & std_logic_vector(textureWindow);
                           
                           when 3 => --Get Draw Area Top Left
                              GPUREAD <= x"000" & '0' & std_logic_vector(drawingAreaTop) & std_logic_vector(drawingAreaLeft);
                           
                           when 4 => --Get Draw Area Bottom Right
                              GPUREAD <= x"000" & '0' & std_logic_vector(drawingAreaBottom) & std_logic_vector(drawingAreaRight);
                           
                           when 5 => --Get Drawing Offset
                              GPUREAD <= x"00" & "00" & std_logic_vector(drawingOffsetY) & std_logic_vector(drawingOffsetX);
                           
                           when others => null;
                        end case;
                     
                     when others => report "GP1 Command not implemented" severity failure; 
                  end case;
               
               end if;
            
            end if;
            
            if (irq_GPU = '1') then
               GPUSTAT_IRQRequest <= '1';
            end if;
            
            -- fps counter
            if (videoout_reports.irq_VBLANK = '1') then
               fps_vramRange_last <= vramRange;
               if (vramRange /= fps_vramRange_last) then
                  if (fpscountBCD_next(3 downto 0) = x"9") then
                     fpscountBCD_next(7 downto 4) <= fpscountBCD_next(7 downto 4) + 1;
                     fpscountBCD_next(3 downto 0) <= x"0";
                  else
                     fpscountBCD_next(3 downto 0) <= fpscountBCD_next(3 downto 0) + 1;
                  end if;
               end if;
            end if;
            
            if (fps_SecondCounter = 33868799) then
               fps_SecondCounter <= 0;
               fpscountBCD       <= fpscountBCD_next;
               fpscountBCD_next  <= (others => '0');       
            else
               fps_SecondCounter <= fps_SecondCounter + 1;            
            end if;

            -- softreset
            if (softReset = '1') then
               vramRange              <= (others => '0');
               hDisplayRange          <= x"C60260";
               vDisplayRange          <= x"3FC10";
                     
               GPUSTAT_ReverseFlag    <= '0';
               GPUSTAT_HorRes2        <= '0';
               GPUSTAT_HorRes1        <= "00";
               GPUSTAT_VerRes         <= '0';
               GPUSTAT_PalVideoMode   <= isPal;
               GPUSTAT_ColorDepth24   <= '0';
               GPUSTAT_VertInterlace  <= '0';
               GPUSTAT_DisplayDisable <= '1';
               GPUSTAT_IRQRequest     <= '0';
               GPUSTAT_DMADirection   <= "00";

            end if;

         end if;
      end if;
   end process;
   
   iSyncFifo_IN: entity mem.SyncFifo
   generic map
   (
      --SIZE             => 32, -- 16 is correct, but only allows 15 entries -> use nearfull or allow this big for broken homebrew -> some games seem to exceed it also with DMA, how is that possible?
      SIZE             => 256, -- using larger fifo because of broken homebrew depending on it, shouldn't matter for official games, simply unused there and the full blockram is free anyway
      DATAWIDTH        => 32,
      NEARFULLDISTANCE => 16
   )
   port map
   ( 
      clk      => clk2x,
      reset    => fifoIn_reset,  
      Din      => fifoIn_Din,     
      Wr       => fifoIn_Wr,      
      Full     => ERRORFIFO,    
      NearFull => open,
      Dout     => fifoIn_Dout,    
      Rd       => fifoIn_Rd,      
      Empty    => fifoIn_Empty   
   );
   
   fifoIn_Rd <= '1' when (ce = '1' and (proc_idle = '1' or proc_requestFifo = '1') and fifoIn_Empty = '0' and fifoIn_Valid = '0' and (clk2xIndex = '0' or REPRODUCIBLEGPUTIMING = '0')) else '0';
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         if (reset = '1') then
            
         elsif (ce = '1') then
         
            fifoIn_Wr  <= '0';
         
            if (clk2xIndex = '1' and bus_write = '1' and bus_addr = 0) then
               fifoIn_Wr  <= '1';
               fifoIn_Din <= bus_dataWrite;
            end if;
            
            if (clk2xIndex = '1' and DMA_GPU_writeEna = '1') then
               fifoIn_Wr  <= '1';
               fifoIn_Din <= DMA_GPU_write;
            end if;
            
         end if;

      end if;
   end process;

   ss_gpu_out(2)(19 downto 0)   <= std_logic_vector(textureWindow);
   ss_gpu_out(4)(9 downto 0)    <= std_logic_vector(drawingAreaLeft);  
   ss_gpu_out(5)(9 downto 0)    <= std_logic_vector(drawingAreaRight); 
   ss_gpu_out(4)(24 downto 16)  <= std_logic_vector(drawingAreaTop);   
   ss_gpu_out(5)(24 downto 16)  <= std_logic_vector(drawingAreaBottom);
   ss_gpu_out(6)(10 downto 0)   <= std_logic_vector(drawingOffsetX);   
   ss_gpu_out(6)(26 downto 16)  <= std_logic_vector(drawingOffsetY);   
   ss_gpu_out(3)(13 downto 0)   <= std_logic_vector(drawMode);         
   ss_gpu_out(3)(16)            <= GPUSTAT_DrawPixelsMask;         
   ss_gpu_out(3)(17)            <= GPUSTAT_TextureDisable;         
   
   process (clk2x)
      variable cmdNew : unsigned(7 downto 0);
   begin
      if rising_edge(clk2x) then
      
         textureWindow_AND_X     <= not (textureWindow(4 downto 0) & "000");
         textureWindow_AND_Y     <= not (textureWindow(9 downto 5) & "000");            
         textureWindow_OR_X      <= (textureWindow(4 downto 0) and textureWindow(14 downto 10)) & "000";
         textureWindow_OR_Y      <= (textureWindow(9 downto 5) and textureWindow(19 downto 15)) & "000";
      
         errorGPU <= '0';
         if (proc_idle = '1') then
            timeout <= 0;
         elsif (timeout < 67108863) then
            timeout  <= timeout + 1;
         else
            errorGPU <= '1';
         end if;
      
         if (reset = '1') then
         
            proc_idle <= '1';
            
            textureWindow           <= unsigned(ss_gpu_in(2)(19 downto 0));   
            
            drawingAreaLeft         <= unsigned(ss_gpu_in(4)(9 downto 0)); 
            drawingAreaRight        <= unsigned(ss_gpu_in(5)(9 downto 0)); 
            drawingAreaTop          <= unsigned(ss_gpu_in(4)(24 downto 16)); 
            drawingAreaBottom       <= unsigned(ss_gpu_in(5)(24 downto 16)); 
            drawingOffsetX          <= signed(ss_gpu_in(6)(10 downto 0)); 
            drawingOffsetY          <= signed(ss_gpu_in(6)(26 downto 16)); 
            
            drawMode                <= unsigned(ss_gpu_in(3)(13 downto 0));  
            
            --GPUSTAT_DrawPixelsMask  <= ss_gpu_in(3)(16);
            --GPUSTAT_TextureDisable  <= ss_gpu_in(3)(17);
            
            GPUSTAT_TextPageX       <= ss_gpu_in(1)(3 downto 0);
            GPUSTAT_TextPageY       <= ss_gpu_in(1)(4);
            GPUSTAT_Transparency    <= ss_gpu_in(1)(6 downto 5);
            GPUSTAT_TextPageColors  <= ss_gpu_in(1)(8 downto 7);
            GPUSTAT_Dither          <= ss_gpu_in(1)(9);
            GPUSTAT_DrawToDisplay   <= ss_gpu_in(1)(10);
            GPUSTAT_SetMask         <= ss_gpu_in(1)(11);
            GPUSTAT_DrawPixelsMask  <= ss_gpu_in(1)(12);
            GPUSTAT_TextureDisable  <= ss_gpu_in(1)(15);
            GPUSTAT_ReadyRecCmd     <= '1'; --ss_gpu_in(1)(26); -- in savestate should never be busy
            GPUSTAT_ReadyRecDMA     <= '1'; --ss_gpu_in(1)(28);
            
            fifoIn_Valid            <= '0';
            
         elsif (ce = '1') then
         
            fifoIn_Valid <= fifoIn_Rd and not fifoIn_reset;
            
            pipeline_clearCache <= '0';
         
            if (poly_drawModeNew = '1') then
               drawMode(8 downto 0) <= poly_drawModeRec(8 downto 0);
               drawMode(11)         <= poly_drawModeRec(11);
            end if;
            
            if (clk2xIndex = '1') then
               irq_GPU <= '0';
            end if;
         
            if (fifoIn_Valid = '1' and proc_idle = '1') then
               
               cmdNew := unsigned(fifoIn_Dout(31 downto 24));
               
               if ((cmdNew >= 16#20# and cmdNew <=16#DF#) or cmdNew = 16#02#) then
                  
                  proc_idle           <= '0';
                  GPUSTAT_ReadyRecCmd <= '0';
                  
               elsif (cmdNew = 16#01#) then -- clear cache
                  pipeline_clearCache <= '1';
                  
               elsif (cmdNew = 16#1F#) then -- irq request
                  if (GPUSTAT_IRQRequest = '0') then
                     irq_GPU <= '1';
                  end if;
                  
               elsif (cmdNew = 16#E1#) then -- Draw Mode setting
                  GPUSTAT_TextPageX      <= fifoIn_Dout(3 downto 0);
                  GPUSTAT_TextPageY      <= fifoIn_Dout(4);
                  GPUSTAT_Transparency   <= fifoIn_Dout(6 downto 5);
                  GPUSTAT_TextPageColors <= fifoIn_Dout(8 downto 7);
                  GPUSTAT_Dither         <= fifoIn_Dout(9);
                  GPUSTAT_DrawToDisplay  <= fifoIn_Dout(10);
                  GPUSTAT_TextureDisable <= fifoIn_Dout(11);
                  drawMode               <= unsigned(fifoIn_Dout(13 downto 0));
                  
               elsif (cmdNew = 16#E2#) then -- Set Texture window
                  textureWindow <= unsigned(fifoIn_Dout(19 downto 0));
                  
               elsif (cmdNew = 16#E3#) then -- Set Drawing Area top left (X1,Y1)
                  drawingAreaLeft <= unsigned(fifoIn_Dout(9 downto 0));
                  drawingAreaTop  <= unsigned(fifoIn_Dout(18 downto 10));
                  
               elsif (cmdNew = 16#E4#) then -- Set Drawing Area bottom right (X2,Y2)
                  drawingAreaRight  <= unsigned(fifoIn_Dout(9 downto 0));
                  drawingAreaBottom <= unsigned(fifoIn_Dout(18 downto 10));
                  
               elsif (cmdNew = 16#E5#) then -- Set Drawing Offset (X,Y)
                  drawingOffsetX <= signed(fifoIn_Dout(10 downto 0));
                  drawingOffsetY <= signed(fifoIn_Dout(21 downto 11));
                  
               elsif (cmdNew = 16#E6#) then -- Mask Bit Setting
                  GPUSTAT_SetMask        <= fifoIn_Dout(0);
                  GPUSTAT_DrawPixelsMask <= fifoIn_Dout(1);
                  
               end if;
            
            
            end if;

            GPUSTAT_ReadyRecDMA <= fifoIn_Empty;
            
            if (proc_done = '1') then
-- synthesis translate_off
               export_gobj          <= export_gobj + 1;
-- synthesis translate_on
               proc_idle            <= '1';
               GPUSTAT_ReadyRecCmd  <= '1';
            end if;
            
            if (softReset = '1') then
               proc_idle              <= '1';
               drawMode               <= (others => '0');
               GPUSTAT_TextPageX      <= "0000";
               GPUSTAT_TextPageY      <= '0';
               GPUSTAT_Transparency   <= "00";
               GPUSTAT_TextPageColors <= "00";
               GPUSTAT_Dither         <= '0';
               GPUSTAT_DrawToDisplay  <= '0';
               GPUSTAT_SetMask        <= '0';
               GPUSTAT_DrawPixelsMask <= '0';
               GPUSTAT_TextureDisable <= '0';
               GPUSTAT_ReadyRecCmd    <= '1';
               GPUSTAT_ReadyRecDMA    <= '1';
            end if;
            
         end if;
         
      end if;
   end process; 
   
   proc_done        <= vramFill_done        or cpu2vram_done        or vram2vram_done        or vram2cpu_done        or line_done        or rect_done        or poly_done       ;
   --proc_CmdDone     <= vramFill_CmdDone     or cpu2vram_CmdDone     or vram2vram_CmdDone     or vram2cpu_CmdDone     or line_CmdDone     or rect_CmdDone     or poly_CmdDone    ;
   proc_requestFifo <= vramFill_requestFifo or cpu2vram_requestFifo or vram2vram_requestFifo or vram2cpu_requestFifo or line_requestFifo or rect_requestFifo or poly_requestFifo;
   
   pixelStall <= fifoOut_NearFull;
   
   interlacedDrawing <= GPUSTAT_VertInterlace and GPUSTAT_VerRes and not GPUSTAT_DrawToDisplay;
   
   -- workers
   igpu_fillVram : entity work.gpu_fillVram
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => softreset or SS_reset, 

      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,      
      
      interlacedDrawing    => interlacedDrawing,
      activeLineLSB        => videoout_reports.activeLineLSB,    
      
      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => vramFill_requestFifo,
      done                 => vramFill_done,
      --CmdDone              => vramFill_CmdDone,
      
      pixelStall           => pixelStall,
      pixelColor           => vramFill_pixelColor,
      pixelAddr            => vramFill_pixelAddr, 
      pixelWrite           => vramFill_pixelWrite
   );
   
   igpu_cpu2vram : entity work.gpu_cpu2vram
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => softreset or SS_reset,    
      drawer_reset         => drawer_reset,
      
      DrawPixelsMask       => GPUSTAT_DrawPixelsMask,
      SetMask              => GPUSTAT_SetMask,
      errorMASK            => errorMASK,
      
      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => cpu2vram_requestFifo,
      done                 => cpu2vram_done,
      --CmdDone              => cpu2vram_CmdDone,
      
      pixelStall           => pixelStall,
      pixelColor           => cpu2vram_pixelColor,
      pixelAddr            => cpu2vram_pixelAddr, 
      pixelWrite           => cpu2vram_pixelWrite
   );
   
   igpu_vram2vram : entity work.gpu_vram2vram
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => softreset or SS_reset,     
      
      DrawPixelsMask       => GPUSTAT_DrawPixelsMask,
      SetMask              => GPUSTAT_SetMask,
      
      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,  
      
      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => vram2vram_requestFifo,
      done                 => vram2vram_done,
      --CmdDone              => vram2vram_CmdDone,
      
      requestVRAMEnable    => vram2vram_reqVRAMEnable,
      requestVRAMXPos      => vram2vram_reqVRAMXPos,  
      requestVRAMYPos      => vram2vram_reqVRAMYPos,  
      requestVRAMSize      => vram2vram_reqVRAMSize,  
      requestVRAMIdle      => reqVRAMIdle,
      requestVRAMDone      => reqVRAMDone,
      
      vramLineEna          => vram2vram_vramLineEna, 
      vramLineAddr         => vram2vram_vramLineAddr,
      vramLineData         => vramLineData,
      
      pixelEmpty           => fifoOut_Empty,
      pixelStall           => pixelStall,
      pixelColor           => vram2vram_pixelColor,
      pixelAddr            => vram2vram_pixelAddr, 
      pixelWrite           => vram2vram_pixelWrite
   );
   
   vram2cpu_Fifo_Rd <= '1' when (vram2cpu_Fifo_Empty = '0' and clk2xIndex = '0' and DMA_GPU_readEna = '1') else
                       '1' when (vram2cpu_Fifo_Empty = '0' and clk2xIndex = '0' and bus_read = '1' and bus_addr(3 downto 2) = "00") else
                       '1' when (vram2cpu_Fifo_Empty = '0' and clk2xIndex = '0' and bus_stall = '1') else
                       '0';
   
   DMA_GPU_read <= vram2cpu_Fifo_Dout when (vram2cpu_Fifo_Empty = '0') else (others => '1');
   
   GPUSTAT_ReadySendVRAM <= not vram2cpu_Fifo_Empty;
   
   igpu_vram2cpu : entity work.gpu_vram2cpu
   port map
   (
      clk2x                => clk2x,     
      ce                   => ce,        
      reset                => softreset or SS_reset,   
      drawer_reset         => drawer_reset,

      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING, 

      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => vram2cpu_requestFifo,
      done                 => vram2cpu_done,
      --CmdDone              => vram2cpu_CmdDone,
      
      requestVRAMEnable    => vram2cpu_reqVRAMEnable,
      requestVRAMXPos      => vram2cpu_reqVRAMXPos,  
      requestVRAMYPos      => vram2cpu_reqVRAMYPos,  
      requestVRAMSize      => vram2cpu_reqVRAMSize,  
      requestVRAMIdle      => reqVRAMIdle,
      requestVRAMDone      => reqVRAMDone,
      
      vramLineEna          => vram2cpu_vramLineEna, 
      vramLineAddr         => vram2cpu_vramLineAddr,
      vramLineData         => vramLineData,
      
      Fifo_Dout            => vram2cpu_Fifo_Dout, 
      Fifo_Rd              => vram2cpu_Fifo_Rd,   
      Fifo_Empty           => vram2cpu_Fifo_Empty,
      Fifo_ready           => vram2cpu_Fifo_ready
   );
   
   igpu_line : entity work.gpu_line
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => softreset or SS_reset,

      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,

      error                => errorLINE,
      
      DrawPixelsMask       => GPUSTAT_DrawPixelsMask,
      interlacedDrawing    => interlacedDrawing,
      activeLineLSB        => videoout_reports.activeLineLSB,    
      drawingOffsetX       => drawingOffsetX,   
      drawingOffsetY       => drawingOffsetY,   
      drawingAreaLeft      => drawingAreaLeft,  
      drawingAreaRight     => drawingAreaRight, 
      drawingAreaTop       => drawingAreaTop,   
      drawingAreaBottom    => drawingAreaBottom,
      
      div1                 => line_div(0), 
      div2                 => line_div(1), 
      div3                 => line_div(2), 
      div4                 => line_div(3), 
      div5                 => line_div(4), 
      div6                 => line_div(5), 
      
      pipeline_busy        => pipeline_busy,
      pipeline_stall       => pipeline_stall,      
      pipeline_new         => line_pipeline_new,        
      pipeline_transparent => line_pipeline_transparent,
      pipeline_x           => line_pipeline_x,          
      pipeline_y           => line_pipeline_y,          
      pipeline_cr          => line_pipeline_cr,         
      pipeline_cg          => line_pipeline_cg,         
      pipeline_cb          => line_pipeline_cb,         
      
      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => line_requestFifo,
      done                 => line_done,
      --CmdDone              => line_CmdDone,
      
      requestVRAMEnable    => line_reqVRAMEnable,
      requestVRAMXPos      => line_reqVRAMXPos,  
      requestVRAMYPos      => line_reqVRAMYPos,  
      requestVRAMSize      => line_reqVRAMSize,  
      requestVRAMIdle      => reqVRAMIdle,
      requestVRAMDone      => reqVRAMDone,
      
      vramLineEna          => line_vramLineEna, 
      vramLineAddr         => line_vramLineAddr
   );
   
   igpu_rect : entity work.gpu_rect
   port map
   (
      clk2x                => clk2x,  
      clk2xIndex           => clk2xIndex,      
      ce                   => ce,        
      reset                => softreset or SS_reset,     
      
      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,
      
      error                => errorRECT,
      
      DrawPixelsMask       => GPUSTAT_DrawPixelsMask,
      interlacedDrawing    => interlacedDrawing,
      activeLineLSB        => videoout_reports.activeLineLSB,    
      drawingOffsetX       => drawingOffsetX,   
      drawingOffsetY       => drawingOffsetY,   
      drawingAreaLeft      => drawingAreaLeft,  
      drawingAreaRight     => drawingAreaRight, 
      drawingAreaTop       => drawingAreaTop,   
      drawingAreaBottom    => drawingAreaBottom,
      
      pipeline_busy        => pipeline_busy,
      pipeline_stall       => pipeline_stall,      
      pipeline_new         => rect_pipeline_new,        
      pipeline_texture     => rect_pipeline_texture,
      pipeline_transparent => rect_pipeline_transparent,
      pipeline_rawTexture  => rect_pipeline_rawTexture,
      pipeline_x           => rect_pipeline_x,          
      pipeline_y           => rect_pipeline_y,          
      pipeline_cr          => rect_pipeline_cr,         
      pipeline_cg          => rect_pipeline_cg,         
      pipeline_cb          => rect_pipeline_cb,         
      pipeline_u           => rect_pipeline_u,         
      pipeline_v           => rect_pipeline_v,         
      
      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => rect_requestFifo,
      done                 => rect_done,
      --CmdDone              => rect_CmdDone,
      
      requestVRAMEnable    => rect_reqVRAMEnable,
      requestVRAMXPos      => rect_reqVRAMXPos,  
      requestVRAMYPos      => rect_reqVRAMYPos,  
      requestVRAMSize      => rect_reqVRAMSize,  
      requestVRAMIdle      => reqVRAMIdle,
      requestVRAMDone      => reqVRAMDone,
      
      textPalNew           => rect_textPalNew,
      textPalX             => rect_textPalX,  
      textPalY             => rect_textPalY,  
      
      vramLineEna          => rect_vramLineEna, 
      vramLineAddr         => rect_vramLineAddr
   );
   
   igpu_poly : entity work.gpu_poly
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => softreset or SS_reset,   

      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,    
      textureFilter        => textureFilter,

      error                => errorPOLY,
      
      DrawPixelsMask       => GPUSTAT_DrawPixelsMask,
      interlacedDrawing    => interlacedDrawing,
      activeLineLSB        => videoout_reports.activeLineLSB,    
      drawingOffsetX       => drawingOffsetX,   
      drawingOffsetY       => drawingOffsetY,   
      drawingAreaLeft      => drawingAreaLeft,  
      drawingAreaRight     => drawingAreaRight, 
      drawingAreaTop       => drawingAreaTop,   
      drawingAreaBottom    => drawingAreaBottom,
      
      drawModeRec          => poly_drawModeRec,
      drawModeNew          => poly_drawModeNew,
      drawmode_dithering   => drawMode(9),
      
      div1                 => poly_div(0), 
      div2                 => poly_div(1), 
      div3                 => poly_div(2), 
      div4                 => poly_div(3), 
      div5                 => poly_div(4), 
      div6                 => poly_div(5), 
      
      pipeline_busy        => pipeline_busy,
      pipeline_stall       => pipeline_stall,      
      pipeline_new         => poly_pipeline_new,        
      pipeline_texture     => poly_pipeline_texture,
      pipeline_transparent => poly_pipeline_transparent,
      pipeline_rawTexture  => poly_pipeline_rawTexture,
      pipeline_dithering   => poly_pipeline_dithering,
      pipeline_x           => poly_pipeline_x,          
      pipeline_y           => poly_pipeline_y,          
      pipeline_cr          => poly_pipeline_cr,         
      pipeline_cg          => poly_pipeline_cg,         
      pipeline_cb          => poly_pipeline_cb,         
      pipeline_u           => poly_pipeline_u,         
      pipeline_v           => poly_pipeline_v,         
      
      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => poly_requestFifo,
      done                 => poly_done,
      --CmdDone              => poly_CmdDone,
      
      requestVRAMEnable    => poly_reqVRAMEnable,
      requestVRAMXPos      => poly_reqVRAMXPos,  
      requestVRAMYPos      => poly_reqVRAMYPos,  
      requestVRAMSize      => poly_reqVRAMSize,  
      requestVRAMIdle      => reqVRAMIdle,
      requestVRAMDone      => reqVRAMDone,
      
      textPalNew           => poly_textPalNew,
      textPalX             => poly_textPalX,  
      textPalY             => poly_textPalY,  
      
      vramLineEna          => poly_vramLineEna, 
      vramLineAddr         => poly_vramLineAddr
   );
   
   pipeline_new         <= line_pipeline_new         or rect_pipeline_new         or poly_pipeline_new        ;       
   pipeline_texture     <= '0'                       or rect_pipeline_texture     or poly_pipeline_texture    ;
   pipeline_transparent <= line_pipeline_transparent or rect_pipeline_transparent or poly_pipeline_transparent;          
   pipeline_rawTexture  <= '0'                       or rect_pipeline_rawTexture  or poly_pipeline_rawTexture ; 
   pipeline_dithering   <= (line_pipeline_new        or '0'                       or poly_pipeline_dithering  ) and drawMode(9) and (not ditherOff);
   pipeline_x           <= line_pipeline_x           or rect_pipeline_x           or poly_pipeline_x          ;       
   pipeline_y           <= line_pipeline_y           or rect_pipeline_y           or poly_pipeline_y          ;     
   pipeline_cr          <= line_pipeline_cr          or rect_pipeline_cr          or poly_pipeline_cr         ;
   pipeline_cg          <= line_pipeline_cg          or rect_pipeline_cg          or poly_pipeline_cg         ;
   pipeline_cb          <= line_pipeline_cb          or rect_pipeline_cb          or poly_pipeline_cb         ;
   
   pipeline_u           <= ((rect_pipeline_u or poly_pipeline_u) and textureWindow_AND_X) or textureWindow_OR_X;
   pipeline_v           <= ((rect_pipeline_v or poly_pipeline_v) and textureWindow_AND_Y) or textureWindow_OR_Y;
   
   pipeline_textPalNew  <= rect_textPalNew or poly_textPalNew;
   pipeline_textPalX    <= rect_textPalX   or poly_textPalX  ;
   pipeline_textPalY    <= rect_textPalY   or poly_textPalY  ;
   
   igpu_pixelpipeline : entity work.gpu_pixelpipeline
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => softreset or SS_reset,

      noTexture            => noTexture,      

      drawMode_in          => drawMode,
      DrawPixelsMask_in    => GPUSTAT_DrawPixelsMask,
      SetMask_in           => GPUSTAT_SetMask,
      
      clearCache           => pipeline_clearCache,
      
      pipeline_busy        => pipeline_busy,
      pipeline_stall       => pipeline_stall,      
      pipeline_new         => pipeline_new,        
      pipeline_texture     => pipeline_texture,    
      pipeline_transparent => pipeline_transparent,
      pipeline_rawTexture  => pipeline_rawTexture, 
      pipeline_dithering   => pipeline_dithering,
      pipeline_x           => pipeline_x,          
      pipeline_y           => pipeline_y,          
      pipeline_cr          => pipeline_cr,         
      pipeline_cg          => pipeline_cg,         
      pipeline_cb          => pipeline_cb,         
      pipeline_u           => pipeline_u,          
      pipeline_v           => pipeline_v,          
      
      requestVRAMEnable    => pipeline_reqVRAMEnable,
      requestVRAMXPos      => pipeline_reqVRAMXPos,  
      requestVRAMYPos      => pipeline_reqVRAMYPos,  
      requestVRAMSize      => pipeline_reqVRAMSize,  
      requestVRAMIdle      => reqVRAMIdle,
      requestVRAMDone      => reqVRAMDone,
      vram_DOUT            => vram_DOUT,      
      vram_DOUT_READY      => vram_DOUT_READY,
      
      vramLineData         => vramLineData,
      
      textPalInNew         => pipeline_textPalNew,
      textPalInX           => pipeline_textPalX,  
      textPalInY           => pipeline_textPalY,  
      
      pixelStall           => pixelStall,
      pixelColor           => pipeline_pixelColor,
      pixelAddr            => pipeline_pixelAddr, 
      pixelWrite           => pipeline_pixelWrite
   );
   
   gdividers: for i in 0 to 5 generate
   begin
   
      div_array(i).start    <= line_div(i).start    or poly_div(i).start;
      div_array(i).dividend <= line_div(i).dividend or poly_div(i).dividend;
      div_array(i).divisor  <= line_div(i).divisor  or poly_div(i).divisor;
      
      line_div(i).done      <= div_array(i).done;     
      line_div(i).quotient  <= div_array(i).quotient; 
      line_div(i).remainder <= div_array(i).remainder;
      
      poly_div(i).done      <= div_array(i).done;     
      poly_div(i).quotient  <= div_array(i).quotient; 
      poly_div(i).remainder <= div_array(i).remainder;
      
      idivider : entity work.divider
      port map
      (
         clk       => clk2x,      
         start     => div_array(i).start,
         done      => div_array(i).done,          
         dividend  => div_array(i).dividend, 
         divisor   => div_array(i).divisor,  
         quotient  => div_array(i).quotient, 
         remainder => div_array(i).remainder
      );
   end generate;
   
   pixelColor <= cpu2vram_pixelColor or vram2vram_pixelColor or pipeline_pixelColor;
   pixelAddr  <= cpu2vram_pixelAddr  or vram2vram_pixelAddr  or pipeline_pixelAddr ;
   pixelWrite <= cpu2vram_pixelWrite or vram2vram_pixelWrite or pipeline_pixelWrite;
   
   -- pixel writing fifo
   iSyncFifo_OUT: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 256,
      DATAWIDTH        => 85,  -- 64bit data, 17 bit address + 4bit word enable
      NEARFULLDISTANCE => 250
   )
   port map
   ( 
      clk      => clk2x,
      reset    => fifoOut_reset,  
      Din      => fifoOut_Din,     
      Wr       => fifoOut_Wr,      
      Full     => open,    
      NearFull => fifoOut_NearFull,
      Dout     => fifoOut_Dout,    
      Rd       => fifoOut_Rd,      
      Empty    => fifoOut_Empty   
   );
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         fifoOut_Wr  <= '0';
         fifoOut_Din <= pixel64wordEna & pixel64Addr & pixel64data;
      
         if (reset = '1') then
            
            pixel64filled <= '0';
            
         elsif (ce = '1') then
         
            if (vramFill_pixelWrite = '1') then
            
               fifoOut_Wr    <= '1';
               fifoOut_Din   <= "1111" & std_logic_vector(vramFill_pixelAddr(19 downto 3)) & vramFill_pixelColor & vramFill_pixelColor & vramFill_pixelColor & vramFill_pixelColor;
               pixel64filled <= '0';
         
            elsif (pixelWrite = '1') then
            
               pixel64timeout <= 15;
            
               if (pixel64filled = '0' or pixelAddr(19 downto 3) /= unsigned(pixel64Addr)) then
               
                  fifoOut_Wr <= pixel64filled;
               
                  pixel64Addr <= std_logic_vector(pixelAddr(19 downto 3));
                  case (pixelAddr(2 downto 1)) is
                     when "00" => pixel64data(15 downto  0) <= pixelColor; pixel64wordEna <= "0001";
                     when "01" => pixel64data(31 downto 16) <= pixelColor; pixel64wordEna <= "0010";
                     when "10" => pixel64data(47 downto 32) <= pixelColor; pixel64wordEna <= "0100";
                     when "11" => pixel64data(63 downto 48) <= pixelColor; pixel64wordEna <= "1000";
                     when others => null;
                  end case;
                  
                  pixel64filled <= '1';
               
               else
                  
                  case (pixelAddr(2 downto 1)) is
                     when "00" => pixel64data(15 downto  0) <= pixelColor; pixel64wordEna(0) <= '1';
                     when "01" => pixel64data(31 downto 16) <= pixelColor; pixel64wordEna(1) <= '1';
                     when "10" => pixel64data(47 downto 32) <= pixelColor; pixel64wordEna(2) <= '1';
                     when "11" => pixel64data(63 downto 48) <= pixelColor; pixel64wordEna(3) <= '1';
                     when others => null;
                  end case;

               end if;
            
            elsif (pixel64timeout > 0) then
            
               pixel64timeout <= pixel64timeout - 1;
               if (pixel64timeout = 1) then
                  pixel64filled  <= '0';
                  fifoOut_Wr     <= '1';
               end if;
               
            end if;
            
         end if;

      end if;
   end process;
   
   fifoOut_Rd <= '1' when (ce = '1' and vramState = IDLE and vram_BUSY = '0' and fifoOut_Empty = '0' and reqVRAMEnable = '0' and vram_pause = '0') else '0';
   
   VRAMIdle    <= '1' when (vramState = IDLE and (vram_WE = '0' or vram_BUSY = '0')) else '0';
   reqVRAMIdle <= VRAMIdle and (not videoout_reqVRAMEnable) and (not vram_pause);
   
   reqVRAMEnable <= vram2vram_reqVRAMEnable or vram2cpu_reqVRAMEnable or line_reqVRAMEnable or rect_reqVRAMEnable or poly_reqVRAMEnable or pipeline_reqVRAMEnable or videoout_reqVRAMEnable;
   reqVRAMXPos   <= vram2vram_reqVRAMXPos   or vram2cpu_reqVRAMXPos   or line_reqVRAMXPos   or rect_reqVRAMXPos   or poly_reqVRAMXPos   or pipeline_reqVRAMXPos   or videoout_reqVRAMXPos  ;  
   reqVRAMYPos   <= vram2vram_reqVRAMYPos   or vram2cpu_reqVRAMYPos   or line_reqVRAMYPos   or rect_reqVRAMYPos   or poly_reqVRAMYPos   or pipeline_reqVRAMYPos   or videoout_reqVRAMYPos  ;  
   reqVRAMSize   <= vram2vram_reqVRAMSize   or vram2cpu_reqVRAMSize   or line_reqVRAMSize   or rect_reqVRAMSize   or poly_reqVRAMSize   or pipeline_reqVRAMSize   or videoout_reqVRAMSize  ;  
   
   vramLineAddr  <= vram2vram_vramLineAddr when vram2vram_vramLineEna else 
                    vram2cpu_vramLineAddr when vram2cpu_vramLineEna else 
                    line_vramLineAddr  when line_vramLineEna else
                    rect_vramLineAddr  when rect_vramLineEna else
                    poly_vramLineAddr  when poly_vramLineEna else
                    (others => '0');
   
   -- vram access
   process (clk2x)
      variable reqVRAMSizeRounded : unsigned(10 downto 0);
   begin
      if rising_edge(clk2x) then
      
         if (vram_BUSY = '0') then
            vram_WE <= '0';
            vram_RD <= '0';
         end if;
         
         vram_paused <= '0';
         if (VRAMIdle = '1' and vram_pause = '1' and vram_WE = '0') then
            if (vram_pauseCnt = 3) then
               vram_paused <= '1';
            else
               vram_pauseCnt <= vram_pauseCnt + 1;
            end if;
         else
            vram_pauseCnt <= 0;
         end if;
         
         if (reset = '1') then
            
            vramState   <= IDLE;
            reqVRAMDone <= '0';
            
         elsif (ce = '1') then
         
            reqVRAMDone <= '0';
         
            case (vramState) is
               when IDLE =>
                  if ((vram_WE = '0' or vram_BUSY = '0') and vram_pause = '0') then
                     if (reqVRAMEnable = '1') then
                        reqVRAMStore <= (not pipeline_reqVRAMEnable) and (not videoout_reqVRAMEnable);
                        reqVRAMSizeRounded := reqVRAMSize;
                        if (reqVRAMSize(1 downto 0) /= "00") then -- round up read size to full 4*16bit
                           reqVRAMSizeRounded(10 downto 2) := reqVRAMSizeRounded(10 downto 2) + 1;
                        end if;
                        if (reqVRAMXPos(1 downto 0) /= "00" and ((to_integer(reqVRAMXPos(1 downto 0)) + to_integer(reqVRAMSize) > 4))) then 
                           reqVRAMSizeRounded(10 downto 2) := reqVRAMSizeRounded(10 downto 2) + 1;
                        end if;
                        vramState     <= READVRAM;
                        vram_ADDR     <= std_logic_vector(reqVRAMYPos) & std_logic_vector(reqVRAMXPos(9 downto 2)) & "000";
                        vram_RD       <= '1';
                        reqVRAMaddr   <= reqVRAMXPos(9 downto 2);
                        if (reqVRAMSizeRounded > 512) then
                           vram_BURSTCNT <= x"80";
                           reqVRAMremain <= x"80" - 1;
                           reqVRAMnext   <= resize((reqVRAMSizeRounded - 512) / 4, 8);
                        else
                           vram_BURSTCNT <= std_logic_vector(reqVRAMSizeRounded(9 downto 2));
                           reqVRAMremain <= reqVRAMSizeRounded(9 downto 2) - 1;
                           reqVRAMnext   <= (others => '0');
                        end if;
                        reqVRAMwrap <= (others => '0');
                        if (vram2vram_reqVRAMEnable = '1' or vram2cpu_reqVRAMEnable = '1') then
                           if (reqVRAMXPos + reqVRAMSizeRounded > 1024) then
                              reqVRAMwrap <= resize(((reqVRAMXPos + reqVRAMSizeRounded) - 1024) / 4, 8);
                           end if;
                        end if;
                     elsif (fifoOut_Empty = '0') then
                        vram_WE       <= '1';
                        vram_ADDR     <= fifoOut_Dout(80 downto 64) & "000";
                        vram_BE       <= fifoOut_Dout(84) & fifoOut_Dout(84) & fifoOut_Dout(83) & fifoOut_Dout(83) & fifoOut_Dout(82) & fifoOut_Dout(82) & fifoOut_Dout(81) & fifoOut_Dout(81);
                        vram_DIN      <= fifoOut_Dout(63 downto 0);
                        vram_BURSTCNT <= x"01";
                     end if;
                  end if;
                  
               when READVRAM =>
                  if (vram_DOUT_READY = '1') then
                     reqVRAMaddr <= reqVRAMaddr + 1;
                     if (reqVRAMremain > 0) then
                        reqVRAMremain <= reqVRAMremain - 1;
                     else
                        if (reqVRAMnext > 0) then
                           vram_ADDR(10) <= '1';
                           vram_RD       <= '1';
                           vram_BURSTCNT <= std_logic_vector(reqVRAMnext);
                           reqVRAMnext   <= (others => '0');
                           reqVRAMremain <= (reqVRAMnext - 1);
                        elsif (reqVRAMwrap > 0) then
                           vram_ADDR(10 downto 0) <= (others => '0');
                           vram_RD       <= '1';
                           vram_BURSTCNT <= std_logic_vector(reqVRAMwrap);
                           reqVRAMwrap   <= (others => '0');
                           reqVRAMaddr   <= (others => '0');
                           reqVRAMremain <= (reqVRAMwrap - 1);
                           if (reqVRAMwrap > 128) then
                              vram_BURSTCNT <= x"80";
                              reqVRAMremain <= x"80" - 1;
                              reqVRAMnext   <= reqVRAMwrap - 128;
                           end if;
                        else
                           vramState   <= IDLE;
                           reqVRAMDone <= '1';
                        end if;
                     end if;
                  end if;
            
            end case;
            
         end if;

      end if;
   end process;
   
   ilineram: entity work.dpram_dif
   generic map 
   ( 
      addr_width_a  => 8,
      data_width_a  => 64,
      addr_width_b  => 10,
      data_width_b  => 16
   )
   port map
   (
      clock_a     => clk2x,
      address_a   => std_logic_vector(reqVRAMaddr),
      data_a      => vram_DOUT,
      wren_a      => (vram_DOUT_READY and reqVRAMStore),
      
      clock_b     => clk2x,
      address_b   => std_logic_vector(vramLineAddr),
      data_b      => x"0000",
      wren_b      => '0',
      q_b         => vramLineData
   );
   
--##############################################################
--############################### video out
--##############################################################
   
   videoout_settings.GPUSTAT_VerRes          <= GPUSTAT_VerRes;
   videoout_settings.GPUSTAT_PalVideoMode    <= GPUSTAT_PalVideoMode;
   videoout_settings.GPUSTAT_VertInterlace   <= GPUSTAT_VertInterlace;
   videoout_settings.GPUSTAT_HorRes2         <= GPUSTAT_HorRes2;
   videoout_settings.GPUSTAT_HorRes1         <= GPUSTAT_HorRes1;
   videoout_settings.GPUSTAT_ColorDepth24    <= GPUSTAT_ColorDepth24;
   videoout_settings.GPUSTAT_DisplayDisable  <= GPUSTAT_DisplayDisable;
   videoout_settings.vramRange               <= vramRange;
   videoout_settings.hDisplayRange           <= hDisplayRange;
   videoout_settings.vDisplayRange           <= vDisplayRange;
   videoout_settings.pal60                   <= pal60;
   videoout_settings.syncInterlace           <= syncInterlace;
   
   videoout_ss_in.interlacedDisplayField  <= ss_timing_in(4)(19);
   videoout_ss_in.nextHCount              <= ss_timing_in(4)(11 downto 0);
   videoout_ss_in.vpos                    <= ss_timing_in(3)(24 downto 16);
   videoout_ss_in.vdisp                   <= ss_timing_in(4)(29 downto 21);
   videoout_ss_in.inVsync                 <= ss_timing_in(4)(17);
   videoout_ss_in.activeLineLSB           <= ss_timing_in(4)(20);
   videoout_ss_in.GPUSTAT_InterlaceField  <= ss_gpu_in(1)(13);
   videoout_ss_in.GPUSTAT_DrawingOddline  <= ss_gpu_in(1)(31);
   
   igpu_videoout : entity work.gpu_videoout
   port map
   (
      clk1x                      => clk1x,
      clk2x                      => clk2x,
      clkvid                     => clkvid,
      ce                         => ce,   
      reset                      => reset,
      softReset                  => softReset,
               
      allowunpause               => allowunpause,
               
      videoout_settings          => videoout_settings,
      videoout_reports           => videoout_reports,
         
      videoout_on                => videoout_on,
      syncVideoOut               => syncVideoOut,
            
      debugmodeOn                => debugmodeOn,
            
      fpscountOn                 => fpscountOn,
      fpscountBCD                => fpscountBCD,
   
      Gun1CrosshairOn            => Gun1CrosshairOn,
      Gun1X                      => Gun1X,
      Gun1Y_scanlines            => Gun1Y_scanlines,
      Gun1IRQ10                  => Gun1IRQ10,
   
      Gun2CrosshairOn            => Gun2CrosshairOn,
      Gun2X                      => Gun2X,
      Gun2Y_scanlines            => Gun2Y_scanlines,
      Gun2IRQ10                  => Gun2IRQ10,
            
      cdSlow                     => cdSlow,      
                                 
      errorOn                    => errorOn,  
      errorEna                   => errorEna, 
      errorCode                  => errorCode, 
                                 
      requestVRAMEnable          => videoout_reqVRAMEnable,
      requestVRAMXPos            => videoout_reqVRAMXPos,  
      requestVRAMYPos            => videoout_reqVRAMYPos,  
      requestVRAMSize            => videoout_reqVRAMSize,  
      requestVRAMIdle            => VRAMIdle and (not vram_pause),
      requestVRAMDone            => reqVRAMDone,
                                 
      vram_DOUT                  => vram_DOUT,      
      vram_DOUT_READY            => vram_DOUT_READY,
          
      videoout_out               => videoout_out,
      
      videoout_ss_in             => videoout_ss_in,
      videoout_ss_out            => videoout_ss_out
   );
   
   video_hsync          <= videoout_out.hsync;         
   video_vsync          <= videoout_out.vsync;         
   video_hblank         <= videoout_out.hblank;        
   video_vblank         <= videoout_out.vblank;        
   video_DisplayWidth   <= videoout_out.DisplayWidth;  
   video_DisplayHeight  <= videoout_out.DisplayHeight; 
   video_DisplayOffsetX <= videoout_out.DisplayOffsetX;
   video_DisplayOffsetY <= videoout_out.DisplayOffsetY;
   video_ce             <= videoout_out.ce;            
   video_interlace      <= videoout_out.interlace;     
   video_r              <= videoout_out.r;             
   video_g              <= videoout_out.g;             
   video_b              <= videoout_out.b;             
   video_isPal          <= videoout_out.isPal;
   video_hResMode       <= videoout_out.hResMode;
   
--##############################################################
--############################### savestates
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (SS_reset = '1') then
         
            for i in 0 to 7 loop
               ss_gpu_in(i)    <= (others => '0');
               ss_timing_in(i) <= (others => '0');
            end loop;
            
            ss_timing_in(0) <= x"0003FC10"; -- vDisplayRange
            ss_timing_in(1) <= x"00C60260"; -- hDisplayRange
            
         else
            if (SS_wren_GPU = '1') then
               ss_gpu_in(to_integer(SS_Adr)) <= SS_DataWrite;
            end if;
            if (SS_wren_Timing = '1') then
               ss_timing_in(to_integer(SS_Adr)) <= SS_DataWrite;
            end if;
         end if;
         
         SS_Idle <= '0';
         if (proc_idle = '1' and fifoIn_Empty = '1' and fifoOut_Empty = '1' and vramState = IDLE and pipeline_busy = '0'  and fifoOut_Wr = '0' and pixelWrite = '0') then
            SS_Idle <= '1';
         end if;     

         if (SS_rden_GPU = '1') then
            SS_DataRead_GPU <= ss_gpu_out(to_integer(SS_Adr));
         end if;
         
         if (SS_rden_Timing = '1') then
            SS_DataRead_Timing <= ss_timing_out(to_integer(SS_Adr));
         end if;
      
      end if;
   end process;

   -- synthesis translate_off
   
   goutput : if 1 = 1 generate
   begin
   
      process
         file outfile      : text;
         variable f_status : FILE_OPEN_STATUS;
         variable line_out : line;
      begin
   
         file_open(f_status, outfile, "R:\\debug_gpufifo_sim.txt", write_mode);
         file_close(outfile);
         
         file_open(f_status, outfile, "R:\\debug_gpufifo_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk1x);
            
            if (DMA_GPU_writeEna = '1') then
               write(line_out, string'("Fifo: ")); 
               write(line_out, to_hstring(DMA_GPU_write));
               writeline(outfile, line_out);
            end if;
            
            if (bus_write = '1' and bus_addr = 0) then
               write(line_out, string'("Fifo: ")); 
               write(line_out, to_hstring(bus_dataWrite));
               writeline(outfile, line_out);
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput;
   
   goutput2 : if 1 = 1 generate
      signal pixelCount          : integer := 0;
   begin
   
      process
         file outfile      : text;
         variable f_status : FILE_OPEN_STATUS;
         variable line_out : line;
      begin
   
         file_open(f_status, outfile, "R:\\debug_pixel_sim.txt", write_mode);
         file_close(outfile);
         
         file_open(f_status, outfile, "R:\\debug_pixel_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk2x);
            
            if (pixelWrite = '1' and pixelCount >= 0) then
            
               write(line_out, to_integer(pixelAddr(10 downto 1)));
               write(line_out, string'(" ")); 
               write(line_out, to_integer(pixelAddr(19 downto 11)));
               write(line_out, string'(" ")); 
               write(line_out, to_integer(unsigned(pixelColor)));
               writeline(outfile, line_out);
               pixelCount <= pixelCount + 1;
   
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput2;
   
   
   -- synthesis translate_on

end architecture;





