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
   
   signal cd_hps_req          : std_logic := '0';
   signal cd_hps_lba          : std_logic_vector(31 downto 0);
   signal cd_hps_ack          : std_logic := '0';
   signal cd_hps_write        : std_logic := '0';
   signal cd_hps_data         : std_logic_vector(15 downto 0);
   
   signal cdSize              : unsigned(29 downto 0);
   
   signal sampleticks         : unsigned(9 downto 0) := (others => '0');
   signal spu_tick            : std_logic := '0';
   
   -- hps emulation
   type ttracknames is array(0 to 99) of string(1 to 255);
   signal tracknames : ttracknames;
   signal trackcount : integer;
   
   type filetype is file of integer;
   type t_data is array(0 to (2**28)-1) of integer;
   signal cdLoaded            : std_logic := '0';
   signal cdTrack             : std_logic_vector(7 downto 0) := x"FF";
   
   signal trackinfo_data      : std_logic_vector(31 downto 0);
   signal trackinfo_addr      : std_logic_vector(8 downto 0);
   signal trackinfo_write     : std_logic := '0';

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

      INSTANTSEEK          => '1',
      hasCD                => '1',
      newCD                => reset_out,
      LIDopen              => '0',
      cdSize               => cdSize,
      fastCD               => '0',
      region               => "10",
      libcryptKey          => x"0000",
      
      fullyIdle            => fullyIdle,
      
      spu_tick             => spu_tick,
      
      bus_addr             => bus_addr,     
      bus_dataWrite        => bus_dataWrite,
      bus_read             => bus_read,     
      bus_write            => bus_write,    
      bus_dataRead         => bus_dataRead,
      
      dma_read             => dma_read,     
      dma_readdata         => dma_readdata,
      
      cd_hps_req           => cd_hps_req,  
      --cd_hps_lba           => cd_hps_lba,  
      cd_hps_lba_sim       => cd_hps_lba,  
      cd_hps_ack           => cd_hps_ack,  
      cd_hps_write         => cd_hps_write,
      cd_hps_data          => cd_hps_data, 
      
      trackinfo_data       => trackinfo_data, 
      trackinfo_addr       => trackinfo_addr, 
      trackinfo_write      => trackinfo_write,
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(13 downto 0),
      SS_wren              => SS_wren(13),
      SS_rden              => '0'
   );  
   
   itb_savestates : entity work.tb_savestates
   generic map
   (
      LOADSTATE         => '1',
      --FILENAME          => "C:\Users\FPGADev\Desktop\savestates_psxcore\Suikoden II (USA)_1.ss"
      FILENAME          => "C:\Projekte\psx\FPSXApp\Die Hard Trilogy (USA) (Rev 1).sst"
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
   
   -- spu speed
   process
   begin
      wait until rising_edge(clk1x);
      
      spu_tick <= '0';
      
      if (sampleticks < 767) then
         sampleticks <= sampleticks + 1;
      else
         sampleticks    <= (others => '0');
         spu_tick       <= '1';
      end if;
   end process;
   
   -- hps emulation
   process
      file infile          : text;
      variable f_status    : FILE_OPEN_STATUS;
      variable inLine      : LINE;
      variable count       : integer;
   begin

      file_open(f_status, infile, "R:\cdtracks.txt", read_mode);
   
      count := 1;
      while (not endfile(infile)) loop
         readline(infile,inLine);
         tracknames(count) <= (others => ' ');
         tracknames(count)(1 to inLine'length) <= inLine(1 to inLine'length); 
         count := count + 1;
      end loop;
      trackcount <= count;
      
      file_close(infile);
      
      wait;
   end process;
   
   process
      variable data           : t_data := (others => 0);
      file infile             : filetype;
      variable f_status       : FILE_OPEN_STATUS;
      variable read_byte0     : std_logic_vector(7 downto 0);
      variable read_byte1     : std_logic_vector(7 downto 0);
      variable read_byte2     : std_logic_vector(7 downto 0);
      variable read_byte3     : std_logic_vector(7 downto 0);
      variable next_vector    : bit_vector (2351 downto 0);
      variable next_int       : integer;
      variable actual_len     : natural;
      variable targetpos      : integer;
      variable cdData         : std_logic_vector(31 downto 0);
      
      -- copy from std_logic_arith, not used here because numeric std is also included
      function CONV_STD_LOGIC_VECTOR(ARG: INTEGER; SIZE: INTEGER) return STD_LOGIC_VECTOR is
        variable result: STD_LOGIC_VECTOR (SIZE-1 downto 0);
        variable temp: integer;
      begin
 
         temp := ARG;
         for i in 0 to SIZE-1 loop
 
         if (temp mod 2) = 1 then
            result(i) := '1';
         else 
            result(i) := '0';
         end if;
 
         if temp > 0 then
            temp := temp / 2;
         elsif (temp > integer'low) then
            temp := (temp - 1) / 2; -- simulate ASR
         else
            temp := temp / 2; -- simulate ASR
         end if;
        end loop;
 
        return result;  
      end;
   begin
      
      if (cdLoaded = '0') then
      
         file_open(f_status, infile, "R:\\cuedata.bin", read_mode);
         
         targetpos := 0;
         
         while (not endfile(infile)) loop
            
            read(infile, next_int);  
            
            data(targetpos) := next_int;
            targetpos       := targetpos + 1;

         end loop;
         
         file_close(infile);
         
         wait for 10 us;
         for i in 0 to 400 loop
            trackinfo_data  <= std_logic_vector(to_signed(data(i), 32));
            trackinfo_addr  <= std_logic_vector(to_unsigned(i, 9));
            trackinfo_write <= '1';
            wait until rising_edge(clk1x);
            trackinfo_write <= '0';
            wait until rising_edge(clk1x);
         end loop;

         cdLoaded <= '1';
      end if;
   
   
      wait until rising_edge(clk1x);
      if (cd_hps_req = '1') then
      
         -- load new track if required
         if (cdTrack /= cd_hps_lba(31 downto 24)) then
         
            cdTrack <= cd_hps_lba(31 downto 24);
            report "Loading new File";
            report tracknames(to_integer(unsigned(cd_hps_lba(31 downto 24))));
            file_open(f_status, infile, tracknames(to_integer(unsigned(cd_hps_lba(31 downto 24)))), read_mode);
            
            targetpos := 0;
            
            if (unsigned(cd_hps_lba(31 downto 24)) > 0 and unsigned(cd_hps_lba(31 downto 24)) < trackcount) then 
            
               while (not endfile(infile)) loop
                  
                  read(infile, next_int);  
                  
                  data(targetpos) := next_int;
                  targetpos       := targetpos + 1;
      
               end loop;
               
               file_close(infile);
               cdSize <= to_unsigned(targetpos * 4, 30);
            
            end if;

         end if;
      end if;
      
      if (cd_hps_req = '1') then
      
         for i in 0 to 100 loop
            wait until rising_edge(clk1x);
         end loop;
         cd_hps_ack <= '1';
         wait until rising_edge(clk1x);
         cd_hps_ack <= '0';
         wait until rising_edge(clk1x);
         
         for i in 0 to 587 loop
            if (unsigned(cd_hps_lba(31 downto 24)) > 0 and unsigned(cd_hps_lba(31 downto 24)) < trackcount) then 
               cdData := std_logic_vector(to_signed(data(to_integer(unsigned(cd_hps_lba(23 downto 0))) * (2352 / 4) + i), 32));
            else
               cdData := (others => '0');
            end if;
            
            cd_hps_data  <= cdData(15 downto 0);
            cd_hps_write <= '1';
            wait until rising_edge(clk1x);
            cd_hps_data  <= cdData(31 downto 16);
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


