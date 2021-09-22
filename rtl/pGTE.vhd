library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pGTE is

   type tMAC0req is record
      mul1        : signed(15 downto 0);
      mul2        : signed(15 downto 0);
      add         : signed(31 downto 0);
      sub         : std_logic;
      swap        : std_logic;
      useIR       : std_logic;
      IRshift     : std_logic;
      checkOvf    : std_logic;
      useResult   : std_logic; 
      trigger     : std_logic; 
   end record;
  
end package;