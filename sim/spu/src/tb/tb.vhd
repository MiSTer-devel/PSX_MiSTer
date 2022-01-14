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
   signal clk3x               : std_logic := '1';
            
   signal reset               : std_logic := '1';
   
   -- spu
   signal bus_addr            : unsigned(9 downto 0) := (others => '0'); 
   signal bus_dataWrite       : std_logic_vector(15 downto 0) := (others => '0');
   signal bus_read            : std_logic := '0';
   signal bus_write           : std_logic := '0';
   signal bus_dataRead        : std_logic_vector(15 downto 0); 
   
   signal dma_read            : std_logic := '0';
   signal dma_readdata        : std_logic_vector(15 downto 0);   
   signal dma_write           : std_logic := '0';
   signal dma_writedata       : std_logic_vector(15 downto 0);
   
   --sdram access 
   signal sdram_dataWrite     : std_logic_vector(31 downto 0);
   signal sdram_dataRead      : std_logic_vector(31 downto 0);
   signal sdram_Adr           : std_logic_vector(18 downto 0);
   signal sdram_be            : std_logic_vector(3 downto 0);
   signal sdram_rnw           : std_logic;
   signal sdram_ena           : std_logic;
   signal sdram_done          : std_logic;     
   
   -- savestates
   signal reset_in            : std_logic := '1';
   signal reset_out           : std_logic := '1';
   signal SS_reset            : std_logic := '0';
   signal SS_DataWrite        : std_logic_vector(31 downto 0) := (others => '0');
   signal SS_Adr              : unsigned(18 downto 0) := (others => '0');
   signal SS_wren             : std_logic_vector(16 downto 0) := (others => '0');
   
   -- testbench
   signal cmdCount            : integer := 0;
   signal clkCount            : integer := 0;
   
begin

   clk1x  <= not clk1x  after 15 ns;
   clk3x  <= not clk3x  after 5 ns;
   
   reset_in  <= '0' after 3000 ns;
   
   ispu : entity psx.spu
   port map
   (
      clk1x                => clk1x,
      ce                   => '1',        
      reset                => reset_out,
      
      bus_addr             => bus_addr,     
      bus_dataWrite        => bus_dataWrite,
      bus_read             => bus_read,     
      bus_write            => bus_write,    
      bus_dataRead         => bus_dataRead,
      
      dma_read             => dma_read,     
      dma_readdata         => dma_readdata,
      dma_write            => dma_write,     
      dma_writedata        => dma_writedata,
      
      -- SDRAM interface        
      sdram_dataWrite      => sdram_dataWrite,
      sdram_dataRead       => sdram_dataRead, 
      sdram_Adr            => sdram_Adr,      
      sdram_be             => sdram_be,      
      sdram_rnw            => sdram_rnw,      
      sdram_ena            => sdram_ena,           
      sdram_done           => sdram_done,
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(8 downto 0),
      SS_wren              => SS_wren(9),
      SS_rden              => '0'
   );
   
   itb_savestates : entity work.tb_savestates
   generic map
   (
      LOADSTATE         => '0',
      FILENAME          => ""
   )
   port map
   (
      clk               => clk1x,         
      reset_in          => reset_in,    
      reset_out         => reset_out,   
      SS_reset          => SS_reset,    
      SS_DataWrite      => SS_DataWrite,
      SS_Adr            => SS_Adr,      
      SS_wren           => SS_wren     
   );
   
   isdram_model : entity work.sdram_model3x 
   generic map
   (
      DOREFRESH     => '1',
      SCRIPTLOADING => '0'
   )
   port map
   (
      clk          => clk1x,
      clk3x        => clk3x,
      refresh      => '0',
      addr(26 downto 19) => "00000000",
      addr(18 downto  0) =>  sdram_Adr,
      req          => sdram_ena,
      ram_128      => '0',
      rnw          => sdram_rnw,
      be           => sdram_be,
      di           => sdram_dataWrite,
      do           => open,
      do32         => sdram_dataRead,
      done         => sdram_done,
      reqprocessed => open,
      ram_idle     => open
   );
   
   process
      file infile          : text;
      variable f_status    : FILE_OPEN_STATUS;
      variable inLine      : LINE;
      variable para_type   : std_logic_vector(7 downto 0);
      variable para_addr   : std_logic_vector(15 downto 0);
      variable para_time   : std_logic_vector(31 downto 0);
      variable para_data   : std_logic_vector(15 downto 0);
      variable space       : character;
      variable idleTime    : integer;
   begin
      
      file_open(f_status, infile, "R:\sound_test_fpsxa.txt", read_mode);
      
      clkCount <= 1;
      wait until reset_out = '1';
      wait until reset_out = '0';
      
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
         end loop;
         
         if (para_type = x"01") then
            bus_dataWrite <= para_data;
            bus_addr      <= unsigned(para_addr(9 downto 0));
            bus_write     <= '1';
         end if;
         
         if (para_type = x"02") then
            bus_addr    <= unsigned(para_addr(9 downto 0));
            bus_read    <= '1';
         end if;
         
         if (para_type = x"03") then
            dma_write     <= '1';
            dma_writedata <= para_data;
         end if;
         
         if (para_type = x"04") then
            dma_read    <= '1';
         end if;
         
         clkCount <= clkCount + 1;
         cmdCount <= cmdCount + 1;
         wait until rising_edge(clk1x);
         bus_read      <= '0';
         bus_write     <= '0';
         dma_write     <= '0';
         dma_read      <= '0';
      end loop;
      
      file_close(infile);
      
      wait for 1 us;
      
      if (cmdCount >= 0) then
         report "DONE" severity failure;
      end if;
      
      
   end process;
   
   
end architecture;


