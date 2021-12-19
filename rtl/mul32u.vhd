library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity mul32u is
   port 
   (
      mul1     : in  unsigned(31 downto 0);
      mul2     : in  unsigned(31 downto 0);
      result   : out unsigned(31 downto 0)
   );
end entity;

architecture arch of mul32u is
   
   
begin 

   result <= resize(mul1 * mul2, 32);

end architecture;


   