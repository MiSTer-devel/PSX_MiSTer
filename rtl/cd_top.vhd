library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;

entity cd_top is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      hasCD                : in  std_logic;
      
      irqOut               : out std_logic := '0';
      
      bus_addr             : in  unsigned(3 downto 0); 
      bus_dataWrite        : in  std_logic_vector(7 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(7 downto 0);
      
      dmaReadRequest       : out std_logic;
      dma_read             : in  std_logic;
      dma_readdata         : out std_logic_vector(31 downto 0) 
   );
end entity;

architecture arch of cd_top is

   -- cpu interface
   signal CDROM_STATUS        : std_logic_vector(7 downto 0);
   signal CDROM_IRQENA        : std_logic_vector(4 downto 0);
   signal CDROM_IRQFLAG       : std_logic_vector(4 downto 0);
      
   signal beginCommand        : std_logic := '0';
   signal nextCmd             : std_logic_vector(7 downto 0);
      
   signal FifoParam_reset     : std_logic := '0';
   signal FifoParam_Din       : std_logic_vector(7 downto 0) := (others => '0');
   signal FifoParam_Wr        : std_logic := '0'; 
   signal FifoParam_Dout      : std_logic_vector(7 downto 0);
   signal FifoParam_Rd        : std_logic := '0';
   signal FifoParam_Empty     : std_logic;
      
   -- command processing   
   signal cmd_busy            : std_logic := '0';
   signal cmd_delay           : integer range 0 to 120000;
   signal cmdPending          : std_logic := '0';
   signal handleCommand       : std_logic := '0';    
   signal paramCount          : integer range 0 to 6;
   signal fifoParamCount      : integer range 0 to 16;
   signal working             : std_logic := '0';
   signal workCommand         : std_logic_vector(7 downto 0);
   signal workDelay           : integer range 0 to 399999;
   signal cmdAck              : std_logic := '0';
   signal driveAck            : std_logic := '0';
   signal softReset           : std_logic := '0';
    
   signal setLocActive        : std_logic := '0';
   signal setLocReadStep      : integer range 0 to 5;
   signal setLocMinute        : unsigned(7 downto 0);
   signal setLocSecond        : unsigned(7 downto 0);
   signal setLocFrame         : unsigned(7 downto 0);
    
   signal FifoResponse_reset  : std_logic := '0';
   signal FifoResponse_Din    : std_logic_vector(7 downto 0) := (others => '0');
   signal FifoResponse_Wr     : std_logic := '0'; 
   signal FifoResponse_Dout   : std_logic_vector(7 downto 0);
   signal FifoResponse_Rd     : std_logic := '0';
   signal FifoResponse_Empty  : std_logic;
    
   -- drive
   type tdrivestate is
	(
		DRIVE_IDLE,
		DRIVE_SEEKPHYSICAL,
		DRIVE_SEEKLOGICAL,
		DRIVE_SEEKIMPLICIT,
		DRIVE_READING,
		DRIVE_PLAYING,
		DRIVE_SPEEDCHANGEORTOCREAD,
		DRIVE_SPINNINGUP,
		DRIVE_CHANGESESSION
	);
   signal driveState          : tdrivestate := DRIVE_IDLE;
   
   signal internalStatus      : std_logic_vector(7 downto 0);
   signal modeReg             : std_logic_vector(7 downto 0);
   
   signal driveBusy           : std_logic;
   signal driveDelay          : integer range 0 to 134217727;
   signal driveDelayNext      : integer range 0 to 134217727;
   
   signal handleDrive         : std_logic := '0';
   signal startMotor          : std_logic := '0';
   
   signal currentLBA          : integer range 0 to 16383;        
    
begin 
   
   -- cpu interface
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         beginCommand      <= '0';
         irqOut            <= '0';
         FifoResponse_Rd   <= '0';
         FifoParam_Wr      <= '0';
      
         if (reset = '1') then
            
            CDROM_STATUS   <= x"18";
            CDROM_IRQENA   <= (others => '0');
            CDROM_IRQFLAG  <= (others => '0');
            
         elsif (ce = '1') then
         
            if (bus_write = '1') then
            
               if (bus_addr = x"0") then
                  CDROM_STATUS(1 downto 0) <= bus_dataWrite(1 downto 0);
               else
                  case (CDROM_STATUS(1 downto 0)) is
                     when "00" =>
                        case (bus_addr) is
                           when x"1" =>
                              beginCommand <= '1';
                              nextCmd      <= bus_dataWrite;
                              
                           when x"2" =>
                              --todo: if (fifoParam.size() == 16) fifoParam.pop_front();
                              FifoParam_Wr  <= '1';
                              FifoParam_Din <= bus_dataWrite;
                           
                           when x"3" =>
                              if (bus_dataWrite(7) = '1') then
                                 -- todo: load data sector to fifo
                              else
                                 -- todo: clear data fifo
                              end if;
                           when others => null;
                        end case;
                        
                     when "01" =>
                        case (bus_addr) is
                           when x"1" => -- sound map write -> do nothing
                           when x"2" =>
                              CDROM_IRQENA <= bus_dataWrite(4 downto 0);
                              
                           when x"3" =>
                              CDROM_IRQFLAG <= CDROM_IRQFLAG and (not bus_dataWrite(4 downto 0));
                              --todo: if CDROM_IRQFLAG = 0 and pendingDriveIRQ -> generate irq from drive or possibly reactive drive
                              if (bus_dataWrite(6) = '1') then
                                 --todo: clear param fifo
                              end if;
                           
                           when others => null;
                        end case;
                     
                     when "10" =>
                        case (bus_addr) is
                           when x"1" => -- sound map coding info write -> do nothing
                           when x"2" => -- todo audio volume
                           when x"3" => -- todo audio volume
                           when others => null;
                        end case;
                        
                     when "11" =>
                        case (bus_addr) is
                           when x"1" => -- todo audio volume
                           when x"2" => -- todo audio volume
                           when x"3" => -- todo apply audio volume
                           when others => null;
                        end case;
                     when others => null;
                  end case;
               end if;
            
            end if; -- end bus write
         
            if (bus_read = '1') then
               bus_dataRead <= (others => '0');
               case (bus_addr) is
                  when x"0" => 
                     bus_dataRead <= CDROM_STATUS;
                     
                  when x"1" =>
                     if (FifoResponse_Empty = '1') then
                        bus_dataRead    <= (others => '0');
                     else
                        bus_dataRead    <= FifoResponse_Dout;
                        FifoResponse_Rd <= '1';
                     end if;
                  
                  when x"2" =>
                     -- todo: return data fifo
                  
                  when x"3" =>
                     if (CDROM_STATUS(0) = '1') then
                        bus_dataRead <= "111" & CDROM_IRQFLAG;
                     else
                        bus_dataRead <= "111" & CDROM_IRQENA;
                     end if;
                  
                  when others => null;
               end case;
            end if;
            
            if (cmdAck = '1') then
               CDROM_IRQFLAG <= "00011";
               if (CDROM_IRQENA(1 downto 0) /= "00") then
                  irqOut <= '1';
               end if;
            end if;            
            
            if (driveAck = '1') then
               CDROM_IRQFLAG <= "00010";
               if (CDROM_IRQENA(1) = '1') then
                  irqOut <= '1';
               end if;
            end if;
         
         end if; -- ce
      end if;
   end process;
   
   ififoParam: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 32,
      DATAWIDTH        => 8,
      NEARFULLDISTANCE => 16
   )
   port map
   ( 
      clk      => clk1x,     
      reset    => FifoParam_reset,   
                
      Din      => FifoParam_Din,     
      Wr       => FifoParam_Wr,      
      Full     => open,    
      NearFull => open,

      Dout     => FifoParam_Dout,    
      Rd       => FifoParam_Rd,      
      Empty    => FifoParam_Empty   
   );
   
   -- command processing
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         handleCommand      <= '0';
         FifoResponse_reset <= '0';
         FifoResponse_Wr    <= '0';
         cmdAck             <= '0';
         driveAck           <= '0';
         softReset          <= '0';
         FifoParam_Rd       <= '0';
         FifoParam_reset    <= '0';
      
         if (reset = '1') then
            
            FifoParam_reset      <= '1';
            FifoResponse_reset   <= '1';
            cmdPending           <= '0';
            cmd_busy             <= '0';
            cmd_delay            <= 0;
            fifoParamCount       <= 0;
            working              <= '0';
            
            setLocActive         <= '0';
            
         elsif (ce = '1') then
         
            -- receive new command request or decrease wait timer on pending command
            if (beginCommand = '1') then
               cmdPending <= '1';
               cmd_busy   <= '1';
               cmd_delay  <= 25000;
               if (nextCmd = x"1C") then -- init
                  cmd_delay <= 120000;
               end if;
               case (nextCmd) is
                  when x"02" => paramCount <= 3; --Setloc
                  when x"0D" => paramCount <= 2; --SetFilter
                  when x"0E" => paramCount <= 1; --Setmode
                  when x"12" => paramCount <= 1; --SetSession
                  when x"14" => paramCount <= 1; --GetTD
                  when x"19" => paramCount <= 1; --Test
                  when x"1D" => paramCount <= 2; --GetQ
                  when x"1F" => paramCount <= 6; --VideoCD
                  when others => paramCount <= 0;
               end case;
            elsif (cmd_busy = '1') then
               if (cmd_delay > 0) then
                  cmd_delay <= cmd_delay - 1;
               else
                  handleCommand <= '1';
                  cmd_busy      <= '0';
               end if;
            end if;
            
            -- command processing time is up -> handle it
            if (handleCommand = '1') then
               if (fifoParamCount < paramCount) then
                  -- todo: errorResponse(1, 0x20);
                  cmdPending <= '0';
               else
                  if (FifoResponse_empty = '0') then 
                     FifoResponse_reset <= '1';
                  end if;
                  
                  case (nextCmd) is
                     when x"00" => -- Sync
                        --todo
                        
                     when x"01" => -- Getstat
                        --todo
                        
                     when x"02" => -- Setloc
                        setLocReadStep <= 5;
                        cmdAck         <= '1';
                        cmdPending     <= '0';
                        
                     when x"03" => -- play
                        --todo
                        
                     when x"04" => -- forward
                        --todo
                        
                     when x"05" => -- backward
                        --todo
                        
                     --when "06" => readN at readS 0x1B
                     
                     when x"07" => -- MotorOn
                        --todo
                        
                     when x"08" => -- Stop
                        --todo
                        
                     when x"09" => -- pause
                        --todo
                     
                     when x"0A" => -- reset
                        cmdAck <= '1';
                        if (working = '1' and workCommand = x"0A") then
                           cmdPending <= '0';
                        else
                           --todo
                           --if (driveState == DRIVESTATE::SEEKLOGICAL || driveState == DRIVESTATE::SEEKPHYSICAL || driveState == DRIVESTATE::SEEKIMPLICIT)
                           --{
                           --   updatePositionWhileSeeking();
                           --}
                           softReset   <= '1';
                           working     <= '1';
                           workDelay   <= 399999;
                           workCommand <= nextCmd;
                           -- call here second time, so response has new values after reset?
                           cmd_delay   <= 24999;
                           cmd_busy    <= '1';
                        end if;
                     
                     when x"0B" => -- mute
                        --todo
                        
                     when x"0C" => -- demute
                        --todo
                        
                     when x"0D" => -- setfilter
                        --todo
                        
                     when x"0E" => -- setmode
                        --todo
                     
                     when x"0F" => -- getparam
                        --todo
                        
                     when x"10" => -- GetLocL
                        --todo
                        
                     when x"11" => -- GetLocP
                        --todo
                        
                     when x"12" => -- SetSession
                        --todo
                        
                     when x"13" => -- GetTN
                        --todo
                        
                     when x"14" => -- GetTD
                        --todo
                        
                     when x"15" | x"16" => -- SeekL/SeekP
                        --todo
                        
                     when x"17" | x"18" => -- SetClock/GetClock
                        --todo
                        
                     when x"19" => -- test
                        --todo
                        
                     when x"1A" => -- getID
                        --todo
                        
                     when x"06" | x"1B" => -- ReadN/ReadS
                        --todo
                        
                     when x"1C" => -- Init
                        --todo
                        
                     when x"1D" => -- GetQ
                        --todo
                        
                     when x"1E" => -- ReadTOC
                        --todo
                     
                     when x"1F" => -- VideoCD
                        --todo
                     
                     when others =>
                        --todo errorResponse(1, 0x40);
                        cmdPending <= '0';
                        
                  end case;
                  
               end if;
            end if;
            
            -- processing of commands that take several parameters
            
            -- setLoc
            if (setLocReadStep > 0) then
               setLocReadStep <= setLocReadStep - 1;
               case (setLocReadStep) is  -- todo: BCDBIN conversion
                  when 5 => 
                     setLocMinute <= unsigned(FifoParam_Dout(7 downto 4)) * 10 + unsigned(FifoParam_Dout(3 downto 0));
                     FifoParam_Rd <= '1';
                  when 3 => 
                     setLocSecond <= unsigned(FifoParam_Dout(7 downto 4)) * 10 + unsigned(FifoParam_Dout(3 downto 0));
                     FifoParam_Rd <= '1';
                  when 1 => 
                     setLocFrame  <= unsigned(FifoParam_Dout(7 downto 4)) * 10 + unsigned(FifoParam_Dout(3 downto 0));
                     FifoParam_Rd <= '1';
                  when others => null;
               end case;
            end if;
            
         
            -- second processing of recurring commands
            if (working = '1') then
               if (workDelay > 0) then
                  workDelay <= workDelay - 1;
               else
                  working <= '0';
                  if (workCommand = x"1A") then -- GetID
                     -- todo
                  else
                     cmd_busy <= '0';
                     driveAck <= '1';
                  end if;
               end if;
            end if;
            
            -- responses
            if (cmdAck = '1' or driveAck = '1') then
               FifoResponse_Din <= internalStatus;
               FifoResponse_Wr  <= '1';
            end if;
            
            if (softReset = '1') then
               FifoParam_reset <= '1';
            end if;
         
         end if; -- ce
         
         if (FifoParam_reset = '1') then
            fifoParamCount <= 0;
         elsif (FifoParam_Wr = '1') then
            fifoParamCount <= fifoParamCount + 1;
         elsif (FifoParam_Rd = '1') then
            fifoParamCount <= fifoParamCount - 1; 
         end if;
          
      end if;
   end process;
   
   ififoResponse: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 32,
      DATAWIDTH        => 8,
      NEARFULLDISTANCE => 16
   )
   port map
   ( 
      clk      => clk1x,     
      reset    => FifoResponse_reset,   
                
      Din      => FifoResponse_Din,     
      Wr       => FifoResponse_Wr,      
      Full     => open,    
      NearFull => open,

      Dout     => FifoResponse_Dout,    
      Rd       => FifoResponse_Rd,      
      Empty    => FifoResponse_Empty   
   );
   
   -- drive
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then

         handleDrive <= '0';
         startMotor  <= '0';

         if (reset = '1') then
            
            driveBusy      <= '0';
            driveState     <= DRIVE_IDLE;
                  
            startMotor     <= '1';
            
            internalStatus <= x"10"; -- shell open
            modeReg        <= x"20"; -- read_raw_sector set
            
            currentLBA     <= 0;
            
         elsif (softReset = '1') then
         
            modeReg        <= x"20"; -- read_raw_sector set
            internalStatus <= x"00";
            if (hasCD = '1') then
               internalStatus(1) <= '1';
               
               if (currentLBA /= 0) then
                  -- todo
               	--driveState = DRIVESTATE::SEEKIMPLICIT;
                  --seekStartLBA = currentLBA;
                  --seekEndLBA = 0;
                  --readOnDisk(0);
               else
                  driveState <= DRIVE_SPEEDCHANGEORTOCREAD;
               end if;
               
               driveBusy  <= '1';
               if (modeReg(7) = '1') then -- double speed
                  driveDelay     <= 16934400 + 33868800 + 19999;
                  driveDelayNext <= 16934400 + 33868800 + 19999;
               else
                  driveDelay     <= 16934400 + 19999;
                  driveDelayNext <= 16934400 + 19999;
               end if;               
            
            else
               driveBusy  <= '0';
               driveState <= DRIVE_IDLE;
               driveDelay <= 0;
            end if;
            
         elsif (ce = '1') then
         
            if (driveBusy = '1') then
               if (driveDelay > 0) then
                  driveDelay <= driveDelay - 1;
               else
                  handleDrive <= '1';
                  driveBusy   <= '0';
               end if;
            end if;
         
            if (startMotor = '1') then
               if (driveState /= DRIVE_SPINNINGUP) then
                  driveState <= DRIVE_SPINNINGUP;
                  driveDelay <= 44100*300;
                  driveBusy  <= '1';
               end if;
            end if;
            
            if (handleDrive = '1') then
               case (driveState) is
               
                  when DRIVE_SPINNINGUP =>
                     driveState     <= DRIVE_IDLE;
                     internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
                     internalStatus(1)          <= hasCD;
                  
                  when others => null;
               end case;
            end if;
            
         end if; -- ce
      end if;
   end process;

goutput : if 1 = 1 generate
   signal outputCnt : unsigned(31 downto 0) := (others => '0'); 
   
   begin
      process
         file outfile               : text;
         variable f_status          : FILE_OPEN_STATUS;
         variable line_out          : line;
         
         variable bus_read_1        : std_logic;
         variable cmdAck_1          : std_logic;
         variable driveAck_1        : std_logic;
         variable fifoResponseSize  : unsigned(31 downto 0);
         variable newoutputCnt      : unsigned(31 downto 0); 
      begin
   
         file_open(f_status, outfile, "R:\\debug_cd_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\debug_cd_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk1x);
            
            if (FifoResponse_reset = '1') then fifoResponseSize := (others => '0'); end if;
            if (FifoResponse_Wr = '1') then fifoResponseSize := fifoResponseSize + 1; end if;
            if (FifoResponse_Rd = '1') then fifoResponseSize := fifoResponseSize - 1; end if;
            
            newoutputCnt := outputCnt;
            
            if (bus_write = '1') then
               write(line_out, string'("CPUWRITE: 0")); 
               write(line_out, to_hstring(bus_addr));
               write(line_out, string'(" 000000")); 
               write(line_out, to_hstring(bus_dataWrite));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            
            if (bus_read_1 = '1') then
               write(line_out, string'("CPUREAD: 0")); 
               write(line_out, to_hstring(bus_addr));
               write(line_out, string'(" 000000")); 
               write(line_out, to_hstring(bus_dataRead));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            bus_read_1 := bus_read;
            
            if (beginCommand = '1') then
               write(line_out, string'("CMD: "));
               write(line_out, to_hstring(nextCmd));
               write(line_out, string'(" 00000000")); 
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            
            if (cmdAck_1 = '1') then
               write(line_out, string'("RSPFIFO: "));
               write(line_out, to_hstring(FifoResponse_Din));
               write(line_out, string'(" "));
               write(line_out, to_hstring(fifoResponseSize));               
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            cmdAck_1 := cmdAck;            
            
            if (driveAck_1 = '1') then
               write(line_out, string'("RSPFIFO2: "));
               write(line_out, to_hstring(FifoResponse_Din));
               write(line_out, string'(" "));
               write(line_out, to_hstring(fifoResponseSize));               
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            driveAck_1 := driveAck;
            
            outputCnt <= newoutputCnt;
           
         end loop;
         
      end process;
   
   end generate goutput;
   
   -- synthesis translate_on

end architecture;





