library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all; 

entity spu_ram is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      SPUon                : in  std_logic;
      useSDRAM             : in  std_logic;
      
      -- internal IF
      ram_dataWrite        : in  std_logic_vector(15 downto 0);
      ram_Adr              : in  std_logic_vector(18 downto 0);
      ram_request          : in  std_logic;
      ram_rnw              : in  std_logic;
      ram_dataRead         : out std_logic_vector(15 downto 0);
      ram_done             : out std_logic;
      
      -- SDRAM interface        
      sdram_dataWrite      : out std_logic_vector(31 downto 0);
      sdram_Adr            : out std_logic_vector(18 downto 0);
      sdram_be             : out std_logic_vector(3 downto 0);
      sdram_rnw            : out std_logic;
      sdram_ena            : out std_logic;
      sdram_dataRead       : in  std_logic_vector(31 downto 0);
      sdram_done           : in  std_logic
   );
end entity;

architecture arch of spu_ram is
   
      
begin 

   sdram_dataWrite <= x"0000" & ram_dataWrite;
   sdram_Adr       <= ram_Adr;
   sdram_be        <= "0011";
   sdram_rnw       <= ram_rnw;
   sdram_ena       <= ram_request when (useSDRAM = '1') else '0'; 

   ram_dataRead    <= (others => '0')             when (SPUon = '0')    else
                      sdram_dataRead(15 downto 0) when (useSDRAM = '1') else 
                      (others => '0'); 
   
   ram_done        <= '1'            when (SPUon = '0')    else
                      sdram_done     when (useSDRAM = '1') else 
                      '0'; 
   
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then
            
         if (reset = '1') then
            
         else
         
            
         end if;
         
      end if;
   end process;

end architecture;





