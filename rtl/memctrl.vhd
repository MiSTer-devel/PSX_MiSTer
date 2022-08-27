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
      bus_dataRead         : out std_logic_vector(31 downto 0);
      
      bus2_addr            : in  unsigned(3 downto 0); 
      bus2_dataWrite       : in  std_logic_vector(31 downto 0);
      bus2_read            : in  std_logic;
      bus2_write           : in  std_logic;
      bus2_dataRead        : out std_logic_vector(31 downto 0);
      
      spu_read_timing      : out unsigned(3 downto 0);
      spu_write_timing     : out unsigned(3 downto 0);
      
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(4 downto 0);
      SS_wren              : in  std_logic;
      SS_rden              : in  std_logic;
      SS_DataRead          : out std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of memctrl is

   signal MC_EXP1_BASE    : std_logic_vector(23 downto 0);
   signal MC_EXP2_BASE    : std_logic_vector(23 downto 0);
   signal MC_EXP1_DELAY   : std_logic_vector(31 downto 0);
   signal MC_EXP3_DELAY   : std_logic_vector(31 downto 0);
   signal MC_BIOS_DELAY   : std_logic_vector(31 downto 0);
   signal MC_SPU_DELAY    : std_logic_vector(31 downto 0);
   signal MC_CDROM_DELAY  : std_logic_vector(31 downto 0);
   signal MC_EXP2_DELAY   : std_logic_vector(31 downto 0);
   signal MC_COMMON_DELAY : std_logic_vector(31 downto 0);
   
   signal MC_RAMSIZE      : std_logic_vector(31 downto 0);

   -- savestates
   type t_ssarray is array(0 to 31) of std_logic_vector(31 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  
   signal ss_out : t_ssarray := (others => (others => '0')); 

begin 

   
   spu_read_timing  <= unsigned(MC_SPU_DELAY(7 downto 4));
   spu_write_timing <= unsigned(MC_SPU_DELAY(3 downto 0));


   ss_out(1)(23 downto 0) <= MC_EXP1_BASE;   
   ss_out(2)(23 downto 0) <= MC_EXP2_BASE;   
   ss_out(3) <= MC_EXP1_DELAY;  
   ss_out(4) <= MC_EXP3_DELAY;  
   ss_out(5) <= MC_BIOS_DELAY;  
   ss_out(6) <= MC_SPU_DELAY;   
   ss_out(7) <= MC_CDROM_DELAY; 
   ss_out(8) <= MC_EXP2_DELAY;  
   ss_out(9) <= MC_COMMON_DELAY;
                            
   ss_out(0) <= MC_RAMSIZE;     
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1') then
               
            MC_EXP1_BASE       <= ss_in(1)(23 downto 0); -- x"000000";
            MC_EXP2_BASE       <= ss_in(2)(23 downto 0); -- x"802000";
            MC_EXP1_DELAY      <= ss_in(3); -- x"0013243F";
            MC_EXP3_DELAY      <= ss_in(4); -- x"00003022";
            MC_BIOS_DELAY      <= ss_in(5); -- x"0013243F";
            MC_SPU_DELAY       <= ss_in(6); -- x"200931E1";
            MC_CDROM_DELAY     <= ss_in(7); -- x"00020843";
            MC_EXP2_DELAY      <= ss_in(8); -- x"00070777";
            MC_COMMON_DELAY    <= ss_in(9); -- x"00031125";
                                    
            MC_RAMSIZE         <= ss_in(0); -- x"00000B88";

         elsif (ce = '1') then
         
            bus_dataRead  <= (others => '0');
            bus2_dataRead <= (others => '0');

            -- bus read
            if (bus_read = '1') then
               case (to_integer(bus_addr(5 downto 2) & "00")) is
                  when 16#00# => bus_dataRead <= x"1F" & MC_EXP1_BASE;   
                  when 16#04# => bus_dataRead <= x"1F" & MC_EXP2_BASE;   
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
                  when 16#00# => MC_EXP1_BASE   <= bus_dataWrite(23 downto 0);   
                  when 16#04# => MC_EXP2_BASE   <= bus_dataWrite(23 downto 0);   
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
            
            -- bus2 read
            if (bus2_read = '1') then
               case (to_integer(bus2_addr(3 downto 0))) is
                  when 16#00# => bus2_dataRead <= MC_RAMSIZE;   
                  when others => bus2_dataRead <= (others => '1');
               end case;
            end if;

            -- bus2 write
            if (bus2_write = '1') then
               case (to_integer(bus2_addr(3 downto 0))) is
                  when 16#00# => MC_RAMSIZE <= bus2_dataWrite;  
                  when others => null;
               end case;
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
            
            ss_in(0) <= x"00000B88"; -- MC_RAMSIZE
            ss_in(1) <= x"00000000"; -- MC_EXP1_BASE   
            ss_in(2) <= x"00802000"; -- MC_EXP2_BASE   
            ss_in(3) <= x"0013243F"; -- MC_EXP1_DELAY  
            ss_in(4) <= x"00003022"; -- MC_EXP3_DELAY  
            ss_in(5) <= x"0013243F"; -- MC_BIOS_DELAY  
            ss_in(6) <= x"200931E1"; -- MC_SPU_DELAY   
            ss_in(7) <= x"00020843"; -- MC_CDROM_DELAY 
            ss_in(8) <= x"00070777"; -- MC_EXP2_DELAY  
            ss_in(9) <= x"00031125"; -- MC_COMMON_DELAY
            
         elsif (SS_wren = '1') then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         end if;
         
         if (SS_rden = '1') then
            SS_DataRead <= ss_out(to_integer(SS_Adr));
         end if;
      
      end if;
   end process;

end architecture;





