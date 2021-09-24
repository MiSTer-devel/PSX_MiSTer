library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity memctrl is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;

      bus_addr             : in  unsigned(5 downto 0); 
      bus_dataWrite        : in  std_logic_vector(31 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of memctrl is

   signal MC_EXP1_BASE    : std_logic_vector(31 downto 0);
   signal MC_EXP2_BASE    : std_logic_vector(31 downto 0);
   signal MC_EXP1_DELAY   : std_logic_vector(31 downto 0);
   signal MC_EXP3_DELAY   : std_logic_vector(31 downto 0);
   signal MC_BIOS_DELAY   : std_logic_vector(31 downto 0);
   signal MC_SPU_DELAY    : std_logic_vector(31 downto 0);
   signal MC_CDROM_DELAY  : std_logic_vector(31 downto 0);
   signal MC_EXP2_DELAY   : std_logic_vector(31 downto 0);
   signal MC_COMMON_DELAY : std_logic_vector(31 downto 0);
   
  
begin 

   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1') then
               
            MC_EXP1_BASE       <= x"1F000000";
            MC_EXP2_BASE       <= x"1F802000";
            MC_EXP1_DELAY      <= x"0013243F";
            MC_EXP3_DELAY      <= x"00003022";
            MC_BIOS_DELAY      <= x"0013243F";
            MC_SPU_DELAY       <= x"200931E1";
            MC_CDROM_DELAY     <= x"00020843";
            MC_EXP2_DELAY      <= x"00070777";
            MC_COMMON_DELAY    <= x"00031125";

         elsif (ce = '1') then
         
            bus_dataRead <= (others => '0');

            -- bus read
            if (bus_read = '1') then
               case (to_integer(bus_addr(5 downto 0))) is
                  when 16#00# => bus_dataRead <= MC_EXP1_BASE;   
                  when 16#04# => bus_dataRead <= MC_EXP2_BASE;   
                  when 16#08# => bus_dataRead <= MC_EXP1_DELAY;  
                  when 16#0C# => bus_dataRead <= MC_EXP3_DELAY;  
                  when 16#10# => bus_dataRead <= MC_BIOS_DELAY;  
                  when 16#14# => bus_dataRead <= MC_SPU_DELAY;   
                  when 16#18# => bus_dataRead <= MC_CDROM_DELAY; 
                  when 16#1C# => bus_dataRead <= MC_EXP2_DELAY;  
                  when 16#20# => bus_dataRead <= MC_COMMON_DELAY; 
                  when others => bus_dataRead <= (others => '0');
               end case;
            end if;

            -- bus write
            if (bus_write = '1') then
               case (to_integer(bus_addr(5 downto 0))) is
                  when 16#00# => MC_EXP1_BASE   <= bus_dataWrite(31) & MC_EXP1_BASE  (30) & bus_dataWrite(29) & MC_EXP1_BASE  (28) & bus_dataWrite(27 downto 24) & MC_EXP1_BASE  (23 downto 21) & bus_dataWrite(20 downto 0);   
                  when 16#04# => MC_EXP2_BASE   <= bus_dataWrite(31) & MC_EXP2_BASE  (30) & bus_dataWrite(29) & MC_EXP2_BASE  (28) & bus_dataWrite(27 downto 24) & MC_EXP2_BASE  (23 downto 21) & bus_dataWrite(20 downto 0);   
                  when 16#08# => MC_EXP1_DELAY  <= bus_dataWrite(31) & MC_EXP1_DELAY (30) & bus_dataWrite(29) & MC_EXP1_DELAY (28) & bus_dataWrite(27 downto 24) & MC_EXP1_DELAY (23 downto 21) & bus_dataWrite(20 downto 0);  
                  when 16#0C# => MC_EXP3_DELAY  <= bus_dataWrite(31) & MC_EXP3_DELAY (30) & bus_dataWrite(29) & MC_EXP3_DELAY (28) & bus_dataWrite(27 downto 24) & MC_EXP3_DELAY (23 downto 21) & bus_dataWrite(20 downto 0);  
                  when 16#10# => MC_BIOS_DELAY  <= bus_dataWrite(31) & MC_BIOS_DELAY (30) & bus_dataWrite(29) & MC_BIOS_DELAY (28) & bus_dataWrite(27 downto 24) & MC_BIOS_DELAY (23 downto 21) & bus_dataWrite(20 downto 0);  
                  when 16#14# => MC_SPU_DELAY   <= bus_dataWrite(31) & MC_SPU_DELAY  (30) & bus_dataWrite(29) & MC_SPU_DELAY  (28) & bus_dataWrite(27 downto 24) & MC_SPU_DELAY  (23 downto 21) & bus_dataWrite(20 downto 0);   
                  when 16#18# => MC_CDROM_DELAY <= bus_dataWrite(31) & MC_CDROM_DELAY(30) & bus_dataWrite(29) & MC_CDROM_DELAY(28) & bus_dataWrite(27 downto 24) & MC_CDROM_DELAY(23 downto 21) & bus_dataWrite(20 downto 0); 
                  when 16#1C# => MC_EXP2_DELAY  <= bus_dataWrite(31) & MC_EXP2_DELAY (30) & bus_dataWrite(29) & MC_EXP2_DELAY (28) & bus_dataWrite(27 downto 24) & MC_EXP2_DELAY (23 downto 21) & bus_dataWrite(20 downto 0);  
                  when 16#20# => MC_COMMON_DELAY(17 downto 0) <= bus_dataWrite(17 downto 0); 
                  when others => null;
               end case;
            end if;
            
         end if;
      end if;
   end process;

end architecture;





