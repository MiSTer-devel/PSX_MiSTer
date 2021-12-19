library ieee;
use ieee.std_logic_1164.all;

entity SyncRam is
   generic 
   (
      DATA_WIDTH : natural := 8;
      ADDR_WIDTH : natural := 6
   );
   port 
   (
      clk        : in std_logic;
      
      addr     : in natural range 0 to 2**ADDR_WIDTH - 1;
      datain   : in std_logic_vector((DATA_WIDTH-1) downto 0);
      dataout  : out std_logic_vector((DATA_WIDTH -1) downto 0);
      we       : in std_logic := '1'
   );
end;

architecture rtl of SyncRam is

   -- Build a 2-D array type for the RAM
   subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
   type memory_t is array(2**ADDR_WIDTH-1 downto 0) of word_t;

   -- Declare the RAM 
   shared variable ram : memory_t;

begin

   -- Port A
   process(clk)
   begin
   if(rising_edge(clk)) then 
      if(we = '1') then
         ram(addr) := datain;
      end if;
      dataout <= ram(addr);
   end if;
   end process;

end rtl;
