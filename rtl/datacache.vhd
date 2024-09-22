library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   
use ieee.math_real.all;  

library mem;

entity datacache is
   generic
   (
      SIZE                     : integer;
      SIZEBASEBITS             : integer;
      BITWIDTH                 : integer
   );
   port 
   (
      clk               : in  std_logic;
      reset             : in  std_logic;
      halfrate          : in  std_logic;
                        
      read_ce           : in  std_logic;
      read_enable       : in  std_logic;
      read_addr         : in  std_logic_vector(SIZEBASEBITS-1 downto 0);
      read_hit          : out std_logic := '0';
      read_data         : out std_logic_vector(BITWIDTH -1 downto 0) := (others => '0');
      
      write_enable      : in  std_logic;
      write_clear       : in  std_logic;
      write_addr        : in  std_logic_vector(SIZEBASEBITS-1 downto 0);
      write_data        : in  std_logic_vector(BITWIDTH -1 downto 0) := (others => '0')
   );
end entity;

architecture arch of datacache is
  
   constant SIZEBITS     : integer := integer(ceil(log2(real(SIZE))));
   constant ADDRSAVEBITS : integer := SIZEBASEBITS - SIZEBITS;
   
   type tState is
   (
      IDLE,
      CLEARCACHE
   );
   signal state : tstate := IDLE;
   
   -- memory
   signal memory_addr_a      : std_logic_vector(SIZEBITS - 1 downto 0) := (others => '0');
   signal memory_addr_b      : std_logic_vector(SIZEBITS - 1 downto 0) := (others => '0');
   signal memory_datain      : std_logic_vector(BITWIDTH - 1 downto 0) := (others => '0');
   signal memory_dataout     : std_logic_vector(BITWIDTH - 1 downto 0) := (others => '0');
   signal memory_we          : std_logic := '0';
                
   signal cache_hit          : std_logic;
   signal cache_half         : std_logic := '0';
                
   -- addr save --  uppermost bit is invalid bit        
   signal addrsave_addr_a    : std_logic_vector(SIZEBITS - 1 downto 0) := (others => '0');
   signal addrsave_addr_b    : std_logic_vector(SIZEBITS - 1 downto 0) := (others => '0');
   signal addrsave_datain    : std_logic_vector(ADDRSAVEBITS downto 0) := (others => '0');
   signal addrsave_dataout   : std_logic_vector(ADDRSAVEBITS downto 0) := (others => '0');
   signal addrsave_we        : std_logic := '0';
   signal upperbits          : std_logic_vector(SIZEBASEBITS - SIZEBITS - 1 downto 0) := (others => '0');
   signal writeAndRead       : std_logic := '0';
   
   -- clear cache
   signal clear_counter      : unsigned(SIZEBITS - 1 downto 0);
   
   -- debug
   signal cache_requests     : integer := 0;
   signal cache_hits         : integer := 0;
   
begin 

   iRamMemory: entity work.dpram
   generic map ( addr_width => SIZEBITS, data_width => BITWIDTH)
   port map
   (
      clock_a     => clk,
      clken_a     => read_ce,
      address_a   => memory_addr_a,
      data_a      => (memory_dataout'range => '0'),
      wren_a      => '0',
      q_a         => memory_dataout,
      
      clock_b     => clk,
      address_b   => memory_addr_b,
      data_b      => memory_datain,
      wren_b      => memory_we,
      q_b         => open
   );
   
   iRamaddrsave: entity work.dpram
   generic map ( addr_width => SIZEBITS, data_width => ADDRSAVEBITS + 1)
   port map
   (
      clock_a     => clk,
      clken_a     => read_ce,
      address_a   => addrsave_addr_a,
      data_a      => (addrsave_dataout'range => '0'),
      wren_a      => '0',
      q_a         => addrsave_dataout,
      
      clock_b     => clk,
      address_b   => addrsave_addr_b,
      data_b      => addrsave_datain,
      wren_b      => addrsave_we,
      q_b         => open
   );
   
   -- reading
   memory_addr_a    <= read_addr(SIZEBITS - 1 downto 0);
   addrsave_addr_a  <= read_addr(SIZEBITS - 1 downto 0);
   
   cache_hit        <= '1' when (addrsave_dataout = '0' & upperbits) else '0';
   
   read_hit         <= cache_hit and cache_half and not writeAndRead;
   read_data        <= memory_dataout;
   
   -- writing
   addrsave_addr_b <= std_logic_vector(clear_counter) when (state = CLEARCACHE) else write_addr(SIZEBITS - 1 downto 0);
   addrsave_datain <= (others => '1')                 when (state = CLEARCACHE) else write_clear & write_addr(SIZEBASEBITS-1 downto SIZEBITS);
   addrsave_we     <= '1'                             when (state = CLEARCACHE) else write_enable;
   
   memory_addr_b   <= write_addr(SIZEBITS - 1 downto 0);
   memory_datain   <= write_data;
   memory_we       <= write_enable;
   
   process (clk)
   begin
      if rising_edge(clk) then
      
         if (read_ce = '1') then
            upperbits <= read_addr(SIZEBASEBITS-1 downto SIZEBITS);
         end if;
         
         if (read_ce = '1') then
            writeAndRead <= '0';
            if (memory_we = '1' and addrsave_addr_a = addrsave_addr_b) then
               writeAndRead <= '1';
            end if;
         end if;

         if (halfrate = '1') then
            cache_half <= not cache_half;
         elsif (halfrate = '0') then
            cache_half <= '1';
         end if;

         if (reset = '1') then
            state          <= CLEARCACHE;
            clear_counter  <= (others => '0');
            cache_requests <= 0;
            cache_hits     <= 0;
         else

            case(state) is
            
               when IDLE =>
                  if (read_enable = '1') then
                     cache_requests  <= cache_requests + 1;
                     if (read_hit = '1') then
                        cache_hits <= cache_hits + 1;
                     end if;
                  end if;
                  
               when CLEARCACHE =>
                  if (clear_counter < SIZE - 1) then
                     clear_counter <= clear_counter + 1;
                  else
                     state          <= IDLE;
                  end if;
                  
            end case;  
            
         end if;
         
         if (cache_requests = 0 and cache_hits = 1) then
            cache_hits <= 0;
         end if;

      end if;
   end process;

   
end architecture;




























