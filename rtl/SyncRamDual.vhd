library ieee;
use ieee.std_logic_1164.all;

entity SyncRamDual is
   generic 
   (
      DATA_WIDTH : natural := 8;
      ADDR_WIDTH : natural := 6
   );
   port 
   (
      clk        : in std_logic;
      
      addr_a     : in natural range 0 to 2**ADDR_WIDTH - 1;
      datain_a   : in std_logic_vector((DATA_WIDTH-1) downto 0);
      dataout_a  : out std_logic_vector((DATA_WIDTH -1) downto 0);
      we_a       : in std_logic := '1';
      re_a       : in std_logic := '1';
                 
      addr_b     : in natural range 0 to 2**ADDR_WIDTH - 1;
      datain_b   : in std_logic_vector((DATA_WIDTH-1) downto 0);
      dataout_b  : out std_logic_vector((DATA_WIDTH -1) downto 0);
      we_b       : in std_logic := '1';
      re_b       : in std_logic := '1'
   );
end;

architecture rtl of SyncRamDual is

   -- Build a 2-D array type for the RAM
   subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
   type memory_t is array(0 to 2**ADDR_WIDTH-1) of word_t;

   -- Declare the RAM 
   signal ram : memory_t := (others => (others => '0'));

begin

   -- Port A
   process(clk)
   begin
      if(rising_edge(clk)) then 
   
         if(we_a = '1') then
            ram(addr_a) <= datain_a;
         end if;
         if (re_a = '1') then
            dataout_a <= ram(addr_a);
         end if;
   
         if(we_b = '1') then
            ram(addr_b) <= datain_b;
         end if;
         if (re_b = '1') then
            dataout_b <= ram(addr_b);
         end if;
         
      end if;
   end process;

end rtl;
