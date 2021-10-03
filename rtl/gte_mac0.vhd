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
      mac0_result    : out signed(34 downto 0);
      mac0_writeback : out std_logic := '0';
      mac0Last       : out signed(34 downto 0);
      ir_result      : out signed(15 downto 0);
      ir_writeback   : out std_logic := '0';
      flagMac0UF     : out std_logic;
      flagMac0OF     : out std_logic;
      flagIR         : out std_logic
   );
end entity;

architecture arch of gte_mac0 is
   
   constant MINVAL      : signed(34 downto 0) := "111" & x"80000000";
   constant MAXVAL      : signed(34 downto 0) := "000" & x"7FFFFFFF";
   
   signal mac0Result_1  : signed(34 downto 0);
   
   signal checkOvf      : std_logic := '0';
   
   signal IRshift_1     : std_logic;

begin 

   flagMac0UF <= '1' when (checkOvf = '1' and mac0Result_1 < MINVAL) else '0';
   flagMac0OF <= '1' when (checkOvf = '1' and mac0Result_1 > MAXVAL) else '0';

   process (clk2x)
      variable mac0Result : signed(34 downto 0);
      variable addVal     : signed(34 downto 0);
   begin
      if rising_edge(clk2x) then
      
         mac0_writeback <= '0';
         ir_writeback   <= '0';
         checkOvf       <= '0';
         
         if (MAC0req.trigger = '1') then
            mac0Last   <= mac0Result_1;
         
            mac0Result := resize(MAC0req.mul1 * MAC0req.mul2, 35);
         
            addVal := resize(MAC0req.add, 35);
            if (MAC0req.useResult = '1') then
               addVal := mac0Result_1;
            end if;
         
            if (MAC0req.swap = '1' and MAC0req.sub = '1') then
               mac0Result := mac0Result - addVal;
            elsif (MAC0req.sub = '1') then
               mac0Result := addVal - mac0Result;
            else
               mac0Result := addVal + mac0Result;
            end if;
            
            mac0Result_1   <= mac0Result;
            mac0_result    <= mac0Result;
            mac0_writeback <= '1';
            
            if (MAC0req.checkOvf) then
               checkOvf <= '1';
            end if;
            
            if (MAC0req.useIR) then
               ir_writeback <= '1';
            end if;
         
            IRshift_1 <= MAC0req.IRshift;
         
         end if;
         
      end if;
   end process;
   
   process (ir_writeback, mac0Result_1, IRshift_1)
      variable IRresult  : signed(31 downto 0);
   begin

      flagIR    <= '0';
      ir_result <= (others => '0');

      if (ir_writeback = '1') then
         IRresult := mac0Result_1(31 downto 0);
         if (IRshift_1 = '1') then
            IRresult := resize(mac0Result_1 / 4096, 32);
         end if;
         
         if (IRresult < 0) then
            ir_result <= (others => '0');
            flagIR    <= '1';
         elsif (IRresult > 16#1000#) then
            ir_result <= x"1000";
            flagIR    <= '1';
         else
            ir_result <= IRresult(15 downto 0);
         end if;
         
      end if;
         
   end process;

end architecture;





