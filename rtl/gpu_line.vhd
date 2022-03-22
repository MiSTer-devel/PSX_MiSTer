library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pGPU.all;

entity gpu_line is
   port 
   (
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      REPRODUCIBLEGPUTIMING: in  std_logic;
      
      error                : out std_logic;
      
      DrawPixelsMask       : in  std_logic;
      interlacedDrawing    : in  std_logic;
      activeLineLSB        : in  std_logic;
      drawingOffsetX       : in  signed(10 downto 0);
      drawingOffsetY       : in  signed(10 downto 0);
      drawingAreaLeft      : in  unsigned(9 downto 0);
      drawingAreaRight     : in  unsigned(9 downto 0);
      drawingAreaTop       : in  unsigned(8 downto 0);
      drawingAreaBottom    : in  unsigned(8 downto 0);
      
      div1                 : inout div_type; 
      div2                 : inout div_type; 
      div3                 : inout div_type; 
      div4                 : inout div_type; 
      div5                 : inout div_type; 
      div6                 : inout div_type; 
      
      pipeline_busy        : in  std_logic;
      pipeline_stall       : in  std_logic;
      pipeline_new         : out std_logic := '0';
      pipeline_transparent : out std_logic := '0';
      pipeline_x           : out unsigned(9 downto 0) := (others => '0');
      pipeline_y           : out unsigned(8 downto 0) := (others => '0');
      pipeline_cr          : out unsigned(7 downto 0) := (others => '0');
      pipeline_cg          : out unsigned(7 downto 0) := (others => '0');
      pipeline_cb          : out unsigned(7 downto 0) := (others => '0');
      
      proc_idle            : in  std_logic;
      fifo_Valid           : in  std_logic;
      fifo_data            : in  std_logic_vector(31 downto 0);
      requestFifo          : out std_logic := '0';
      done                 : out std_logic := '0';
      CmdDone              : out std_logic := '0';
      
      requestVRAMEnable    : out std_logic;
      requestVRAMXPos      : out unsigned(9 downto 0);
      requestVRAMYPos      : out unsigned(8 downto 0);
      requestVRAMSize      : out unsigned(10 downto 0);
      requestVRAMIdle      : in  std_logic;
      requestVRAMDone      : in  std_logic;
      
      vramLineEna          : out std_logic;
      vramLineAddr         : out unsigned(9 downto 0)
   );
end entity;

architecture arch of gpu_line is
   
   -- receive
   type trecState is
   (
      REQUESTIDLE,
      REQUESTPOS1,
      REQUESTCOLOR2,
      REQUESTPOS2,
      REQUESTWAITDONE,
      REQUESTWAITIMING
   );
   signal recstate : trecState := REQUESTIDLE;
   
   signal drawTiming          : unsigned(31 downto 0);
   signal targetTiming        : unsigned(31 downto 0);
   
   signal rec_polyline        : std_logic := '0';
   signal rec_shading         : std_logic := '0';
   signal rec_transparency    : std_logic := '0';
      
   signal rec_color1          : std_logic_vector(23 downto 0) := (others => '0');
   signal rec_color2          : std_logic_vector(23 downto 0) := (others => '0');
      
   signal rec_pos1x           : signed(11 downto 0) := (others => '0');
   signal rec_pos1y           : signed(11 downto 0) := (others => '0');   
   signal rec_pos2x           : signed(11 downto 0) := (others => '0');
   signal rec_pos2y           : signed(11 downto 0) := (others => '0');
   
   signal swap12              : std_logic := '0';
   signal checkEnd            : std_logic := '0';
   
   -- fifo
   signal fifoLine_Din        : std_logic_vector(97 downto 0);
   signal fifoLine_Wr         : std_logic := '0'; 
   signal fifoLine_Full       : std_logic;
   signal fifoLine_Dout       : std_logic_vector(97 downto 0);
   signal fifoLine_Rd         : std_logic;
   signal fifoLine_Empty      : std_logic;
   signal fifoLine_Valid      : std_logic;
   
   -- base line handling
   type tprocState is
   (
      PROCIDLE,
      PROCRECEIVE,
      PROCCALC1,
      PROCCALC2,
      PROCCALC3,
      PROCREADLINE,
      PROCREADWAIT,
      PROCPIXELS
   );
   signal procstate : tprocState := PROCIDLE;
   
   signal proc_shading        : std_logic := '0';
   signal proc_transparency   : std_logic := '0';
          
   signal proc_color1         : std_logic_vector(23 downto 0) := (others => '0');
   signal proc_color2         : std_logic_vector(23 downto 0) := (others => '0');
          
   signal proc_pos1x          : signed(11 downto 0) := (others => '0');
   signal proc_pos1y          : signed(11 downto 0) := (others => '0');   
   signal proc_pos2x          : signed(11 downto 0) := (others => '0');
   signal proc_pos2y          : signed(11 downto 0) := (others => '0');
   
   signal points              : unsigned(9 downto 0) := (others => '0');
   signal singlePixelLines    : std_logic := '0';
   
   signal stepDx              : signed(43 downto 0) := (others => '0');
   signal stepDy              : signed(43 downto 0) := (others => '0');
   signal stepDr              : signed(19 downto 0) := (others => '0');
   signal stepDg              : signed(19 downto 0) := (others => '0');
   signal stepDb              : signed(19 downto 0) := (others => '0');   
   
   signal workx               : signed(44 downto 0) := (others => '0');
   signal worky               : signed(44 downto 0) := (others => '0');
   signal workr               : signed(20 downto 0) := (others => '0');
   signal workg               : signed(20 downto 0) := (others => '0');
   signal workb               : signed(20 downto 0) := (others => '0');
   
   signal yPerLine            : unsigned(10 downto 0) := (others => '0');
   
   signal pixelCnt            : unsigned(9 downto 0) := (others => '0');
   
   signal firstPixel          : std_logic;
   
   signal timeout             : integer range 0 to 67108863 := 0;

begin 

   requestFifo <= '1' when (recstate = REQUESTPOS1 or recstate = REQUESTCOLOR2 or recstate = REQUESTPOS2) else '0';
   
   requestVRAMEnable <= '1'                           when (procstate = PROCREADLINE and requestVRAMIdle = '1' and pipeline_stall = '0') else '0';
   requestVRAMXPos   <= unsigned(workx(41 downto 32)) when (procstate = PROCREADLINE and requestVRAMIdle = '1' and pipeline_stall = '0') else (others => '0');
   requestVRAMYPos   <= unsigned(worky(40 downto 32)) when (procstate = PROCREADLINE and requestVRAMIdle = '1' and pipeline_stall = '0') else (others => '0');
   requestVRAMSize   <= yPerLine                      when (procstate = PROCREADLINE and requestVRAMIdle = '1' and pipeline_stall = '0') else (others => '0');
   
   vramLineEna  <= '1' when (procstate = PROCPIXELS) else '0';
   vramLineAddr <= unsigned(workx(41 downto 32)) when (procstate = PROCPIXELS) else (others => '0');
   
   -- receive details
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         
         if (reset = '1') then
         
            recstate <= REQUESTIDLE;
            checkEnd <= '0';
         
         elsif (ce = '1') then
         
            done         <= '0';
            CmdDone      <= '0';
            fifoLine_Wr  <= '0';
            swap12       <= '0';
         
            if (swap12 = '1') then
               rec_pos1x  <= rec_pos2x;
               rec_pos1y  <= rec_pos2y;
               if (rec_shading = '1') then
                  rec_color1 <= rec_color2;
               end if;
            end if;
            
            if (recstate /= REQUESTIDLE) then
               drawTiming <= drawTiming + 1;
            end if;
            
            error <= '0';
            if (recstate = REQUESTIDLE) then
               timeout <= 0;
            elsif (timeout < 67108863) then
               timeout  <= timeout + 1;
            else
               error <= '1';
            end if;
            
            if (fifoLine_Full = '1') then
               error <= '1';
            end if;
         
            case (recstate) is
            
               when REQUESTIDLE =>
                  drawTiming   <= (others => '0');
                  targetTiming <= (others => '0');
                  if (proc_idle = '1' and fifo_Valid = '1' and fifo_data(31 downto 29) = "010") then
                     recstate          <= REQUESTPOS1;
                     rec_polyline      <= fifo_data(27);
                     rec_shading       <= fifo_data(28);
                     rec_transparency  <= fifo_data(25);
                     rec_color1        <= fifo_data(23 downto 0);
                     checkEnd          <= '0';
                  end if;
                  
               when REQUESTPOS1 =>
                  if (fifo_Valid = '1') then
                     rec_pos1x   <= resize(signed(fifo_data(10 downto  0)),12) + resize(drawingOffsetX, 12);
                     rec_pos1y   <= resize(signed(fifo_data(26 downto 16)),12) + resize(drawingOffsetY, 12);
                     if (rec_shading = '0') then
                        recstate    <= REQUESTPOS2;  
                     else
                        recstate    <= REQUESTCOLOR2;  
                     end if;
                  end if;
                  
               when REQUESTCOLOR2 =>
                  if (fifo_Valid = '1') then
                     rec_color2     <= fifo_data(23 downto 0);
                     recstate       <= REQUESTPOS2;  
                     if (checkEnd = '1' and rec_shading = '1' and fifo_data(31 downto 28) = x"5" and fifo_data(15 downto 12) = x"5") then
                        recstate  <= REQUESTWAITDONE; 
                        CmdDone   <= '1';                        
                     end if;
                  end if;
            
               when REQUESTPOS2 =>
                  if (fifo_Valid = '1') then
                     rec_pos2x   <= resize(signed(fifo_data(10 downto  0)),12) + resize(drawingOffsetX, 12);
                     rec_pos2y   <= resize(signed(fifo_data(26 downto 16)),12) + resize(drawingOffsetY, 12);
                     swap12      <= '1';
                     if (rec_polyline = '1') then
                        checkEnd    <= '1';
                        if (checkEnd = '1' and rec_shading = '0' and fifo_data(31 downto 28) = x"5" and fifo_data(15 downto 12) = x"5") then
                           recstate  <= REQUESTWAITDONE; 
                           CmdDone   <= '1';                           
                        else
                           fifoLine_Wr  <= '1';
                           targetTiming <= targetTiming + 1000;
                           if (rec_shading = '0') then
                              recstate    <= REQUESTPOS2;  
                           else
                              recstate    <= REQUESTCOLOR2;  
                           end if;
                        end if;
                     else
                        targetTiming <= targetTiming + 1000; 
                        fifoLine_Wr <= '1';
                        recstate    <= REQUESTWAITDONE;  
                        CmdDone     <= '1';
                     end if;
                  end if;
                  
               when REQUESTWAITDONE =>
                  if (procstate = PROCIDLE and fifoLine_Empty = '1' and fifoLine_Wr = '0') then
                     if (REPRODUCIBLEGPUTIMING = '1') then
                        recstate    <= REQUESTWAITIMING;  
                     else
                        recstate    <= REQUESTIDLE;  
                        done        <= '1';
                     end if;
                  end if;
                  
               when REQUESTWAITIMING =>
                  if (drawTiming + 2 >= targetTiming) then
                     recstate <= REQUESTIDLE;
                     done     <= '1';
                  end if;
                       
            end case;
         
         end if;
         
      end if;
   end process; 
   
   -- fifowidth          1                 1            24                          12                           12              24                          12                            12
   fifoLine_Din <= rec_shading & rec_transparency & rec_color2 & std_logic_vector(rec_pos2y) & std_logic_vector(rec_pos2x) & rec_color1 & std_logic_vector(rec_pos1y) & std_logic_vector(rec_pos1x);
   
   iFifoLines: entity mem.SyncFifo
   generic map
   (
      SIZE             => 64,
      DATAWIDTH        => 98,  -- 2 bit status + 2 * (2bit color + 2 * 12bit position)
      NEARFULLDISTANCE => 60
   )
   port map
   ( 
      clk      => clk2x,
      reset    => reset,  
      Din      => fifoLine_Din,     
      Wr       => fifoLine_Wr,      
      Full     => fifoLine_Full,    
      NearFull => open,
      Dout     => fifoLine_Dout,    
      Rd       => fifoLine_Rd,      
      Empty    => fifoLine_Empty   
   );
   
   fifoLine_Rd <= '1' when (fifoLine_Empty = '0' and procstate = PROCIDLE) else '0';

   -- process lines
   process (clk2x)
      variable dx    : signed(11 downto 0);
      variable dy    : signed(11 downto 0);
      variable drawx : signed(10 downto 0);
      variable drawy : signed(10 downto 0);
      variable nexty : signed(44 downto 0);
   begin
      if rising_edge(clk2x) then
         
         if (reset = '1') then
         
            procstate <= PROCIDLE;
         
         elsif (ce = '1') then
         
            pipeline_new         <= '0';
            pipeline_transparent <= '0';
            pipeline_x           <= (others => '0');
            pipeline_y           <= (others => '0');
            pipeline_cr          <= (others => '0');
            pipeline_cg          <= (others => '0');
            pipeline_cb          <= (others => '0');
            
            div1.start           <= '0';
            div2.start           <= '0';
            div3.start           <= '0';
            div4.start           <= '0';
            div5.start           <= '0';
            div6.start           <= '0';
            
            div1.dividend        <= (others => '0');
            div2.dividend        <= (others => '0');
            div3.dividend        <= (others => '0');
            div4.dividend        <= (others => '0');
            div5.dividend        <= (others => '0');
            div6.dividend        <= (others => '0');
            
            div1.divisor         <= (others => '0');
            div2.divisor         <= (others => '0');
            div3.divisor         <= (others => '0');
            div4.divisor         <= (others => '0');
            div5.divisor         <= (others => '0');
            div6.divisor         <= (others => '0');
            
            case (procstate) is
            
               when PROCIDLE =>
                  firstPixel   <= '1';
                  if (fifoLine_Empty = '0') then
                     procstate <= PROCRECEIVE;
                  end if;
                       
               when PROCRECEIVE =>   
                  procstate            <= PROCCALC1;
                  proc_pos1x           <= signed(fifoLine_Dout(11 downto  0));          
                  proc_pos1y           <= signed(fifoLine_Dout(23 downto 12));
                  proc_color1          <= fifoLine_Dout(47 downto 24);        
                  proc_pos2x           <= signed(fifoLine_Dout(59 downto 48)); 
                  proc_pos2y           <= signed(fifoLine_Dout(71 downto 60));
                  proc_color2          <= fifoLine_Dout(95 downto 72);        
                  proc_transparency    <= fifoLine_Dout(96);
                  proc_shading          <= fifoLine_Dout(97);            
                       
               when PROCCALC1 =>
                  procstate   <= PROCCALC2;
                  workx       <= resize(proc_pos1x & x"80000000", 45) - 1024;
                  worky       <= resize(proc_pos1y & x"80000000", 45); 
                  workr       <= '0' & signed(proc_color1( 7 downto  0)) & x"800";
                  workg       <= '0' & signed(proc_color1(15 downto  8)) & x"800";
                  workb       <= '0' & signed(proc_color1(23 downto 16)) & x"800";
                  dx          := abs(proc_pos2x - proc_pos1x);
                  dy          := abs(proc_pos2y - proc_pos1y);
                  if (dx > dy) then 
                     points            <= unsigned(dx(9 downto 0)); 
                     singlePixelLines  <= '0';
                  else
                     if (dy(9 downto 0) = 0) then 
                        if (proc_transparency = '1' or DrawPixelsMask = '1') then
                           procstate <= PROCREADLINE;
                        else
                           procstate <= PROCPIXELS;
                        end if;
                     end if;
                     points            <= unsigned(dy(9 downto 0));
                     singlePixelLines  <= '1';
                     yPerLine          <= to_unsigned(1, 11);
                  end if;
                  if (dx >= 16#400# or dy >= 16#200#) then
                     procstate <= PROCIDLE;
                  end if;
                  if (proc_pos1x >= proc_pos2x) then
                     proc_pos1x  <= proc_pos2x; 
                     proc_pos1y  <= proc_pos2y; 
                     proc_pos2x  <= proc_pos1x; 
                     proc_pos2y  <= proc_pos1y; 
                     if (proc_shading = '1') then
                        proc_color1 <= proc_color2;
                        proc_color2 <= proc_color1;
                     end if;
                  end if;
                  
               when PROCCALC2 =>   
                  procstate   <= PROCCALC3;
                  div1.start     <= '1';
                  dx := proc_pos2x - proc_pos1x;
                  if (dx < 0) then div1.dividend <= (resize(dx, 13) & x"00000000") - to_integer(points - 1);
                  else             div1.dividend <= (resize(dx, 13) & x"00000000") + to_integer(points - 1); end if;
                  div1.divisor   <= "000" & x"000" & signed(points);
                  
                  div2.start     <= '1';
                  dy := proc_pos2y - proc_pos1y;
                  if (dy < 0) then div2.dividend <= (resize(dy, 13) & x"00000000") - to_integer(points - 1);
                  else             div2.dividend <= (resize(dy, 13) & x"00000000") + to_integer(points - 1); end if;
                  div2.divisor   <= "000" & x"000" & signed(points);
                  
                  div3.start     <= '1';
                  div3.dividend  <= (('0' & x"000000" & signed(proc_color2(7 downto 0))) - (x"000000" & signed(proc_color1(7 downto 0)))) & x"000";
                  div3.divisor   <= "000" & x"000" & signed(points);
                  
                  div4.start     <= '1';
                  div4.dividend  <= (('0' & x"000000" & signed(proc_color2(15 downto 8))) - (x"000000" & signed(proc_color1(15 downto 8)))) & x"000";
                  div4.divisor   <= "000" & x"000" & signed(points);
                  
                  div5.start     <= '1';
                  div5.dividend  <= (('0' & x"000000" & signed(proc_color2(23 downto 16))) - (x"000000" & signed(proc_color1(23 downto 16)))) & x"000";
                  div5.divisor   <= "000" & x"000" & signed(points);

                  -- calculate pixels per line for transparency readback
                  div6.start     <= '1';
                  div6.dividend  <= "000" & x"00000000" & signed(points);
                  div6.divisor   <= "0" & x"000" & (abs(proc_pos2y - proc_pos1y));
                  
               when PROCCALC3 =>
                  pixelCnt  <= (others => '0');
                  workx <= resize(proc_pos1x & x"80000000", 45) - 1024;
                  if (div2.quotient < 0) then 
                     worky <= resize(proc_pos1y & x"80000000", 45) - 1024;
                  else                        
                     worky <= resize(proc_pos1y & x"80000000", 45); 
                  end if;
                  workr <= '0' & signed(proc_color1( 7 downto  0)) & x"800";
                  workg <= '0' & signed(proc_color1(15 downto  8)) & x"800";
                  workb <= '0' & signed(proc_color1(23 downto 16)) & x"800";
                  if (div1.done = '1') then
                     if (proc_transparency = '1' or DrawPixelsMask = '1') then
                        procstate <= PROCREADLINE;
                     else
                        procstate <= PROCPIXELS;
                     end if;
                     stepDx   <= div1.quotient(43 downto 0);
                     stepDy   <= div2.quotient(43 downto 0);
                     stepDr   <= div3.quotient(19 downto 0);
                     stepDg   <= div4.quotient(19 downto 0);
                     stepDb   <= div5.quotient(19 downto 0);
                     if (singlePixelLines = '0') then
                        yPerLine <= resize(unsigned(div6.quotient(9 downto 0)),11) + 1;
                     end if;
                  end if;
                  
               when PROCREADLINE =>
                  if (pipeline_stall = '0' and requestVRAMIdle = '1') then
                     procstate         <= PROCREADWAIT;
                  end if;
                  
               when PROCREADWAIT =>
                  if (requestVRAMDone = '1') then
                     procstate <= PROCPIXELS;
                  end if;
                  
               when PROCPIXELS =>
                  if (pipeline_stall = '0' and (firstPixel = '0' or pipeline_busy = '0')) then
                     firstPixel <= '0';
                     
                     pixelCnt <= pixelCnt + 1;
                     
                     nexty := worky + stepDy;
                     if (pixelCnt >= points) then
                        procstate <= PROCIDLE;
                     elsif ((proc_transparency = '1' or DrawPixelsMask = '1') and nexty(40 downto 32) /= worky(40 downto 32)) then
                        procstate <= PROCREADLINE;
                     end if;
                     
                     drawx := workx(42 downto 32);
                     drawy := worky(42 downto 32);
                     
                     if (interlacedDrawing = '0' or (activeLineLSB /= drawy(0))) then
                        if (drawx >= to_integer(drawingAreaLeft) and drawx <= to_integer(drawingAreaRight) and drawy >= to_integer(drawingAreaTop) and drawy <= to_integer(drawingAreaBottom)) then
                           pipeline_new         <= '1';
                           pipeline_transparent <= proc_transparency;
                           pipeline_x           <= unsigned(drawx(9 downto 0));
                           pipeline_y           <= unsigned(drawy(8 downto 0));
                           if (proc_shading = '0') then
                              pipeline_cr       <= unsigned(proc_color1( 7 downto  0));
                              pipeline_cg       <= unsigned(proc_color1(15 downto  8));
                              pipeline_cb       <= unsigned(proc_color1(23 downto 16));
                           else
                              pipeline_cr       <= unsigned(workr(19 downto 12));
                              pipeline_cg       <= unsigned(workg(19 downto 12));
                              pipeline_cb       <= unsigned(workb(19 downto 12));
                           end if;
                        end if;
                     end if;
                     
                     workx <= workx + stepDx;
                     worky <= worky + stepDy;
                     workr <= workr + stepDr;
                     workg <= workg + stepDg;
                     workb <= workb + stepDb;
                  end if;
                       
            end case;
         
         end if;
         
      end if;
   end process; 
   

end architecture;





