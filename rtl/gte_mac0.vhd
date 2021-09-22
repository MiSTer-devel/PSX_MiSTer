library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

use work.pGTE.all;

entity gte_mac0 is
   port 
   (
      clk2x          : in  std_logic;
      MAC0req        : in  tMAC0req;
      mac0_result    : out signed(31 downto 0);
      mac0_writeback : out std_logic := '0';
      mac0Last       : out signed(31 downto 0)
   );
end entity;

architecture arch of gte_mac0 is

begin 

   process (clk2x)
      variable mac0Result : signed(32 downto 0);
      variable addVal     : signed(31 downto 0);
   begin
      if rising_edge(clk2x) then
      
         mac0_writeback <= '0';
         
         if (MAC0req.trigger = '1') then
            mac0Result := resize(MAC0req.mul1 * MAC0req.mul2, 33);
         
            addVal := MAC0req.add;
            if (MAC0req.useResult = '1') then
               addVal := mac0Last;
            end if;
         
            if (MAC0req.swap = '1' and MAC0req.sub = '1') then
               mac0Result := mac0Result - addVal;
            elsif (MAC0req.sub = '1') then
               mac0Result := addVal - mac0Result;
            else
               mac0Result := addVal + mac0Result;
            end if;
            
            mac0_result    <= mac0Result(31 downto 0);
            mac0_writeback <= '1';
            
            if (MAC0req.checkOvf) then
               -- todo MAC0OverflowCheck
            end if;
            
            if (MAC0req.useIR) then
               if (MAC0req.IRshift = '1') then
                  mac0Result := x"000" & mac0Result(32 downto 12);
               end if;
               -- todo IR0OverflowSet
            end if;
            
            mac0Last <= mac0Result(31 downto 0);
         
         end if;
         
      end if;
   end process;

end architecture;





