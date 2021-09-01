library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library rs232;
library tb;

entity etb_interpreter  is
   generic
   (
      clk_speed : integer := 50000000;
      baud      : integer := 115200
   );
   port 
   (
      clk         : in  std_logic; 
      command_in  : out std_logic;
      command_out : in  std_logic
   );
end entity;

architecture arch of etb_interpreter is
   
   signal slow_counter : unsigned(3 downto 0) := (others => '0');
   
   signal addr_counter : integer := 0;
   
   signal idle : std_logic := '1';
   
   signal transmit_command : std_logic_vector(31 downto 0) := (others => '0');
   signal transmit_byte_nr : integer := 0;
   signal sendbyte         : std_logic_vector(7 downto 0) := (others => '0');
   signal tx_enable        : std_logic := '0';
   signal tx_busy          : std_logic;
   
   signal receive_command  : std_logic_vector(31 downto 0) := (others => '0');
   signal receive_byte_nr  : integer := 0;
   signal receive_valid    : std_logic := '0';
   
   signal rx_valid         : std_logic;
   signal rx_byte          : std_logic_vector(7 downto 0);
   
   signal proc_command : std_logic_vector(31 downto 0);
   signal proc_bytes   : integer range 0 to 4;
   signal proc_enable  : std_logic;
   
begin

   process (clk)
   begin
      if rising_edge(clk) then
   
         -- tx side
         tx_enable <= '0';
      
         if (idle = '1' and proc_enable = '1') then
            addr_counter  <= addr_counter + 1;
            transmit_command <= proc_command;
            transmit_byte_nr <= 0;
            idle <= '0';     
         elsif (idle = '0') then
            if (tx_busy = '0') then
               transmit_byte_nr <= transmit_byte_nr + 1;
               sendbyte <= transmit_command((transmit_byte_nr*8)+7 downto (transmit_byte_nr*8));
               tx_enable <= '1';
               if (transmit_byte_nr = (proc_bytes - 1)) then
                  idle <= '1'; 
               end if;
            end if;
         end if;
         
         -- rx side
         receive_valid <= '0';
         if (rx_valid = '1') then
            receive_byte_nr <= receive_byte_nr + 1;
            receive_command((receive_byte_nr*8)+7 downto (receive_byte_nr*8)) <= rx_byte;
            if (receive_byte_nr = 3) then
               receive_byte_nr   <= 0;
               receive_valid     <= '1';
            end if;
         end if;
   
      end if;
   end process;
   
   
   istringprocessor: entity tb.estringprocessor
   generic map
   (
      clk_speed => clk_speed
   )
   port map
   (
      ready       => idle,
      tx_command  => proc_command,
      tx_bytes    => proc_bytes,
      tx_enable   => proc_enable,
      rx_command  => receive_command,
      rx_valid    => receive_valid
   );
   
   
   itbrs232_transmitter : entity rs232.tbrs232_transmitter
   port map 
   (
      clk         => clk,     
      busy        => tx_busy,    
      sendbyte    => sendbyte,
      enable      => tx_enable,  
      tx          => command_in      
   );
   
   itbrs232_receiver : entity rs232.tbrs232_receiver
   port map
   (
      clk         => clk,
      rx_byte     => rx_byte,
      valid       => rx_valid,
      rx          => command_out
   );

   
   
   
end architecture;