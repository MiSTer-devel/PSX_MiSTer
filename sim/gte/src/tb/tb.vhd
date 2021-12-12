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
            
   signal reset               : std_logic := '1';
   
   signal clk1xToggle         : std_logic := '0';
   signal clk1xToggle2X       : std_logic := '0';
   signal clk2xIndex          : std_logic := '0';
   
   -- gte
   signal gte_busy            : std_logic;
   signal gte_readAddr        : unsigned(5 downto 0) := (others => '0');
   signal gte_readData        : unsigned(31 downto 0);
   signal gte_readEna         : std_logic;
   signal gte_writeAddr       : unsigned(5 downto 0);
   signal gte_writeData       : unsigned(31 downto 0);
   signal gte_writeEna        : std_logic; 
   signal gte_cmdData         : unsigned(31 downto 0);
   signal gte_cmdEna          : std_logic; 
   
   -- testbench
   signal cmdCount            : integer := 0;
   
begin

   clk1x  <= not clk1x  after 15 ns;
   clk2x  <= not clk2x  after 7500 ps;
   
   reset  <= '0' after 3000 ns;
   
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
   
   igte : entity psx.gte
   port map
   (
      clk1x                => clk1x,     
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => '1',        
      reset                => reset,     
      
      gte_busy             => gte_busy,     
      gte_readAddr         => gte_readAddr, 
      gte_readData         => gte_readData, 
      gte_readEna          => gte_readEna, 
      gte_writeAddr_in     => gte_writeAddr,
      gte_writeData_in     => gte_writeData,
      gte_writeEna_in      => gte_writeEna, 
      gte_cmdData          => gte_cmdData,  
      gte_cmdEna           => gte_cmdEna,

      loading_savestate    => '0',
      SS_reset             => '0',
      SS_DataWrite         => x"00000000",
      SS_Adr               => "000000",
      SS_wren              => '0',
      SS_rden              => '0',
      SS_DataRead          => open
   );
   
   process
      file infile          : text;
      variable f_status    : FILE_OPEN_STATUS;
      variable inLine      : LINE;
      variable para_type   : std_logic_vector(7 downto 0);
      variable para_addr   : std_logic_vector(7 downto 0);
      variable para_data   : std_logic_vector(31 downto 0);
      variable space       : character;
   begin
      
      gte_readEna  <= '0';
      gte_writeEna <= '0';
      gte_cmdEna   <= '0';
      
      wait until reset = '0';
         
      file_open(f_status, infile, "R:\gte_test_fpsxa.txt", read_mode);
      
      while (not endfile(infile)) loop
         
         readline(infile,inLine);
         
         HREAD(inLine, para_type);
         Read(inLine, space);
         HREAD(inLine, para_addr);
         Read(inLine, space);
         HREAD(inLine, para_data);
         
         if (para_type = x"01") then
            gte_cmdData <= unsigned(para_data);
            gte_cmdEna  <= '1';
         elsif (para_type = x"04") then
            gte_writeAddr <= unsigned(para_addr(5 downto 0));
            gte_writeData <= unsigned(para_data);
            gte_writeEna  <= '1';
         elsif (para_type = x"05") then
            gte_readAddr <= unsigned(para_addr(5 downto 0));
            gte_readEna  <= '1';
            wait until rising_edge(clk1x);
            gte_readEna  <= '0';
            --if (gte_readData /= unsigned(para_data)) then
            --   report "wrong read value" severity warning;
            --   wait until rising_edge(clk1x);
            --   wait until rising_edge(clk1x);
            --   report "stopping test" severity failure;
            --end if;
         end if;
         
         cmdCount <= cmdCount + 1;
         wait until rising_edge(clk1x);
         
         gte_writeEna <= '0';
         gte_cmdEna   <= '0';
         
         wait until rising_edge(clk1x);
         
         while (gte_busy = '1') loop
            wait until rising_edge(clk1x);
         end loop;
         
      end loop;
      
      file_close(infile);
      
      wait for 1 us;
      
      if (cmdCount >= 0) then
         report "DONE" severity failure;
      end if;
      
      
   end process;
   
   
end architecture;


