library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

use work.pGTE.all;

entity gte_UNRDivide is
   port 
   (
      clk2x          : in  std_logic;
      trigger        : in  std_logic;
      lhs            : in  unsigned(15 downto 0);
      rhs            : in  unsigned(15 downto 0);
      result         : out unsigned(16 downto 0);
      divError       : out std_logic
   );
end entity;

architecture arch of gte_UNRDivide is

   type tunr_table is array(0 to 256) of unsigned(7 downto 0);
   constant unr_table : tunr_table :=
   (
      x"FF", x"FD", x"FB", x"F9", x"F7", x"F5", x"F3", x"F1", x"EF", x"EE", x"EC", x"EA", x"E8", x"E6", x"E4", x"E3", --
      x"E1", x"DF", x"DD", x"DC", x"DA", x"D8", x"D6", x"D5", x"D3", x"D1", x"D0", x"CE", x"CD", x"CB", x"C9", x"C8", --  00h..3Fh
      x"C6", x"C5", x"C3", x"C1", x"C0", x"BE", x"BD", x"BB", x"BA", x"B8", x"B7", x"B5", x"B4", x"B2", x"B1", x"B0", --
      x"AE", x"AD", x"AB", x"AA", x"A9", x"A7", x"A6", x"A4", x"A3", x"A2", x"A0", x"9F", x"9E", x"9C", x"9B", x"9A", --
      x"99", x"97", x"96", x"95", x"94", x"92", x"91", x"90", x"8F", x"8D", x"8C", x"8B", x"8A", x"89", x"87", x"86", --
      x"85", x"84", x"83", x"82", x"81", x"7F", x"7E", x"7D", x"7C", x"7B", x"7A", x"79", x"78", x"77", x"75", x"74", --  40h..7Fh
      x"73", x"72", x"71", x"70", x"6F", x"6E", x"6D", x"6C", x"6B", x"6A", x"69", x"68", x"67", x"66", x"65", x"64", --
      x"63", x"62", x"61", x"60", x"5F", x"5E", x"5D", x"5D", x"5C", x"5B", x"5A", x"59", x"58", x"57", x"56", x"55", --
      x"54", x"53", x"53", x"52", x"51", x"50", x"4F", x"4E", x"4D", x"4D", x"4C", x"4B", x"4A", x"49", x"48", x"48", --
      x"47", x"46", x"45", x"44", x"43", x"43", x"42", x"41", x"40", x"3F", x"3F", x"3E", x"3D", x"3C", x"3C", x"3B", --  80h..BFh
      x"3A", x"39", x"39", x"38", x"37", x"36", x"36", x"35", x"34", x"33", x"33", x"32", x"31", x"31", x"30", x"2F", --
      x"2E", x"2E", x"2D", x"2C", x"2C", x"2B", x"2A", x"2A", x"29", x"28", x"28", x"27", x"26", x"26", x"25", x"24", --
      x"24", x"23", x"22", x"22", x"21", x"20", x"20", x"1F", x"1E", x"1E", x"1D", x"1D", x"1C", x"1B", x"1B", x"1A", --
      x"19", x"19", x"18", x"18", x"17", x"16", x"16", x"15", x"15", x"14", x"14", x"13", x"12", x"12", x"11", x"11", --  C0h..FFh
      x"10", x"0F", x"0F", x"0E", x"0E", x"0D", x"0D", x"0C", x"0C", x"0B", x"0A", x"0A", x"09", x"09", x"08", x"08", --
      x"07", x"07", x"06", x"06", x"05", x"05", x"04", x"04", x"03", x"03", x"02", x"02", x"01", x"01", x"00", x"00", --
      x"00" -- one extra table entry (for "(d-7FC0h)/80h"=100h)
   );

   type tstate is
   (
      IDLE,
      SHIFT,
      READTABLE,
      CALC_X,
      CALC_D,
      CALC_R,
      CALCRESULT,
      CLIP
   );
   signal state : tstate := IDLE;
   
   signal shiftcount    : integer range 0 to 15;        
      
   signal calc_lhs      : unsigned(31 downto 0);
   signal calc_rhs      : unsigned(15 downto 0);
   signal tableValue    : unsigned(7 downto 0);
   signal divisor       : signed(16 downto 0);
   signal calc_val_x    : signed(10 downto 0);
   signal calc_val_xn   : signed(10 downto 0);
   signal calc_val_d    : signed(19 downto 0);
   signal calc_val_r    : unsigned(19 downto 0);
   signal calc_result   : unsigned(31 downto 0);

begin 

   process (clk2x)
      variable var_calc_d : signed(27 downto 0);
      variable var_calc_r : signed(27 downto 0);
   begin
      if rising_edge(clk2x) then
      
         divError       <= '0';
         
         case (state) is
         
            when IDLE =>
               if (trigger = '1') then
                  if (rhs * 2 <= lhs) then
                     divError <= '1';
                     result   <= (others => '1');
                  else
                     state <= SHIFT;
                  end if;
                  
                  shiftcount <= 0;
                  for i in 0 to 15 loop
                     if (rhs(i) = '1') then
                        shiftcount <= 15 - i;
                     end if;
                  end loop;
               
               end if;
               
            when SHIFT =>
               state    <= READTABLE;
               calc_lhs <= resize(lhs, 32) sll shiftcount;
               calc_rhs <= rhs sll shiftcount;
               
            when READTABLE =>
               state      <= CALC_X;
               tableValue <= unr_table((to_integer(calc_rhs(14 downto 0)) + 64) / 128);
               divisor    <= '0' & signed(calc_rhs);
               divisor(15)<= '1';
               
            when CALC_X =>
               state       <= CALC_D;
               calc_val_x  <= signed(resize(tableValue, 11) + 16#101#);
               calc_val_xn <= -signed((resize(tableValue, 11) + 16#101#));
            
            when CALC_D =>
               state      <= CALC_R;
               var_calc_d := resize(((divisor * calc_val_xn) + 16#80#), 28);
               calc_val_d <= x"20000" + var_calc_d(27 downto 8); 

            when CALC_R =>
               state      <= CALCRESULT;
               var_calc_r := resize(((calc_val_x * calc_val_d) + 16#80#), 28);
               calc_val_r <= unsigned(var_calc_r(27 downto 8));

            when CALCRESULT =>
               state       <= CLIP;
               calc_result <= resize(((calc_lhs * calc_val_r) + x"8000") / x"10000", 32);

            when CLIP =>
               state      <= IDLE;
               if (calc_result > x"1FFFF") then
                  result   <= (others => '1');
               else
                  result   <= calc_result(16 downto 0);
               end if;
               
         end case;
         

         
      end if;
   end process;

end architecture;





