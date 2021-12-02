library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity irq is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      irq_VBLANK           : in  std_logic;
      irq_GPU              : in  std_logic;
      irq_CDROM            : in  std_logic;
      irq_DMA              : in  std_logic;
      irq_TIMER0           : in  std_logic;
      irq_TIMER1           : in  std_logic;
      irq_TIMER2           : in  std_logic;
      irq_PAD              : in  std_logic;
      irq_SIO              : in  std_logic;
      irq_SPU              : in  std_logic;
      irq_LIGHTPEN         : in  std_logic;
      
      bus_addr             : in  unsigned(3 downto 0); 
      bus_dataWrite        : in  std_logic_vector(31 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(31 downto 0);
      
      irqRequest           : out std_logic := '0';
      
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(0 downto 0);
      SS_wren              : in  std_logic;
      SS_DataRead          : out std_logic_vector(31 downto 0);
      SS_idle              : out std_logic;
      
      export_irq           : out unsigned(15 downto 0)
   );
end entity;

architecture arch of irq is

   signal I_STATUS : unsigned(10 downto 0) := (others => '0');
   signal I_MASK   : unsigned(10 downto 0) := (others => '0');
   
   signal irqIn    : unsigned(10 downto 0);
   signal irqIn_1  : unsigned(10 downto 0);
   
   -- savestates
   type t_ssarray is array(0 to 1) of std_logic_vector(31 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  
   
begin 

   export_irq  <= "00000" & I_STATUS;

   irqRequest <= '1' when ((I_STATUS and I_MASK) > 0) else '0';
   
   irqIn(0)  <= irq_VBLANK;  
   irqIn(1)  <= irq_GPU;     
   irqIn(2)  <= irq_CDROM;   
   irqIn(3)  <= irq_DMA;     
   irqIn(4)  <= irq_TIMER0;  
   irqIn(5)  <= irq_TIMER1;  
   irqIn(6)  <= irq_TIMER2;  
   irqIn(7)  <= irq_PAD;     
   irqIn(8)  <= irq_SIO;     
   irqIn(9)  <= irq_SPU;     
   irqIn(10) <= irq_LIGHTPEN;

   process (clk1x)
      variable I_STATUSNew : unsigned(10 downto 0);
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1') then
               
            I_STATUS    <= unsigned(ss_in(0)(10 downto 0));
            I_MASK      <= unsigned(ss_in(1)(10 downto 0));
            irqIn_1     <= (others => '0');

         elsif (ce = '1') then
         
            I_STATUSNew := I_STATUS;
         
            bus_dataRead <= (others => '0');

            -- bus read
            if (bus_read = '1') then
               if (bus_addr(3 downto 2) = "00") then
                  bus_dataRead <= x"00000" & '0' & std_logic_vector(I_STATUS);
               elsif (bus_addr(3 downto 2) = "01") then
                  bus_dataRead <= x"00000" & '0' & std_logic_vector(I_MASK);
               else
                  bus_dataRead <= x"FFFFFFFF";
               end if;
            end if;

            -- bus write
            if (bus_write = '1') then
            
               if (bus_addr = 0) then
                  I_STATUSNew := I_STATUSNew and unsigned(bus_dataWrite(10 downto 0));
               elsif (bus_addr = 4) then
                  I_MASK   <= unsigned(bus_dataWrite(10 downto 0));
               end if;
            
            end if;
            
            irqIn_1 <= irqIn;
            I_STATUSNew := I_STATUSNew or (irqIn and (not irqIn_1));
            
            I_STATUS <= I_STATUSNew;
            
            SS_idle <= '0';
            if ((I_STATUSNew and I_MASK) = 0) then
               SS_idle <= '1';
            end if;
            
         end if;
      end if;
   end process;
   
--##############################################################
--############################### savestates
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (SS_reset = '1') then
         
            for i in 0 to 1 loop
               ss_in(i) <= (others => '0');
            end loop;
            
         elsif (SS_wren = '1') then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         end if;
      
      end if;
   end process;

end architecture;





