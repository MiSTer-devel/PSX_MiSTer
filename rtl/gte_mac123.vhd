library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

use work.pGTE.all;

entity gte_mac123 is
   port 
   (
      clk2x          : in  std_logic;
      MACreq         : in  tMAC123req;
      mac_result     : out signed(31 downto 0);
      mac_writeback  : out std_logic := '0';
      ir_result      : out signed(15 downto 0);
      ir_writeback   : out std_logic := '0';
      macLast        : out signed(31 downto 0);
      flagMacUF      : out std_logic;
      flagMacOF      : out std_logic;
      flagIR         : out std_logic
   );
end entity;

architecture arch of gte_mac123 is
   
   constant MINVAL      : signed(43 downto 0) := x"80000000000";
   constant MAXVAL      : signed(43 downto 0) := x"7FFFFFFFFFF";
   
   signal macResult_1  : signed(43 downto 0);
   
   signal checkOvf      : std_logic := '0';

begin 

   flagMacUF <= '1' when (checkOvf = '1' and macResult_1 < MINVAL) else '0';
   flagMacOF <= '1' when (checkOvf = '1' and macResult_1 > MAXVAL) else '0';

   macLast <= macResult_1(31 downto 0);

   process (clk2x)
      variable macResult : signed(63 downto 0);
      variable addVal    : signed(43 downto 0);
      variable IRresult  : signed(31 downto 0);
   begin
      if rising_edge(clk2x) then
      
         mac_writeback  <= '0';
         ir_writeback   <= '0';
         checkOvf       <= '0';
         flagIR         <= '0';
         
         if (MACreq.trigger = '1') then
            macResult := MACreq.mul1 * MACreq.mul2;
         
            addVal := resize(MACreq.add, 44);
            if (MACreq.useResult = '1') then
               addVal := macResult_1;
            end if;
         
            if (MACreq.swap = '1' and MACreq.sub = '1') then
               macResult := macResult - addVal;
            elsif (MACreq.sub = '1') then
               macResult := addVal - macResult;
            else
               macResult := addVal + macResult;
            end if;
            
            macResult_1   <= macResult(43 downto 0);
            
            if (MACreq.saveShifted = '1') then
               mac_result <= macResult(43 downto 12);
            else
               mac_result <= macResult(31 downto 0);
            end if;
            mac_writeback <= '1';
            
            checkOvf <= '1';
            
            if (MACreq.useIR) then
            
               -- result
               IRresult := macResult(31 downto 0);
               if (MACreq.IRshift = '1') then
                  IRresult := macResult(43 downto 12);
               end if;
               
               ir_writeback <= '1';
               ir_result    <= IRresult(15 downto 0);
               if (MACreq.satIR = '1' and IRresult < 0) then
                  ir_result <= (others => '0');
               elsif (MACreq.satIR = '0' and IRresult < -32768) then
                  ir_result <= x"8000";
               elsif (IRresult > 16#7FFF#) then
                  ir_result <= x"7FFF";
               end if;
               
               -- flags
               IRresult := macResult(31 downto 0);
               if (MACreq.IRshiftFlag = '1') then
                  IRresult := macResult(43 downto 12);
               end if;
               
               if (MACreq.satIRFlag = '1' and IRresult < 0) then
                  flagIR <= '1';
               elsif (MACreq.satIRFlag = '0' and IRresult < -32768) then
                  flagIR <= '1';
               elsif (IRresult > 16#7FFF#) then
                  flagIR <= '1';
               end if;
               
               
            end if;
         
         end if;
         
      end if;
   end process;

end architecture;





