library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     


entity rs232_receiver  is
   generic
   (
      clk_speed : integer := 50000000;
      baud : integer := 115200
   );
   port 
   (
      clk         : in  std_logic; 
      rx_byte     : out std_logic_vector(7 downto 0);
      valid       : out std_logic;
      rx          : in  std_logic
   );
end entity;

architecture arch of rs232_receiver is
   
   constant bittime  : integer := (clk_speed / baud)-1;
   
   signal idle   : std_logic := '1';
   
   signal rx_ff  : std_logic := '0';
   signal old_rx : std_logic := '0';
   
   signal bitslow    : integer range 0 to bittime+1 := 0;
   signal bitcount   : integer range 0 to 8 := 0;
   
   signal byte_rx       : std_logic_vector(8 downto 0) := (others => '0');
   signal valid_buffer  : std_logic := '0';

   
begin


   process (clk) 
   begin
      if rising_edge(clk) then
         
         valid_buffer <= '0';
         
         rx_ff  <= rx;
         old_rx <= rx_ff;
         
         if (idle = '1' and rx_ff = '0' and old_rx = '1') then
            bitslow <= (bittime / 2) + 1;
            bitcount <= 0;
            idle <= '0';
         end if;
         
         if (idle = '0') then
            bitslow <= bitslow + 1;
            if (bitslow = bittime) then
               bitslow <= 0;
               byte_rx(bitcount) <= rx_ff;
               if (bitcount < 8) then
                  bitcount <= bitcount + 1;
               else
                  bitcount <= 0;
                  idle <= '1';  
                  valid_buffer <= '1';
               end if;    
            end if; 
         end if;
         
         
      end if;
   end process;
   
   rx_byte <= byte_rx(8 downto 1);
   
   valid <= valid_buffer;
  
   
end architecture;