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
      macLast        : out signed(44 downto 0);
      macShifted     : out signed(31 downto 0);
      flagMacUF      : out std_logic;
      flagMacOF      : out std_logic;
      flagIR         : out std_logic
   );
end entity;

architecture arch of gte_mac123 is
   
   constant MINVAL      : signed(44 downto 0) := '1' & x"80000000000";
   constant MAXVAL      : signed(44 downto 0) := '0' & x"7FFFFFFFFFF";
   
   signal macResult_1   : signed(44 downto 0);
   
   signal checkOvf      : std_logic := '0';
   
   signal IRshift_1     : std_logic; 
   signal IRshiftFlag_1 : std_logic; 
   signal satIR_1       : std_logic; 
   signal satIRFlag_1   : std_logic; 

begin 

   flagMacUF <= '1' when (checkOvf = '1' and macResult_1 < MINVAL) else '0';
   flagMacOF <= '1' when (checkOvf = '1' and macResult_1 > MAXVAL) else '0';

   process (clk2x)
      variable macResult : signed(44 downto 0);
      variable addVal    : signed(44 downto 0);
      variable IRresult  : signed(31 downto 0);
   begin
      if rising_edge(clk2x) then
      
         mac_writeback  <= '0';
         ir_writeback   <= '0';
         checkOvf       <= '0';
         
         if (MACreq.trigger = '1') then
            macLast   <= macResult_1;
         
            macResult := resize(MACreq.mul1 * MACreq.mul2, 45);
         
            addVal := MACreq.add;
            if (MACreq.useResult = '1') then
               addVal := resize(macResult_1(43 downto 0), 45);
            end if;
         
            if (MACreq.swap = '1' and MACreq.sub = '1') then
               macResult := macResult - addVal;
            elsif (MACreq.sub = '1') then
               macResult := addVal - macResult;
            else
               macResult := addVal + macResult;
            end if;
            
            macResult_1   <= macResult(44 downto 0);
            
            if (MACreq.saveShifted = '1') then
               mac_result <= macResult(43 downto 12);
            else
               mac_result <= macResult(31 downto 0);
            end if;
            mac_writeback <= '1';
            
            macShifted <= macResult(43 downto 12);
            
            checkOvf <= '1';
            
            if (MACreq.useIR) then
               ir_writeback <= '1';
            end if;
            
            IRshift_1     <= MACreq.IRshift;  
            IRshiftFlag_1 <= MACreq.IRshiftFlag;  
            satIR_1       <= MACreq.satIR;    
            satIRFlag_1   <= MACreq.satIRFlag;
            
         end if;
         
      end if;
   end process;
   
   process (macResult_1, ir_writeback, IRshift_1, IRshiftFlag_1, satIR_1, satIRFlag_1)
      variable IRresult  : signed(31 downto 0);
   begin
   
      flagIR    <= '0';
      ir_result <= (others => '0');
      
      if (ir_writeback = '1') then
         -- result
         IRresult := macResult_1(31 downto 0);
         if (IRshift_1 = '1') then
            IRresult := macResult_1(43 downto 12);
         end if;
         
         ir_result    <= IRresult(15 downto 0);
         if (satIR_1 = '1' and IRresult < 0) then
            ir_result <= (others => '0');
         elsif (satIR_1 = '0' and IRresult < -32768) then
            ir_result <= x"8000";
         elsif (IRresult > 16#7FFF#) then
            ir_result <= x"7FFF";
         end if;
         
         -- flags
         IRresult := macResult_1(31 downto 0);
         if (IRshiftFlag_1 = '1') then
            IRresult := macResult_1(43 downto 12);
         end if;
         
         if (satIRFlag_1 = '1' and IRresult < 0) then
            flagIR <= '1';
         elsif (satIRFlag_1 = '0' and IRresult < -32768) then
            flagIR <= '1';
         elsif (IRresult > 16#7FFF#) then
            flagIR <= '1';
         end if;
      end if;
         
   end process;

end architecture;





