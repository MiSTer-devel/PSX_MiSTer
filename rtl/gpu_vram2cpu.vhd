library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;

-- todo: how does it behave when copy with srcX + widt wrapping around?

entity gpu_vram2cpu is
   port 
   (
      clk2x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      drawer_reset         : in  std_logic;
      
      REPRODUCIBLEGPUTIMING: in  std_logic;
      
      proc_idle            : in  std_logic;
      fifo_Valid           : in  std_logic;
      fifo_data            : in  std_logic_vector(31 downto 0);
      requestFifo          : out std_logic := '0';
      done                 : out std_logic := '0';
      CmdDone              : out std_logic := '0';
      
      pipeline_busy        : in  std_logic;
      fifoOut_idle         : in  std_logic;
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
      Fifo_Empty           : out std_logic;
      Fifo_ready           : out std_logic
   );
end entity;

architecture arch of gpu_vram2cpu is
   
   type tState is
   (
      IDLE,
      REQUESTWORD2,
      REQUESTWORD3,
      REQUESTFIRST,
      READVRAM,
      WAITREAD,
      WAITIMING,
      WRITING,
      FINISH,
      WAITLAST1,
      WAITLAST2
   );
   signal state : tState := IDLE;
   
   signal srcX          : unsigned(9 downto 0);
   signal srcY          : unsigned(8 downto 0);     
   signal widt          : unsigned(10 downto 0);
   signal widtVram      : unsigned(10 downto 0);
   signal heig          : unsigned(9 downto 0);
                        
   signal xSrc          : unsigned(9 downto 0);
   signal xCnt          : unsigned(10 downto 0);
   signal yCnt          : unsigned(9 downto 0);
   
   signal drawTiming    : unsigned(6 downto 0);
   
   --fifo
   signal Fifo_Din         : std_logic_vector(31 downto 0);
   signal Fifo_Wr          : std_logic; 
   signal Fifo_NearFull    : std_logic;
   signal Fifo_Reset       : std_logic;
      
   signal Fifo_wordhalf    : std_logic;
  
begin 

   requestFifo <= '1' when (state = REQUESTWORD2 or state = REQUESTWORD3) else '0';
   
   requestVRAMEnable <= '1'      when (state = READVRAM and requestVRAMIdle = '1' and Fifo_NearFull = '0') else '0';
   requestVRAMXPos   <= srcX     when (state = READVRAM and requestVRAMIdle = '1')                         else (others => '0');
   requestVRAMYPos   <= srcY     when (state = READVRAM and requestVRAMIdle = '1')                         else (others => '0');
   requestVRAMSize   <= widtVram when (state = READVRAM and requestVRAMIdle = '1')                         else (others => '0');
   
   vramLineEna       <= '1'  when (state = WRITING or state = WAITREAD or state = WAITIMING) else '0';
   vramLineAddr      <= xSrc when (state = WRITING or state = WAITREAD or state = WAITIMING) else (others => '0');
   
   Fifo_ready        <= '1' when (Fifo_Empty = '0' or state = IDLE) else '0';
   
   -- fifo has size of two full lines. Filling can start whenever at least a full line fits in.
   ififo: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE              => 1024,
      DATAWIDTH         => 32,
      NEARFULLDISTANCE  => 500,
      NEAREMPTYDISTANCE => 16
   )
   port map
   ( 
      clk         => clk2x,     
      reset       => Fifo_Reset,   
                  
      Din         => Fifo_Din,     
      Wr          => Fifo_Wr,      
      Full        => open,    
      NearFull    => Fifo_NearFull,
   
      Dout        => Fifo_Dout,    
      Rd          => Fifo_Rd,      
      Empty       => Fifo_Empty,
      NearEmpty   => open      
   );
   
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         
         Fifo_Wr    <= '0';
         Fifo_Reset <= '0';
        
         -- must be done here, so it also is effected when ce is off = paused
         if (state = WAITREAD) then
            if (requestVRAMDone = '1') then
               if (REPRODUCIBLEGPUTIMING = '1') then
                  state <= WAITIMING;
               else
                  state <= WRITING; 
                  xSrc  <= xSrc + 1;
               end if;
            end if;
         end if;
         
         if (reset = '1') then
         
            state       <= IDLE;
            Fifo_Reset  <= '1';
         
         elsif (ce = '1') then
            
            done        <= '0';
            CmdDone     <= '0';
         
            if (state /= IDLE) then
               drawTiming <= drawTiming + 1;
            end if;
         
            case (state) is
            
               when IDLE =>
                  yCnt          <= (others => '0');
                  Fifo_wordhalf <= '0';
                  if (proc_idle = '1' and fifo_Valid = '1' and fifo_data(31 downto 29) = "110") then
                     state <= REQUESTWORD2;
                  end if;
                  
               when REQUESTWORD2 =>
                  Fifo_Reset   <= '1';
                  if (fifo_Valid = '1') then
                     state    <= REQUESTWORD3;  
                     srcX <= unsigned(fifo_data( 9 downto  0));
                     srcY <= unsigned(fifo_data(24 downto 16));
                  end if;
            
               when REQUESTWORD3 =>
                  if (fifo_Valid = '1') then
                     CmdDone    <= '1';
                     state      <= REQUESTFIRST;
                     widt       <= '0' & unsigned(fifo_data( 9 downto  0));
                     widtVram   <= '0' & unsigned(fifo_data( 9 downto  0));
                     heig       <= '0' & unsigned(fifo_data(24 downto 16));
                     
                     if (fifo_data(0) = '1') then
                        widtVram <= resize(unsigned(fifo_data(9 downto 0)), 11) + 1;
                     end if;
                     
                     if (unsigned(fifo_data( 9 downto  0)) = 0) then 
                        widt       <= to_unsigned(16#400#, 11); 
                        widtVram   <= to_unsigned(16#400#, 11); 
                     end if;
                     if (unsigned(fifo_data(24 downto 16)) = 0) then 
                        heig <= to_unsigned(16#200#, 10); 
                     end if;
                  end if;
                  
               when REQUESTFIRST =>
                  if (pipeline_busy = '0' and fifoOut_idle = '1') then
                     state <= READVRAM;
                  end if;
                  
               when READVRAM =>
                  xSrc <= srcX;
                  xCnt <= (others => '0');
                  if (requestVRAMIdle = '1' and Fifo_NearFull = '0') then
                     state      <= WAITREAD;
                     drawTiming <= (others => '0');
                  end if;
                  
               when WAITREAD => null; -- handled outside due to ce
                  
               when WAITIMING =>
                  if (drawTiming >= 80) then
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
                     Fifo_Din(31 downto 16) <= vramLineData;
                     Fifo_wordhalf          <= '0';
                     Fifo_Wr                <= '1';
                  end if;
                  state       <= WAITLAST1;
                  
               when WAITLAST1 =>
                  state       <= WAITLAST2;
                  
               when WAITLAST2 =>
                  state       <= IDLE;
                  done        <= '1';
            
            end case;
            
            if (drawer_reset = '1') then
               state <= IDLE;
               if (state /= IDLE) then
                  done  <= '1'; 
               end if;
            end if;
         
         end if;
         
      end if;
   end process; 

   -- synthesis translate_off

   goutput : if 1 = 1 generate
   signal outputCnt  : unsigned(23 downto 0) := (others => '0'); 
   
   begin
      process
         file outfile                  : text;
         variable f_status             : FILE_OPEN_STATUS;
         variable line_out             : line;
      begin
   
         file_open(f_status, outfile, "R:\\debug_vram2cpu_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\debug_vram2cpu_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk2x);
            
            if (Fifo_Rd = '1') then
               write(line_out, to_hstring(outputCnt));
               write(line_out, string'(" ")); 
               write(line_out, to_hstring(Fifo_Dout));
               writeline(outfile, line_out);
               outputCnt <= outputCnt + 1;
            end if; 
            
         end loop;
         
      end process;
   
   end generate goutput;
   
   -- synthesis translate_on

end architecture;





