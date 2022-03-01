library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pGPU.all;

entity gpu_videoout_sync is
   port 
   (
      clk1x                   : in  std_logic;
      clk2x                   : in  std_logic;
      ce                      : in  std_logic;
      reset                   : in  std_logic;
      softReset               : in  std_logic;
      
      videoout_settings       : in  tvideoout_settings;
      videoout_reports        : out tvideoout_reports;
         
      videoout_on             : in  std_logic;
         
      debugmodeOn             : in  std_logic;
      
      fpscountOn              : in  std_logic;
      fpscountBCD             : in  unsigned(7 downto 0);     

      Gun1CrosshairOn         : in  std_logic;
      Gun1X                   : in  unsigned(7 downto 0);
      Gun1Y_scanlines         : in  unsigned(8 downto 0);

      Gun2CrosshairOn         : in  std_logic;
      Gun2X                   : in  unsigned(7 downto 0);
      Gun2Y_scanlines         : in  unsigned(8 downto 0);
         
      cdSlow                  : in  std_logic;
         
      errorOn                 : in  std_logic;
      errorEna                : in  std_logic;
      errorCode               : in  unsigned(3 downto 0);
      
      videoout_request        : out tvideoout_request := ('0', (others => '0'), (others => '0'), (others => '0'), 0, (others => '0'));
      videoout_pixelRead      : in  std_logic_vector(15 downto 0);
      
      overlay_data            : in  std_logic_vector(23 downto 0);
      overlay_ena             : in  std_logic;
      
      vram_DOUT               : in  std_logic_vector(63 downto 0);
      vram_DOUT_READY         : in  std_logic;
         
      video_ce                : out std_logic := '0';
      video_r                 : out std_logic_vector(7 downto 0) := (others => '0');
      video_g                 : out std_logic_vector(7 downto 0) := (others => '0');
      video_b                 : out std_logic_vector(7 downto 0) := (others => '0');
      video_hblank            : out std_logic := '1';
      video_hsync             : out std_logic := '0';
      
      videoout_ss_in          : in  tvideoout_ss;
      videoout_ss_out         : out tvideoout_ss
   );
end entity;

architecture arch of gpu_videoout_sync is
   
   -- timing
   signal nextHCount       : integer range 0 to 4095;
   signal vpos             : integer range 0 to 511;
   signal vsyncCount       : integer range 0 to 511;
   
   signal htotal           : integer range 2169 to 2173; -- 3406 to 3413 in GPU clock domain
   signal vtotal           : integer range 263 to 314;
   signal vDisplayStart    : integer range 0 to 314;
   signal vDisplayEnd      : integer range 0 to 314;
   
   -- output   
   signal pixelData_R      : std_logic_vector(7 downto 0) := (others => '0');
   signal pixelData_G      : std_logic_vector(7 downto 0) := (others => '0');
   signal pixelData_B      : std_logic_vector(7 downto 0) := (others => '0');
      
   signal clkDiv           : integer range 5 to 12 := 5; 
   signal clkCnt           : integer range 0 to 12 := 0;
   signal xmax             : integer range 0 to 1023;
      
   signal hsync_start      : integer range 0 to 4095;
   signal hsync_end        : integer range 0 to 4095;
   
   type tReadState is
   (
      IDLE,
      READ16,
      READ24_0,
      READ24_8,
      READ24_16,
      READ24_24
   );
   signal readstate     : tReadState := IDLE;
   signal readstate24   : tReadState := READ24_0;
   
   signal fetchNext : std_logic := '0';
   
begin 

   -- video timing
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
                        videoout_request.lineIn <= to_unsigned(((vposNew - vDisplayStart) * 2) + 1, 9);
                     else
                        videoout_request.lineIn <= to_unsigned((vposNew - vDisplayStart) * 2, 9);
                     end if;
                  else
                     videoout_request.lineIn <= to_unsigned(vposNew - vDisplayStart, 9);
                  end if;
               end if;

               interlacedDisplayFieldNew := videoout_reports.interlacedDisplayField;
               if (isVsync /= videoout_reports.inVsync) then
                  if (isVsync = '1') then
                     videoout_request.fetch      <= '0';
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
                           videoout_request.lineInNext <= to_unsigned(((vposNew - vDisplayStart) * 2) + 1, 9);
                        else
                           videoout_request.lineInNext <= to_unsigned((vposNew - vDisplayStart) * 2, 9);
                        end if;
                     else
                        videoout_request.lineInNext <= to_unsigned(vposNew - vDisplayStart, 9);
                     end if;
                     videoout_request.fetch      <= '1';
                  end if;
               else  
                  if (vposNew = vtotal) then
                     if (videoout_settings.GPUSTAT_VerRes = '1' and videoout_reports.interlacedDisplayField = '1') then
                        videoout_request.lineInNext <= to_unsigned(1, 9);
                     else
                        videoout_request.lineInNext <= to_unsigned(0, 9);
                     end if;
                     videoout_request.fetch      <= '1';
                  elsif (vposNew >= vDisplayStart and vposNew < vDisplayEnd) then 
                     if (videoout_settings.GPUSTAT_VerRes = '1') then
                        if (videoout_reports.activeLineLSB = '1') then
                           videoout_request.lineInNext <= to_unsigned(((vposNew - vDisplayStart) * 2) + 1, 9);
                        else
                           videoout_request.lineInNext <= to_unsigned((vposNew - vDisplayStart) * 2, 9);
                        end if;
                     else
                        videoout_request.lineInNext <= to_unsigned(vposNew - vDisplayStart, 9);
                     end if;
                     videoout_request.fetch      <= '1';
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
   
   -- timing generation reading
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         
         video_ce <= '0';
         
         if (reset = '1') then
         
            clkCnt                     <= 0;
            video_hblank               <= '1';
            videoout_request.lineDisp  <= (others => '0');
            readstate                  <= IDLE;
         
         elsif (ce = '1') then
         
            if (videoout_settings.GPUSTAT_HorRes2 = '1') then
               clkDiv  <= 9; -- 368
            else
               case (videoout_settings.GPUSTAT_HorRes1) is
                  when "00" => clkDiv <= 12; -- 256;
                  when "01" => clkDiv <= 10; -- 320;
                  when "10" => clkDiv <= 6;  -- 512;
                  when "11" => clkDiv <= 5;  -- 640;
                  when others => null;
               end case;
            end if;
            
            if (clkCnt < (clkDiv - 1)) then
               clkCnt <= clkCnt + 1;
            else
               clkCnt    <= 0;
               video_ce  <= '1';
               if (videoout_request.xpos < 1023) then
                  videoout_request.xpos <= videoout_request.xpos + 1;
               end if;
               if (videoout_request.xpos > 0 and videoout_request.xpos <= xmax) then
                  video_hblank <= '0';
                  if (overlay_ena = '1') then
                     video_r      <= overlay_data( 7 downto 0);
                     video_g      <= overlay_data(15 downto 8);
                     video_b      <= overlay_data(23 downto 16);
                  elsif (videoout_settings.GPUSTAT_DisplayDisable = '1') then
                     video_r      <= (others => '0');
                     video_g      <= (others => '0');
                     video_b      <= (others => '0');
                  else
                     video_r      <= pixelData_R;
                     video_g      <= pixelData_G;
                     video_b      <= pixelData_B;
                  end if;
               else
                  video_hblank <= '1';
                  if (video_hblank = '0') then
                     hsync_start <= (nextHCount / 2) + (26 * clkDiv) - (8 * clkDiv);
                     hsync_end   <= (nextHCount / 2) + (2 * clkDiv) - (8 * clkDiv);
                  end if;
               end if;
            end if;
            
            if (videoout_request.lineIn /= videoout_request.lineDisp) then
               videoout_request.lineDisp <= videoout_request.lineIn;
               videoout_request.readAddr <= videoout_request.lineIn(0) & "00" & x"00";
               if (videoout_settings.GPUSTAT_VerRes = '1') then -- interlaced mode
                  videoout_request.readAddr(10) <= videoout_request.lineIn(1);
               end if;
               videoout_request.xpos <= 0;
               xmax                  <= to_integer(videoout_settings.DisplayWidth);
            end if;
            
            if (nextHCount = hsync_start) then video_hsync <= '1'; end if;
            if (nextHCount = hsync_end  ) then video_hsync <= '0'; end if;
         
            case (readstate) is
            
               when IDLE =>
                  if (clkCnt >= (clkDiv - 1) and videoout_request.xpos < xmax) then
                     if (videoout_settings.GPUSTAT_ColorDepth24 = '1') then
                        videoout_request.readAddr  <= videoout_request.readAddr + 1;
                        if (videoout_request.xpos = 0 or readstate24 = READ24_0) then
                           readstate <= READ24_0;
                        else
                           readstate <= READ24_8;
                        end if;
                     else
                        readstate <= READ16;
                     end if;
                  end if;

               when READ16 =>
                  readstate                  <= IDLE;
                  videoout_request.readAddr  <= videoout_request.readAddr + 1;
                  pixelData_R                <= videoout_pixelRead( 4 downto  0) & videoout_pixelRead( 4 downto 2);
                  pixelData_G                <= videoout_pixelRead( 9 downto  5) & videoout_pixelRead( 9 downto 7);
                  pixelData_B                <= videoout_pixelRead(14 downto 10) & videoout_pixelRead(14 downto 12);
                  
               when READ24_0 =>
                  readstate                  <= READ24_16;
                  pixelData_R                <= videoout_pixelRead( 7 downto  0);
                  pixelData_G                <= videoout_pixelRead(15 downto  8);
                 
               when READ24_8 =>
                  readstate                  <= READ24_24;
                  pixelData_R                <= videoout_pixelRead(15 downto  8);
                  
               when READ24_16 =>
                  readstate                  <= IDLE;
                  readstate24                <= READ24_8;
                  pixelData_B                <= videoout_pixelRead( 7 downto  0);
            
                when READ24_24 =>
                  readstate                  <= IDLE;
                  readstate24                <= READ24_0;
                  videoout_request.readAddr  <= videoout_request.readAddr + 1;
                  pixelData_G                <= videoout_pixelRead( 7 downto  0);
                  pixelData_B                <= videoout_pixelRead(15 downto  8);
            
            end case;
         
         end if;
         
      end if;
   end process; 

end architecture;





