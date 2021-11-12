library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     
use IEEE.std_logic_textio.all; 
library STD;    
use STD.textio.all;

library psx;

entity etb  is
end entity;

architecture arch of etb is

   signal clk1x               : std_logic := '1';
            
   signal reset               : std_logic := '1';
   signal SS_reset            : std_logic := '1';
   
   -- cd
   signal bus_addr            : unsigned(3 downto 0) := (others => '0'); 
   signal bus_dataWrite       : std_logic_vector(7 downto 0) := (others => '0');
   signal bus_read            : std_logic := '0';
   signal bus_write           : std_logic := '0';
   signal bus_dataRead        : std_logic_vector(7 downto 0); 
   
   signal dma_read            : std_logic := '0';
   signal dma_readdata        : std_logic_vector(7 downto 0);
   
   signal fullyIdle           : std_logic;
   
   signal cd_req              : std_logic;
   signal cd_addr             : std_logic_vector(26 downto 0) := (others => '0');
   signal cd_data             : std_logic_vector(31 downto 0);
   signal cd_done             : std_logic := '0';
   
   signal ram_do              : std_logic_vector(127 downto 0);
   
   -- testbench
   signal cmdCount            : integer := 0;
   signal clkCount            : integer := 0;
   
begin

   clk1x  <= not clk1x  after 15 ns;
   
   reset     <= '0' after 3000 ns;
   SS_reset  <= '0' after 1500 ns;
   
   icd_top : entity psx.cd_top
   port map
   (
      clk1x                => clk1x,
      ce                   => '1',        
      reset                => reset,  

      hasCD                => '1',
      
      fullyIdle            => fullyIdle,
      
      bus_addr             => bus_addr,     
      bus_dataWrite        => bus_dataWrite,
      bus_read             => bus_read,     
      bus_write            => bus_write,    
      bus_dataRead         => bus_dataRead,
      
      dma_read             => dma_read,     
      dma_readdata         => dma_readdata,
      
      cd_req               => cd_req,
      cd_addr              => cd_addr,
      cd_data              => cd_data,
      cd_done              => cd_done,
      
      SS_reset             => SS_reset,
      SS_DataWrite         => (31 downto 0 => '0'),
      SS_Adr               => (14 downto 0 => '0'),
      SS_wren              => '0'
   );
   
   isdram_model : entity work.sdram_model 
   generic map
   (
      INITFILE => "test.iso"
   )
   port map
   (
      clk          => clk1x,
      addr         => cd_addr,
      req          => cd_req,
      ram_128      => '0',
      rnw          => '1',
      be           => "0000",
      di           => x"00000000",
      do           => ram_do,
      done         => cd_done,
      reqprocessed => open,
      ram_idle     => open
   );
   
   cd_data <= ram_do(31 downto 0);
   
   process
      file infile          : text;
      variable f_status    : FILE_OPEN_STATUS;
      variable inLine      : LINE;
      variable para_type   : std_logic_vector(7 downto 0);
      variable para_addr   : std_logic_vector(7 downto 0);
      variable para_time   : std_logic_vector(31 downto 0);
      variable para_data   : std_logic_vector(31 downto 0);
      variable space       : character;
      variable idleTime    : integer;
   begin
      
      wait until reset = '0';
         
      file_open(f_status, infile, "R:\cd_test_fpsxa.txt", read_mode);
      
      while (not endfile(infile)) loop
         
         readline(infile,inLine);
         
         HREAD(inLine, para_type);
         Read(inLine, space);
         HREAD(inLine, para_time);
         Read(inLine, space);
         HREAD(inLine, para_addr);
         Read(inLine, space);
         HREAD(inLine, para_data);
         
         idleTime := 0;
         
         while (clkCount < unsigned(para_time)) loop
            clkCount <= clkCount + 1;
            wait until rising_edge(clk1x);
            if (fullyIdle = '1') then
               idleTime := idleTime + 1;
               if (idleTime > 10000) then
                  idleTime := 0;
                  clkCount <= to_integer(unsigned(para_time)) - 1000;
                  wait until rising_edge(clk1x);
               end if;
            end if;
         end loop;
         
         if (para_type = x"08") then
            bus_addr    <= unsigned(para_addr(3 downto 0));
            bus_read    <= '1';
         end if;
         
         if (para_type = x"09") then
            bus_dataWrite <= para_data(7 downto 0);
            bus_addr      <= unsigned(para_addr(3 downto 0));
            bus_write     <= '1';
         end if;
         
         if (para_type = x"0A") then
            dma_read    <= '1';
         end if;
         
         clkCount <= clkCount + 1;
         cmdCount <= cmdCount + 1;
         wait until rising_edge(clk1x);
         bus_read      <= '0';
         bus_write     <= '0';
         dma_read      <= '0';
      end loop;
      
      file_close(infile);
      
      wait for 1 us;
      
      if (cmdCount >= 0) then
         report "DONE" severity failure;
      end if;
      
      
   end process;
   
   
end architecture;


