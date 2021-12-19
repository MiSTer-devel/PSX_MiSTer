library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all; 

entity spu is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      irqOut               : out std_logic := '0';
      
      FAKESPU              : in  std_logic;
      enaSPUirq            : out std_logic;
      
      bus_addr             : in  unsigned(9 downto 0); 
      bus_dataWrite        : in  std_logic_vector(15 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(15 downto 0);
      
      spu_dmaRequest       : out std_logic;
      dma_read             : in  std_logic;
      dma_readdata         : out std_logic_vector(15 downto 0);     
      dma_write            : in  std_logic;
      dma_writedata        : in  std_logic_vector(15 downto 0);
      
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(7 downto 0);
      SS_wren              : in  std_logic;
      SS_rden              : in  std_logic;
      SS_DataRead          : out std_logic_vector(31 downto 0);
      SS_idle              : out std_logic
   );
end entity;

architecture arch of spu is
   
   -- voiceregs
   signal RamVoice1_addrA     : unsigned(7 downto 0) := (others => '0');
   signal RamVoice1_dataA     : std_logic_vector(15 downto 0) := (others => '0');
   signal RamVoice1_write     : std_logic := '0';     
   signal RamVoice1_addrB     : unsigned(7 downto 0) := (others => '0');
   signal RamVoice1_dataB     : std_logic_vector(15 downto 0); 
   
   signal RamVoice2_addrA     : unsigned(7 downto 0) := (others => '0');
   signal RamVoice2_dataA     : std_logic_vector(15 downto 0) := (others => '0');
   signal RamVoice2_write     : std_logic := '0';     
   signal RamVoice2_addrB     : unsigned(7 downto 0) := (others => '0');
   signal RamVoice2_dataB     : std_logic_vector(15 downto 0); 
   
   -- Regs                          
	signal VOLUME_LEFT         : std_logic_vector(15 downto 0);  -- 0x1F801D80
	signal VOLUME_RIGHT        : std_logic_vector(15 downto 0);  -- 0x1F801D82
                              
	signal KEYON               : std_logic_vector(31 downto 0);  -- 0x1F801D88
	signal KEYOFF              : std_logic_vector(31 downto 0);  -- 0x1F801D8C
	signal PITCHMODENA         : std_logic_vector(31 downto 0);  -- 0x1F801D90
	signal NOISEMODE           : std_logic_vector(31 downto 0);  -- 0x1F801D94
	signal REVERBON            : std_logic_vector(31 downto 0);  -- 0x1F801D98
	signal ENDX                : std_logic_vector(31 downto 0);  -- 0x1F801D9C
                              
	signal TRANSFERADDR        : std_logic_vector(15 downto 0);  -- 0x1F801DA6
                              
	signal CNT                 : std_logic_vector(15 downto 0);  -- 0x1F801DAA
	signal TRANSFER_CNT        : std_logic_vector(15 downto 0);  -- 0x1F801DAC
	signal STAT                : std_logic_vector(15 downto 0);  -- 0x1F801DAE
                              
	signal CDAUDIO_VOL_L       : std_logic_vector(15 downto 0);  -- 0x1F801DB0	
	signal CDAUDIO_VOL_R       : std_logic_vector(15 downto 0);  -- 0x1F801DB2	
	signal EXT_VOL_L           : std_logic_vector(15 downto 0);  -- 0x1F801DB4	
	signal EXT_VOL_R           : std_logic_vector(15 downto 0);  -- 0x1F801DB6	
	signal CURVOL_L            : std_logic_vector(15 downto 0);  -- 0x1F801DB8	
	signal CURVOL_R            : std_logic_vector(15 downto 0);  -- 0x1F801DBA	
   
   -- fifoIn
   signal FifoIn_reset        : std_logic := '0';
   signal FifoIn_Din          : std_logic_vector(15 downto 0) := (others => '0');
   signal FifoIn_Wr           : std_logic := '0'; 
   signal FifoIn_Dout         : std_logic_vector(15 downto 0);
   signal FifoIn_Rd           : std_logic := '0';
   signal FifoIn_Empty        : std_logic;
   
   -- fifoOut
   signal FifoOut_reset       : std_logic := '0';
   signal FifoOut_Din         : std_logic_vector(15 downto 0) := (others => '0');
   signal FifoOut_Wr          : std_logic := '0'; 
   signal FifoOut_Dout        : std_logic_vector(15 downto 0);
   signal FifoOut_Rd          : std_logic := '0';
   signal FifoOut_Empty       : std_logic;
   
   -- processing
   signal busy                : std_logic := '0';
   signal capturePosition     : unsigned(9 downto 0) := (others => '0');
   signal sampleticks         : unsigned(9 downto 0) := (others => '0');
   signal cmdTicks            : unsigned(9 downto 0) := (others => '0');
   
   -- savestates
   type t_ssarray is array(0 to 63) of std_logic_vector(31 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));
   signal ss_out : t_ssarray := (others => (others => '0'));
      
   signal ss_voice_loading : std_logic := '0';
      
begin 

   ififoIn: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 64,
      DATAWIDTH        => 16,
      NEARFULLDISTANCE => 32
   )
   port map
   ( 
      clk      => clk1x,     
      reset    => FifoIn_reset,   
                
      Din      => FifoIn_Din,     
      Wr       => FifoIn_Wr,      
      Full     => open,    
      NearFull => open,

      Dout     => FifoIn_Dout,    
      Rd       => FifoIn_Rd,      
      Empty    => FifoIn_Empty   
   );
   
   ififoOut: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 64,
      DATAWIDTH        => 16,
      NEARFULLDISTANCE => 32
   )
   port map
   ( 
      clk      => clk1x,     
      reset    => FifoOut_reset,   
                
      Din      => FifoOut_Din,     
      Wr       => FifoOut_Wr,      
      Full     => open,    
      NearFull => open,

      Dout     => FifoOut_Dout,    
      Rd       => FifoOut_Rd,      
      Empty    => FifoOut_Empty   
   );
   
   STAT(15) <= '0'; -- unused
   STAT(14) <= '0'; -- unused
   STAT(13) <= '0'; -- unused
   STAT(12) <= '0'; -- unused
   STAT(11) <= capturePosition(9); -- Writing to First/Second half of Capture Buffers (0=First, 1=Second)
   STAT(10) <= busy; -- Data Transfer Busy Flag
   STAT( 9) <= '1' when (CNT(5 downto 4) = "10" and FifoIn_Empty = '1') else '0';  -- Data Transfer DMA Read Request 
   STAT( 8) <= '1' when (CNT(5 downto 4) = "11" and FifoOut_Empty = '0') else '0'; -- Data Transfer DMA Write Request
   STAT( 7) <= STAT(8) or STAT(9); -- Data Transfer DMA Read/Write Request ;seems to be same as SPUCNT.Bit5
   STAT( 6) <= '0'; -- todo: IRQ9
   STAT(5 downto 0) <= CNT(5 downto 0);

   spu_dmaRequest <= STAT(7);
   
   itagramVOICEREGS1 : altdpram
	GENERIC MAP 
   (
   	indata_aclr                         => "OFF",
      indata_reg                          => "INCLOCK",
      intended_device_family              => "Cyclone V",
      lpm_type                            => "altdpram",
      outdata_aclr                        => "OFF",
      outdata_reg                         => "UNREGISTERED",
      ram_block_type                      => "MLAB",
      rdaddress_aclr                      => "OFF",
      rdaddress_reg                       => "UNREGISTERED",
      rdcontrol_aclr                      => "OFF",
      rdcontrol_reg                       => "UNREGISTERED",
      read_during_write_mode_mixed_ports  => "CONSTRAINED_DONT_CARE",
      width                               => 16,
      widthad                             => 8,
      width_byteena                       => 1,
      wraddress_aclr                      => "OFF",
      wraddress_reg                       => "INCLOCK",
      wrcontrol_aclr                      => "OFF",
      wrcontrol_reg                       => "INCLOCK"
	)
	PORT MAP (
      inclock    => clk1x,
      wren       => RamVoice1_write,
      data       => RamVoice1_dataA,
      wraddress  => std_logic_vector(RamVoice1_addrA),
      rdaddress  => std_logic_vector(RamVoice1_addrB),
      q          => RamVoice1_dataB
	);
   
   RamVoice1_addrB <= bus_addr(8 downto 1);
   
   itagramVOICEREGS2 : altdpram
	GENERIC MAP 
   (
   	indata_aclr                         => "OFF",
      indata_reg                          => "INCLOCK",
      intended_device_family              => "Cyclone V",
      lpm_type                            => "altdpram",
      outdata_aclr                        => "OFF",
      outdata_reg                         => "UNREGISTERED",
      ram_block_type                      => "MLAB",
      rdaddress_aclr                      => "OFF",
      rdaddress_reg                       => "UNREGISTERED",
      rdcontrol_aclr                      => "OFF",
      rdcontrol_reg                       => "UNREGISTERED",
      read_during_write_mode_mixed_ports  => "CONSTRAINED_DONT_CARE",
      width                               => 16,
      widthad                             => 8,
      width_byteena                       => 1,
      wraddress_aclr                      => "OFF",
      wraddress_reg                       => "INCLOCK",
      wrcontrol_aclr                      => "OFF",
      wrcontrol_reg                       => "INCLOCK"
	)
	PORT MAP (
      inclock    => clk1x,
      wren       => RamVoice2_write,
      data       => RamVoice2_dataA,
      wraddress  => std_logic_vector(RamVoice2_addrA),
      rdaddress  => std_logic_vector(RamVoice2_addrB),
      q          => RamVoice2_dataB
	);
   
   RamVoice2_addrB <= (SS_Adr - 64) when SS_Adr > 64 else (others => '0');

   ss_out(0)(9 downto 0)    <= std_logic_vector(cmdTicks);       
   ss_out(1)(9 downto 0)    <= std_logic_vector(sampleticks);    
   ss_out(2)(9 downto 0)    <= std_logic_vector(capturePosition);
      
   ss_out(32)               <= KEYON;          
   ss_out(33)               <= KEYOFF;         
   ss_out(34)               <= PITCHMODENA;    
   ss_out(35)               <= NOISEMODE;      
   ss_out(36)               <= REVERBON;       
   ss_out(37)               <= ENDX;           
      
   ss_out(38)(15 downto 0)  <= VOLUME_LEFT;    
   ss_out(38)(31 downto 16) <= VOLUME_RIGHT;   
   ss_out(39)(15 downto 0)  <= TRANSFERADDR;   
   ss_out(39)(31 downto 16) <= CNT;		      
   ss_out(40)(15 downto 0)  <= TRANSFER_CNT;   
   ss_out(40)(31 downto 16) <= STAT;   
   ss_out(41)(15 downto 0)  <= CDAUDIO_VOL_L;  
   ss_out(41)(31 downto 16) <= CDAUDIO_VOL_R;  
   ss_out(42)(15 downto 0)  <= EXT_VOL_L;	   
   ss_out(42)(31 downto 16) <= EXT_VOL_R;	   
   ss_out(43)(15 downto 0)  <= CURVOL_L;	      
   ss_out(43)(31 downto 16) <= CURVOL_R;	      

   -- cpu interface
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then
            
         FifoIn_Wr         <= '0';
         FifoIn_Rd         <= '0';
         FifoIn_reset      <= '0';
   
         FifoOut_Wr        <= '0';
         FifoOut_Rd        <= '0';
         FifoOut_reset     <= '0';
            
         irqOut            <= '0';
         
         RamVoice1_write   <= '0';
         RamVoice2_write   <= '0';
         
         if (SS_reset = '1') then
            ss_voice_loading <= '1';
            RamVoice1_write <= '1';
            RamVoice1_dataA <= x"0000";
            RamVoice1_addrA <= (others => '0');
            RamVoice2_write <= '1';
            RamVoice2_dataA <= x"0000";
            RamVoice2_addrA <= (others => '0');
         end if;
         
         if (ss_voice_loading = '1') then
            RamVoice1_write <= '1';
            RamVoice1_addrA <= RamVoice1_addrA + 1;
            RamVoice2_write <= '1';
            RamVoice2_addrA <= RamVoice2_addrA + 1;
            if (RamVoice1_addrA = 191) then
               ss_voice_loading <= '0';
            end if;
         end if;
      
         if (reset = '1') then
            
            busy              <= '0';
            
            cmdTicks          <= unsigned(ss_in(0)(9 downto 0));
            sampleticks       <= unsigned(ss_in(1)(9 downto 0));
            capturePosition   <= unsigned(ss_in(2)(9 downto 0));
            
            KEYON             <= ss_in(32);
            KEYOFF            <= ss_in(33);
            PITCHMODENA       <= ss_in(34);
            NOISEMODE         <= ss_in(35);
            REVERBON          <= ss_in(36);
            ENDX              <= ss_in(37);
               
            VOLUME_LEFT       <= ss_in(38)(15 downto 0);
            VOLUME_RIGHT      <= ss_in(38)(31 downto 16);
            TRANSFERADDR      <= ss_in(39)(15 downto 0);
            CNT		         <= ss_in(39)(31 downto 16);
            TRANSFER_CNT      <= ss_in(40)(15 downto 0);
            CDAUDIO_VOL_L     <= ss_in(41)(15 downto 0);
            CDAUDIO_VOL_R     <= ss_in(41)(31 downto 16);
            EXT_VOL_L	      <= ss_in(42)(15 downto 0);
            EXT_VOL_R	      <= ss_in(42)(31 downto 16);
            CURVOL_L	         <= ss_in(43)(15 downto 0);
            CURVOL_R	         <= ss_in(43)(31 downto 16);

         elsif (SS_wren = '1') then
            
            if (SS_Adr >= 64) then
               RamVoice1_write <= '1';
               RamVoice1_dataA <= SS_DataWrite(15 downto 0);
               RamVoice1_addrA <= SS_Adr - 64;
               RamVoice2_write <= '1';
               RamVoice2_dataA <= SS_DataWrite(15 downto 0);
               RamVoice2_addrA <= SS_Adr - 64;
            end if;
            
         elsif (ce = '1') then
         
            if (bus_write = '1') then
            
               --if (bus_addr = x"0") then
               --   CDROM_STATUS(1 downto 0) <= bus_dataWrite(1 downto 0);
               --end if;
               
               if (bus_addr < 16#180#) then
                  RamVoice1_write <= '1';
                  RamVoice1_dataA <= bus_dataWrite;
                  RamVoice1_addrA <= bus_addr(8 downto 1);                 
                  RamVoice2_write <= '1';
                  RamVoice2_dataA <= bus_dataWrite;
                  RamVoice2_addrA <= bus_addr(8 downto 1);
               else
                  case (to_integer(bus_addr)) is
                     when 16#180# => VOLUME_LEFT               <= bus_dataWrite; CURVOL_L <= VOLUME_LEFT(14 downto 0) & '0';
                     when 16#182# => VOLUME_RIGHT              <= bus_dataWrite; CURVOL_R <= VOLUME_RIGHT(14 downto 0) & '0';
                  
                     when 16#188# => KEYON(15 downto 0)        <= bus_dataWrite;
                     when 16#18A# => KEYON(31 downto 16)       <= bus_dataWrite;
                     when 16#18C# => KEYOFF(15 downto 0)       <= bus_dataWrite;
                     when 16#18E# => KEYOFF(31 downto 16)      <= bus_dataWrite;
                     when 16#190# => PITCHMODENA(15 downto 0)  <= bus_dataWrite;
                     when 16#192# => PITCHMODENA(31 downto 16) <= bus_dataWrite;
                     when 16#194# => NOISEMODE(15 downto 0)    <= bus_dataWrite;
                     when 16#196# => NOISEMODE(31 downto 16)   <= bus_dataWrite;
                     when 16#198# => REVERBON(15 downto 0)     <= bus_dataWrite;
                     when 16#19A# => REVERBON(31 downto 16)    <= bus_dataWrite;
                                     
                     when 16#1A6# => TRANSFERADDR              <= bus_dataWrite; -- todo: trigger RAMIRQ
                     
                     when 16#1A8# => -- todo: push fifo
                                                             
                     when 16#1AA# => 
                        -- todo: clear fifo if DMAREAD
                        -- todo: copy to ram if not DMAREAD?
                        -- todo if enable turned off changed -> mute
                        CNT              <= bus_dataWrite;
                        
                     when 16#1AC# => TRANSFER_CNT              <= bus_dataWrite;
                                     
                     when 16#1B0# => CDAUDIO_VOL_L             <= bus_dataWrite;
                     when 16#1B2# => CDAUDIO_VOL_R             <= bus_dataWrite;
                     when 16#1B4# => EXT_VOL_L                 <= bus_dataWrite;
                     when 16#1B6# => EXT_VOL_R                 <= bus_dataWrite;
                     when 16#1B8# => CURVOL_L                  <= bus_dataWrite;
                     when 16#1BA# => CURVOL_R                  <= bus_dataWrite;
                        
                     when others => null;
                  end case;
               end if;
            
            end if; -- end bus write
         
            if (bus_read = '1') then
               bus_dataRead <= (others => '1');
               if (bus_addr < 16#180#) then
                  bus_dataRead <= RamVoice1_dataB;
               else
                  case (to_integer(bus_addr)) is
                     when 16#180# => bus_dataRead <= VOLUME_LEFT;
                     when 16#182# => bus_dataRead <= VOLUME_RIGHT;
                  
                     when 16#188# => bus_dataRead <= KEYON(15 downto 0);
                     when 16#18A# => bus_dataRead <= KEYON(31 downto 16);
                     when 16#18C# => bus_dataRead <= KEYOFF(15 downto 0);
                     when 16#18E# => bus_dataRead <= KEYOFF(31 downto 16);
                     when 16#190# => bus_dataRead <= PITCHMODENA(15 downto 0);
                     when 16#192# => bus_dataRead <= PITCHMODENA(31 downto 16);
                     when 16#194# => bus_dataRead <= NOISEMODE(15 downto 0);
                     when 16#196# => bus_dataRead <= NOISEMODE(31 downto 16);
                     when 16#198# => bus_dataRead <= REVERBON(15 downto 0);
                     when 16#19A# => bus_dataRead <= REVERBON(31 downto 16);
                     when 16#19C# => bus_dataRead <= ENDX(15 downto 0);
                     when 16#19E# => bus_dataRead <= ENDX(31 downto 16);
                  
                     when 16#1A6# => bus_dataRead <= TRANSFERADDR;
                
                     when 16#1AA# => bus_dataRead <= CNT;
                     when 16#1AC# => bus_dataRead <= TRANSFER_CNT;
                     when 16#1AE# => bus_dataRead <= STAT;
                   
                     when 16#1B0# => bus_dataRead <= CDAUDIO_VOL_L;
                     when 16#1B2# => bus_dataRead <= CDAUDIO_VOL_R;
                     when 16#1B4# => bus_dataRead <= EXT_VOL_L;
                     when 16#1B6# => bus_dataRead <= EXT_VOL_R;
                     when 16#1B8# => bus_dataRead <= CURVOL_L;
                     when 16#1BA# => bus_dataRead <= CURVOL_R;
                        
                     when others => null;
                  end case;
               end if;
            end if;
            
            if (cmdTicks > 0) then
               cmdTicks <= cmdTicks - 1;
               if (cmdTicks = 1) then
                  busy <= '0';
                  if (CNT(5 downto 4) = "11") then -- DMARead
                     -- push 32 words into fifo
                  else
                     FifoIn_reset <= '1'; -- quirk to clear fifo
                     -- todo: copy data to ram
                  end if;
               end if;
            end if;
            
            if (sampleticks < 767) then
               sampleticks <= sampleticks + 1;
            else
               sampleticks     <= (others => '0');
               capturePosition <= capturePosition + 2;
            end if;
            
            enaSPUirq <= '0';
            if (FAKESPU = '1') then
               ENDX <= x"00FFFFFF";
               if (CNT(15) = '1' and CNT(6) = '1') then
                  enaSPUirq <= '1';
               end if;
            end if;

         end if; -- ce
         
         if (dma_write = '1') then
            FifoIn_Wr  <= '1';
            FifoIn_Din <= dma_writedata;
            cmdTicks   <= cmdTicks + 15;
         end if;
         
      end if;
   end process;
   
   
--##############################################################
--############################### savestates
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (SS_reset = '1') then
         
            for i in 0 to 63 loop
               ss_in(i) <= (others => '0');
            end loop;
            
         elsif (SS_wren = '1' and SS_Adr < 64) then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         end if;
         
         SS_idle <= '0';
         if (FifoIn_Empty = '1' and FifoOut_Empty = '1') then
            SS_idle <= '1';
         end if;
         
         if (SS_rden = '1') then
            if (SS_Adr < 64) then
               SS_DataRead <= ss_out(to_integer(SS_Adr));
            else
               SS_DataRead <= x"0000" & RamVoice2_dataB;
            end if;
         end if;
      
      end if;
   end process;

   -- synthesis translate_off

   goutput : if 1 = 1 generate
   signal outputCnt : unsigned(31 downto 0) := (others => '0'); 
   
   begin
      process
         constant WRITETIME            : std_logic := '1';
         
         file outfile                  : text;
         variable f_status             : FILE_OPEN_STATUS;
         variable line_out             : line;
            
         variable clkCounter           : unsigned(31 downto 0);
            
         variable bus_read_1           : std_logic;
         variable newoutputCnt         : unsigned(31 downto 0); 
      begin
   
         file_open(f_status, outfile, "R:\\debug_sound_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\debug_sound_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk1x);
            
            if (reset = '1') then
               clkCounter := (others => '0');
            end if;
            
            newoutputCnt := outputCnt;
            
            if (bus_write = '1') then
               write(line_out, string'("WRITEREG: ")); 
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter));
               end if;
               write(line_out, string'(" ")); 
               write(line_out, to_hstring("000000" & bus_addr));
               write(line_out, string'(" ")); 
               write(line_out, to_hstring(bus_dataWrite));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            
            if (bus_read_1 = '1') then
               write(line_out, string'("READREG: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter - 1));
               end if;
               write(line_out, string'(" ")); 
               write(line_out, to_hstring("000000" & bus_addr));
               write(line_out, string'(" ")); 
               write(line_out, to_hstring(bus_dataRead));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            bus_read_1 := bus_read;
            
                        
            if (dma_write = '1') then
               write(line_out, string'("DMAWRITE: ")); 
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter));
               end if;
               write(line_out, string'(" 0000 ")); 
               write(line_out, to_hstring(dma_writedata));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if;
            
            if (dma_read = '1') then
               write(line_out, string'("DMAREAD: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter - 1));
               end if;
               write(line_out, string'(" 0000 ")); 
               write(line_out, to_hstring(dma_readdata));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            
            
            outputCnt <= newoutputCnt;
            clkCounter := clkCounter + 1;
           
         end loop;
         
      end process;
   
   end generate goutput;
   
   -- synthesis translate_on

end architecture;





