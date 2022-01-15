library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all; 

entity RamMLAB is
   generic 
   (
      width           :  natural;
      width_byteena   :  natural := 1;
      widthad         :  natural
   );
   port 
   (
      inclock         : in std_logic;
      wren            : in std_logic;
      data            : in std_logic_vector(width-1 downto 0);
      wraddress       : in std_logic_vector(widthad-1 downto 0);
      rdaddress       : in std_logic_vector(widthad-1 downto 0);
      q               : out std_logic_vector(width-1 downto 0)
   );
end;

architecture rtl of RamMLAB is

   -- Build a 2-D array type for the RAM
   subtype word_t is std_logic_vector((width-1) downto 0);
   type memory_t is array(2**widthad-1 downto 0) of word_t;

   -- Declare the RAM 
   signal ram : memory_t := (others => (others => '0'));

begin

   process(inclock)
   begin
      if(rising_edge(inclock)) then 
   
         if(wren = '1') then
            ram(to_integer(unsigned(wraddress))) <= data;
         end if;

      end if;
   end process;
   
   q <=  ram(to_integer(unsigned(rdaddress)));

end rtl;