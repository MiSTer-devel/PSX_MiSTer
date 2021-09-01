library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     


entity tbrs232_transmitter  is
   port 
   (
      clk         : in  std_logic; 
      busy        : out std_logic := '0';
      sendbyte    : in  std_logic_vector(7 downto 0);
      enable      : in  std_logic;
      tx          : out std_logic := '1'
   );
end entity;

architecture arch of tbrs232_transmitter is
   
   
begin

   busy <= enable;

   process
   begin
      tx <= '1';
      
      if (enable = '1') then
         
         tx <= '0';
         wait for 2 ps;
         for i in 0 to 7 loop
            tx <= sendbyte(i);
            wait for 2 ps;
         end loop;
         tx <= '1';
      
      end if;
      
      wait until clk = '0';
      wait until clk = '1';

   end process;

   
end architecture;