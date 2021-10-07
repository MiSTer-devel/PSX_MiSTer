library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

-- todo: how does it behave when copy with srcX + widt wrapping around?

entity gpu_vram2cpu is
   port 
   (
      clk2x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      proc_idle            : in  std_logic;
      fifo_Valid           : in  std_logic;
      fifo_data            : in  std_logic_vector(31 downto 0);
      requestFifo          : out std_logic := '0';
      done                 : out std_logic := '0';
      
      requestVRAMEnable    : out std_logic;
      requestVRAMXPos      : out unsigned(9 downto 0);
      requestVRAMYPos      : out unsigned(8 downto 0);
      requestVRAMSize      : out unsigned(10 downto 0);
      requestVRAMIdle      : in  std_logic;
      requestVRAMDone      : in  std_logic;
      
      vramLineEna          : out std_logic;
      vramLineAddr         : out unsigned(9 downto 0);
      vramLineData         : in  std_logic_vector(15 downto 0);
      
      Fifo_Dout            : out std_logic_vector(31 downto 0);
      Fifo_Rd              : in  std_logic;
      Fifo_Empty           : out std_logic
   );
end entity;

architecture arch of gpu_vram2cpu is
   
   type tState is
   (
      IDLE,
      REQUESTWORD2,
      REQUESTWORD3,
      READVRAM,
      WAITREAD,
      WRITING,
      FINISH
   );
   signal state : tState := IDLE;
   
   signal srcX          : unsigned(9 downto 0);
   signal srcY          : unsigned(8 downto 0);     
   signal widt          : unsigned(10 downto 0);
   signal heig          : unsigned(9 downto 0);
                        
   signal xSrc          : unsigned(9 downto 0);
   signal xCnt          : unsigned(10 downto 0);
   signal yCnt          : unsigned(9 downto 0);
   
   --fifo
   signal Fifo_Din      : std_logic_vector(31 downto 0);
   signal Fifo_Wr       : std_logic; 
   signal Fifo_NearFull : std_logic;
   
   signal Fifo_wordhalf : std_logic;
  
begin 

   requestFifo <= '1' when (state = REQUESTWORD2 or state = REQUESTWORD3) else '0';
   
   requestVRAMEnable <= '1'  when (state = READVRAM and Fifo_NearFull = '0') else '0';
   requestVRAMXPos   <= srcX when state = READVRAM else (others => '0');
   requestVRAMYPos   <= srcY when state = READVRAM else (others => '0');
   requestVRAMSize   <= widt when state = READVRAM else (others => '0');
   
   vramLineEna       <= '1'  when (state = WRITING or state = WAITREAD) else '0';
   vramLineAddr      <= xSrc when (state = WRITING or state = WAITREAD) else (others => '0');
   
   -- fifo has size of two full lines. Filling can start whenever at least a full line fits in.
   ififo: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 1024,
      DATAWIDTH        => 32,
      NEARFULLDISTANCE => 500
   )
   port map
   ( 
      clk      => clk2x,     
      reset    => reset,   
                
      Din      => Fifo_Din,     
      Wr       => Fifo_Wr,      
      Full     => open,    
      NearFull => Fifo_NearFull,

      Dout     => Fifo_Dout,    
      Rd       => Fifo_Rd,      
      Empty    => Fifo_Empty   
   );
   
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         
         Fifo_Wr <= '0';
         
         if (reset = '1') then
         
            state <= IDLE;
         
         elsif (ce = '1') then
            
            done              <= '0';
         
            case (state) is
            
               when IDLE =>
                  yCnt          <= (others => '0');
                  Fifo_wordhalf <= '0';
                  if (proc_idle = '1' and fifo_Valid = '1' and fifo_data(31 downto 29) = "110") then
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
                     state      <= READVRAM;
                     widt       <= '0' & unsigned(fifo_data( 9 downto  0));
                     heig       <= '0' & unsigned(fifo_data(24 downto 16));
                     if (unsigned(fifo_data( 9 downto  0)) = 0) then widt <= to_unsigned(16#400#, 11); end if;
                     if (unsigned(fifo_data(24 downto 16)) = 0) then heig <= to_unsigned(16#200#, 10); end if;
                  end if;
                  
               when READVRAM =>
                  xSrc <= srcX;
                  xCnt <= (others => '0');
                  if (requestVRAMIdle = '1' and Fifo_NearFull = '0') then
                     state <= WAITREAD;
                  end if;
                  
               when WAITREAD =>
                  if (requestVRAMDone = '1') then
                     state <= WRITING; 
                     xSrc  <= xSrc + 1;
                  end if;
                  
               when WRITING => 
               
                  if (Fifo_wordhalf = '0') then
                     Fifo_Din(15 downto 0) <= vramLineData;
                     Fifo_wordhalf         <= '1';
                  else
                     Fifo_Din(31 downto 16) <= vramLineData;
                     Fifo_wordhalf          <= '0';
                     Fifo_Wr                <= '1';
                  end if;
               
                  xSrc  <= xSrc + 1;
                  xCnt  <= xCnt + 1;
                  if (xCnt + 1 = widt) then
                     srcY  <= srcY + 1;
                     yCnt  <= yCnt + 1;
                     if (yCnt + 1 = heig) then
                        state <= FINISH;
                     else
                        state <= READVRAM;
                     end if;
                  end if;
                  
               when FINISH =>
                  if (Fifo_wordhalf = '1') then
                     Fifo_Din(31 downto 16) <= x"0000";
                     Fifo_wordhalf          <= '0';
                     Fifo_Wr                <= '1';
                  end if;
                  state <= IDLE;
                  done  <= '1';
            
            end case;
         
         end if;
         
      end if;
   end process; 


end architecture;





