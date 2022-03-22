library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

-- todo: how does it behave when copy with srcX + widt wrapping around?

-- todo: if (width == 0 || height == 0 || (srcX == dstX && srcY == dstY && !((PSXRegs.GPUSTAT >> 11) & 1))) -> don't draw

entity gpu_vram2vram is
   port 
   (
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      DrawPixelsMask       : in  std_logic;
      SetMask              : in  std_logic;
      
      REPRODUCIBLEGPUTIMING: in  std_logic;
      
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
      vramLineAddr         : out unsigned(9 downto 0);
      vramLineData         : in  std_logic_vector(15 downto 0);
      
      pixelEmpty           : in  std_logic;
      pixelStall           : in  std_logic;
      pixelColor           : out std_logic_vector(15 downto 0);
      pixelAddr            : out unsigned(19 downto 0);
      pixelWrite           : out std_logic
   );
end entity;

architecture arch of gpu_vram2vram is
   
   type tState is
   (
      IDLE,
      REQUESTWORD2,
      REQUESTWORD3,
      REQUESTWORD4,
      READVRAM,
      WAITREAD,
      WAITIMING,
      READFIRST,
      WRITING
   );
   signal state : tState := IDLE;
   
   signal srcX         : unsigned(9 downto 0);
   signal srcY         : unsigned(8 downto 0);   
   signal dstX         : unsigned(9 downto 0);
   signal dstY         : unsigned(8 downto 0);   
   signal widt         : unsigned(10 downto 0);
   signal heig         : unsigned(9 downto 0);
   
   signal dir          : std_logic;
                       
   signal xSrc         : unsigned(9 downto 0);
   signal xDst         : unsigned(9 downto 0);
   signal xCnt         : unsigned(10 downto 0);
   signal yCnt         : unsigned(9 downto 0);
   
   signal drawTiming   : unsigned(6 downto 0);
  
begin 

   requestFifo <= '1' when (state = REQUESTWORD2 or state = REQUESTWORD3 or state = REQUESTWORD4) else '0';
   
   requestVRAMEnable <= '1'  when (state = READVRAM and requestVRAMIdle = '1') else '0';
   requestVRAMXPos   <= srcX when (state = READVRAM and requestVRAMIdle = '1') else (others => '0');
   requestVRAMYPos   <= srcY when (state = READVRAM and requestVRAMIdle = '1') else (others => '0');
   requestVRAMSize   <= widt when (state = READVRAM and requestVRAMIdle = '1') else (others => '0');
   
   vramLineEna       <= '1'  when (state = WRITING or state = READFIRST) else '0';
   vramLineAddr      <= xSrc when (state = WRITING or state = READFIRST) else (others => '0');
   
   process (clk2x)
      variable srcXCheck : unsigned(9 downto 0);
      variable dstXCheck : unsigned(9 downto 0);
   begin
      if rising_edge(clk2x) then
         
         if (reset = '1') then
         
            state <= IDLE;
         
         elsif (ce = '1') then
         
            pixelColor        <= (others => '0');
            pixelAddr         <= (others => '0');
            pixelWrite        <= '0';
            
            done              <= '0';
            CmdDone           <= '0';
            
            if (state /= IDLE) then
               drawTiming <= drawTiming + 1;
            end if;
         
         
            case (state) is
            
               when IDLE =>
                  yCnt <= (others => '0');
                  if (proc_idle = '1' and fifo_Valid = '1' and fifo_data(31 downto 29) = "100") then
                     state <= REQUESTWORD2;
                  end if;
                  
               when REQUESTWORD2 =>
                  if (fifo_Valid = '1') then
                     state    <= REQUESTWORD3;  
                     srcX <= unsigned(fifo_data( 9 downto  0));
                     srcY <= unsigned(fifo_data(24 downto 16));
                  end if;
            
               when REQUESTWORD3 =>
                  if (fifo_Valid = '1') then
                     state    <= REQUESTWORD4;  
                     dstX <= unsigned(fifo_data( 9 downto  0));
                     dstY <= unsigned(fifo_data(24 downto 16));
                  end if;
            
               when REQUESTWORD4 =>
                  dir <= '0';
                  srcXCheck := srcX + unsigned(fifo_data(9 downto 0)) - 1;
                  dstXCheck := dstX + unsigned(fifo_data(9 downto 0)) - 1;
                  if (srcX < dstX or (srcXCheck < dstXCheck)) then
                     dir <= '1';
                  end if;
                  
                  if (fifo_Valid = '1') then
                     CmdDone    <= '1';
                     state      <= READVRAM;
                     widt       <= '0' & unsigned(fifo_data( 9 downto  0));
                     heig       <= '0' & unsigned(fifo_data(24 downto 16));
                     if (unsigned(fifo_data( 9 downto  0)) = 0) then widt <= to_unsigned(16#400#, 11); end if;
                     if (unsigned(fifo_data(24 downto 16)) = 0) then heig <= to_unsigned(16#200#, 10); end if;
                  end if;
                  
               when READVRAM =>
                  if (dir = '1') then
                     xSrc <= resize(srcX + widt - 1, 10);
                     xDst <= resize(dstX + widt - 1, 10);
                  else
                     xSrc <= srcX;
                     xDst <= dstX;
                  end if;

                  xCnt <= (others => '0');
                  if (requestVRAMIdle = '1') then
                     state      <= WAITREAD;
                     drawTiming <= (others => '0');
                  end if;
                  
               when WAITREAD =>
                  if (requestVRAMDone = '1') then
                     if (REPRODUCIBLEGPUTIMING = '1') then
                        state <= WAITIMING;
                     else
                        state <= READFIRST;
                     end if;
                  end if;
                  
               when WAITIMING =>
                  if (drawTiming >= 80) then
                     state <= READFIRST; 
                  end if;
                  
               when READFIRST => 
                  if (pixelEmpty = '1') then
                     state <= WRITING; 
                     if (dir = '1') then
                        xSrc <= xSrc - 1;
                     else
                        xSrc <= xSrc + 1;
                     end if;
                  end if;
                  
               when WRITING => 
                  if (DrawPixelsMask = '0' or vramLineData(15) = '0') then
                     pixelWrite <= '1';
                  end if;  
                   
                  pixelAddr  <= dstY & xDst & '0';
                  pixelColor <= vramLineData;
                  
                  if (SetMask = '1') then
                     pixelColor(15) <= '1';
                  end if;
               
                  if (dir = '1') then
                     xSrc  <= xSrc - 1;
                     xDst  <= xDst - 1;
                  else
                     xSrc  <= xSrc + 1;
                     xDst  <= xDst + 1;
                  end if;
                  
                  xCnt  <= xCnt + 1;
                  if (xCnt + 1 = widt) then
                     srcY  <= srcY + 1;
                     dstY  <= dstY + 1;
                     yCnt  <= yCnt + 1;
                     if (yCnt + 1 = heig) then
                        state <= IDLE;
                        done  <= '1';
                     else
                        state <= READVRAM;
                     end if;
                  end if;
            
            end case;
         
         end if;
         
      end if;
   end process; 


end architecture;





