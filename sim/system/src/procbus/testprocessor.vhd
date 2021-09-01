library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library rs232;
library mem;

library procbus;
use procbus.pProc_bus.all;

entity eTestprocessor  is
   generic
   (
      clk_speed : integer := 50000000;
      baud      : integer := 115200;
      is_simu   : std_logic := '0'
   );
   port 
   (
      clk             : in     std_logic;
      bootloader      : in     std_logic;
      debugaccess     : in     std_logic;
      command_in      : in     std_logic;
      command_out     : out    std_logic;
                      
      proc_bus        : inout proc_bus_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z');
      
      fifo_full_error : out    std_logic;
      timeout_error   : buffer std_logic := '0'
   );
end entity;

architecture arch of eTestprocessor is
   
   type tState is
   (
      START,
      BOOTLOADER_READ,
      BOOTLOADER_READWAIT,
      BOOTLOADER_WRITEWAIT,
      BOTLOADER_WRITE_START,
      DEBUGIDLE,
      RECEIVELENGTH,
      BLOCKWRITE,
      BLOCKWRITE_WAIT,
      BLOCKREAD_READ,
      BLOCKREAD_WAIT,
      BLOCKREAD_SEND
   );
   signal state : tState := START;
   
   signal startcounter : integer range 0 to 100000001 := 0;
   
   signal boot_read_addr  : unsigned(proc_busadr - 1 downto 0) := to_unsigned(2097152, proc_busadr); -- flash
   signal boot_write_addr : unsigned(proc_busadr - 1 downto 0) := to_unsigned(524288, proc_busadr);  -- sram
   signal boot_cnt        : integer range 0 to 65535 := 0;
   
   signal receive_command  : std_logic_vector(31 downto 0);
   signal receive_byte_nr  : integer range 0 to 4 := 0;
   
   signal rx_valid         : std_logic;
   signal rx_byte          : std_logic_vector(7 downto 0);
   
   signal transmit_command : std_logic_vector(31 downto 0);
   signal transmit_byte_nr : integer range 0 to 4 := 4;
   signal sendbyte         : std_logic_vector(7 downto 0) := (others => '0');
   signal tx_enable        : std_logic := '0';
   signal tx_busy          : std_logic;
   
   signal proc_din         : std_logic_vector(31 downto 0);
   signal proc_dout        : std_logic_vector(31 downto 0) := (others => '0');
   signal proc_adr         : std_logic_vector(proc_busadr - 1 downto 0) := (others => '0');
   signal proc_rnw         : std_logic := '0';
   signal proc_ena         : std_logic := '0';
   signal proc_done        : std_logic;
   
   signal blocklength_m1   : integer range 0 to 255 := 0;
   signal workcount        : integer range 0 to 255 := 0;
   signal addr_buffer      : std_logic_vector(proc_busadr - 1 downto 0) := (others => '0');
   
   signal Fifo_writena     : std_logic;
   signal Fifo_full        : std_logic;
   signal Fifo_Dout        : std_logic_vector(7 downto 0);
   signal Fifo_Rd          : std_logic := '0';
   signal Fifo_Empty       : std_logic;
   signal Fifo_valid       : std_logic;
   
   constant TIMEOUTVALUE : integer := 100000000;
   signal timeout          : integer range 0 to TIMEOUTVALUE := 0;
   

begin

   iProc_bus : entity procbus.eProc_bus
   port map 
   (
      proc_din  => proc_din,
      proc_dout => proc_dout,
      proc_adr  => proc_adr, 
      proc_rnw  => proc_rnw,
      proc_ena  => proc_ena,
      proc_done => proc_done,
      proc_bus  => proc_bus
   );
   
   iReceiveFifo : entity mem.SyncFifo
   generic map
   (
      SIZE             => 1024,
      DATAWIDTH        => 8,
      NEARFULLDISTANCE => 128
   )
   port map 
   ( 
      clk      => clk,
      reset    => timeout_error,
               
      Din      => rx_byte, 
      Wr       => Fifo_writena,  
      Full     => Fifo_full,
      NearFull => open,
      
      Dout     => Fifo_Dout, 
      Rd       => Fifo_Rd,   
      Empty    => Fifo_Empty
   );

   Fifo_writena    <= rx_valid and (debugaccess or is_simu);
   fifo_full_error <= Fifo_full;

   process (clk)
   begin
      if rising_edge(clk) then
   
         proc_ena      <= '0';
         tx_enable     <= '0';
         timeout_error <= '0';
   
         Fifo_valid <= Fifo_rd;
         Fifo_rd    <= '0';
         if (Fifo_Empty = '0' and Fifo_rd = '0' and Fifo_valid = '0' and (state = DEBUGIDLE or state = RECEIVELENGTH or state = BLOCKWRITE)) then
            Fifo_rd <= '1';
         end if;
         
         if (timeout < TIMEOUTVALUE) then
            timeout <= timeout + 1;
         end if;
   
         case state is
         
            when START =>
               startcounter <= startcounter + 1;
               --if ((is_simu = '0' and startcounter = 100000000) or (is_simu = '1' and startcounter = 10000)) then
               if ((is_simu = '0' and startcounter = 100000000) or (is_simu = '1' and startcounter = 1)) then
                  if (bootloader = '1') then
                     state <= BOOTLOADER_READ;
                  else
                     state <= DEBUGIDLE;
                  end if;
               end if;
               
            when BOOTLOADER_READ =>
               proc_adr       <= std_logic_vector(boot_read_addr);
               proc_rnw       <= '1';
               proc_ena       <= '1';
               state          <= BOOTLOADER_READWAIT;
               boot_read_addr <= boot_read_addr + 1;
               
            when BOOTLOADER_READWAIT =>
               if (proc_done = '1') then
                  proc_dout       <= proc_din;
                  proc_adr        <= std_logic_vector(boot_write_addr);
                  proc_rnw        <= '0';
                  proc_ena        <= '1';
                  state           <= BOOTLOADER_WRITEWAIT;
                  boot_write_addr <= boot_write_addr + 1;
               end if;
            
            when BOOTLOADER_WRITEWAIT =>
               if (proc_done = '1') then
                  boot_cnt    <= boot_cnt + 1;
                  if ((is_simu = '0' and boot_cnt = 32767) or (is_simu = '1' and boot_cnt = 127)) then
                     proc_dout       <= x"00080000";
                     proc_adr        <= std_logic_vector(to_unsigned(1152, proc_busadr)); -- core addr
                     proc_rnw        <= '0';
                     proc_ena        <= '1';
                     state <= BOTLOADER_WRITE_START;
                  else
                     state <= BOOTLOADER_READ;
                  end if;
               end if;
               
            when BOTLOADER_WRITE_START =>
               if (proc_done = '1') then
                  proc_dout       <= x"00000001";
                  proc_adr        <= std_logic_vector(to_unsigned(1024, proc_busadr)); -- core enable
                  proc_rnw        <= '0';
                  proc_ena        <= '1';
                  state <= DEBUGIDLE;
               end if;   
            
            
            -- receive register command
            when DEBUGIDLE =>
               blocklength_m1  <= 0;
               workcount       <= 0;
               timeout         <= 0;
            
               if (Fifo_valid = '1') then
                  receive_command((receive_byte_nr*8)+7 downto (receive_byte_nr*8)) <= Fifo_Dout;
                  if (receive_byte_nr < 3) then
                     receive_byte_nr <= receive_byte_nr + 1;
                  else
                     receive_byte_nr <= 0;
                     addr_buffer     <= Fifo_Dout(1 downto 0) & receive_command(23 downto 0);
                     proc_rnw        <= Fifo_Dout(6);
                     
                     if (Fifo_Dout(7) = '0') then -- non block mode
                        if (Fifo_Dout(6) = '1') then
                           state <= BLOCKREAD_READ;
                        else
                           state <= BLOCKWRITE;
                        end if;
                     else -- block mode
                        state           <= RECEIVELENGTH;
                     end if;
                  end if;
               end if;
               
            when RECEIVELENGTH =>
               if (timeout = TIMEOUTVALUE) then
                  state         <= DEBUGIDLE;
                  timeout_error <= '1';
               end if;
               
               if (Fifo_valid = '1') then
                  blocklength_m1 <= to_integer(unsigned(Fifo_Dout));
                  if (receive_command(30) = '1') then
                     state <= BLOCKREAD_READ;
                  else
                     state <= BLOCKWRITE;
                  end if;
               end if;
            
            -- write
            when BLOCKWRITE =>
               if (timeout = TIMEOUTVALUE) then
                  state         <= DEBUGIDLE;
                  timeout_error <= '1';
               end if;
            
               if (Fifo_valid = '1') then
                  receive_command((receive_byte_nr*8)+7 downto (receive_byte_nr*8)) <= Fifo_Dout;
                  if (receive_byte_nr < 3) then
                     receive_byte_nr <= receive_byte_nr + 1;
                  else
                     receive_byte_nr <= 0;
                     proc_adr        <= addr_buffer;
                     proc_dout       <= Fifo_Dout & receive_command(23 downto 0);
                     proc_ena        <= '1';
                     addr_buffer     <= std_logic_vector(unsigned(addr_buffer) + 1);
                     state           <= BLOCKWRITE_WAIT;
                  end if;
               end if;
               
            when BLOCKWRITE_WAIT =>
               if (timeout = TIMEOUTVALUE) then
                  state         <= DEBUGIDLE;
                  timeout_error <= '1';
               end if;
            
               if (proc_done = '1') then
                  if (workcount >= blocklength_m1) then
                     state  <= DEBUGIDLE;
                  else
                     workcount <= workcount + 1;
                     state     <= BLOCKWRITE;
                  end if;
               end if;
            
            -- read
            when BLOCKREAD_READ =>
               proc_adr        <= addr_buffer;
               proc_ena        <= '1';
               addr_buffer     <= std_logic_vector(unsigned(addr_buffer) + 1);
               state           <= BLOCKREAD_WAIT;
               
            when BLOCKREAD_WAIT =>
               if (timeout = TIMEOUTVALUE) then
                  state         <= DEBUGIDLE;
                  timeout_error <= '1';
               end if;
            
               if (proc_done = '1') then
                  transmit_command <= proc_din;
                  transmit_byte_nr <= 0;
                  state            <= BLOCKREAD_SEND;
               end if;
            
            when BLOCKREAD_SEND =>
               if (timeout = TIMEOUTVALUE) then
                  state         <= DEBUGIDLE;
                  timeout_error <= '1';
               end if;
            
               if (tx_busy = '0') then
                  transmit_byte_nr <= transmit_byte_nr + 1;
                  sendbyte <= transmit_command((transmit_byte_nr*8)+7 downto (transmit_byte_nr*8));
                  tx_enable <= '1';
                  if (transmit_byte_nr = 3) then
                     if (workcount >= blocklength_m1) then
                        state  <= DEBUGIDLE;
                     else
                        workcount <= workcount + 1;
                        state     <= BLOCKREAD_READ;
                     end if;
                  end if;
               end if;

         end case;
   
      end if;
   end process;
   
   gtestbench : if (is_simu = '1') generate
   begin
   
      itbrs232_receiver : entity rs232.tbrs232_receiver
      port map
      (
         clk         => clk,
         rx_byte     => rx_byte,
         valid       => rx_valid,
         rx          => command_in
      );
      
      itbrs232_transmitter : entity rs232.tbrs232_transmitter
      port map 
      (
         clk         => clk,     
         busy        => tx_busy,    
         sendbyte    => sendbyte,
         enable      => tx_enable,  
         tx          => command_out      
      );
      
   
   end generate;
   
   gsynthesis : if (is_simu = '0') generate
   begin
   
      irs232_receiver : entity rs232.rs232_receiver
      generic map
      (
         clk_speed   =>  clk_speed,
         baud        =>  baud
      )
      port map
      (
         clk         => clk,
         rx_byte     => rx_byte,
         valid       => rx_valid,
         rx          => command_in
      );
      
      irs232_transmitter : entity rs232.rs232_transmitter
      generic map
      (
         clk_speed => clk_speed,
         baud      => baud
      )
      port map 
      (
         clk         => clk,     
         busy        => tx_busy,    
         sendbyte    => sendbyte,
         enable      => tx_enable,  
         tx          => command_out      
      );
   
   end generate;
   
   
end architecture;

