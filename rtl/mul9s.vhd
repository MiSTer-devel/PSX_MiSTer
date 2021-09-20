library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity mul9s is
   port 
   (
      mul1     : in  signed(8 downto 0);
      mul2     : in  signed(12 downto 0);
      result   : out signed(21 downto 0)
   );
end entity;

architecture arch of mul9s is
   
   
begin 

   result <= mul1 * mul2;

end architecture;


   