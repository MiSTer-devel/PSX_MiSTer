library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     


entity rs232_transmitter  is
   generic
   (
      clk_speed : integer := 50000000;
      baud : integer := 115200
   );
   port 
   (
      clk         : in  std_logic; 
      busy        : out std_logic := '0';
      sendbyte    : in  std_logic_vector(7 downto 0);
      enable      : in  std_logic;
      tx          : out std_logic
   );
end entity;

architecture arch of rs232_transmitter is
   
   constant bittime  : integer := (clk_speed / baud)-1;
   
   signal running : std_logic := '0';
   
   signal bitslow    : integer range 0 to bittime + 1 := 0;
   signal bitcount   : integer range 0 to 9 := 0;
   
   signal byte_tx : std_logic_vector(9 downto 0) := (others => '0');
   

   
begin

   process (clk) 
   begin
      if rising_edge(clk) then
         
         if (running = '0' and enable = '1') then
            running <= '1';        
            bitcount <= 0;
            bitslow <= 0;
            byte_tx <= '1' & sendbyte & '0';
         end if;
         
         if (running = '1') then
            bitslow <= bitslow + 1;
            if (bitslow = bittime) then
               bitslow <= 0;
               if (bitcount < 9) then
                  bitcount <= bitcount + 1;
               else
                  bitcount <= 0;
                  running <= '0';  
               end if;    
            end if; 
    
         end if;
         
      end if;
   end process;
   
   busy <= '1' when running = '1' or enable = '1' else '0';
  
   tx <= '1' when running = '0' else byte_tx(bitcount);
   
end architecture;