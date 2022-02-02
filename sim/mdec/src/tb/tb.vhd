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
   signal clk2x               : std_logic := '1';
   
   signal clk1xToggle         : std_logic := '0';
   signal clk1xToggle2X       : std_logic := '0';
   signal clk2xIndex          : std_logic := '0';
   
   -- mdec
   signal bus_addr            : unsigned(3 downto 0) := (others => '0'); 
   signal bus_dataWrite       : std_logic_vector(31 downto 0) := (others => '0');
   signal bus_read            : std_logic := '0';
   signal bus_write           : std_logic := '0';
   signal bus_dataRead        : std_logic_vector(31 downto 0); 
   
   signal dma_write           : std_logic;
   signal dma_writedata       : std_logic_vector(31 downto 0);
   signal dma_read            : std_logic;
   signal dma_readdata        : std_logic_vector(31 downto 0);
   
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
   clk2x  <= not clk2x  after 7500 ps;
   
   reset_in  <= '0' after 3000 ns;
   
   -- clock index
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         clk1xToggle <= not clk1xToggle;
      end if;
   end process;
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         clk1xToggle2x <= clk1xToggle;
         clk2xIndex    <= '0';
         if (clk1xToggle2x = clk1xToggle) then
            clk2xIndex <= '1';
         end if;
      end if;
   end process;
   
   imdec : entity psx.mdec
   port map
   (
      clk1x                => clk1x,
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => '1',        
      reset                => reset_out,     
      
      bus_addr             => bus_addr,     
      bus_dataWrite        => bus_dataWrite,
      bus_read             => bus_read,     
      bus_write            => bus_write,    
      bus_dataRead         => bus_dataRead,
      
      dma_write            => dma_write,    
      dma_writedata        => dma_writedata,
      dma_read             => dma_read,     
      dma_readdata         => dma_readdata,
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(6 downto 0),
      SS_wren              => SS_wren(6),
      SS_rden              => '0',
      SS_DataRead          => open,
      SS_Idle              => open
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
   
   process
      file infile          : text;
      variable f_status    : FILE_OPEN_STATUS;
      variable inLine      : LINE;
      variable para_type   : std_logic_vector(7 downto 0);
      variable para_addr   : std_logic_vector(7 downto 0);
      variable para_time   : std_logic_vector(31 downto 0);
      variable para_data   : std_logic_vector(31 downto 0);
      variable space       : character;
   begin
      
      wait until reset_out = '1';
      wait until reset_out = '0';
         
      file_open(f_status, infile, "R:\mdec_test_fpsxa.txt", read_mode);
      
      while (not endfile(infile)) loop
         
         readline(infile,inLine);
         
         HREAD(inLine, para_type);
         Read(inLine, space);
         HREAD(inLine, para_time);
         Read(inLine, space);
         HREAD(inLine, para_addr);
         Read(inLine, space);
         HREAD(inLine, para_data);
         
         while (clkCount < unsigned(para_time)) loop
            clkCount <= clkCount + 1;
            wait until rising_edge(clk1x);
         end loop;
         
         if (para_type = x"07") then
            bus_addr    <= unsigned(para_addr(3 downto 0));
            bus_read    <= '1';
         end if;
         
         if (para_type = x"08") then
            bus_dataWrite <= para_data;
            bus_addr      <= unsigned(para_addr(3 downto 0));
            bus_write     <= '1';
         end if;
         
         if (para_type = x"0A") then
            dma_write     <= '1';
            dma_writedata <= para_data;
         end if;
         
         if (para_type = x"0C") then
            dma_read    <= '1';
         end if;
         
         clkCount <= clkCount + 1;
         cmdCount <= cmdCount + 1;
         wait until rising_edge(clk1x);
         bus_read      <= '0';
         bus_write     <= '0';
         dma_read      <= '0';
         dma_write     <= '0';
      end loop;
      
      file_close(infile);
      
      wait for 1 us;
      
      if (cmdCount >= 0) then
         report "DONE" severity failure;
      end if;
      
      
   end process;
   
   
end architecture;


