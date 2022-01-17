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
   
   signal captureram_we        : std_logic;
   signal captureram_readdata  : std_logic_vector(15 downto 0);
      
   signal ram_processed        : std_logic := '0';
      
begin 

   captureram_we <= '1' when (ram_request = '1' and ram_rnw = '0' and ram_Adr(18 downto 12) = "0000000") else '0';

   iram_capture: entity mem.dpram
   generic map (addr_width => 11, data_width => 16)
   port map
   (
      clock_a     => clk1x,
      address_a   => ram_Adr(11 downto 1),
      data_a      => ram_dataWrite,
      wren_a      => captureram_we,
      q_a         => captureram_readdata,
      
      clock_b     => clk1x,
      address_b   => (10 downto 0 => '0'),
      data_b      => x"0000",
      wren_b      => '0',
      q_b         => open
   );
   


   sdram_dataWrite <= x"0000" & ram_dataWrite;
   sdram_Adr       <= ram_Adr;
   sdram_be        <= "0011";
   sdram_rnw       <= ram_rnw;
   sdram_ena       <= '0'         when (ram_Adr(18 downto 12) = "0000000") else
                      ram_request when (useSDRAM = '1') else 
                      '0'; 

   ram_dataRead    <= captureram_readdata         when (ram_Adr(18 downto 12) = "0000000") else
                      (others => '0')             when (SPUon = '0')    else
                      sdram_dataRead(15 downto 0) when (useSDRAM = '1') else 
                      (others => '0'); 
   
   ram_done        <= '1'            when (ram_processed = '1') else
                      '1'            when (SPUon = '0')         else
                      sdram_done     when (useSDRAM = '1')      else 
                      '0'; 
   
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then
            
         ram_processed <= '0';
            
         if (reset = '1') then
            
         else
         
            if (ram_request = '1' and ram_Adr(18 downto 12) = "0000000") then
               ram_processed <= '1';
            end if;
            
         end if;
         
      end if;
   end process;

end architecture;





