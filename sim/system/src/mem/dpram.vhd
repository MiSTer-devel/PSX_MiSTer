library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all; 

ENTITY dpram IS
   generic (
       addr_width : integer := 8;
       data_width : integer := 8
   ); 
   PORT
   (
      clock_a     : IN STD_LOGIC;
      clken_a     : IN STD_LOGIC := '1';
      address_a   : IN STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
      data_a      : IN STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);
      wren_a      : IN STD_LOGIC := '0';
      q_a         : OUT STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);

      clock_b     : IN STD_LOGIC;
      clken_b     : IN STD_LOGIC := '1';
      address_b   : IN STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
      data_b      : IN STD_LOGIC_VECTOR (data_width-1 DOWNTO 0) := (others => '0');
      wren_b      : IN STD_LOGIC := '0';
      q_b         : OUT STD_LOGIC_VECTOR (data_width-1 DOWNTO 0)
   );
END dpram;

architecture rtl of dpram is

  -- Build a 2-D array type for the RAM
   subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
   type memory_t is array(2**ADDR_WIDTH-1 downto 0) of word_t;

   -- Declare the RAM 
   shared variable ram : memory_t := (others => (others => '0'));

begin

   -- Port A
   process(clock_a)
   begin
      if(rising_edge(clock_a)) then
         if (clken_a = '1') then
            if(wren_a = '1') then
               ram(to_integer(unsigned(address_a))) := data_a;
            end if;
            q_a <= ram(to_integer(unsigned(address_a)));
         end if;
      end if;
   end process;

   -- Port B
   process(clock_b)
   begin
      if(rising_edge(clock_b)) then
         if (clken_b = '1') then
            if(wren_b = '1') then
               ram(to_integer(unsigned(address_b))) := data_b;
            end if;
            q_b <= ram(to_integer(unsigned(address_b)));
         end if;
      end if;
   end process;

end rtl;
