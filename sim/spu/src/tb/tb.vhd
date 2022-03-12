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
   signal clk3x               : std_logic := '1';
   
   signal clk1xToggle         : std_logic := '0';
   signal clk1xToggle2X       : std_logic := '0';
   signal clk2xIndex          : std_logic := '0';
   
   signal ce                  : std_logic := '0';
            
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
   
   -- ddrram
   signal memSPU_request      : std_logic;
   signal memSPU_ack          : std_logic := '0';
   signal memSPU_BURSTCNT     : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memSPU_ADDR         : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memSPU_DIN          : std_logic_vector(63 downto 0) := (others => '0');
   signal memSPU_BE           : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memSPU_WE           : std_logic := '0';
   signal memSPU_RD           : std_logic := '0';
   
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
   
   -- ddr3 arbiter
   type tddr3State is
   (
      ARBITERIDLE,
      WAITGPUPAUSED,
      REQUEST,
      WAITDONE
   );
   signal ddr3state              : tddr3State := ARBITERIDLE;
   
   signal memSPU_acknext         : std_logic := '0';
   
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
   clk3x  <= not clk3x  after 5 ns;
   
   reset_in  <= '0' after 3000 ns;
   
   ce <= '1' when reset_out = '1';
   
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
   
   ispu : entity psx.spu
   port map
   (
      clk1x                => clk1x,
      clk2x                => clk2x,
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => reset_out,
      
      SPUon                => '1',
      useSDRAM             => '1',
      REPRODUCIBLESPUIRQ   => '1',
      REPRODUCIBLESPUDMA   => '0',
      REVERBOFF            => '0',
      
      cpuPaused            => '0',
         
      cd_left              => x"0000",
      cd_right             => x"0000",
      
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
      
      -- ddr3 interface
      mem_request          => memSPU_request,  
      mem_BURSTCNT         => memSPU_BURSTCNT, 
      mem_ADDR             => memSPU_ADDR,     
      mem_DIN              => memSPU_DIN,      
      mem_BE               => memSPU_BE,       
      mem_WE               => memSPU_WE,       
      mem_RD               => memSPU_RD,       
      mem_ack              => memSPU_ack,      
      mem_DOUT             => DDRAM_DOUT,      
      mem_DOUT_READY       => DDRAM_DOUT_READY,
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(8 downto 0),
      SS_wren              => SS_wren(9),
      SS_rden              => '0',
      
      SS_RAM_dataWrite     => SS_DataWrite(15 downto 0),
      SS_RAM_Adr           => std_logic_vector(SS_Adr),      
      SS_RAM_request       => SS_wren(14),  
      SS_RAM_rnw           => '0',      
      SS_RAM_dataRead      => open, 
      SS_RAM_done          => open     
   );
   
   itb_savestates : entity work.tb_savestates
   generic map
   (
      LOADSTATE         => '0',
      --FILENAME          => "C:\Projekte\psx\FPSXApp\02 - Living Room.sst"
      FILENAME          => "C:\Projekte\psx\FPSXApp\Metal Gear Solid (Europe) (Disc 1).sst"
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
      SCRIPTLOADING => '0',
      INITFILE      => "R:\spu_ram_FPSXA.bin",
      FILELOADING   => '0'
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
   
   iddrram_model : entity work.ddrram_model
   generic map
   (
      SLOWTIMING => 0
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
   
   -- DDR3 arbiter
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         memSPU_ack          <= '0';
      
         if (reset_out = '1') then
            ddr3state <= ARBITERIDLE;
         else
         
            case (ddr3state) is
            
               when ARBITERIDLE =>
                  if (memSPU_request = '1') then
                     ddr3state  <= WAITGPUPAUSED;
                  end if;
                  
               when WAITGPUPAUSED =>
                  ddr3state      <= REQUEST; 
                  if (memSPU_request = '1') then
                     DDRAM_BURSTCNT     <= memSPU_BURSTCNT;
                     DDRAM_ADDR         <= "0011" & x"03" & memSPU_ADDR(19 downto 3);    
                     DDRAM_DIN          <= memSPU_DIN;     
                     DDRAM_BE           <= memSPU_BE;      
                     DDRAM_WE           <= memSPU_WE;      
                     DDRAM_RD           <= memSPU_RD;
                  end if;
               
               when REQUEST =>
                  if (DDRAM_BUSY = '0') then
                     ddr3state  <= WAITDONE; 
                     DDRAM_WE   <= '0';     
                     DDRAM_RD   <= '0';
                     memSPU_ack <= '1';
                  end if;
               
               when WAITDONE =>
                  if (memSPU_request = '0') then
                     ddr3state      <= ARBITERIDLE;
                  end if;
               
            end case;
         end if;
      end if;
   end process;
   
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


