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
   
   -- gpu
   signal bus_gpu_addr        : unsigned(3 downto 0) := (others => '0'); 
   signal bus_gpu_dataWrite   : std_logic_vector(31 downto 0) := (others => '0');
   signal bus_gpu_read        : std_logic := '0';
   signal bus_gpu_write       : std_logic := '0';
   signal bus_gpu_dataRead    : std_logic_vector(31 downto 0); 
   
   signal vram_ADDR           : std_logic_vector(19 downto 0);
   
   -- ddrram
   signal DDRAM_CLK           : std_logic;
   signal DDRAM_BUSY          : std_logic;
   signal DDRAM_BURSTCNT      : std_logic_vector(7 downto 0);
   signal DDRAM_ADDR          : std_logic_vector(28 downto 0);
   signal DDRAM_DOUT          : std_logic_vector(63 downto 0);
   signal DDRAM_DOUT_READY    : std_logic;
   signal DDRAM_RD            : std_logic;
   signal DDRAM_DIN           : std_logic_vector(63 downto 0);
   signal DDRAM_BE            : std_logic_vector(7 downto 0);
   signal DDRAM_WE            : std_logic;
   
   -- testbench
   signal clkCount            : integer := 0;
   
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
   
   igpu : entity psx.gpu
   port map
   (
      clk1x                => clk1x,
      clk2x                => clk2x,
      clk2xIndex           => clk2xIndex,
      ce                   => '1',   
      reset                => reset,
      
      ditherOff            => '0',
      REPRODUCIBLEGPUTIMING=> '0',
      isPal                => '1',
      videoout_on          => '1',
      
      dmaOn                => '0',
      
      bus_addr             => bus_gpu_addr,     
      bus_dataWrite        => bus_gpu_dataWrite,
      bus_read             => bus_gpu_read,     
      bus_write            => bus_gpu_write,    
      bus_dataRead         => bus_gpu_dataRead,
      
      DMA_GPU_writeEna     => '0',
      DMA_GPU_readEna      => '0',
      DMA_GPU_write        => x"00000000",
      
      vram_BUSY             => DDRAM_BUSY,      
      vram_DOUT             => DDRAM_DOUT,      
      vram_DOUT_READY       => DDRAM_DOUT_READY,
      vram_BURSTCNT         => DDRAM_BURSTCNT,  
      vram_ADDR             => vram_ADDR,      
      vram_DIN              => DDRAM_DIN,       
      vram_BE               => DDRAM_BE,        
      vram_WE               => DDRAM_WE,        
      vram_RD               => DDRAM_RD,
      
      loading_savestate     => '0',
      SS_reset              => '0',
      SS_DataWrite          => (31 downto 0 => '0'),
      SS_Adr                => (2 downto 0 => '0'),
      SS_wren_GPU           => '0',
      SS_wren_Timing        => '0',      
      SS_rden_GPU           => '0',
      SS_rden_Timing        => '0'
   );
   
   -- vram is at 0x30000000
   DDRAM_ADDR(28 downto 25) <= "0011";
   DDRAM_ADDR(24 downto 17) <= (others => '0');
   DDRAM_ADDR(16 downto  0) <= vram_ADDR(19 downto 3);
   
   iddrram_model : entity work.ddrram_model
   generic map
   (
      loadVram => '1'
   )
   port map
   (
      DDRAM_CLK        => clk2x,      
      DDRAM_BUSY       => DDRAM_BUSY,      
      DDRAM_BURSTCNT   => DDRAM_BURSTCNT,  
      DDRAM_ADDR       => DDRAM_ADDR,      
      DDRAM_DOUT       => DDRAM_DOUT,      
      DDRAM_DOUT_READY => DDRAM_DOUT_READY,
      DDRAM_RD         => DDRAM_RD,        
      DDRAM_DIN        => DDRAM_DIN,       
      DDRAM_BE         => DDRAM_BE,        
      DDRAM_WE         => DDRAM_WE        
   );
   
   process
      file infile          : text;
      variable f_status    : FILE_OPEN_STATUS;
      variable inLine      : LINE;
      variable para_type   : std_logic_vector(7 downto 0);
      variable para_time   : std_logic_vector(31 downto 0);
      variable para_data   : std_logic_vector(31 downto 0);
      variable space       : character;
   begin
      
      wait until reset = '0';
         
      file_open(f_status, infile, "R:\gpu_test_FPSXA.txt", read_mode);
      
      while (not endfile(infile)) loop
         
         readline(infile,inLine);
         
         HREAD(inLine, para_type);
         Read(inLine, space);
         HREAD(inLine, para_time);
         Read(inLine, space);
         HREAD(inLine, para_data);
         
         while (clkCount < unsigned(para_time)) loop
            clkCount <= clkCount + 1;
            wait until rising_edge(clk1x);
         end loop;
         
         bus_gpu_dataWrite <= para_data;
         bus_gpu_write     <= '1';
         
         clkCount <= clkCount + 1;
         wait until rising_edge(clk1x);
         bus_gpu_write     <= '0';
      end loop;
      
      file_close(infile);
      
      wait for 10 ms;
      
      report "DONE" severity failure;
      
   end process;
   
   
end architecture;


