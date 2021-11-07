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
      dma_readdata         : out std_logic_vector(7 downto 0) 
   );
end entity;

architecture arch of cd_top is
  
   constant RAW_SECTOR_SIZE         : integer := 2352;
   constant SECTOR_SYNC_SIZE        : integer := 12;
   constant RAW_SECTOR_OUTPUT_SIZE  : integer := RAW_SECTOR_SIZE - SECTOR_SYNC_SIZE;
   constant DATA_SECTOR_SIZE        : integer := 2048;
   
   constant FRAMES_PER_SECOND       : integer := 75;
   constant FRAMES_PER_MINUTE       : integer := 75 * 60;
   constant LEAD_OUT_TRACK_NUMBER   : unsigned(7 downto 0) := x"AA";
   constant startLBA                : integer := 150; -- todo: is this really constant?
   
   constant lbaCount                : integer := 27; -- todo: CD size / RAW_SECTOR_SIZE;
   
   -- data fifo
   signal FifoData_reset            : std_logic := '0';
   signal FifoData_Din              : std_logic_vector(7 downto 0) := (others => '0');
   signal FifoData_Wr               : std_logic := '0'; 
   signal FifoData_Dout             : std_logic_vector(7 downto 0);
   signal FifoData_Rd               : std_logic := '0';
   signal FifoData_Empty            : std_logic;
   
   -- cpu interface  
   signal CDROM_STATUS              : std_logic_vector(7 downto 0);
   signal CDROM_IRQENA              : std_logic_vector(4 downto 0);
   signal CDROM_IRQFLAG             : std_logic_vector(4 downto 0);
            
   signal beginCommand              : std_logic := '0';
   signal nextCmd                   : std_logic_vector(7 downto 0);
   
   signal pendingDriveIRQ           : std_logic := '0';
   signal pendingDriveResponse      : std_logic_vector(7 downto 0);
   signal ackRead_valid             : std_logic := '0';
            
   signal FifoParam_reset           : std_logic := '0';
   signal FifoParam_Din             : std_logic_vector(7 downto 0) := (others => '0');
   signal FifoParam_Wr              : std_logic := '0'; 
   signal FifoParam_Dout            : std_logic_vector(7 downto 0);
   signal FifoParam_Rd              : std_logic := '0';
   signal FifoParam_Empty           : std_logic;
            
   -- command processing         
   signal cmd_busy                  : std_logic := '0';
   signal cmd_delay                 : integer range 0 to 120000;
   signal cmdPending                : std_logic := '0';
   signal handleCommand             : std_logic := '0';    
   signal paramCount                : integer range 0 to 6;
   signal fifoParamCount            : integer range 0 to 16;
   signal working                   : std_logic := '0';
   signal workCommand               : std_logic_vector(7 downto 0);
   signal workDelay                 : integer range 0 to 399999;
   signal cmdAck                    : std_logic := '0';
   signal driveAck                  : std_logic := '0';
   signal softReset                 : std_logic := '0';
         
   signal setLocActive              : std_logic := '0';
   signal setLocReadStep            : integer range 0 to 5;
   signal setLocMinute              : unsigned(7 downto 0);
   signal setLocSecond              : unsigned(7 downto 0);
   signal setLocFrame               : unsigned(7 downto 0);
      
   signal seekOnDiskCmd             : std_logic := '0';
   signal setMode                   : std_logic := '0';
   signal newMode                   : std_logic_vector(7 downto 0);
   signal readSN                    : std_logic := '0';
   
   signal errorResponseCmd_new      : std_logic := '0'; 
   signal errorResponseCmd_error    : std_logic_vector(7 downto 0);
   signal errorResponseCmd_reason   : std_logic_vector(7 downto 0);
   
   signal errorResponseNext_new     : std_logic := '0'; 
   signal errorResponseNext_reason  : std_logic_vector(7 downto 0);
    
   signal FifoResponse_reset        : std_logic := '0';
   signal FifoResponse_Din          : std_logic_vector(7 downto 0) := (others => '0');
   signal FifoResponse_Wr           : std_logic := '0'; 
   signal FifoResponse_Dout         : std_logic_vector(7 downto 0);
   signal FifoResponse_Rd           : std_logic := '0';
   signal FifoResponse_Empty        : std_logic;
    
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
   signal driveState                : tdrivestate := DRIVE_IDLE;
         
   signal internalStatus            : std_logic_vector(7 downto 0);
   signal modeReg                   : std_logic_vector(7 downto 0);
         
   signal driveBusy                 : std_logic;
   signal driveDelay                : integer range 0 to 134217727;
   signal driveDelayNext            : integer range 0 to 134217727;
         
   signal handleDrive               : std_logic := '0';
   signal startMotor                : std_logic := '0';
   signal ackDrive                  : std_logic := '0';
   signal seekOnDiskDrive           : std_logic := '0';
   signal ackRead                   : std_logic := '0';
         
   signal currentLBA                : integer range 0 to 262143;        
   signal seekLBA                   : integer range 0 to 262143;       
   
   signal readAfterSeek             : std_logic := '0';
   signal playAfterSeek             : std_logic := '0';
   signal lastSectorHeaderValid     : std_logic := '0'; 
   
   signal errorResponseDrive_new    : std_logic := '0'; 
   signal errorResponseDrive_error  : std_logic_vector(7 downto 0);
   signal errorResponseDrive_reason : std_logic_vector(7 downto 0);

   -- exchange with data part
   signal readOnDisk                : std_logic := '0';   
   signal readLBA                   : integer range 0 to 262143; 
   signal trackNumberBCD            : unsigned(7 downto 0) := x"00";
   
   signal copyData                  : std_logic := '0';  
   signal seekOK                    : std_logic := '1';  
   signal startReading              : std_logic := '0';  
   signal processDataSector         : std_logic := '0';  
   signal writeSectorPointer        : unsigned(2 downto 0) := (others => '0');
   signal readSectorPointer         : unsigned(2 downto 0) := (others => '0');
   
   -- sector fetch
   type tsectorFetch is
	(
		SFETCH_IDLE,
      SFETCH_START,
		SFETCH_FIRST,
		SFETCH_DATA
	);
   signal sectorFetchState          : tsectorFetch := SFETCH_IDLE;
   
   type tsectorBuffer is array(0 to 587) of std_logic_vector(31 downto 0);
   signal sectorBuffer              : tsectorBuffer;
      
   signal positionInIndex           : integer range 0 to 262143; 
   signal lastReadSector            : integer range 0 to 262143; 
   signal fetchCount                : integer range 0 to 588;
      
   -- sector process
   type tsectorProcess is
	(
		SPROC_IDLE,
      SPROC_READHEADER,
      SPROC_READSUBHEADER,
      SPROC_START,
		SPROC_FIRST,
		SPROC_DATA
	);
   signal sectorProcessState        : tsectorProcess := SPROC_IDLE;
   
   type tsectorBuffers is array(0 to 7) of tsectorBuffer;
   signal sectorBuffers             : tsectorBuffers;
   
   type tsectorBufferSizes is array(0 to 7) of integer range 0 to 588;
   signal sectorBufferSizes         : tsectorBufferSizes;
   
   signal procCount                 : integer range 0 to 588;
   signal procSize                  : integer range 0 to 588;
   signal procReadAddr              : integer range 0 to 588;
   signal procReadData              : std_logic_vector(31 downto 0);
   signal header                    : std_logic_vector(31 downto 0);
   signal subheader                 : std_logic_vector(31 downto 0);
   
   -- copy data
   type tCopyState is
	(
		COPY_IDLE,
		COPY_FIRST,
		COPY_DATA,
      COPY_CHECKPTR
	);
   signal copyState                 : tCopyState := COPY_IDLE;

   signal copyCount                 : integer range 0 to 588;
   signal copyByteCnt               : integer range 0 to 3;
   signal copySize                  : integer range 0 to 588;    
   signal copyReadAddr              : integer range 0 to 588;
   signal copyReadData              : std_logic_vector(31 downto 0); 
      
   --test cd
   signal cd_addr                   : std_logic_vector(14 downto 0) := (others => '0');
   signal cd_data                   : std_logic_vector(31 downto 0);
      
      
begin 

   ififoData: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 4096,
      DATAWIDTH        => 8,
      NEARFULLDISTANCE => 16
   )
   port map
   ( 
      clk      => clk1x,     
      reset    => FifoData_reset,   
                
      Din      => FifoData_Din,     
      Wr       => FifoData_Wr,      
      Full     => open,    
      NearFull => open,

      Dout     => FifoData_Dout,    
      Rd       => FifoData_Rd,      
      Empty    => FifoData_Empty   
   );
   
   FifoData_Rd <= ce when (FifoData_Empty = '0' and bus_read = '1' and bus_addr(3 downto 0) = "0010") else
                  ce when (FifoData_Empty = '0' and dma_read = '1') else 
                  '0';
   
   dma_readdata <= FifoData_Dout when (FifoData_Empty = '0') else (others => '1');
   
   -- cpu interface
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         beginCommand      <= '0';
         irqOut            <= '0';
         FifoResponse_Rd   <= '0';
         FifoParam_Wr      <= '0';
         ackRead_valid     <= '0';
         FifoData_reset    <= '0';
         copyData          <= '0';
      
         if (reset = '1') then
            
            CDROM_STATUS    <= x"18";
            CDROM_IRQENA    <= (others => '0');
            CDROM_IRQFLAG   <= (others => '0');
            pendingDriveIRQ <= '0';
            
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
                                 if (FifoData_Empty = '1') then -- don't do anything when data still inside?
                                    copyData <= '1';
                                 end if;
                              else
                                 FifoData_reset <= '1';
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
                     if (FifoData_Empty = '0') then
                        bus_dataRead <= FifoData_Dout;
                     else
                        bus_dataRead <= (others => '0');
                     end if;
                  
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
            
            if (driveAck = '1' or ackDrive = '1') then
               CDROM_IRQFLAG <= "00010";
               if (CDROM_IRQENA(1) = '1') then
                  irqOut <= '1';
               end if;
            end if;
            
            if (ackRead = '1') then
               if (CDROM_IRQFLAG = "00001") then -- irq still pending, sector missed
                  -- todo: nothing can be done?
               elsif (CDROM_IRQFLAG /= "00000") then
                  pendingDriveIRQ      <= '1';
                  pendingDriveResponse <= internalStatus;
               else
                  CDROM_IRQFLAG <= "00001";
                  if (CDROM_IRQENA(0) = '1') then
                     irqOut <= '1';
                  end if;
                  ackRead_valid <= '1';
               end if;
            end if;
               
            if (errorResponseNext_new = '1') then
               CDROM_IRQFLAG <= "00101";
               if (CDROM_IRQENA(2) = '1' or CDROM_IRQENA(0) = '1') then
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
      
         handleCommand           <= '0';
         cmdAck                  <= '0';
         driveAck                <= '0';
         softReset               <= '0';
         seekOnDiskCmd           <= '0';
         setMode                 <= '0';
         readSN                  <= '0';
         errorResponseCmd_new    <= '0';
         errorResponseNext_new   <= '0';
         
         FifoResponse_reset      <= '0';
         FifoResponse_Wr         <= '0';
         FifoParam_Rd            <= '0';
         FifoParam_reset         <= '0';
      
         if (reset = '1') then
            
            FifoParam_reset         <= '1';
            FifoResponse_reset      <= '1';
            cmdPending              <= '0';
            cmd_busy                <= '0';
            cmd_delay               <= 0;
            fifoParamCount          <= 0;
            working                 <= '0';
               
            setLocActive            <= '0';
            
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
                  errorResponseCmd_new    <= '1';
                  errorResponseCmd_error  <= x"01";
                  errorResponseCmd_reason <= x"20";
                  cmdPending              <= '0';
                  FifoParam_reset         <= '1';
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
                        FifoParam_Rd <= '1';
                        setMode      <= '1';
                        newMode      <= FifoParam_Dout;
                        cmdAck       <= '1';
                        cmdPending   <= '0';
                     
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
                        --todo: if seeking, update position?
                        cmdAck                <= '1';
                        cmdPending            <= '0';
                        seekOnDiskCmd         <= '1';
                        setLocActive          <= '0';
                        
                     when x"17" | x"18" => -- SetClock/GetClock
                        --todo
                        
                     when x"19" => -- test
                        --todo
                        
                     when x"1A" => -- getID
                        --todo
                        
                     when x"06" | x"1B" => -- ReadN/ReadS
                        cmdPending <= '0';
                        if (hasCD = '0') then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"80";
                        else
                           -- todo: missing checks
                           cmdAck <= '1';
                           readSN <= '1';
                        end if;
                        
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
            if (cmdAck = '1' or driveAck = '1' or ackDrive = '1' or ackRead_valid = '1') then
               FifoResponse_Din <= internalStatus;
               FifoResponse_Wr  <= '1';
            end if;
                      
            if (errorResponseCmd_new = '1') then
               FifoResponse_Din           <= internalStatus or errorResponseCmd_error;
               FifoResponse_Wr            <= '1';
               errorResponseNext_new      <= '1';
               errorResponseNext_reason   <= errorResponseCmd_reason;
            end if;      
            if (errorResponseDrive_new = '1') then
               FifoResponse_Din        <= internalStatus or errorResponseDrive_error;
               FifoResponse_Wr         <= '1';
               errorResponseNext_new   <= '1';
               errorResponseNext_reason   <= errorResponseDrive_reason;
            end if;   
            if (errorResponseNext_new = '1') then
               FifoResponse_Din        <= errorResponseNext_reason;
               FifoResponse_Wr         <= '1';
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

         handleDrive             <= '0';
         startMotor              <= '0';
         readOnDisk              <= '0';
         ackDrive                <= '0';
         seekOnDiskDrive         <= '0';
         errorResponseDrive_new  <= '0';
         startReading            <= '0';
         ackRead                 <= '0';
         processDataSector       <= '0';

         if (reset = '1') then
            
            driveBusy               <= '0';
            driveState              <= DRIVE_IDLE;
                           
            startMotor              <= '1';
                     
            internalStatus          <= x"10"; -- shell open
            modeReg                 <= x"20"; -- read_raw_sector set
                     
            currentLBA              <= 0;
            
            readAfterSeek           <= '0';
            playAfterSeek           <= '0';
            lastSectorHeaderValid   <= '0';
            
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
               
                  when DRIVE_SEEKIMPLICIT =>
                     --todo
                     
                  when DRIVE_SEEKLOGICAL | DRIVE_SEEKPHYSICAL =>
                     driveState     <= DRIVE_IDLE;
                     internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
                     if (seekOk = '1') then
                        if (readAfterSeek = '1') then
                           startReading  <= '1';
                           readAfterSeek <= '0';
                        elsif (playAfterSeek = '1') then
                           --todo start playing
                        else
                           ackDrive <= '1';
                        end if;
                     else
                        lastSectorHeaderValid     <= '0';
                        errorResponseDrive_new    <= '1';
                        errorResponseDrive_error  <= x"04";
                        errorResponseDrive_reason <= x"04";
                     end if;
                     ackDrive <= '1';
                     
                     
                  when DRIVE_READING | DRIVE_PLAYING =>
                     if (trackNumberBCD = LEAD_OUT_TRACK_NUMBER) then
                        internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
                        internalStatus(1)          <= '0'; -- motor off
                        driveState   <= DRIVE_IDLE;
                        ackDrive     <= '1';
                     else
                        -- todo: if dataSector
                           processDataSector     <= '1';
                           lastSectorHeaderValid <= '1';
                           writeSectorPointer    <= writeSectorPointer + 1;
                           internalStatus(5)     <= '1'; -- reading
                        --endif
                        driveDelay   <= driveDelayNext;
                        ackRead      <= '1';
                        -- todo: currentLBA   <= lastReadSector;
                        -- todo: physical lba position?
                        -- todo: subdata = nextSubdata
                        --readOnDisk   <= '1'; -- todo: move after read
                        readLBA      <= lastReadSector + 1;
                     end if;
                     
                  when DRIVE_SPEEDCHANGEORTOCREAD =>
                     driveState     <= DRIVE_IDLE;
               
                  when DRIVE_SPINNINGUP =>
                     driveState     <= DRIVE_IDLE;
                     internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
                     internalStatus(1)          <= hasCD;
                  
                  when DRIVE_CHANGESESSION =>
                     --todo
                  
                  when others => null;
               end case;
            end if;
            
            if (seekOnDiskCmd = '1' or seekOnDiskDrive = '1') then
               seekLBA               <= to_integer(setLocMinute) * FRAMES_PER_MINUTE + to_integer(setLocSecond) * FRAMES_PER_SECOND + to_integer(setLocFrame);
               readLBA               <= to_integer(setLocMinute) * FRAMES_PER_MINUTE + to_integer(setLocSecond) * FRAMES_PER_SECOND + to_integer(setLocFrame);
               readOnDisk            <= '1';
               readAfterSeek         <= '0';
               playAfterSeek         <= '0';
               lastSectorHeaderValid <= '0';
               internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
               internalStatus(1)          <= '1'; -- motor on
               internalStatus(6)          <= '1'; -- seeking
               driveDelay     <= 19999; -- todo: real seek time
               driveDelayNext <= 19999; -- todo: real seek time
               driveBusy      <= '1';
               if (nextCmd = x"15") then
                  driveState  <= DRIVE_SEEKLOGICAL;
               else
                  driveState  <= DRIVE_SEEKPHYSICAL;
               end if;
            end if;
            
            if (readSN = '1') then
               -- todo !
               --if ((!setLocActive || seekLBA == lastReadSector) && (driveState == DRIVESTATE::READING || ((driveState == DRIVESTATE::SEEKLOGICAL || driveState == DRIVESTATE::SEEKPHYSICAL || driveState == DRIVESTATE::SEEKIMPLICIT) && readAfterSeek)))
               --{
               --   setLocActive = false;
               --}
               --else
                  if (driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or driveState = DRIVE_SEEKIMPLICIT) then
                     -- todo: updatePositionWhileSeeking();
                  end if;
                  if (setLocActive = '1') then
                     seekOnDiskDrive   <= '1';
                     readAfterSeek     <= '1';
                     playAfterSeek     <= '0';
                  else
                     startReading <= '1';
                  end if;
            end if;
            
            if (startReading = '1') then
               --todo: check for setLocActive needed when coming from readSN?
               --todo: check for seekstate required? should never end here when still in seek?
               internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
               internalStatus(1)          <= '1'; -- motor on
               driveDelay         <= 9999; -- todo: real read time
               driveDelayNext     <= 9999; -- todo: real read time
               driveBusy          <= '1';
               driveState         <= DRIVE_READING;
               writeSectorPointer <= (others => '0');
               readSectorPointer  <= (others => '0');
            end if;
            
            if (ackRead_valid = '1') then
               readSectorPointer <= writeSectorPointer;
            end if;
            
            if (setMode = '1') then
               modeReg <= newMode;
               if (modeReg(7) /= newMode(7)) then -- speedchange
                  if (driveState = DRIVE_SPEEDCHANGEORTOCREAD) then
                     -- todo: need to early finish here?
                  elsif (driveState /= DRIVE_SEEKIMPLICIT) then
                     -- todo: add time? for now just set new time, it's very long anyway
                     if (newMode(7) = '1') then
                        driveDelay     <= 27095040; -- 80%
                        driveDelayNext <= 27095040; -- 80%%
                     else
                        driveDelay     <= 33868800; -- 44100 * 0x300; -- 100%
                        driveDelayNext <= 33868800; -- 44100 * 0x300; -- 100%
                     end if;
                  end if;
               end if;
            end if;
            
         end if; -- ce
      end if;
   end process;
   
   
   -- todo: readOnDisk 
   -- todo: readSubchannel 
   -- todo : seekOK
   
   -- data processing
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then

         FifoData_Wr  <= '0';

         if (reset = '1') then
            
            sectorFetchState     <= SFETCH_IDLE;
            sectorProcessState   <= SPROC_IDLE;
            copyState            <= COPY_IDLE;
            trackNumberBCD       <= x"00";
            
         elsif (ce = '1') then
   
            case (sectorFetchState) is
            
               when SFETCH_IDLE =>
                  if (readOnDisk = '1') then
                     lastReadSector   <= readLBA;
                     positionInIndex  <= readLBA - startLBA;
                     sectorFetchState <= SFETCH_START;
                     fetchCount       <= 0;
                  end if;
                  
               when SFETCH_START =>
                  sectorFetchState <= SFETCH_FIRST;
                  if (positionInIndex = lbaCount) then
                     trackNumberBCD <= x"AA";
                  else
                     trackNumberBCD <= x"01"; -- todo
                  end if;
                  cd_addr <= std_logic_vector(to_unsigned(positionInIndex * (2352 / 4), 15)); -- todo: needs more bits for real CD
               
               when SFETCH_FIRST =>
                  sectorFetchState <= SFETCH_DATA;
                  cd_addr          <= std_logic_vector(unsigned(cd_addr) + 1);
               
               when SFETCH_DATA =>
                  cd_addr          <= std_logic_vector(unsigned(cd_addr) + 1);
                  fetchCount       <= fetchCount + 1;
                  sectorBuffer(fetchCount) <= cd_data;
                  if (fetchCount = 587) then
                     sectorFetchState  <= SFETCH_IDLE;
                  end if;
                  
            end case;
            
            procReadData <= sectorBuffer(procReadAddr);
            
            case (sectorProcessState) is
            
               when SPROC_IDLE =>
                  procReadAddr <= SECTOR_SYNC_SIZE / 4;
                  if (processDataSector = '1') then
                     sectorProcessState <= SPROC_READHEADER;
                     procReadAddr       <= procReadAddr + 1;
                     procCount          <= 0;
                  end if;
                  
               when SPROC_READHEADER =>
                  sectorProcessState <= SPROC_READSUBHEADER;
                  header <= procReadData;
                  
               when SPROC_READSUBHEADER => 
                  subheader <= procReadData;
                  sectorProcessState <= SPROC_START;
                  if (modeReg(6) = '1') then -- xa_enable
                     if (header(31 downto 24) = x"02") then
                        if (subheader(22) = '1') then -- realtime
                           if (subheader(18) = '1') then -- audio
                              -- todo : ProcessXAADPCMSector
                              sectorProcessState   <= SPROC_IDLE;
                           end if;
                        end if;
                     end if;
                  end if;
                  
               when SPROC_START =>
                  sectorProcessState <= SPROC_FIRST;
                  if (modeReg(5) = '1') then -- raw sector read
                     procReadAddr <= SECTOR_SYNC_SIZE / 4;
                     procSize <= (RAW_SECTOR_OUTPUT_SIZE) / 4;
                  else
                     procReadAddr <= (SECTOR_SYNC_SIZE + 12) / 4;
                     procSize <= (DATA_SECTOR_SIZE) / 4;
                     if (header(31 downto 24) /= x"02") then
                        sectorProcessState   <= SPROC_IDLE;
                     end if;
                  end if;
               
               when SPROC_FIRST =>
                  sectorProcessState <= SPROC_DATA;
                  procReadAddr <= procReadAddr + 1;
                  sectorBufferSizes(to_integer(writeSectorPointer)) <= procSize;
               
               when SPROC_DATA =>
                  procCount    <= procCount + 1;
                  procReadAddr <= procReadAddr + 1;
                  sectorBuffers(to_integer(writeSectorPointer))(procCount) <= procReadData;
                  if (procCount = (procSize - 1)) then
                     sectorProcessState  <= SPROC_IDLE;
                  end if;
                  
            end case;
            

            copyReadData <= sectorBuffers(to_integer(readSectorPointer))(copyReadAddr);
            case (copyState) is
            
               when COPY_IDLE =>
                  if (copyData = '1') then
                     copyState      <= COPY_FIRST;
                     copyCount      <= 0;
                     copyReadAddr   <= 0;
                     if (sectorBufferSizes(to_integer(readSectorPointer)) = 0) then
                        copySize <= RAW_SECTOR_OUTPUT_SIZE / 4;
                     else
                        copySize <= sectorBufferSizes(to_integer(readSectorPointer));
                     end if;
                  end if;
               
               when COPY_FIRST =>
                  copyState     <= COPY_DATA;
                  sectorBufferSizes(to_integer(writeSectorPointer)) <= procSize;
               
               when COPY_DATA =>
                  FifoData_Wr  <= '1';
                  case (copyByteCnt) is
                     when 0 => 
                        copyByteCnt <= 1; 
                        FifoData_Din <= copyReadData(7 downto 0);
                        
                     when 1 => 
                        copyByteCnt <= 2; 
                        FifoData_Din <= copyReadData(15 downto 8);
                        
                     when 2 => 
                        copyByteCnt  <= 3; 
                        FifoData_Din <= copyReadData(23 downto 16); 
                        copyReadAddr <= copyReadAddr + 1;
                        
                     when 3 => 
                        copyByteCnt  <= 0; 
                        FifoData_Din <= copyReadData(31 downto 24); 
                        copyCount    <= copyCount + 1;
                        if (copyCount = (copySize - 1)) then
                           copyState  <= COPY_CHECKPTR;
                           sectorBufferSizes(to_integer(readSectorPointer)) <= 0;
                        end if;
                     when others => null;
                  end case;
                
               when COPY_CHECKPTR =>
                  copyState <= COPY_IDLE;
                  if (sectorBufferSizes(to_integer(writeSectorPointer)) /= 0) then
                     -- todo: additional irq for missed sector
                  end if;
                 
            end case;
   
         end if; -- ce
      end if;
   end process;
   
   itestiso : entity work.testiso 
   port map
   (
      clk     => clk1x,
      address => cd_addr,
      data    => cd_data
   );

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
         variable fifoDataWrCnt     : unsigned(7 downto 0);
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
            driveAck_1 := driveAck or ackDrive or ackRead_valid;
            
            if (processDataSector = '1') then
               write(line_out, string'("WPTR: "));
               if (modeReg(5) = '1') then
                  write(line_out, string'("24"));
               else
                  write(line_out, string'("00"));
               end if;
               write(line_out, string'(" 000000"));
               write(line_out, to_hstring("00000" & writeSectorPointer));               
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            
            if (copyState = COPY_DATA and copyByteCnt = 0) then
               write(line_out, string'("DATA: "));
               write(line_out, to_hstring(fifoDataWrCnt));
               write(line_out, string'(" "));
               write(line_out, to_hstring(copyReadData));               
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
               fifoDataWrCnt := fifoDataWrCnt + 4;
            elsif (copyState = COPY_IDLE) then
               fifoDataWrCnt := (others => '0');
            end if;
            
            --if (dma_read = '1') then
            --   write(line_out, string'("DMAREAD: 00 000000"));
            --   write(line_out, to_hstring(dma_readdata));               
            --   writeline(outfile, line_out);
            --   newoutputCnt := newoutputCnt + 1;
            --end if; 
            
            
            outputCnt <= newoutputCnt;
           
         end loop;
         
      end process;
   
   end generate goutput;
   
   -- synthesis translate_on

end architecture;





