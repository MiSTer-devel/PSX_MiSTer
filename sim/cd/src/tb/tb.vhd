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
   
   signal cd_hps_req          : std_logic := '0';
   signal cd_hps_lba          : std_logic_vector(31 downto 0);
   signal cd_hps_ack          : std_logic;
   signal cd_hps_write        : std_logic;
   signal cd_hps_data         : std_logic_vector(15 downto 0);
   
   signal cdSize              : unsigned(29 downto 0);
   
   --sdram
   signal ram_req             : std_logic;
   signal ram_addr            : std_logic_vector(26 downto 0) := (others => '0');
   signal ram_do              : std_logic_vector(127 downto 0);
   signal ram_done            : std_logic := '0';
   
   -- hps emulation
   signal hps_req             : std_logic := '0';
   signal hps_addr            : std_logic_vector(26 downto 0) := (others => '0');
   
   -- savestates
   signal reset_in            : std_logic;
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
   
   reset_in  <= '0' after 3000 ns;
   
   icd_top : entity psx.cd_top
   port map
   (
      clk1x                => clk1x,
      ce                   => '1',        
      reset                => reset_out,  

      CDDISABLE            => '0',
      hasCD                => '1',
      cdSize               => cdSize,
      fastCD               => '0',
      
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
      
      cd_hps_on            => '1',
      cd_hps_req           => cd_hps_req,  
      cd_hps_lba           => cd_hps_lba,  
      cd_hps_ack           => cd_hps_ack,  
      cd_hps_write         => cd_hps_write,
      cd_hps_data          => cd_hps_data, 
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(13 downto 0),
      SS_wren              => SS_wren(13)
   );
   
   isdram_model : entity work.sdram_model 
   generic map
   (
      FILELOADING => '1',
      --INITFILE => "test_triangle.iso"
   )
   port map
   (
      clk          => clk1x,
      addr         => ram_addr,
      req          => ram_req,
      ram_128      => '0',
      rnw          => '1',
      be           => "0000",
      di           => x"00000000",
      do           => ram_do,
      done         => ram_done,
      reqprocessed => open,
      ram_idle     => open,
      fileSize     => cdSize
   );
   
   ram_addr <= cd_addr when cd_req = '1' else hps_addr;
   ram_req  <= cd_req or hps_req;
   
   cd_data <= ram_do(31 downto 0);
   cd_done <= ram_done;
   
   
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
   
   
   -- hps emulation
   process
   begin
      wait until rising_edge(clk1x);
      if (cd_hps_req = '1') then
         for i in 0 to 100 loop
            wait until rising_edge(clk1x);
         end loop;
         cd_hps_ack <= '1';
         wait until rising_edge(clk1x);
         cd_hps_ack <= '0';
         wait until rising_edge(clk1x);
         
         for i in 0 to 587 loop
            hps_req  <= '1';
            hps_addr <= std_logic_vector(to_unsigned(to_integer(unsigned(cd_hps_lba)) * 2352 + i * 4, 27));
            wait until rising_edge(clk1x);
            hps_req <= '0';
            wait until rising_edge(clk1x);
            
            wait until ram_done = '1';
            cd_hps_data  <= ram_do(15 downto 0);
            cd_hps_write <= '1';
            wait until rising_edge(clk1x);
            cd_hps_data  <= ram_do(31 downto 16);
            wait until rising_edge(clk1x);
            cd_hps_write <= '0';
         end loop;
         
      end if;
   end process;
   
   
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
      
      file_open(f_status, infile, "R:\cd_test_fpsxa.txt", read_mode);
      
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
            if (fullyIdle = '1') then
               idleTime := idleTime + 1;
               --if (idleTime > 10000) then
               --   idleTime := 0;
               --   clkCount <= to_integer(unsigned(para_time)) - 1000;
               --   wait until rising_edge(clk1x);
               --end if;
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


