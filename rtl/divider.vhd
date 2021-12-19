library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

entity divider is
   port 
   (
      clk       : in  std_logic;
      start     : in  std_logic;
      done      : out std_logic := '0';
      busy      : out std_logic := '0';
      dividend  : in  signed;
      divisor   : in  signed;
      quotient  : out signed;
      remainder : out signed
   );
end entity;

architecture arch of divider is

   constant bits_per_cycle : integer := 1;
   
   signal dividend_u    : unsigned(dividend'length downto 0);
   signal divisor_u     : unsigned(divisor'length downto 0);
   signal quotient_u    : unsigned(quotient'length downto 0) := (others => '0');
   signal Akku          : unsigned (divisor'left + 1 downto divisor'right);
   signal QPointer      : integer range quotient_u'range;
   signal done_buffer   : std_logic := '0';
   
   signal sign_dividend : std_logic := '0';
   signal sign_divisor  : std_logic := '0';

begin 
   
   process (clk) is
      variable XPointer    : integer range dividend_u'range;
      variable QPointerNew : integer range quotient_u'range;
      variable AkkuNew     : unsigned (divisor'left + 1 downto divisor'right);
      variable Rdy_i       : std_logic;
      variable Q_bits      : std_logic_vector(bits_per_cycle-1 downto 0);
      variable Diff        : unsigned (AkkuNew'range);
   begin
      if rising_edge(clk) then

         done_buffer <= '0';
         busy        <= '0';
         
         -- == Initialize loop ===============================================
         if start = '1' then
            
            busy    <= '1';
            
            dividend_u  <= '0' & unsigned(abs(dividend));
            divisor_u   <= '0' & unsigned(abs(divisor));
            
            sign_dividend <= dividend(dividend'left);
            sign_divisor  <= divisor(divisor'left);
            
            QPointerNew := quotient_u'left;
            XPointer    := dividend_u'left;
            Rdy_i       := '0';
            --AkkuNew     := (Akku'left downto 1 => '0') & dividend(XPointer);
            AkkuNew     := (others => '0');
         -- == Repeat for every Digit in Q ===================================
         elsif Rdy_i = '0' then
            busy    <= '1';
            AkkuNew := Akku;
            QPointerNew := QPointer;        
            
            for i in 1 to bits_per_cycle loop
             
               -- Calculate output digit and new Akku ---------------------------
               Diff := AkkuNew - divisor_u;
               if Diff(Diff'left) = '0' then              -- Does Y fit in Akku?
                  Q_bits(bits_per_cycle-i)   := '1';                         -- YES: Digit is '1'
                  AkkuNew := unsigned(shift_left(Diff,1));--      Diff -> Akku
               else                                       --    
                  Q_bits(bits_per_cycle-i)   := '0';                         -- NO : Digit is '0'
                  AkkuNew := unsigned(Shift_left(AkkuNew,1));--      Shift Akku
               end if;
               -- ---------------------------------------------------------------
               if XPointer > dividend'right then                 -- divisor read completely?
                  XPointer := XPointer - 1;               -- NO : Put next digit
                  AkkuNew(AkkuNew'right) := dividend_u(XPointer);  --      in Akku         
               else
                  AkkuNew(AkkuNew'right) := '0'        ;  -- YES: Read Zeros (post point)      
               end if;
               -- ---------------------------------------------------------------
               if QPointerNew > quotient'right then                 -- Has this been the last cycle?
                  QPointerNew := QPointerNew - 1;               -- NO : Prepare next cycle
               else                                       -- 
                  Rdy_i := '1';                             -- YES: work done
                  done_buffer <= '1';
               end if;
               
            end loop; 
            
            quotient_u(QPointer downto QPointer-(bits_per_cycle-1)) <= unsigned(Q_bits);
         end if;

         QPointer  <= QPointerNew;
         Akku      <= AkkuNew;
         
         if ((sign_dividend xor sign_divisor) = '1') then
            quotient <= -signed(quotient_u(quotient'left downto 0));
         else
            quotient <= signed(quotient_u(quotient'left downto 0));
         end if;
         if (sign_dividend = '1') then
            remainder <= -signed(AkkuNew(remainder'left + 1 downto remainder'right + 1));
         else
            remainder <= signed(AkkuNew(remainder'left + 1 downto remainder'right + 1));
         end if;
         
         done <= done_buffer;
            
      end if;
      
      
      
   end process;
   

end architecture;





