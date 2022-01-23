library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all; 

entity spu_ram is
   port 
   (
      clk1x                : in  std_logic;
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      SPUon                : in  std_logic;
      useSDRAM             : in  std_logic;
      
      -- internal IF
      ram_dataWrite        : in  std_logic_vector(15 downto 0);
      ram_Adr              : in  std_logic_vector(18 downto 0);
      ram_request          : in  std_logic;
      ram_rnw              : in  std_logic;
      ram_dataRead         : out std_logic_vector(15 downto 0);
      ram_done             : out std_logic;
      
      ram_isTransfer       : in  std_logic;
      
      ram_isVoice          : in  std_logic;
      ram_VoiceIndex       : in  integer range 0 to 23;
      
      ram_isReverb         : in  std_logic;
      ram_ReverbIndex      : in  integer range 0 to 9;
      
      -- SDRAM interface        
      sdram_dataWrite      : out std_logic_vector(31 downto 0);
      sdram_Adr            : out std_logic_vector(18 downto 0);
      sdram_be             : out std_logic_vector(3 downto 0);
      sdram_rnw            : out std_logic;
      sdram_ena            : out std_logic;
      sdram_dataRead       : in  std_logic_vector(31 downto 0);
      sdram_done           : in  std_logic;
      
      -- DDR3 interface
      mem_request          : out std_logic := '0';
      mem_BURSTCNT         : out std_logic_vector(7 downto 0) := (others => '0'); 
      mem_ADDR             : out std_logic_vector(19 downto 0) := (others => '0');                       
      mem_DIN              : out std_logic_vector(63 downto 0) := (others => '0');
      mem_BE               : out std_logic_vector(7 downto 0) := (others => '0'); 
      mem_WE               : out std_logic := '0';
      mem_RD               : out std_logic := '0';
      mem_ack              : in  std_logic;
      mem_DOUT             : in  std_logic_vector(63 downto 0);
      mem_DOUT_READY       : in  std_logic
   );
end entity;

architecture arch of spu_ram is
   
   signal ram_isCapture        : std_logic;
   signal captureram_we        : std_logic;
   signal captureram_readdata  : std_logic_vector(15 downto 0);
      
   signal ram_processed        : std_logic := '0';
      
   signal ram_Adr64            : unsigned(15 downto 0);  
   signal ram_Adr64_m1         : unsigned(15 downto 0);  
    
   -- cache
   signal cache_addr_a         : unsigned(8 downto 0) := (others => '0');
   signal cache_wren_a         : std_logic;
   
   signal cache_addr_b         : unsigned(10 downto 0) := (others => '0');
   signal cache_data_b         : std_logic_vector(15 downto 0);
   
   signal cache_transfer_valid : std_logic := '0';
   signal cache_transfer_start : unsigned(15 downto 0);
      
   signal cache_voice_valid    : std_logic_vector(23 downto 0);
   type t_cache_voice_starts is array(0 to 23) of unsigned(15 downto 0);
   signal cache_voice_starts   : t_cache_voice_starts;
   signal cache_voice_start    : unsigned(15 downto 0);
      
   -- statemachine
   type tState is
   (
      IDLE,
      WAITWRITE,
      WAITTRANSFER
   );
   signal state : tState := IDLE;
   
   signal fetch_request             : std_logic := '0';
   signal fetch_addr                : std_logic_vector(15 downto 0);
   signal fetch_count               : std_logic_vector(7 downto 0);
   signal fetch_target              : unsigned(8 downto 0);
      
   -- write fifo
   signal fifoOut_reset             : std_logic; 
   signal fifoOut_Din               : std_logic_vector(83 downto 0);
   signal fifoOut_Wr                : std_logic; 
   signal fifoOut_Wr_1              : std_logic; 
   signal fifoOut_Full              : std_logic;
   signal fifoOut_NearFull          : std_logic;
   signal fifoOut_Dout              : std_logic_vector(83 downto 0);
   signal fifoOut_Rd                : std_logic;
   signal fifoOut_Empty             : std_logic;
   signal fifoOut_Valid             : std_logic;
      
   signal sample64data              : std_logic_vector(63 downto 0) := (others => '0');
   signal sample64wordEna           : std_logic_vector(3 downto 0) := (others => '0');
   signal sample64addr              : std_logic_vector(15 downto 0) := (others => '0');
   signal sample64filled            : std_logic := '0';
   signal sample64timeout           : integer range 0 to 40;
      
   -- DDR3 access
   type tMemState is
   (
      MEMIDLE,
      MEMWRITE_WAITACK,
      MEMREAD_WAITACK,
      MEMREAD_READDATA
   );
   signal memstate      : tMemState := MEMIDLE;
   
   signal fetch_request_1  : std_logic := '0'; 
   signal triggerRead      : std_logic := '0'; 
   signal fetch_done       : std_logic := '0';
   signal readCount        : unsigned(7 downto 0);
      
begin 

   ram_isCapture <= '1' when (ram_Adr(18 downto 12) = "0000000") else '0';

   captureram_we <= '1' when (ram_request = '1' and ram_rnw = '0' and ram_isCapture = '1') else '0';

   iram_capture: entity mem.dpram
   generic map (addr_width => 11, data_width => 16)
   port map
   (
      clock_a     => clk1x,
      address_a   => ram_Adr(11 downto 1),
      data_a      => ram_dataWrite,
      wren_a      => captureram_we,
      q_a         => captureram_readdata,
      
      clock_b     => clk1x,
      address_b   => (10 downto 0 => '0'),
      data_b      => x"0000",
      wren_b      => '0',
      q_b         => open
   );
   
   -- cache layout
   -- 8 QWords = 32 Words per Line
   -- 24 lines for voices -> 0..23
   -- 10 Lines for Reverb -> 32..41
   -- 1 Line for Transfer -> 48
   -- 35 lines -> rounded up to 64
   -- 64 * 8 QWords = 512 QWords, 2048 Words
   
   icache: entity work.dpram_dif
   generic map 
   ( 
      addr_width_a  => 9,
      data_width_a  => 64,
      addr_width_b  => 11,
      data_width_b  => 16
   )
   port map
   (
      clock       => clk2x,
      
      address_a   => std_logic_vector(cache_addr_a),
      data_a      => mem_DOUT,
      wren_a      => cache_wren_a,
      
      address_b   => std_logic_vector(cache_addr_b),
      data_b      => x"0000",
      wren_b      => '0',
      q_b         => cache_data_b
   );

   cache_wren_a <= '1' when (mem_DOUT_READY = '1' and memstate = MEMREAD_READDATA) else '0';

   -- output multiplexing
   sdram_dataWrite <= x"0000" & ram_dataWrite;
   sdram_Adr       <= ram_Adr;
   sdram_be        <= "0011";
   sdram_rnw       <= ram_rnw;
   sdram_ena       <= '0'         when (ram_isCapture = '1') else
                      ram_request when (useSDRAM = '1') else 
                      '0'; 

   ram_dataRead    <= captureram_readdata         when (ram_isCapture = '1') else
                      (others => '0')             when (SPUon = '0')    else
                      sdram_dataRead(15 downto 0) when (useSDRAM = '1') else 
                      cache_data_b; 
   
   ram_done        <= '1'            when (ram_processed = '1') else
                      '1'            when (SPUon = '0')         else
                      sdram_done     when (useSDRAM = '1')      else 
                      '0'; 
   
   
   ram_Adr64    <= unsigned(ram_Adr(18 downto 3));
   ram_Adr64_m1 <= unsigned(ram_Adr(18 downto 3)) - 1;
   
   
   cache_voice_start <= cache_voice_starts(ram_VoiceIndex);
   
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then
            
         ram_processed <= '0';
         fifoOut_reset <= '0';
         fetch_request <= '0';
            
         if (reset = '1') then
            
            fifoOut_reset        <= '1';
            cache_transfer_valid <= '0';
            cache_voice_valid    <= (others => '0');
            
         else
         
            if (ram_request = '1' and ram_isCapture = '1') then
               ram_processed <= '1';
            end if;
            
            if (useSDRAM = '0') then
               case (state) is
                  
                  when IDLE =>
                     if (ram_request = '1' and ram_isCapture = '0') then
                  
                        if (ram_rnw = '0') then
                           cache_transfer_valid <= '0';
                           -- cache_voice_valid    <= (others => '0'); too slow, need to see if invalidating is really required. There should be no writes to currently played samples
                           if (fifoOut_NearFull = '1') then
                              state <= WAITWRITE;
                           else
                              ram_processed <= '1';
                           end if;
                        end if;
               
                        if (ram_rnw = '1') then
                        
                           if (ram_isTransfer = '1') then
                              if (cache_transfer_valid = '1' and ram_Adr64 >= cache_transfer_start and ram_Adr64 <= (cache_transfer_start + 7)) then
                                 ram_processed        <= '1';
                                 cache_addr_b         <= "110000" & resize(ram_Adr64 - cache_transfer_start, 3) & unsigned(ram_Adr(2 downto 1));
                              else
                                 state                <= WAITTRANSFER;
                                 fetch_request        <= '1';
                                 fetch_addr           <= ram_Adr(18 downto 3);
                                 fetch_count          <= x"08";
                                 fetch_target         <= "110000" & "000";
                                 cache_addr_b         <= "110000" & "000" & unsigned(ram_Adr(2 downto 1));
                                 cache_transfer_start <= ram_Adr64;
                                 cache_transfer_valid <= '1';
                              end if;
                              
                           elsif (ram_isVoice = '1') then
                              if (cache_voice_valid(ram_VoiceIndex) = '1' and ram_Adr64 >= cache_voice_start and ram_Adr64 <= (cache_voice_start + 7)) then
                                 ram_processed        <= '1';
                                 cache_addr_b         <= "0" & to_unsigned(ram_VoiceIndex, 5) & resize(ram_Adr64 - cache_voice_start, 3) & unsigned(ram_Adr(2 downto 1));
                              else
                                 state                <= WAITTRANSFER;
                                 fetch_request        <= '1';
                                 fetch_addr           <= std_logic_vector(ram_Adr64_m1);
                                 fetch_count          <= x"08";
                                 fetch_target         <= "0" & to_unsigned(ram_VoiceIndex, 5) & "000";
                                 cache_addr_b         <= "0" & to_unsigned(ram_VoiceIndex, 5) & "001" & unsigned(ram_Adr(2 downto 1));
                                 cache_voice_starts(ram_VoiceIndex) <= ram_Adr64_m1;
                                 cache_voice_valid(ram_VoiceIndex)  <= '1';
                              end if;
                              
                           elsif (ram_isReverb = '1') then
                              state                <= WAITTRANSFER;
                              fetch_request        <= '1';
                              fetch_addr           <= ram_Adr(18 downto 3);
                              fetch_count          <= x"01";
                              fetch_target         <= "10" & to_unsigned(ram_ReverbIndex, 4) & "000";
                              cache_addr_b         <= "10" & to_unsigned(ram_ReverbIndex, 4) & "000" & unsigned(ram_Adr(2 downto 1));
                              
                           else
                              report "should never happen" severity failure; 
                           end if;
                        end if;
                        
                     end if;
                     
                  when WAITWRITE =>
                     if (fifoOut_NearFull = '1') then
                        ram_processed <= '0';
                     end if;
               
                  when WAITTRANSFER =>
                     if (fetch_done = '1') then
                        state         <= IDLE;
                        ram_processed <= '1';
                     end if;
               
               end case;
            end if;
            
         end if;
         
      end if;
   end process;
   
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         fifoOut_Wr  <= '0';
         fifoOut_Din <= sample64wordEna & sample64Addr & sample64data;
      
         if (reset = '1') then
            
            sample64filled <= '0';
            
         elsif (clk2xIndex = '1') then
         
            if (useSDRAM = '0' and ram_request = '1' and ram_rnw = '0' and ram_isCapture = '0') then
            
               sample64timeout <= 40;
            
               if (sample64filled = '0' or unsigned(ram_Adr(18 downto 3)) /= unsigned(sample64Addr)) then
               
                  fifoOut_Wr <= sample64filled;
               
                  sample64Addr <= std_logic_vector(ram_Adr(18 downto 3));
                  case (ram_Adr(2 downto 1)) is
                     when "00" => sample64data(15 downto  0) <= ram_dataWrite; sample64wordEna <= "0001";
                     when "01" => sample64data(31 downto 16) <= ram_dataWrite; sample64wordEna <= "0010";
                     when "10" => sample64data(47 downto 32) <= ram_dataWrite; sample64wordEna <= "0100";
                     when "11" => sample64data(63 downto 48) <= ram_dataWrite; sample64wordEna <= "1000";
                     when others => null;
                  end case;
                  
                  sample64filled <= '1';
               
               else
                  
                  case (ram_Adr(2 downto 1)) is
                     when "00" => sample64data(15 downto  0) <= ram_dataWrite; sample64wordEna(0) <= '1';
                     when "01" => sample64data(31 downto 16) <= ram_dataWrite; sample64wordEna(1) <= '1';
                     when "10" => sample64data(47 downto 32) <= ram_dataWrite; sample64wordEna(2) <= '1';
                     when "11" => sample64data(63 downto 48) <= ram_dataWrite; sample64wordEna(3) <= '1';
                     when others => null;
                  end case;

               end if;
               
            elsif (sample64filled = '1' and fetch_request = '1') then
            
               sample64filled  <= '0';
               fifoOut_Wr      <= '1';
               sample64timeout <= 0;
            
            elsif (sample64timeout > 0) then
            
               sample64timeout <= sample64timeout - 1;
               if (sample64timeout = 1) then
                  sample64filled  <= '0';
                  fifoOut_Wr      <= '1';
               end if;
               
            end if;
            
         end if;

      end if;
   end process;
   
   -- sample writing fifo
   iSyncFifo_OUT: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 32,
      DATAWIDTH        => 84,  -- 64bit data, 16 bit address + 4bit word enable
      NEARFULLDISTANCE => 20
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
   
   fifoOut_Rd <= '1' when (memstate = MEMIDLE and fifoOut_Empty = '0') else '0';
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         fifoOut_Wr_1 <= fifoOut_Wr;
         
         fetch_request_1 <= fetch_request;
         if (fetch_request = '1' and fetch_request_1 = '0') then
            triggerRead <= '1';
         end if;  
         
         if (state = IDLE) then
            fetch_done <= '0';
         end if;
      
         if (reset = '1') then

            memstate    <= MEMIDLE;
            mem_request <= '0';
            triggerRead <= '0';

         else
            
            case (memstate) is
            
               when MEMIDLE =>
                  if (fifoOut_Empty = '0') then
                     memstate     <= MEMWRITE_WAITACK;
                     mem_request  <= '1';
                     mem_BURSTCNT <= x"01";
                     mem_ADDR     <= "0" & fifoOut_Dout(79 downto 64) & "000";
                     mem_DIN      <= fifoOut_Dout(63 downto 0);
                     mem_BE       <= fifoOut_Dout(83) & fifoOut_Dout(83) & fifoOut_Dout(82) & fifoOut_Dout(82) & fifoOut_Dout(81) & fifoOut_Dout(81) & fifoOut_Dout(80) & fifoOut_Dout(80);
                     mem_WE       <= '1';
                     mem_RD       <= '0'; 
                  elsif (fifoOut_Wr = '1' or fifoOut_Wr_1 = '1') then -- don't read yet, new data to be written first
                     null;
                  elsif (triggerRead = '1') then
                     memstate     <= MEMREAD_WAITACK;
                     readCount    <= unsigned(fetch_count);
                     cache_addr_a <= fetch_target;
                     triggerRead  <= '0';
                     mem_request  <= '1';
                     mem_BURSTCNT <= fetch_count;
                     mem_ADDR     <= "0" & fetch_addr & "000";
                     mem_BE       <= x"FF";
                     mem_WE       <= '0';
                     mem_RD       <= '1';
                  end if;
            
               -- write from SPU to DDR3
               when MEMWRITE_WAITACK =>
                  if (mem_ack = '1') then
                     mem_request <= '0';
                     memstate    <= MEMIDLE;
                     mem_WE      <= '0';
                     mem_RD      <= '0';
                  end if;
                  
               -- read from DDR3 to CACHES
               when MEMREAD_WAITACK =>
                  if (mem_ack = '1') then
                     memstate <= MEMREAD_READDATA;
                  end if;
                  
               when MEMREAD_READDATA =>
                  if (mem_DOUT_READY = '1') then
                  
                     cache_addr_a <= cache_addr_a + 1;
                     readCount    <= readCount - 1;
                  
                     if (readCount = 1) then
                        memstate    <= MEMIDLE;
                        fetch_done  <= '1';
                        mem_request <= '0';
                        mem_WE      <= '0';
                        mem_RD      <= '0';
                     end if;
                     
                  end if;
            
            end case;
         
         
         end if;
      
      end if;
   end process;

end architecture;





