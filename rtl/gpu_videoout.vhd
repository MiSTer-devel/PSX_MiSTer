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
      ce                         : in  std_logic;
      reset                      : in  std_logic;
      softReset                  : in  std_logic;
            
      videoout_settings          : in  tvideoout_settings;
      videoout_reports           : out tvideoout_reports;
            
      videoout_on                : in  std_logic;
            
      debugmodeOn                : in  std_logic;
         
      fpscountOn                 : in  std_logic;
      fpscountBCD                : in  unsigned(7 downto 0);     
   
      Gun1CrosshairOn            : in  std_logic;
      Gun1X                      : in  unsigned(7 downto 0);
      Gun1Y_scanlines            : in  unsigned(8 downto 0);
   
      Gun2CrosshairOn            : in  std_logic;
      Gun2X                      : in  unsigned(7 downto 0);
      Gun2Y_scanlines            : in  unsigned(8 downto 0);   
            
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
            
      video_ce                   : buffer std_logic := '0';
      video_r                    : out std_logic_vector(7 downto 0);
      video_g                    : out std_logic_vector(7 downto 0);
      video_b                    : out std_logic_vector(7 downto 0);
      video_hblank               : out std_logic := '1';
      video_hsync                : out std_logic := '0';
      
      videoout_ss_in             : in  tvideoout_ss;
      videoout_ss_out            : out tvideoout_ss
   );
end entity;

architecture arch of gpu_videoout is
   
   signal nextHCount                : integer range 0 to 4095;
   signal vpos                      : integer range 0 to 511;
   signal vsyncCount                : integer range 0 to 511;
   
   signal DisplayWidth              : unsigned( 9 downto 0);
   signal DisplayOffsetX            : unsigned( 9 downto 0) := (others => '0'); 
   signal DisplayOffsetY            : unsigned( 8 downto 0) := (others => '0'); 
   
   signal htotal                    : integer range 2169 to 2173; -- 3406 to 3413 in GPU clock domain
   signal vtotal                    : integer range 263 to 314;
   signal vDisplayStart             : integer range 0 to 314;
   signal vDisplayEnd               : integer range 0 to 314;
    
   -- data fetch
   signal videoout_fetch            : std_logic := '0';
   signal videoout_lineIn           : unsigned(8 downto 0) := (others => '0');
   signal videoout_lineInNext       : unsigned(8 downto 0) := (others => '0');
   
begin 

   videoout_ss_out.interlacedDisplayField <= videoout_reports.interlacedDisplayField;                 
   videoout_ss_out.nextHCount             <= std_logic_vector(to_unsigned(nextHCount, 12));                             
   videoout_ss_out.vpos                   <= std_logic_vector(to_unsigned(vpos, 9));                            
   videoout_ss_out.inVsync                <= videoout_reports.inVsync;                                
   videoout_ss_out.activeLineLSB          <= videoout_reports.activeLineLSB;                          
   videoout_ss_out.GPUSTAT_InterlaceField <= videoout_reports.GPUSTAT_InterlaceField;
   videoout_ss_out.GPUSTAT_DrawingOddline <= videoout_reports.GPUSTAT_DrawingOddline;

   process (clk1x)
      variable mode480i                  : std_logic;
      variable isVsync                   : std_logic;
      variable vposNew                   : integer range 0 to 511;
      variable interlacedDisplayFieldNew : std_logic;
   begin
      if rising_edge(clk1x) then
      
         if (nextHCount <   3) then videoout_reports.hblank_tmr <= '1'; else videoout_reports.hblank_tmr <= '0'; end if; -- todo: correct hblank timer tick position to be found
                
         videoout_reports.vsync <= '0';
         if (videoout_settings.GPUSTAT_VerRes = '1') then
            if (vsyncCount >= 5 and vsyncCount < 8) then videoout_reports.vsync <= '1'; end if;
         else
            if (vsyncCount >= 10 and vsyncCount < 13) then videoout_reports.vsync <= '1'; end if;
         end if;
         
         DisplayOffsetX <= videoout_settings.vramRange(9 downto 0);
         DisplayOffsetY <= videoout_settings.vramRange(18 downto 10);

         if (videoout_settings.GPUSTAT_HorRes2 = '1') then
            DisplayWidth  <= to_unsigned(368, 10);
         else
            case (videoout_settings.GPUSTAT_HorRes1) is
               when "00" => DisplayWidth <= to_unsigned(256, 10);
               when "01" => DisplayWidth <= to_unsigned(320, 10);
               when "10" => DisplayWidth <= to_unsigned(512, 10);
               when "11" => DisplayWidth <= to_unsigned(640, 10);
               when others => null;
            end case;
         end if;

         if (reset = '1') then
               
            videoout_reports.irq_VBLANK  <= '0';
               
            videoout_reports.interlacedDisplayField   <= videoout_ss_in.interlacedDisplayField;
            nextHCount                                <= to_integer(unsigned(videoout_ss_in.nextHCount));
            vpos                                      <= to_integer(unsigned(videoout_ss_in.vpos));
            videoout_reports.inVsync                  <= videoout_ss_in.inVsync;
            videoout_reports.activeLineLSB            <= videoout_ss_in.activeLineLSB;
            videoout_reports.GPUSTAT_InterlaceField   <= videoout_ss_in.GPUSTAT_InterlaceField;
            videoout_reports.GPUSTAT_DrawingOddline   <= videoout_ss_in.GPUSTAT_DrawingOddline;
                  
         elsif (ce = '1') then
         
            videoout_reports.irq_VBLANK <= '0';
            
            --gpu timing calc
            if (videoout_settings.GPUSTAT_PalVideoMode = '1' and videoout_settings.pal60 = '0') then
               htotal <= 2169; -- overwritten below
               vtotal <= 314;
            else
               htotal <= 2173; -- overwritten below
               vtotal <= 263;
            end if;
            
            -- todo: different values for ntsc
            if (videoout_settings.GPUSTAT_HorRes2 = '1') then
               htotal  <= 2169; -- 368
            else
               case (videoout_settings.GPUSTAT_HorRes1) is
                  when "00" => htotal <= 2172; -- 256;
                  when "01" => htotal <= 2170; -- 320;
                  when "10" => htotal <= 2169;  -- 512;
                  when "11" => htotal <= 2170;  -- 640;
                  when others => null;
               end case;
            end if;
            
            
            if (videoout_settings.vDisplayRange( 9 downto  0) < 314) then vDisplayStart <= to_integer(videoout_settings.vDisplayRange( 9 downto  0)); else vDisplayStart <= 314; end if;
            if (videoout_settings.vDisplayRange(19 downto 10) < 314) then vDisplayEnd   <= to_integer(videoout_settings.vDisplayRange(19 downto 10)); else vDisplayEnd   <= 314; end if;
              
            -- gpu timing count
            if (nextHCount > 1) then
               nextHCount <= nextHCount - 1;
            else
               
               nextHCount <= htotal;
               
               vposNew := vpos + 1;
               if (vposNew >= vtotal) then
                  vposNew := 0;
                  if (videoout_settings.GPUSTAT_VertInterlace = '1') then
                     videoout_reports.GPUSTAT_InterlaceField <= not videoout_reports.GPUSTAT_InterlaceField;
                  else
                     videoout_reports.GPUSTAT_InterlaceField <= '0';
                  end if;
               end if;
               
               vpos <= vposNew;
               
               -- todo: timer 1
               
               mode480i := '0';
               if (videoout_settings.GPUSTAT_VerRes = '1' and videoout_settings.GPUSTAT_VertInterlace = '1') then mode480i := '1'; end if;
               
               isVsync := '0';
               vsyncCount <= 0;
               if (vposNew < vDisplayStart or vposNew >= vDisplayEnd) then 
                  isVsync := '1'; 
                  vsyncCount <= vsyncCount + 1;
               else
                  if (videoout_settings.GPUSTAT_VerRes = '1') then
                     if (videoout_reports.interlacedDisplayField = '1') then
                        videoout_lineIn <= to_unsigned(((vposNew - vDisplayStart) * 2) + 1, 9);
                     else
                        videoout_lineIn <= to_unsigned((vposNew - vDisplayStart) * 2, 9);
                     end if;
                  else
                     videoout_lineIn <= to_unsigned(vposNew - vDisplayStart, 9);
                  end if;
               end if;

               interlacedDisplayFieldNew := videoout_reports.interlacedDisplayField;
               if (isVsync /= videoout_reports.inVsync) then
                  if (isVsync = '1') then
                     videoout_fetch <= '0';
                     videoout_reports.irq_VBLANK <= '1';
                     if (mode480i = '1') then 
                        interlacedDisplayFieldNew := not videoout_reports.GPUSTAT_InterlaceField;
                     else 
                        interlacedDisplayFieldNew := '0';
                     end if;
                  end if;
                  videoout_reports.inVsync <= isVsync;
                  --Timer.gateChange(1, inVsync);
               end if;
               videoout_reports.interlacedDisplayField <= interlacedDisplayFieldNew;
               
             
               videoout_reports.GPUSTAT_DrawingOddline <= '0';
               videoout_reports.activeLineLSB          <= '0';
               if (mode480i = '1') then
                  if (videoout_settings.vramRange(10) = '0' and interlacedDisplayFieldNew = '1') then videoout_reports.activeLineLSB <= '1'; end if;
                  if (videoout_settings.vramRange(10) = '1' and interlacedDisplayFieldNew = '0') then videoout_reports.activeLineLSB <= '1'; end if;
               
                  if (videoout_settings.vramRange(10) = '0' and isVsync = '0' and interlacedDisplayFieldNew = '1') then videoout_reports.GPUSTAT_DrawingOddline <= '1'; end if;
                  if (videoout_settings.vramRange(10) = '1' and isVsync = '1' and interlacedDisplayFieldNew = '0') then videoout_reports.GPUSTAT_DrawingOddline <= '1'; end if;
               else
                  if (videoout_settings.vramRange(10) = '0' and (vposNew mod 2) = 1) then videoout_reports.GPUSTAT_DrawingOddline <= '1'; end if;
                  if (videoout_settings.vramRange(10) = '1' and (vposNew mod 2) = 0) then videoout_reports.GPUSTAT_DrawingOddline <= '1'; end if;
               end if;
               
               vposNew := vposNew + 1;
               if (vDisplayStart > 0) then
                  if (vposNew >= vDisplayStart and vposNew < vDisplayEnd) then 
                     if (videoout_settings.GPUSTAT_VerRes = '1') then
                        if (videoout_reports.activeLineLSB = '1') then
                           videoout_lineInNext <= to_unsigned(((vposNew - vDisplayStart) * 2) + 1, 9);
                        else
                           videoout_lineInNext <= to_unsigned((vposNew - vDisplayStart) * 2, 9);
                        end if;
                     else
                        videoout_lineInNext <= to_unsigned(vposNew - vDisplayStart, 9);
                     end if;
                     videoout_fetch      <= '1';
                  end if;
               else  
                  if (vposNew = vtotal) then
                     if (videoout_settings.GPUSTAT_VerRes = '1' and videoout_reports.interlacedDisplayField = '1') then
                        videoout_lineInNext <= to_unsigned(1, 9);
                     else
                        videoout_lineInNext <= to_unsigned(0, 9);
                     end if;
                     videoout_fetch      <= '1';
                  elsif (vposNew >= vDisplayStart and vposNew < vDisplayEnd) then 
                     if (videoout_settings.GPUSTAT_VerRes = '1') then
                        if (videoout_reports.activeLineLSB = '1') then
                           videoout_lineInNext <= to_unsigned(((vposNew - vDisplayStart) * 2) + 1, 9);
                        else
                           videoout_lineInNext <= to_unsigned((vposNew - vDisplayStart) * 2, 9);
                        end if;
                     else
                        videoout_lineInNext <= to_unsigned(vposNew - vDisplayStart, 9);
                     end if;
                     videoout_fetch      <= '1';
                  end if;
               end if;
              
            end if;
            
            if (softReset = '1') then
               videoout_reports.GPUSTAT_InterlaceField <= '1';
               videoout_reports.GPUSTAT_DrawingOddline <= '0';
               videoout_reports.irq_VBLANK             <= '0';
            end if;

         end if;
      end if;
   end process;
  
   igpu_videoout_sync : entity work.gpu_videoout_sync
   port map
   (
      clk2x                   => clk2x,                  
      ce                      => ce,                     
      reset                   => reset,                  
                                                
      videoout_on             => videoout_on,            
                                   
      debugmodeOn             => debugmodeOn,            
                             
      fpscountOn              => fpscountOn,             
      fpscountBCD             => fpscountBCD,            
                    
      Gun1CrosshairOn         => Gun1CrosshairOn,        
      Gun1X                   => Gun1X,                  
      Gun1Y_scanlines         => Gun1Y_scanlines,        
                        
      Gun2CrosshairOn         => Gun2CrosshairOn,        
      Gun2X                   => Gun2X,                  
      Gun2Y_scanlines         => Gun2Y_scanlines,          
                     
      cdSlow                  => cdSlow,                 
                  
      errorOn                 => errorOn,                
      errorEna                => errorEna,               
      errorCode               => errorCode,              
                                
      fetch                   => videoout_fetch,                
      lineIn                  => videoout_lineIn,               
      lineInNext              => videoout_lineInNext,           
      nextHCount              => nextHCount,             
      DisplayWidth            => DisplayWidth,           
      DisplayOffsetX          => DisplayOffsetX,         
      DisplayOffsetY          => DisplayOffsetY,         
      GPUSTAT_HorRes2         => videoout_settings.GPUSTAT_HorRes2,        
      GPUSTAT_HorRes1         => videoout_settings.GPUSTAT_HorRes1,        
      GPUSTAT_ColorDepth24    => videoout_settings.GPUSTAT_ColorDepth24,   
      GPUSTAT_DisplayDisable  => videoout_settings.GPUSTAT_DisplayDisable, 
      interlacedMode          => videoout_settings.GPUSTAT_VerRes,         
                         
      requestVRAMEnable       => requestVRAMEnable,      
      requestVRAMXPos         => requestVRAMXPos,        
      requestVRAMYPos         => requestVRAMYPos,        
      requestVRAMSize         => requestVRAMSize,        
      requestVRAMIdle         => requestVRAMIdle,        
      requestVRAMDone         => requestVRAMDone,        
                         
      vram_DOUT               => vram_DOUT,              
      vram_DOUT_READY         => vram_DOUT_READY,        
                   
      video_ce                => video_ce,               
      video_r                 => video_r,                
      video_g                 => video_g,                
      video_b                 => video_b,                
      video_hblank            => video_hblank,           
      video_hsync             => video_hsync            
   );
  

end architecture;





