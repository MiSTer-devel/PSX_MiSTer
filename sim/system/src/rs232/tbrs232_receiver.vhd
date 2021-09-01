library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     


entity tbrs232_receiver  is
   port 
   (
      clk         : in  std_logic; 
      rx_byte     : out std_logic_vector(7 downto 0) := (others => '0');
      valid       : out std_logic := '0';
      rx          : in  std_logic
   );
end entity;

architecture arch of tbrs232_receiver is
   
   
begin

   process
   begin
      valid <= '0';
      
      wait until rx = '0';
      
      wait for 3 ps;
      for i in 0 to 7 loop
         rx_byte(i) <= rx;
         wait for 2 ps;
      end loop; 
      
      valid <= '1';
      wait until clk = '0';
      wait until clk = '1';
      valid <= '0';
      
   end process;
   
end architecture;