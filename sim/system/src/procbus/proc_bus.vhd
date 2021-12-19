-----------------------------------------------------------------
--------------- Proc Bus Package --------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pProc_bus is

   constant proc_buswidth : integer := 32;
   constant proc_busadr   : integer := 26;
   
   constant proc_buscount : integer := 15;
   
   constant proc_mpu_bits : integer := 16;
   
   type proc_bus_type is record
      Din  : std_logic_vector(proc_buswidth-1 downto 0);
      Dout : std_logic_vector(proc_buswidth-1 downto 0);
      Adr  : std_logic_vector(proc_busadr-1 downto 0);
      rnw  : std_logic;
      ena  : std_logic;
      done : std_logic;
   end record;
   
   type tBusArray_Din  is array(0 to proc_buscount - 1) of std_logic_vector(proc_buswidth-1 downto 0);
   type tBusArray_Dout is array(0 to proc_buscount - 1) of std_logic_vector(proc_buswidth-1 downto 0);
   type tBusArray_Adr  is array(0 to proc_buscount - 1) of std_logic_vector(proc_busadr-1 downto 0);
   type tBusArray_rnw  is array(0 to proc_buscount - 1) of std_logic;
   type tBusArray_ena  is array(0 to proc_buscount - 1) of std_logic;
   type tBusArray_done is array(0 to proc_buscount - 1) of std_logic;
   
   type tMPUArray      is array(0 to proc_buscount - 1) of std_logic_vector(proc_mpu_bits-1 downto 0);

end package;


-----------------------------------------------------------------
--------------- Reg Map Package --------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library work;
use work.pProc_bus.all;

package pRegmap is

   type regaccess_type is
   (
      readwrite,
      readonly,
      pulse,
      writeonly
   );

   type regmap_type is record
      Adr         : integer range 0 to (2**proc_busadr)-1;
      upper       : integer range 0 to proc_buswidth-1;
      lower       : integer range 0 to proc_buswidth-1;
      size        : integer range 0 to (2**proc_busadr)-1;
      default     : integer;
      acccesstype : regaccess_type;
   end record;
   
end package;


-----------------------------------------------------------------
--------------- Converter Bus -> Processor ----------------------
-----------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;  

library work;
use work.pProc_bus.all;

entity eProc_bus  is
   port 
   (
      proc_din  : out   std_logic_vector(proc_buswidth-1 downto 0);
      proc_dout : in    std_logic_vector(proc_buswidth-1 downto 0); 
      proc_adr  : in    std_logic_vector(proc_busadr-1 downto 0); 
      proc_rnw  : in    std_logic;
      proc_ena  : in    std_logic;
      proc_done : out   std_logic;
      
      proc_bus  : inout proc_bus_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z')
   );
end entity;

architecture arch of eProc_bus is

begin
   
   proc_din     <= proc_bus.Dout;
   proc_done    <= proc_bus.done;
   
   proc_bus.adr <= proc_adr;
   proc_bus.rnw <= proc_rnw;
   proc_bus.ena <= proc_ena;
   proc_bus.Din <= proc_dout;
      
   -- prevent simulation warnings
   proc_bus.Dout <= (others => 'Z');

end architecture;

-----------------------------------------------------------------
--------------- Reg Interface -----------------------------------
-----------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;  

library work;
use work.pProc_bus.all;
use work.pRegmap.all;

entity eProcReg  is
   generic
   (
      Reg       : regmap_type;
      index     : integer := 0
   );
   port 
   (
      clk       : in    std_logic;
      proc_bus  : inout proc_bus_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z');
      Din       : in    std_logic_vector(Reg.upper downto Reg.lower);
      Dout      : out   std_logic_vector(Reg.upper downto Reg.lower);
      written   : out   std_logic := '0'
   );
end entity;

architecture arch of eProcReg is

   signal Dout_buffer : std_logic_vector(Reg.upper downto Reg.lower) := std_logic_vector(to_unsigned(Reg.default,Reg.upper-Reg.lower+1));
    
   signal Adr : std_logic_vector(proc_bus.adr'left downto 0);
    
begin

   Adr <= std_logic_vector(to_unsigned(Reg.Adr + index, proc_bus.adr'length));

   greadwrite : if (Reg.acccesstype = readwrite or Reg.acccesstype = writeonly) generate
   begin
   
      process (clk)
      begin
         if rising_edge(clk) then
         
            if (proc_bus.Adr = Adr and proc_bus.rnw = '0' and proc_bus.ena = '1') then
               Dout_buffer <= proc_bus.Din(Reg.upper downto Reg.lower);  
               written <= '1';
            else
               written <= '0';
            end if;
            
         end if;
      end process;
   end generate;
   
   gpulse : if (Reg.acccesstype = pulse) generate
   begin
   
      process (clk)
      begin
         if rising_edge(clk) then
         
            Dout_buffer <= (others => '0');
            if (proc_bus.Adr = Adr and proc_bus.rnw = '0' and proc_bus.ena = '1') then
               Dout_buffer <= proc_bus.Din(Reg.upper downto Reg.lower); 
               written <= '1';
            else
               written <= '0';
            end if;
            
         end if;
      end process;
   end generate;
   
   Dout <= Dout_buffer;

   proc_bus.Dout <= (others => 'Z');
   
   goutput : if (Reg.acccesstype = readwrite or Reg.acccesstype = readonly) generate
   begin
      proc_bus.Dout(Reg.upper downto Reg.lower) <= Din when proc_bus.Adr = Adr else (others => 'Z');
   end generate;
   
   proc_bus.done <= '1' when proc_bus.Adr = Adr else 'Z';
   
   -- prevent simulation warnings
   proc_bus.Adr <= (others => 'Z');
   proc_bus.Din <= (others => 'Z');
   proc_bus.rnw <= 'Z';
   
   
end architecture;



-----------------------------------------------------------------
--------------- Address enable  ---------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;  

library work;
use work.pProc_bus.all;
use work.pRegmap.all;

entity eProcAddrEna  is
   generic
   (
      Reg       : regmap_type
   );
   port 
   (
      clk       : in    std_logic;
      proc_bus  : inout proc_bus_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z');
      ena       : out   std_logic;
      addr      : out   std_logic_vector(proc_busadr-1 downto 0)
   );
end entity;

architecture arch of eProcAddrEna is
   
   signal proc_adr_buf :std_logic_vector(proc_busadr-1 downto 0) := (others => '0');
   
   signal calc_addr : std_logic_vector(proc_busadr-1 downto 0);
   signal calc_ena  : std_logic;
   
begin

   

   calc_addr <= std_logic_vector(unsigned(proc_adr_buf) - to_unsigned(Reg.Adr, proc_busadr)); 
   calc_ena  <= '1' when to_integer(unsigned(proc_adr_buf)) >= Reg.Adr and to_integer(unsigned(proc_adr_buf)) < (Reg.Adr + Reg.size) else '0';

   process (clk)
   begin
      if rising_edge(clk) then
      
         proc_adr_buf <= proc_bus.Adr;

         if (to_integer(unsigned(calc_addr)) < Reg.size) then
            addr <= calc_addr;
         else
            addr <= (others => '0');
         end if;
         
         ena  <= calc_ena;
         
      end if;
   end process; 
     
   
   
end architecture;






