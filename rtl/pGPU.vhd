library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pGPU is

   type div_type is record
      start     : std_logic;
      done      : std_logic;
      dividend  : signed(43 downto 0);
      divisor   : signed(11 downto 0);
      quotient  : signed(43 downto 0);
      remainder : signed(11 downto 0);
   end record;
  
end package;