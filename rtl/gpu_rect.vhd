library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

entity gpu_rect is
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
      
      pipeline_busy        : in  std_logic;
      pipeline_stall       : in  std_logic;
      pipeline_new         : out std_logic := '0';
      pipeline_texture     : out std_logic := '0';
      pipeline_transparent : out std_logic := '0';
      pipeline_rawTexture  : out std_logic := '0';
      pipeline_x           : out unsigned(9 downto 0) := (others => '0');
      pipeline_y           : out unsigned(8 downto 0) := (others => '0');
      pipeline_cr          : out unsigned(7 downto 0) := (others => '0');
      pipeline_cg          : out unsigned(7 downto 0) := (others => '0');
      pipeline_cb          : out unsigned(7 downto 0) := (others => '0');
      pipeline_u           : out unsigned(7 downto 0) := (others => '0');
      pipeline_v           : out unsigned(7 downto 0) := (others => '0');
      
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
      
      textPalNew           : out std_logic := '0';
      textPalX             : out unsigned(9 downto 0) := (others => '0');   
      textPalY             : out unsigned(8 downto 0) := (others => '0'); 
      
      vramLineEna          : out std_logic;
      vramLineAddr         : out unsigned(9 downto 0)
   );
end entity;

architecture arch of gpu_rect is
   
   type tState is
   (
      IDLE,
      REQUESTPOS,
      REQUESTTEXTURE,
      REQUESTSIZE,
      CHECKPOS,
      REQUESTLINE,
      READWAIT,
      PROCPIXELS,
      WAITIMING
   );
   signal state : tState := IDLE;
   
   signal drawTiming          : unsigned(31 downto 0);
   signal targetTiming        : unsigned(31 downto 0);
   
   signal rec_texture         : std_logic := '0';
   signal rec_size            : std_logic_vector(1 downto 0) := "00";
   signal rec_transparency    : std_logic := '0';
   signal rec_rawTexture      : std_logic := '0';
      
   signal rec_color           : std_logic_vector(23 downto 0) := (others => '0');
      
   signal rec_posx            : signed(11 downto 0) := (others => '0');
   signal rec_sizex           : unsigned(9 downto 0) := (others => '0');   
   signal rec_sizey           : unsigned(8 downto 0) := (others => '0');  
   
   signal rec_u               : unsigned(7 downto 0) := (others => '0');     

   signal xPos                : signed(11 downto 0) := (others => '0'); 
   signal yPos                : signed(11 downto 0) := (others => '0');    
   signal xCnt                : unsigned(9 downto 0) := (others => '0');   
   signal yCnt                : unsigned(8 downto 0) := (others => '0');  
   signal uWork               : unsigned(7 downto 0) := (others => '0');   
   signal vWork               : unsigned(7 downto 0) := (others => '0');  

   signal firstPixel          : std_logic;
   
   signal timeout             : integer range 0 to 67108863 := 0;

begin 

   requestFifo <= '1' when (state = REQUESTPOS or state = REQUESTTEXTURE or state = REQUESTSIZE) else '0';
   
   requestVRAMEnable <= '1'                        when (state = REQUESTLINE and requestVRAMIdle = '1' and pipeline_stall = '0') else '0';
   requestVRAMXPos   <= unsigned(xPos(9 downto 0)) when (state = REQUESTLINE and requestVRAMIdle = '1' and pipeline_stall = '0') else (others => '0');
   requestVRAMYPos   <= unsigned(yPos(8 downto 0)) when (state = REQUESTLINE and requestVRAMIdle = '1' and pipeline_stall = '0') else (others => '0');
   requestVRAMSize   <= '0' & rec_sizex            when (state = REQUESTLINE and requestVRAMIdle = '1' and pipeline_stall = '0') else (others => '0');
   
   vramLineEna  <= '1' when (state = PROCPIXELS) else '0';
   vramLineAddr <= unsigned(xPos(9 downto 0)) when (state = PROCPIXELS) else (others => '0');
   
   process (clk2x)
      variable xrec12 : signed(11 downto 0);
      variable yrec12 : signed(11 downto 0);
      variable xsize  : signed(11 downto 0);
      variable ysize  : signed(11 downto 0);
      variable xdiff  : signed(11 downto 0);
      variable ydiff  : signed(11 downto 0);
      variable ynew   : signed(11 downto 0);
      variable yAdd   : integer range 1 to 2;
   begin
      if rising_edge(clk2x) then
      
         if (reset = '1') then
         
            state <= IDLE;
         
         elsif (ce = '1') then
         
            done                 <= '0';
            CmdDone              <= '0';
            
            pipeline_new         <= '0';
            pipeline_texture     <= '0';
            pipeline_transparent <= '0';
            pipeline_rawTexture  <= '0';
            pipeline_x           <= (others => '0');
            pipeline_y           <= (others => '0');
            pipeline_cr          <= (others => '0');
            pipeline_cg          <= (others => '0');
            pipeline_cb          <= (others => '0');
            pipeline_u           <= (others => '0');
            pipeline_v           <= (others => '0');
            
            textPalNew           <= '0';
            textPalX             <= (others => '0');
            textPalY             <= (others => '0');
         
            if (state /= IDLE) then
               drawTiming <= drawTiming + 1;
            end if;
            
            error <= '0';
            if (state = IDLE) then
               timeout <= 0;
            elsif (timeout < 67108863) then
               timeout  <= timeout + 1;
            else
               error <= '1';
            end if;
         
            case (state) is
            
               when IDLE =>
                  drawTiming   <= (others => '0');
                  firstPixel   <= '1';
                  if (proc_idle = '1' and fifo_Valid = '1' and fifo_data(31 downto 29) = "011") then
                     state             <= REQUESTPOS;
                     rec_texture       <= fifo_data(26);
                     rec_size          <= fifo_data(28 downto 27);
                     rec_transparency  <= fifo_data(25);
                     rec_rawTexture    <= fifo_data(24);
                     rec_color         <= fifo_data(23 downto 0);
                  end if;
                  
               when REQUESTPOS =>
                  xCnt <= (others => '0');
                  yCnt <= (others => '0');
                  case (rec_size) is
                     when "01" =>
                        rec_sizex <= to_unsigned(1, 10);
                        rec_sizey <= to_unsigned(1, 9);
                        
                     when "10" =>
                        rec_sizex <= to_unsigned(8, 10);
                        rec_sizey <= to_unsigned(8, 9);
                        
                     when "11" =>
                        rec_sizex <= to_unsigned(16, 10);
                        rec_sizey <= to_unsigned(16, 9);
                        
                     when others => null;
                  end case;
               
                  if (fifo_Valid = '1') then
                     xrec12     := resize(drawingOffsetX, 12) + signed('0' & fifo_data(10 downto  0));
                     yrec12     := resize(drawingOffsetY, 12) + signed('0' & fifo_data(26 downto 16));                     
                     rec_posx   <= resize(xrec12(10 downto 0), 12);
                     yPos       <= resize(yrec12(10 downto 0), 12);
                     
                     if (rec_texture = '1') then
                        state    <= REQUESTTEXTURE;  
                     elsif (rec_size = "00") then
                        state    <= REQUESTSIZE;  
                     else
                        state    <= CHECKPOS;
                        CmdDone  <= '1'; 
                     end if;
                  end if;
                  
               when REQUESTTEXTURE =>
                  if (fifo_Valid = '1') then
                     uWork         <= unsigned(fifo_data( 7 downto  0));
                     vWork         <= unsigned(fifo_data(15 downto  8));
                     rec_u         <= unsigned(fifo_data( 7 downto  0));
                     textPalX      <= unsigned(fifo_data(21 downto 16)) & "0000";
                     textPalY      <= unsigned(fifo_data(30 downto 22));
                     textPalNew    <= '1';
                     if (rec_size = "00") then
                        state    <= REQUESTSIZE;  
                     else
                        state    <= CHECKPOS;
                        CmdDone  <= '1'; 
                     end if;
                  end if;
            
               when REQUESTSIZE =>
                  if (fifo_Valid = '1') then
                     rec_sizex   <= unsigned(fifo_data(9 downto  0));
                     rec_sizey   <= unsigned(fifo_data(24 downto 16));
                     state       <= CHECKPOS;
                     CmdDone     <= '1'; 
                  end if;
                  
               when CHECKPOS =>
                  if (rec_transparency = '1' or rec_texture = '1') then 
                     targetTiming <= to_unsigned(50 + to_integer(rec_sizex * rec_sizey * 4), 32);
                  else
                     targetTiming <= to_unsigned(50 + to_integer(rec_sizex * rec_sizey * 2), 32);
                  end if;
               
                  xsize := to_signed(to_integer(rec_sizex), 12);
                  xdiff := (others => '0');
                  if (rec_posx < to_integer(drawingAreaLeft)) then
                     xdiff := to_signed(to_integer(drawingAreaLeft), 12) - rec_posx;
                     xsize := xsize - xdiff;
                  end if;
                  rec_posx  <= rec_posx + xdiff;
                  xPos      <= rec_posx + xdiff;
                  uWork     <= uWork + unsigned(xdiff(7 downto 0));
                  rec_u     <= rec_u + unsigned(xdiff(7 downto 0));
                  rec_sizex <= unsigned(xsize(9 downto 0)); 
               
                  ysize := to_signed(to_integer(rec_sizey), 12);
                  ydiff := (others => '0');
                  if (to_integer(yPos) < to_integer(drawingAreaTop)) then
                     ydiff := to_signed(to_integer(drawingAreaTop), 12) - yPos;
                     ysize := ysize - ydiff;
                  end if;
                  ynew := yPos + ydiff;
                  if (interlacedDrawing = '1' and (activeLineLSB = ynew(0))) then
                     ydiff := ydiff + 1;
                     ysize := ysize - 1;
                  end if;
                  yPos      <= yPos + ydiff;
                  vWork     <= vWork + unsigned(ydiff(7 downto 0));
                  rec_sizey <= unsigned(ysize(8 downto 0)); 
                  
                  if (xsize < 1 or ysize < 1 or rec_posx > to_integer(drawingAreaRight) or yPos > to_integer(drawingAreaBottom)) then
                     if (REPRODUCIBLEGPUTIMING = '1') then
                        state <= WAITIMING;
                     else
                        state <= IDLE;
                        done  <= '1';
                     end if;
                  elsif (rec_transparency = '1' or DrawPixelsMask = '1') then
                     state  <= REQUESTLINE;
                  else
                     state  <= PROCPIXELS;
                  end if;
                       
               when REQUESTLINE =>
                  if (pipeline_stall = '0' and requestVRAMIdle = '1') then
                     state  <= READWAIT;
                  end if;
                  
               when READWAIT =>
                  if (requestVRAMDone = '1') then
                     state <= PROCPIXELS;
                  end if;
               
               when PROCPIXELS =>
                  if (pipeline_stall = '0' and (firstPixel = '0' or pipeline_busy = '0')) then
                     firstPixel <= '0';
                  
                     xCnt  <= xCnt + 1;
                     xPos  <= xPos + 1;
                     uWork <= uWork + 1;
                     
                     if (xCnt + 1 >= rec_sizex or xPos + 1 > to_integer(drawingAreaRight)) then
                        yAdd := 1;
                        if (interlacedDrawing = '1') then
                           yAdd := 2;
                        end if;
                        yCnt  <= yCnt + yAdd;
                        ypos  <= yPos + yAdd;
                        vWork <= vWork + yAdd;
                        if (yCnt + yAdd >= rec_sizey or ypos + yAdd > to_integer(drawingAreaBottom)) then
                           if (REPRODUCIBLEGPUTIMING = '1') then
                              state <= WAITIMING;
                           else
                              state <= IDLE;
                              done  <= '1';
                           end if;
                        else
                           xPos  <= rec_posx;
                           xCnt  <= (others => '0');
                           uWork <= rec_u;
                           if (rec_transparency = '1' or DrawPixelsMask = '1') then
                              state <= REQUESTLINE;
                           end if;
                        end if;
                     end if; 
                     
                     if (xPos >= to_integer(drawingAreaLeft) and xPos <= to_integer(drawingAreaRight) and ypos >= to_integer(drawingAreaTop) and ypos <= to_integer(drawingAreaBottom)) then
                        pipeline_new         <= '1';
                        pipeline_texture     <= rec_texture;
                        pipeline_transparent <= rec_transparency;
                        pipeline_rawTexture  <= rec_rawTexture;
                        pipeline_x           <= unsigned(xPos(9 downto 0));
                        pipeline_y           <= unsigned(yPos(8 downto 0));
                        pipeline_cr          <= unsigned(rec_color( 7 downto  0));
                        pipeline_cg          <= unsigned(rec_color(15 downto  8));
                        pipeline_cb          <= unsigned(rec_color(23 downto 16));
                        pipeline_u           <= uWork;
                        pipeline_v           <= vWork;
                     end if;
                  end if;
               
                  if (drawingAreaLeft > drawingAreaRight or drawingAreaTop > drawingAreaBottom) then
                     if (REPRODUCIBLEGPUTIMING = '1') then
                        state <= WAITIMING;
                     else
                        state <= IDLE;
                        done  <= '1';
                     end if;
                  end if;
                  
                when WAITIMING =>
                  if (clk2xIndex = '0' and drawTiming + 4 >= targetTiming) then
                     state <= IDLE;
                     done  <= '1';
                  end if;
                       
            end case;
         
         end if;
         
      end if;
   end process; 


end architecture;





