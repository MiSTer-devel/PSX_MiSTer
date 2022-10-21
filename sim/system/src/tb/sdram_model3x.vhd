library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library tb;
use tb.globals.all;

entity sdram_model3x is
   generic
   (
      DOREFRESH         : std_logic := '0';
      INITFILE          : string := "NONE";
      SCRIPTLOADING     : std_logic := '0';
      FILELOADING       : std_logic := '0'
   );
   port 
   (
      clk               : in  std_logic;
      clk3x             : in  std_logic;
      refresh           : in  std_logic;
      addr              : in  std_logic_vector(26 downto 0);
      req               : in  std_logic;
      ram_dma           : in  std_logic;
      ram_dmacnt        : in  std_logic_vector(1 downto 0);
      ram_iscache       : in  std_logic;
      rnw               : in  std_logic;
      be                : in  std_logic_vector(3 downto 0);
      di                : in  std_logic_vector(31 downto 0);
      do                : buffer std_logic_vector(127 downto 0);
      do32              : out std_logic_vector(31 downto 0);
      done              : buffer std_logic := '0';
      cache_wr          : out std_logic_vector(3 downto 0) := (others => '0');
      cache_data        : out std_logic_vector(31 downto 0) := (others => '0');
      cache_addr        : out std_logic_vector(7 downto 0) := (others => '0');
      dma_wr            : buffer std_logic := '0';
      dma_data          : out std_logic_vector(31 downto 0) := (others => '0');
      reqprocessed      : buffer std_logic := '0';
      ram_idle          : out std_logic := '0';
      ram_dmafifo_adr   : in  std_logic_vector(22 downto 0);
      ram_dmafifo_data  : in  std_logic_vector(31 downto 0);
      ram_dmafifo_empty : in  std_logic;
      ram_dmafifo_read  : out std_logic := '0';
      fileSize          : out unsigned(29 downto 0) := (others => '0');
      exe_initial_pc    : out unsigned(31 downto 0);
      exe_initial_gp    : out unsigned(31 downto 0);
      exe_load_address  : out unsigned(31 downto 0);
      exe_file_size     : out unsigned(31 downto 0);
      exe_stackpointer  : out unsigned(31 downto 0)
   );
end entity;

architecture arch of sdram_model3x is

   constant cycles_per_refresh   : integer := 780; 
   constant BURST_LENGTH         : integer := 8;
   constant CAS_LATENCY          : integer := 2;
   
   signal clk1xToggle            : std_logic := '0';
   signal clk1xToggle3X          : std_logic := '0';
   signal clk1xToggle3X_1        : std_logic := '0';
   signal clk3xIndex             : std_logic := '0';

   -- not full size, because of memory required
   type t_data is array(0 to (2**27)-1) of integer;
   type bit_vector_file is file of bit_vector;
   
   signal data_ready_delay1      : std_logic_vector(BURST_LENGTH+CAS_LATENCY downto 0);
   
   signal req_buffer             : std_logic := '0';
   signal refresh_buffer         : std_logic := '0';
   signal addr_buffer            : std_logic_vector(26 downto 0);
   signal rnw_buffer             : std_logic := '0';
   
   signal lastbank               : std_logic_vector(12 downto 0);
        
   signal refreshcnt             : integer range 0 to 1000 := 0;
   
   signal initFromFile           : std_logic := '1';
   
   signal reqprocessed_3x        : std_logic := '0';
   signal done_3x                : std_logic := '0';
   signal req_1                  : std_logic := '0';
   signal refresh_1              : std_logic := '0';
   
   signal cache_buffer           : std_logic := '0';
   signal cache_buffer_next      : std_logic := '0';
   
   signal cache_done_0           : std_logic := '0';
   signal cache_done_1           : std_logic := '0';
   signal cache_done_2           : std_logic := '0';
   signal cache_done_3           : std_logic := '0';
   signal cache_wr_next          : std_logic_vector(3 downto 0);
   
   signal dma_buffer             : std_logic := '0';
   signal dma_done               : std_logic := '0';
   signal dma_ack                : std_logic := '0';
   signal dma_count_3x           : unsigned(1 downto 0);
   signal dma_count              : unsigned(1 downto 0);
   signal dma_counter            : unsigned(1 downto 0);
   signal dma_do                 : std_logic_vector(127 downto 0);
   
   type tstate is
   (
      STATE_IDLE, 
      STATE_WAIT,  
      STATE_RW1,    
      STATE_RW2,   
      STATE_IDLE_9, 
      STATE_IDLE_8, 
      STATE_IDLE_7, 
      STATE_IDLE_6, 
      STATE_IDLE_5, 
      STATE_IDLE_4, 
      STATE_IDLE_3, 
      STATE_IDLE_2, 
      STATE_IDLE_1, 
      STATE_RFSH   
   );
   signal state : tstate := STATE_IDLE;
   
begin


   process
   begin
      wait until rising_edge(clk);
      
      clk1xToggle  <= not clk1xToggle;
      
      done         <= done_3x;
      reqprocessed <= reqprocessed_3x;
      
      ram_idle <= '0';
      if (state = STATE_IDLE or state = STATE_IDLE_1 or state = STATE_IDLE_2 or state = STATE_RW1 or state = STATE_RW2) then
         if (refreshcnt < (cycles_per_refresh - 16) and req_buffer = '0') then
            ram_idle <= '1';
         end if;
      end if;
      
      if (done_3x = '1') then
         if (addr_buffer(0) = '1') then
            do32 <= x"00" & do(31 downto 8);
         else
            do32 <= do(31 downto 0);
         end if;
      end if;
      
      dma_wr  <= '0';
      dma_ack <= '0';

      if (dma_wr = '1') then
         if (dma_counter < dma_count) then
            dma_wr      <= '1';
            dma_counter <= dma_counter + 1;
            if (dma_counter = 0) then dma_data <= dma_do( 63 downto 32); end if;
            if (dma_counter = 1) then dma_data <= dma_do( 95 downto 64); end if;
            if (dma_counter = 2) then dma_data <= dma_do(127 downto 96); end if;
         end if;
      end if;
      
      if (dma_done = '1') then
         dma_ack     <= '1';
         dma_wr      <= '1';
         dma_data    <= do( 31 downto  0);
         dma_do      <= do;
         dma_counter <= (others => '0');
         dma_count   <= dma_count_3x;
      end if;
   
   end process;

   process
   
      variable data           : t_data := (others => 0);
      variable bs93           : std_logic;
      
      file infile             : bit_vector_file;
      variable f_status       : FILE_OPEN_STATUS;
      variable read_byte      : std_logic_vector(7 downto 0);
      variable next_vector    : bit_vector (0 downto 0);
      variable actual_len     : natural;
      variable targetpos      : integer;
      variable loadcount      : integer;
      
      variable addr_rotate    : std_logic_vector(26 downto 0);
      
      -- copy from std_logic_arith, not used here because numeric std is also included
      function CONV_STD_LOGIC_VECTOR(ARG: INTEGER; SIZE: INTEGER) return STD_LOGIC_VECTOR is
        variable result: STD_LOGIC_VECTOR (SIZE-1 downto 0);
        variable temp: integer;
      begin
 
         temp := ARG;
         for i in 0 to SIZE-1 loop
 
         if (temp mod 2) = 1 then
            result(i) := '1';
         else 
            result(i) := '0';
         end if;
 
         if temp > 0 then
            temp := temp / 2;
         elsif (temp > integer'low) then
            temp := (temp - 1) / 2; -- simulate ASR
         else
            temp := temp / 2; -- simulate ASR
         end if;
        end loop;
 
        return result;  
      end;
   
   begin
      wait until rising_edge(clk3x);
      
      clk1xToggle3x   <= clk1xToggle;
      clk1xToggle3X_1 <= clk1xToggle3X;
      clk3xIndex    <= '0';
      if (clk1xToggle3X_1 = clk1xToggle) then
         clk3xIndex <= '1';
      end if;
      
      if (done = '1') then
         done_3x <= '0';
      end if;
      
      if (dma_ack = '1') then
         dma_done <= '0';
      end if;
      
      cache_wr     <= (others => '0');
      cache_done_0 <= '0';
      cache_done_1 <= '0';
      cache_done_2 <= '0';
      cache_done_3 <= '0';
      if (cache_done_0 = '1') then cache_data <= do( 31 downto  0); cache_wr <= cache_wr_next; cache_wr_next <= cache_wr_next(2 downto 0) & '0'; end if;
      if (cache_done_1 = '1') then cache_data <= do( 63 downto 32); cache_wr <= cache_wr_next; cache_wr_next <= cache_wr_next(2 downto 0) & '0'; end if;
      if (cache_done_2 = '1') then cache_data <= do( 95 downto 64); cache_wr <= cache_wr_next; cache_wr_next <= cache_wr_next(2 downto 0) & '0'; end if;
      if (cache_done_3 = '1') then cache_data <= do(127 downto 96); cache_wr <= cache_wr_next; cache_wr_next <= cache_wr_next(2 downto 0) & '0'; end if;
      
      if (reqprocessed = '1') then
         reqprocessed_3x <= '0';
      end if;
      
      ram_dmafifo_read <= '0';
      
      if (clk3xIndex = '1' and req = '1') then
         req_buffer <= '1';
      end if;
      
      refresh_1 <= refresh;
      if (refresh = '1' and refresh_1 = '0') then
         refresh_buffer <= '1';
      end if;
      
      if (DOREFRESH = '1' and refreshcnt < 1000) then
         refreshcnt <= refreshcnt + 1;
      end if;
      
      data_ready_delay1 <= '0' & data_ready_delay1(10 downto 1);

      if(data_ready_delay1(6) = '1' and dma_buffer = '0' and cache_buffer_next = '0') then done_3x  <= '1'; end if;
      if(data_ready_delay1(4) = '1' and cache_buffer_next = '1')                      then done_3x  <= '1'; end if;
      if(data_ready_delay1(6) = '1' and dma_buffer = '1')                             then dma_done <= '1'; end if;
      
      if(data_ready_delay1(7) = '1') then cache_buffer_next <= cache_buffer; end if;
      if(data_ready_delay1(6) = '1' and cache_buffer_next = '1') then cache_done_0 <= '1'; end if;
      if(data_ready_delay1(4) = '1' and cache_buffer_next = '1') then cache_done_1 <= '1'; end if;
      if(data_ready_delay1(2) = '1' and cache_buffer_next = '1') then cache_done_2 <= '1'; end if;
      if(data_ready_delay1(0) = '1' and cache_buffer_next = '1') then cache_done_3 <= '1'; end if;
      
      if(data_ready_delay1(7) = '1') then
         addr_rotate := addr_buffer;
         for i in 0 to 7 loop
            do(7  + (i * 16) downto     (i * 16))  <= std_logic_vector(to_unsigned(data(to_integer(unsigned(addr_rotate(26 downto 1)) & '0') + 0), 8));
            do(15 + (i * 16) downto 8 + (i * 16))  <= std_logic_vector(to_unsigned(data(to_integer(unsigned(addr_rotate(26 downto 1)) & '0') + 1), 8));
            addr_rotate(9 downto 1) := std_logic_vector(unsigned(addr_rotate(9 downto 1)) + 1); 
         end loop;
      end if;
      
      case (state) is
      
         when STATE_IDLE =>
            if (DOREFRESH = '1' and (refresh_buffer = '1' or refreshcnt > cycles_per_refresh)) then
               state <= STATE_RFSH;
               if (refreshcnt > cycles_per_refresh) then
                  refreshcnt <= refreshcnt - cycles_per_refresh + 1;
               else
                  refreshcnt <= 0;
               end if;
               refresh_buffer <= '0';
               
            elsif (ram_dmafifo_empty = '0') then
               data(to_integer(unsigned(ram_dmafifo_adr(22 downto 1)) & '0') + 3) := to_integer(unsigned(ram_dmafifo_data(31 downto 24)));
               data(to_integer(unsigned(ram_dmafifo_adr(22 downto 1)) & '0') + 2) := to_integer(unsigned(ram_dmafifo_data(23 downto 16)));
               data(to_integer(unsigned(ram_dmafifo_adr(22 downto 1)) & '0') + 1) := to_integer(unsigned(ram_dmafifo_data(15 downto  8)));
               data(to_integer(unsigned(ram_dmafifo_adr(22 downto 1)) & '0') + 0) := to_integer(unsigned(ram_dmafifo_data( 7 downto  0)));
               lastbank         <= ram_dmafifo_adr(22 downto 10);
               ram_dmafifo_read <= '1';
               rnw_buffer       <= '0';
               state            <= STATE_WAIT;
            
            elsif ((req = '1' or req_buffer = '1') and rnw = '0') then
               if (be(3) = '1') then data(to_integer(unsigned(addr(26 downto 1)) & '0') + 3) := to_integer(unsigned(di(31 downto 24))); end if;
               if (be(2) = '1') then data(to_integer(unsigned(addr(26 downto 1)) & '0') + 2) := to_integer(unsigned(di(23 downto 16))); end if;
               if (be(1) = '1') then data(to_integer(unsigned(addr(26 downto 1)) & '0') + 1) := to_integer(unsigned(di(15 downto  8))); end if;
               if (be(0) = '1') then data(to_integer(unsigned(addr(26 downto 1)) & '0') + 0) := to_integer(unsigned(di( 7 downto  0))); end if;
               req_buffer      <= '0';
               rnw_buffer      <= '0';
               done_3x         <= '1';
               state           <= STATE_WAIT;
               
            elsif ((req = '1' or req_buffer = '1') and rnw = '1') then
               req_buffer      <= '0';
               addr_buffer     <= addr; 
               rnw_buffer      <= '1';
               state           <= STATE_WAIT;
               
               cache_buffer    <= ram_iscache;
               cache_addr      <= addr(11 downto 4);
               if (addr(3 downto 2) = "00") then cache_wr_next <= "0001"; end if;
               if (addr(3 downto 2) = "01") then cache_wr_next <= "0010"; end if;
               if (addr(3 downto 2) = "10") then cache_wr_next <= "0100"; end if;
               if (addr(3 downto 2) = "11") then cache_wr_next <= "1000"; end if;
               
               dma_buffer      <= ram_dma;
               reqprocessed_3x <= ram_dma;
               dma_count_3x    <= unsigned(ram_dmacnt);
            end if;
         
         when STATE_WAIT => 
            state <= STATE_RW1;
         
         when STATE_RW1 =>  
            if (rnw_buffer = '1') then
               state <= STATE_IDLE_9;
               data_ready_delay1(CAS_LATENCY+BURST_LENGTH) <= '1';
            else
               state <= STATE_RW2;
            end if;
         
         when STATE_RW2 => 
            if (ram_dmafifo_empty = '0' and ram_dmafifo_adr(22 downto 10) = lastbank) then
               data(to_integer(unsigned(ram_dmafifo_adr(22 downto 1)) & '0') + 3) := to_integer(unsigned(ram_dmafifo_data(31 downto 24)));
               data(to_integer(unsigned(ram_dmafifo_adr(22 downto 1)) & '0') + 2) := to_integer(unsigned(ram_dmafifo_data(23 downto 16)));
               data(to_integer(unsigned(ram_dmafifo_adr(22 downto 1)) & '0') + 1) := to_integer(unsigned(ram_dmafifo_data(15 downto  8)));
               data(to_integer(unsigned(ram_dmafifo_adr(22 downto 1)) & '0') + 0) := to_integer(unsigned(ram_dmafifo_data( 7 downto  0)));
               ram_dmafifo_read <= '1';
               state            <= STATE_RW1;
            else
               state   <= STATE_IDLE_2;
            end if;
         
         when STATE_IDLE_9 => state <= STATE_IDLE_8;
         when STATE_IDLE_8 => state <= STATE_IDLE_7;
         when STATE_IDLE_7 => state <= STATE_IDLE_6;
         when STATE_IDLE_6 => state <= STATE_IDLE_5;
         when STATE_IDLE_5 => state <= STATE_IDLE_4;
         when STATE_IDLE_4 => state <= STATE_IDLE_3;
         when STATE_IDLE_3 => state <= STATE_IDLE_2;
         when STATE_IDLE_2 => state <= STATE_IDLE_1;
         when STATE_IDLE_1 =>
            state <= STATE_IDLE;
            if (DOREFRESH = '1' and refreshcnt > cycles_per_refresh) then
               refreshcnt <= refreshcnt - cycles_per_refresh + 1;
               state      <= STATE_RFSH;
            end if;
         
         when STATE_RFSH =>  
            state  <= STATE_IDLE_5;
            
            
      end case;
      

      if (SCRIPTLOADING = '1') then
         COMMAND_FILE_ACK_1 <= '0';
         if COMMAND_FILE_START_1 = '1' then
            
            assert false report "received" severity note;
            assert false report COMMAND_FILE_NAME(1 to COMMAND_FILE_NAMELEN) severity note;
         
            file_open(f_status, infile, COMMAND_FILE_NAME(1 to COMMAND_FILE_NAMELEN), read_mode);
         
            targetpos := COMMAND_FILE_TARGET;
            
            wait until rising_edge(clk);
            
            for i in 1 to COMMAND_FILE_OFFSET loop
               read(infile, next_vector, actual_len); 
            end loop;
            
            loadcount := 0;
      
            while (not endfile(infile) and (COMMAND_FILE_SIZE = 0 or loadcount < COMMAND_FILE_SIZE)) loop
               
               read(infile, next_vector, actual_len);  
               
               read_byte := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(0)), 8);
               
               --report "read_byte=" & integer'image(to_integer(unsigned(read_byte)));
               
               data(targetpos) := to_integer(unsigned(read_byte));
               targetpos       := targetpos + 1;
               loadcount       := loadcount + 1;
               
            end loop;
            
            wait until rising_edge(clk);
         
            file_close(infile);
         
            COMMAND_FILE_ACK_1 <= '1';
            
            targetpos := COMMAND_FILE_TARGET;
            
            exe_initial_pc   <= to_unsigned(data(targetpos + 16#13#), 8) & to_unsigned(data(targetpos + 16#12#), 8) & to_unsigned(data(targetpos + 16#11#), 8) & to_unsigned(data(targetpos + 16#10#), 8);
            exe_initial_gp   <= to_unsigned(data(targetpos + 16#17#), 8) & to_unsigned(data(targetpos + 16#16#), 8) & to_unsigned(data(targetpos + 16#15#), 8) & to_unsigned(data(targetpos + 16#14#), 8);
            exe_load_address <= to_unsigned(data(targetpos + 16#1B#), 8) & to_unsigned(data(targetpos + 16#1A#), 8) & to_unsigned(data(targetpos + 16#19#), 8) & to_unsigned(data(targetpos + 16#18#), 8);
            exe_file_size    <= to_unsigned(data(targetpos + 16#1F#), 8) & to_unsigned(data(targetpos + 16#1E#), 8) & to_unsigned(data(targetpos + 16#1D#), 8) & to_unsigned(data(targetpos + 16#1C#), 8);
            
            exe_stackpointer <= (to_unsigned(data(targetpos + 16#33#), 8) & to_unsigned(data(targetpos + 16#32#), 8) & to_unsigned(data(targetpos + 16#31#), 8) & to_unsigned(data(targetpos + 16#30#), 8)) + 
                                (to_unsigned(data(targetpos + 16#37#), 8) & to_unsigned(data(targetpos + 16#36#), 8) & to_unsigned(data(targetpos + 16#35#), 8) & to_unsigned(data(targetpos + 16#34#), 8));
            
         end if;
      end if;
      
      if (FILELOADING = '1') then
         if (initFromFile = '1') then
            initFromFile <= '0';
            file_open(f_status, infile, INITFILE, read_mode);
            targetpos := 0;
            while (not endfile(infile)) loop
               read(infile, next_vector, actual_len);  
               read_byte := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(0)), 8);
               data(targetpos) := to_integer(unsigned(read_byte));
               targetpos       := targetpos + 1;
            end loop;
            fileSize <= to_unsigned(targetpos, 30);
            file_close(infile);
         end if;
      end if;
   
   
   end process;
   
end architecture;


