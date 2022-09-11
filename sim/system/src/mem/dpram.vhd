library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all; 

ENTITY dpram IS
   generic 
   (
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

-- ##############################################
-- dif : Port a wider than port b
-- ##############################################

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all; 

ENTITY dpram_dif_A IS
   generic 
   (
		addr_width_a  : integer := 8;
		data_width_a  : integer := 8;
		addr_width_b  : integer := 8;
		data_width_b  : integer := 8
   ); 
   PORT
   (
      clock_a     : IN STD_LOGIC;
      clken_a     : IN STD_LOGIC := '1';
      address_a   : IN STD_LOGIC_VECTOR (addr_width_a-1 DOWNTO 0);
      data_a      : IN STD_LOGIC_VECTOR (data_width_a-1 DOWNTO 0);
      wren_a      : IN STD_LOGIC := '0';
      q_a         : OUT STD_LOGIC_VECTOR (data_width_a-1 DOWNTO 0);

      clock_b     : IN STD_LOGIC;
      clken_b     : IN STD_LOGIC := '1';
      address_b   : IN STD_LOGIC_VECTOR (addr_width_b-1 DOWNTO 0);
      data_b      : IN STD_LOGIC_VECTOR (data_width_b-1 DOWNTO 0) := (others => '0');
      wren_b      : IN STD_LOGIC := '0';
      q_b         : OUT STD_LOGIC_VECTOR (data_width_b-1 DOWNTO 0)
   );
END dpram_dif_A;

architecture rtl of dpram_dif_A is

   constant RATIO : integer := data_width_a / data_width_b;

   -- Build a 2-D array type for the RAM
   subtype word_t is std_logic_vector((data_width_b-1) downto 0);
   type memory_t is array(2**addr_width_b-1 downto 0) of word_t;

   -- Declare the RAM 
   shared variable ram : memory_t := (others => (others => '0'));

begin

   -- Port A
   process(clock_a)
   begin
      if(rising_edge(clock_a)) then
         if (clken_a = '1') then
            for i in 0 to RATIO - 1 loop
               if(wren_a = '1') then
                  ram(to_integer(unsigned(address_a)) * RATIO + i) := data_a(((i * data_width_b) + (data_width_b - 1)) downto (i *data_width_b));
               end if;
               q_a(((i * data_width_b) + (data_width_b - 1)) downto (i *data_width_b)) <= ram(to_integer(unsigned(address_a)) * RATIO + i);
            end loop;
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

-- ##############################################
-- dif : Port b wider than port a
-- ##############################################

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all; 

ENTITY dpram_dif_b IS
   generic 
   (
		addr_width_a  : integer := 8;
		data_width_a  : integer := 8;
		addr_width_b  : integer := 8;
		data_width_b  : integer := 8
   ); 
   PORT
   (
      clock_a     : IN STD_LOGIC;
      clken_a     : IN STD_LOGIC := '1';
      address_a   : IN STD_LOGIC_VECTOR (addr_width_a-1 DOWNTO 0);
      data_a      : IN STD_LOGIC_VECTOR (data_width_a-1 DOWNTO 0);
      wren_a      : IN STD_LOGIC := '0';
      q_a         : OUT STD_LOGIC_VECTOR (data_width_a-1 DOWNTO 0);

      clock_b     : IN STD_LOGIC;
      clken_b     : IN STD_LOGIC := '1';
      address_b   : IN STD_LOGIC_VECTOR (addr_width_b-1 DOWNTO 0);
      data_b      : IN STD_LOGIC_VECTOR (data_width_b-1 DOWNTO 0) := (others => '0');
      wren_b      : IN STD_LOGIC := '0';
      q_b         : OUT STD_LOGIC_VECTOR (data_width_b-1 DOWNTO 0)
   );
END dpram_dif_b;

architecture rtl of dpram_dif_b is

   constant RATIO : integer := data_width_b / data_width_a;

   -- Build a 2-D array type for the RAM
   subtype word_t is std_logic_vector((data_width_a-1) downto 0);
   type memory_t is array(2**addr_width_a-1 downto 0) of word_t;

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
            for i in 0 to RATIO - 1 loop
               if(wren_b = '1') then
                     ram(to_integer(unsigned(address_b)) * RATIO + i) := data_b(((i * data_width_a) + (data_width_a - 1)) downto (i *data_width_a));
               end if;
               q_b(((i * data_width_a) + (data_width_a - 1)) downto (i *data_width_a)) <= ram(to_integer(unsigned(address_b)) * RATIO + i);
            end loop;
         end if;
      end if;
   end process;

end rtl;

-- ##############################################
-- dif : base unit that instantiates A or B
-- ##############################################

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all; 

ENTITY dpram_dif IS
   generic 
   (
		addr_width_a  : integer := 8;
		data_width_a  : integer := 8;
		addr_width_b  : integer := 8;
		data_width_b  : integer := 8
   ); 
   PORT
   (
      clock_a     : IN STD_LOGIC;
      clken_a     : IN STD_LOGIC := '1';
      address_a   : IN STD_LOGIC_VECTOR (addr_width_a-1 DOWNTO 0);
      data_a      : IN STD_LOGIC_VECTOR (data_width_a-1 DOWNTO 0);
      wren_a      : IN STD_LOGIC := '0';
      q_a         : OUT STD_LOGIC_VECTOR (data_width_a-1 DOWNTO 0);

      clock_b     : IN STD_LOGIC;
      clken_b     : IN STD_LOGIC := '1';
      address_b   : IN STD_LOGIC_VECTOR (addr_width_b-1 DOWNTO 0);
      data_b      : IN STD_LOGIC_VECTOR (data_width_b-1 DOWNTO 0) := (others => '0');
      wren_b      : IN STD_LOGIC := '0';
      q_b         : OUT STD_LOGIC_VECTOR (data_width_b-1 DOWNTO 0)
   );
END dpram_dif;

architecture rtl of dpram_dif is

begin

   gAlarger : if data_width_a >= data_width_b generate
   begin
      idpram_dif_A : entity work.dpram_dif_A
      generic map
      (
         addr_width_a  => addr_width_a,
         data_width_a  => data_width_a,
         addr_width_b  => addr_width_b,
         data_width_b  => data_width_b
      )
      PORT map
      (
         clock_a     => clock_a,  
         clken_a     => clken_a,  
         address_a   => address_a,
         data_a      => data_a,  
         wren_a      => wren_a,   
         q_a         => q_a,      
                                 
         clock_b     => clock_b,  
         clken_b     => clken_b,  
         address_b   => address_b,
         data_b      => data_b,   
         wren_b      => wren_b,   
         q_b         => q_b      
      );
   end generate;
   
   gBlarger : if data_width_a < data_width_b generate
   begin
      idpram_dif_b : entity work.dpram_dif_b
      generic map
      (
         addr_width_a  => addr_width_a,
         data_width_a  => data_width_a,
         addr_width_b  => addr_width_b,
         data_width_b  => data_width_b
      )
      PORT map
      (
         clock_a     => clock_a,  
         clken_a     => clken_a,  
         address_a   => address_a,
         data_a      => data_a,  
         wren_a      => wren_a,   
         q_a         => q_a,      
                                 
         clock_b     => clock_b,  
         clken_b     => clken_b,  
         address_b   => address_b,
         data_b      => data_b,   
         wren_b      => wren_b,   
         q_b         => q_b      
      );
   end generate;
   

end rtl;