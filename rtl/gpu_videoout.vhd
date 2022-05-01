library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pGPU.all;

entity gpu_videoout is
   port 
   (
      clk1x                      : in  std_logic;
      clk2x                      : in  std_logic;
      clkvid                     : in  std_logic;
      ce                         : in  std_logic;
      reset                      : in  std_logic;
      softReset                  : in  std_logic;
      
      allowunpause               : out std_logic;
            
      videoout_settings          : in  tvideoout_settings;
      videoout_reports           : out tvideoout_reports;
            
      videoout_on                : in  std_logic;
      syncVideoOut               : in  std_logic;
            
      debugmodeOn                : in  std_logic;
         
      fpscountOn                 : in  std_logic;
      fpscountBCD                : in  unsigned(7 downto 0);     
   
      Gun1CrosshairOn            : in  std_logic;
      Gun1X                      : in  unsigned(7 downto 0);
      Gun1Y_scanlines            : in  unsigned(8 downto 0);
      Gun1IRQ10                  : out std_logic;
   
      Gun2CrosshairOn            : in  std_logic;
      Gun2X                      : in  unsigned(7 downto 0);
      Gun2Y_scanlines            : in  unsigned(8 downto 0);   
      Gun2IRQ10                  : out std_logic;
            
      cdSlow                     : in  std_logic;
            
      errorOn                    : in  std_logic;
      errorEna                   : in  std_logic;
      errorCode                  : in  unsigned(3 downto 0); 
         
      requestVRAMEnable          : out std_logic := '0';
      requestVRAMXPos            : out unsigned(9 downto 0);
      requestVRAMYPos            : out unsigned(8 downto 0);
      requestVRAMSize            : out unsigned(10 downto 0);
      requestVRAMIdle            : in  std_logic;
      requestVRAMDone            : in  std_logic;
            
      vram_DOUT                  : in  std_logic_vector(63 downto 0);
      vram_DOUT_READY            : in  std_logic;
            
      videoout_out               : buffer tvideoout_out;
      
      videoout_ss_in             : in  tvideoout_ss;
      videoout_ss_out            : out tvideoout_ss
   );
end entity;

architecture arch of gpu_videoout is

   signal DisplayOffsetX            : unsigned( 9 downto 0) := (others => '0'); 
   signal DisplayOffsetY            : unsigned( 8 downto 0) := (others => '0'); 
   signal vDisplayStart             : unsigned( 9 downto 0) := (others => '0'); 
         
   -- muxing      
   signal videoout_reports_s        : tvideoout_reports;
   signal videoout_reports_a        : tvideoout_reports;
         
   signal videoout_out_s            : tvideoout_out;
   signal videoout_out_a            : tvideoout_out;
         
   signal videoout_ss_out_s         : tvideoout_ss;
   signal videoout_ss_out_a         : tvideoout_ss;
         
   signal videoout_request_s        : tvideoout_request;
   signal videoout_request_as       : tvideoout_request;
   signal videoout_request_aa       : tvideoout_request;
         
   signal videoout_readAddr_s       : unsigned(10 downto 0);
   signal videoout_readAddr_a       : unsigned(10 downto 0);
   
   signal allowunpause_a            : std_logic;
    
   -- data fetch
   signal videoout_request_clk2x    : tvideoout_request;
   signal videoout_request_clkvid   : tvideoout_request;
   signal videoout_readAddr         : unsigned(10 downto 0);
   signal videoout_pixelRead        : std_logic_vector(15 downto 0);
   
   type tState is
   (
      WAITNEWLINE,
      WAITREQUEST,
      REQUEST,
      WAITREAD
   );
   signal state : tState := WAITNEWLINE;
   
   signal waitcnt             : integer range 0 to 3;
   
   signal reqPosX             : unsigned(9 downto 0) := (others => '0');
   signal reqPosY             : unsigned(8 downto 0) := (others => '0');
   signal reqSize             : unsigned(10 downto 0) := (others => '0');
   signal lineAct             : unsigned(8 downto 0) := (others => '0');
   signal fillAddr            : unsigned(8 downto 0) := (others => '0');
   signal store               : std_logic := '0';
   
   -- overlay
   signal overlay_data        : std_logic_vector(23 downto 0);
   signal overlay_ena         : std_logic;
   
   signal fpstext             : unsigned(15 downto 0);
   signal overlay_fps_data    : std_logic_vector(23 downto 0);
   signal overlay_fps_ena     : std_logic;
   
   signal overlay_cd_data     : std_logic_vector(23 downto 0);
   signal overlay_cd_ena      : std_logic;
   
   signal errortext           : unsigned(7 downto 0);
   signal overlay_error_data  : std_logic_vector(23 downto 0);
   signal overlay_error_ena   : std_logic;
   
   signal debugtextDbg        : unsigned(23 downto 0);
   signal debugtextDbg_data   : std_logic_vector(23 downto 0);
   signal debugtextDbg_ena    : std_logic;

   signal overlay_Gun1_ena    : std_logic;
   signal overlay_Gun2_ena    : std_logic;

   signal Gun1X_screen        : integer range 0 to 1023;
   signal Gun2X_screen        : integer range 0 to 1023;

   signal Gun1Y_screen        : unsigned(9 downto 0);
   signal Gun2Y_screen        : unsigned(9 downto 0);
   
begin 

   videoout_reports        <= videoout_reports_s  when (syncVideoOut = '1') else videoout_reports_a; 
   videoout_out            <= videoout_out_s      when (syncVideoOut = '1') else videoout_out_a;     
   videoout_ss_out         <= videoout_ss_out_s   when (syncVideoOut = '1') else videoout_ss_out_a;  
   videoout_readAddr       <= videoout_readAddr_s when (syncVideoOut = '1') else videoout_readAddr_a;
   videoout_request_clk2x  <= videoout_request_s  when (syncVideoOut = '1') else videoout_request_as; 
   videoout_request_clkvid <= videoout_request_s  when (syncVideoOut = '1') else videoout_request_aa; 

   allowunpause            <= '1'                 when (syncVideoOut = '1') else allowunpause_a;

   igpu_videoout_sync : entity work.gpu_videoout_sync
   port map
   (
      clk1x                   => clk1x,
      clk2x                   => clk2x,
      ce                      => ce,   
      reset                   => reset,
      softReset               => softReset,
               
      videoout_settings       => videoout_settings,
      videoout_reports        => videoout_reports_s,                 
                                                                      
      videoout_request        => videoout_request_s, 
      videoout_readAddr       => videoout_readAddr_s,  
      videoout_pixelRead      => videoout_pixelRead,   
   
      overlay_data            => overlay_data,
      overlay_ena             => overlay_ena,                     
                   
      videoout_out            => videoout_out_s,
      
      videoout_ss_in          => videoout_ss_in,
      videoout_ss_out         => videoout_ss_out_s      
   );   
   
   igpu_videoout_async : entity work.gpu_videoout_async
   port map
   (
      clk1x                   => clk1x,
      clk2x                   => clk2x,
      clkvid                  => clkvid,
      ce_1x                   => ce,   
      reset_1x                => reset,
      softReset_1x            => softReset,
               
      allowunpause1x          => allowunpause_a,
               
      videoout_settings_1x    => videoout_settings,
      videoout_reports_1x     => videoout_reports_a,                 
                                                                      
      videoout_request_2x     => videoout_request_as, 
      videoout_request_vid    => videoout_request_aa, 
      videoout_readAddr       => videoout_readAddr_a,  
      videoout_pixelRead      => videoout_pixelRead,   

      overlay_data            => overlay_data,
      overlay_ena             => overlay_ena,                     
      
      videoout_out            => videoout_out_a,
      
      videoout_ss_in          => videoout_ss_in,
      videoout_ss_out         => videoout_ss_out_a      
   );
   
   -- vram reading
   requestVRAMEnable <= '1'     when (state = REQUEST and requestVRAMIdle = '1') else '0';
   requestVRAMXPos   <= reqPosX when (state = REQUEST and requestVRAMIdle = '1') else (others => '0');
   requestVRAMYPos   <= reqPosY when (state = REQUEST and requestVRAMIdle = '1') else (others => '0');
   requestVRAMSize   <= reqSize when (state = REQUEST and requestVRAMIdle = '1') else (others => '0');
   
   DisplayOffsetX <= videoout_settings.vramRange(9 downto 0);
   
   vDisplayStart  <= videoout_settings.vDisplayRange(9 downto 0);
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         
         -- display offset is adjusted if display start is below typical line for CRTs
         DisplayOffsetY <= videoout_settings.vramRange(18 downto 10);
         if (videoout_settings.GPUSTAT_PalVideoMode = '1' and videoout_settings.pal60 = '0') then
            if (vDisplayStart < 19) then
               if (videoout_settings.GPUSTAT_VerRes = '1' and videoout_settings.GPUSTAT_VertInterlace = '1') then
                  DisplayOffsetY <= resize(videoout_settings.vramRange(18 downto 10) + ((19 - vDisplayStart) * 2), 9);
               else
                  DisplayOffsetY <= resize(videoout_settings.vramRange(18 downto 10) + (19 - vDisplayStart), 9);
               end if;
            end if;
         else
            if (vDisplayStart < 16) then
               if (videoout_settings.GPUSTAT_VerRes = '1' and videoout_settings.GPUSTAT_VertInterlace = '1') then
                  DisplayOffsetY <= resize(videoout_settings.vramRange(18 downto 10) + ((16 - vDisplayStart) * 2), 9);
               else
                  DisplayOffsetY <= resize(videoout_settings.vramRange(18 downto 10) + (16 - vDisplayStart), 9);
               end if;
            end if;
         end if;
         
         
         if (reset = '1') then
         
            state   <= WAITNEWLINE;
            lineAct <= (others => '0');
         
         elsif (ce = '1') then
         
            case (state) is
            
               when WAITNEWLINE =>
                  if (videoout_on = '1' and videoout_request_clk2x.lineInNext /= lineAct and videoout_request_clk2x.fetch = '1' and videoout_settings.GPUSTAT_DisplayDisable = '0') then
                     waitcnt <= 3;
                     state   <= WAITREQUEST;
                  end if;
                  
               when WAITREQUEST => 
                  if (waitcnt > 0) then
                     waitcnt <= waitcnt - 1;
                  else
                     state     <= REQUEST;
                     lineAct   <= videoout_request_clk2x.lineInNext;
                     reqPosX   <= DisplayOffsetX;
                     reqPosY   <= videoout_request_clk2x.lineInNext + DisplayOffsetY;
                     fillAddr  <= videoout_request_clk2x.lineInNext(0) & x"00";
                     if (videoout_settings.GPUSTAT_VerRes = '1') then
                        fillAddr(8) <= videoout_request_clk2x.lineInNext(1);
                     end if;
                     if (videoout_settings.GPUSTAT_ColorDepth24 = '1') then
                        reqSize <= resize(videoout_request_clk2x.fetchsize, 11) + resize(videoout_request_clk2x.fetchsize(9 downto 1), 11);
                     else
                        reqSize <= '0' & videoout_request_clk2x.fetchsize;
                     end if;
                  end if;

               when REQUEST =>
                  if (requestVRAMIdle = '1') then
                     state <= WAITREAD;
                     store <= '1';
                  end if;
                  
               when WAITREAD =>
                  if (vram_DOUT_READY = '1') then
                     fillAddr <= fillAddr + 1;
                  end if;
                  if (requestVRAMDone = '1') then
                     state <= WAITNEWLINE; 
                     store <= '0';
                  end if;
            
            end case;
         
         end if;
         
      end if;
   end process; 
   
   ilineram: entity work.dpram_dif
   generic map 
   ( 
      addr_width_a  => 9,
      data_width_a  => 64,
      addr_width_b  => 11,
      data_width_b  => 16
   )
   port map
   (
      clock_a     => clk2x,
      address_a   => std_logic_vector(fillAddr),
      data_a      => vram_DOUT,
      wren_a      => (vram_DOUT_READY and store),
      
      clock_b     => clkvid,
      address_b   => std_logic_vector(videoout_readAddr),
      data_b      => x"0000",
      wren_b      => '0',
      q_b         => videoout_pixelRead
   );
  
  
   -- overlays
   fpstext( 7 downto 0) <= resize(fpscountBCD(3 downto 0), 8) + 16#30#;
   fpstext(15 downto 8) <= resize(fpscountBCD(7 downto 4), 8) + 16#30#;
   
   ioverlayFPS : entity work.gpu_overlay
   generic map
   (
      COLS                   => 2,
      BACKGROUNDON           => '1',
      RGB_BACK               => x"FFFFFF",
      RGB_FRONT              => x"0000FF",
      OFFSETX                => 4,
      OFFSETY                => 4
   )
   port map
   (
      clk                    => clkvid,
      ce                     => videoout_out.ce,
      ena                    => fpscountOn,                    
      i_pixel_out_x          => videoout_request_clkvid.xpos,
      i_pixel_out_y          => to_integer(videoout_request_clkvid.lineDisp),
      o_pixel_out_data       => overlay_fps_data,
      o_pixel_out_ena        => overlay_fps_ena,
      textstring             => fpstext
   );
   
   ioverlayCD : entity work.gpu_overlay
   generic map
   (
      COLS                   => 2,
      BACKGROUNDON           => '1',
      RGB_BACK               => x"FFFFFF",
      RGB_FRONT              => x"0000FF",
      OFFSETX                => 4,
      OFFSETY                => 24
   )
   port map
   (
      clk                    => clkvid,
      ce                     => videoout_out.ce,
      ena                    => cdSlow,                    
      i_pixel_out_x          => videoout_request_clkvid.xpos,
      i_pixel_out_y          => to_integer(videoout_request_clkvid.lineDisp),
      o_pixel_out_data       => overlay_cd_data,
      o_pixel_out_ena        => overlay_cd_ena,
      textstring             => x"4344"
   );
   
   errortext <= resize(errorCode, 8) + 16#30# when (errorCode < 10) else resize(errorCode, 8) + 16#37#;
   ioverlayError : entity work.gpu_overlay
   generic map
   (
      COLS                   => 2,
      BACKGROUNDON           => '1',
      RGB_BACK               => x"FFFFFF",
      RGB_FRONT              => x"0000FF",
      OFFSETX                => 4,
      OFFSETY                => 44
   )
   port map
   (
      clk                    => clkvid,
      ce                     => videoout_out.ce,
      ena                    => errorOn and errorEna,                    
      i_pixel_out_x          => videoout_request_clkvid.xpos,
      i_pixel_out_y          => to_integer(videoout_request_clkvid.lineDisp),
      o_pixel_out_data       => overlay_error_data,
      o_pixel_out_ena        => overlay_error_ena,
      textstring             => x"45" & errortext
   );   
   
   idebugtext_dbg : entity work.gpu_overlay
   generic map
   (
      COLS                   => 3,
      BACKGROUNDON           => '1',
      RGB_BACK               => x"FFFFFF",
      RGB_FRONT              => x"0000FF",
      OFFSETX                => 30,
      OFFSETY                => 4
   )
   port map
   (
      clk                    => clkvid,
      ce                     => videoout_out.ce,
      ena                    => debugmodeOn,                    
      i_pixel_out_x          => videoout_request_clkvid.xpos,
      i_pixel_out_y          => to_integer(videoout_request_clkvid.lineDisp),
      o_pixel_out_data       => debugtextDbg_data,
      o_pixel_out_ena        => debugtextDbg_ena,
      textstring             => x"444247"
   );

   -- Map gun coordinates (0-255 X, Y) to screen positions
   process (clkvid)
   begin
      if rising_edge(clkvid) then
         Gun1X_screen <= to_integer(to_unsigned(to_integer(videoout_out.DisplayWidth * Gun1X), 18) (17 downto 8));
         Gun2X_screen <= to_integer(to_unsigned(to_integer(videoout_out.DisplayWidth * Gun2X), 18) (17 downto 8));
         if (videoout_settings.GPUSTAT_VerRes = '1') then
            Gun1Y_screen <= Gun1Y_scanlines & '0';
            Gun2Y_screen <= Gun2Y_scanlines & '0';
         else
            Gun1Y_screen <= '0' & Gun1Y_scanlines;
            Gun2Y_screen <= '0' & Gun2Y_scanlines;
         end if;
      end if;
   end process;
  
   gpu_crosshair1: entity work.gpu_crosshair
   port map
   (
      clk            => clkvid,
      ce             => videoout_out.ce,
      vsync          => videoout_out.vsync,
      hblank         => videoout_out.hblank,
              
      xpos_cross     => Gun1X_screen,
      ypos_cross     => to_integer(Gun1Y_screen),
      xpos_screen    => videoout_request_clkvid.xpos,
      ypos_screen    => to_integer(videoout_request_clkvid.lineDisp),
      
      out_ena        => overlay_Gun1_ena
   );
   
   gpu_crosshair2: entity work.gpu_crosshair
   port map
   (
      clk            => clkvid,
      ce             => videoout_out.ce,
      vsync          => videoout_out.vsync,
      hblank         => videoout_out.hblank,
              
      xpos_cross     => Gun2X_screen,
      ypos_cross     => to_integer(Gun2Y_screen),
      xpos_screen    => videoout_request_clkvid.xpos,
      ypos_screen    => to_integer(videoout_request_clkvid.lineDisp),
      
      out_ena        => overlay_Gun2_ena
   );
   
   justifier_sensor1: entity work.justifier_sensor
   port map
   (
      clk            => clk1x,
      clkvid         => clkvid,
      ce             => videoout_out.ce,
      vsync          => videoout_out.vsync,
      hblank         => videoout_out.hblank,

      xpos_gun       => Gun1X_screen,
      ypos_gun       => to_integer(Gun1Y_screen),
      xpos_screen    => videoout_request_clkvid.xpos,
      ypos_screen    => to_integer(videoout_request_clkvid.lineDisp),

      out_irq10      => Gun1IRQ10
   );

   justifier_sensor2: entity work.justifier_sensor
   port map
   (
      clk            => clk1x,
      clkvid         => clkvid,
      ce             => videoout_out.ce,
      vsync          => videoout_out.vsync,
      hblank         => videoout_out.hblank,

      xpos_gun       => Gun2X_screen,
      ypos_gun       => to_integer(Gun2Y_screen),
      xpos_screen    => videoout_request_clkvid.xpos,
      ypos_screen    => to_integer(videoout_request_clkvid.lineDisp),

      out_irq10      => Gun2IRQ10
   );

   overlay_ena <= overlay_error_ena or overlay_cd_ena or overlay_fps_ena or debugtextDbg_ena or (overlay_Gun1_ena and Gun1CrosshairOn) or (overlay_Gun2_ena and Gun2CrosshairOn);
   
   overlay_data <= overlay_error_data when (overlay_error_ena = '1') else
                   overlay_cd_data    when (overlay_cd_ena = '1') else
                   overlay_fps_data   when (overlay_fps_ena = '1') else
                   debugtextDbg_data  when (debugtextDbg_ena = '1') else
                   x"0000FF"          when (overlay_Gun1_ena = '1' and Gun1CrosshairOn = '1') else
                   x"FFFF00"          when (overlay_Gun2_ena = '1' and Gun2CrosshairOn = '1') else
                   (others => '0');

end architecture;





