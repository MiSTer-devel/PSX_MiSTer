library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use ieee.math_real.all;   

entity SyncFifoFallThroughMLAB is
   generic 
   (
      SIZE              : integer;
      DATAWIDTH         : integer;
      NEARFULLDISTANCE  : integer;
      NEAREMPTYDISTANCE : integer := 0
   );
   port 
   ( 
      clk         : in  std_logic;
      reset       : in  std_logic;
                  
      Din         : in  std_logic_vector(DATAWIDTH - 1 downto 0);
      Wr          : in  std_logic; 
      Full        : out std_logic := '0';
      NearFull    : out std_logic := '0';
         
      Dout        : out std_logic_vector(DATAWIDTH - 1 downto 0) := (others => '0');
      Rd          : in  std_logic;
      Empty       : out std_logic := '1';
      NearEmpty   : out std_logic := '0'
   );
end;

architecture arch of SyncFifoFallThroughMLAB is

   constant SIZEBITS : integer := integer(ceil(log2(real(SIZE))));

   signal wrcnt   : unsigned(SIZEBITS - 1 downto 0) := (others => '0');
   signal rdcnt   : unsigned(SIZEBITS - 1 downto 0) := (others => '0');
 
   signal fifocnt : unsigned(SIZEBITS - 1 downto 0) := (others => '0');
 
   signal full_wire     : std_logic;
   signal empty_wire    : std_logic;

begin

   iRamMLAB: entity work.RamMLAB
   generic map
   (
      width           => DATAWIDTH,
      widthad         => SIZEBITS
   )
   port map
   (
      inclock         => clk,
      wren            => Wr,
      data            => Din,
      wraddress       => std_logic_vector(wrcnt),
      rdaddress       => std_logic_vector(rdcnt),
      q               => Dout
   );


   full_wire      <= '1' when fifocnt = (SIZEBITS - 1 downto 0 => '1')  else '0';
   empty_wire     <= '1' when fifocnt = 0                               else '0';

   process(clk)
      variable newCount : unsigned(SIZEBITS - 1 downto 0);
   begin
      if rising_edge(clk) then
         if (reset = '1') then
            wrcnt   <= (others => '0');
            rdcnt   <= (others => '0');
            fifocnt <= (others => '0');
            Full    <= '0';
            Empty   <= '1';
         else
            newCount := fifocnt;
            if (Wr = '1' and full_wire = '0') then
               if (Rd = '0' or empty_wire = '1') then
                  newCount := newCount + 1;
               end if;
            elsif (Rd = '1' and empty_wire = '0') then
               newCount := newCount - 1;
            end if;
            
            if (newCount < NEARFULLDISTANCE) then
               NearFull <= '0';
            else
               NearFull <= '1';
            end if;            
            
            if (newCount >= NEAREMPTYDISTANCE) then
               NearEmpty <= '0';
            else
               NearEmpty <= '1';
            end if;
         
            if (Wr = '1') then
               wrcnt <= wrcnt+1;
            end if;
            
            if (Rd = '1') then
               rdcnt <= rdcnt+1;
            end if;
            
            if (newCount = 0) then
               Empty <= '1'; 
            else
               Empty <= '0';
            end if;
            
            if (newCount = (SIZEBITS - 1 downto 0 => '1') or full_wire = '1') then
               Full <= '1'; 
            else
               Full <= '0';
            end if;
            
            fifocnt <= newCount;
            
         end if;
      end if;
   end process;

end architecture;