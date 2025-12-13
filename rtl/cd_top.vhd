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
      
      INSTANTSEEK          : in  std_logic;
      FORCECDSPEED         : in  std_logic_vector(2 downto 0);
      LIMITREADSPEED       : in  std_logic;
      hasCD                : in  std_logic;
      LIDopen              : in  std_logic;
      fastCD               : in  std_logic;
      testSeek             : in  std_logic;
      pauseOnCDSlow        : in  std_logic;
      region               : in  std_logic_vector(1 downto 0);
      region_out           : out std_logic_vector(1 downto 0);
      
      pauseCD              : out std_logic := '0';
      Pause_idle_cd        : out std_logic := '0';
      fullyIdle            : out std_logic;
      cdSlow               : out std_logic := '0';
      error                : out std_logic := '0';
      LBAdisplay           : out unsigned(19 downto 0);
      
      irqOut               : out std_logic := '0';
      
      spu_tick             : in  std_logic;
      cd_left              : out signed(15 downto 0) := (others => '0');
      cd_right             : out signed(15 downto 0) := (others => '0');
      
      mdec_idle            : in  std_logic;
      
      bus_addr             : in  unsigned(3 downto 0); 
      bus_dataWrite        : in  std_logic_vector(7 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(7 downto 0) := (others => '0');
      
      dma_read             : in  std_logic;
      dma_readdata         : out std_logic_vector(7 downto 0);
      
      cd_hps_req           : out std_logic := '0';
      cd_hps_lba           : out std_logic_vector(31 downto 0);
      cd_hps_lba_sim       : out std_logic_vector(31 downto 0) := (others => '0');
      cd_hps_ack           : in  std_logic;
      cd_hps_write         : in  std_logic;
      cd_hps_data          : in  std_logic_vector(15 downto 0);
         
      trackinfo_data       : in  std_logic_vector(31 downto 0);
      trackinfo_addr       : in  std_logic_vector(8 downto 0);
      trackinfo_write      : in  std_logic;
      resetFromCD          : out std_logic := '0';
         
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(13 downto 0);
      SS_wren              : in  std_logic;
      SS_rden              : in  std_logic;
      SS_DataRead          : out std_logic_vector(31 downto 0);
      SS_idle              : out std_logic
   );
end entity;

architecture arch of cd_top is
  
   constant RAW_SECTOR_SIZE         : integer := 2352;
   constant SECTOR_SYNC_SIZE        : integer := 12;
   constant RAW_SECTOR_OUTPUT_SIZE  : integer := RAW_SECTOR_SIZE - SECTOR_SYNC_SIZE;
   constant DATA_SECTOR_SIZE        : integer := 2048;
   constant PREGAPSIZE              : integer := 150;
   
   constant FRAMES_PER_SECOND       : integer := 75;
   constant FRAMES_PER_MINUTE       : integer := 75 * 60;
   constant LEAD_OUT_TRACK_NUMBER   : std_logic_vector(7 downto 0) := x"AA";
   
   constant READSPEED1X             : integer := 44100 * 16#300# / 75;
   constant READSPEED2X             : integer := 44100 * 16#300# / 150;
   constant READSPEED4X             : integer := 44100 * 16#300# / 300;
   constant READSPEED6X             : integer := 44100 * 16#300# / 450;
   constant READSPEED8X             : integer := 44100 * 16#300# / 600;
   
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
   signal cmd_unpause               : std_logic := '0';
   signal newCmd                    : std_logic_vector(7 downto 0);
   signal nextCmd                   : std_logic_vector(7 downto 0);
   
   signal pendingDriveIRQ           : std_logic_vector(4 downto 0);
   signal pendingDriveResponse      : std_logic_vector(7 downto 0);
   signal ackPendingIRQ             : std_logic := '0';
   signal ackPendingSector          : std_logic := '0';
   signal ackRead_valid             : std_logic := '0';
   signal irqTimeout                : integer range 0 to 10000 := 0;
            
   signal FifoParam_reset           : std_logic := '0';
   signal FifoParam_Din             : std_logic_vector(7 downto 0) := (others => '0');
   signal FifoParam_Wr              : std_logic := '0'; 
   signal FifoParam_NearFull         : std_logic := '0'; 
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
   signal workDelay                 : integer range 0 to 33554431;
   signal cmdAck                    : std_logic := '0';
   signal cmdIRQ                    : std_logic := '0';
   signal driveAck                  : std_logic := '0';
   signal getIDAck                  : std_logic := '0';
   signal startMotorCMD             : std_logic := '0';
   signal softReset                 : std_logic := '0';
   signal ackPendingIRQNext         : std_logic := '0';
   signal cmdResetXa                : std_logic := '0';
   signal updatePhysicalPosition    : std_logic := '0';
   signal muted                     : std_logic;
         
   signal setLocActive              : std_logic := '0';
   signal setLocReadStep            : integer range 0 to 5;
   signal setLocMinute              : unsigned(7 downto 0);
   signal setLocSecond              : unsigned(7 downto 0);
   signal setLocFrame               : unsigned(7 downto 0);         
   
   signal session                   : std_logic_vector(7 downto 0);
   signal fastForwardRate           : signed(7 downto 0);
   
   signal setFilterReadStep         : integer range 0 to 3;
   signal XaFilterFile              : std_logic_vector(7 downto 0);
   signal XaFilterChannel           : std_logic_vector(7 downto 0);
   signal ClearXACurrentSet         : std_logic;
   
   signal XaCurrentFile             : std_logic_vector(7 downto 0);
   signal XaCurrentChannel          : std_logic_vector(7 downto 0);
   signal XaCurrentSet              : std_logic;
   
   signal lastreportCDDA            : std_logic_vector(4 downto 0);
   signal CDDA_outcnt               : integer range 0 to 8;
      
   signal seekOnDiskCmd             : std_logic := '0';
   signal stop_afterseek            : std_logic := '0';
   signal setMode                   : std_logic := '0';
   signal newMode                   : std_logic_vector(7 downto 0);
   signal readSN                    : std_logic := '0';
   signal play                      : std_logic := '0';
   signal playTrack                 : std_logic := '0';
   signal setSession                : std_logic := '0';
   signal cmdStartMotor             : std_logic := '0';
   signal cmdStop                   : std_logic := '0';
   signal drive_stop                : std_logic := '0';
   signal shell_close               : std_logic := '0';
   
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
      DRIVE_CHANGESESSION,
      DRIVE_OPENING
	);
   signal driveState                : tdrivestate := DRIVE_IDLE;
         
   signal internalStatus            : std_logic_vector(7 downto 0);
   signal internalStatus_1          : std_logic_vector(7 downto 0);
   signal modeReg                   : std_logic_vector(7 downto 0);
         
   signal driveBusy                 : std_logic;
   signal driveDelay                : integer range 0 to 134217727;
   signal driveDelayNext            : integer range 0 to 134217727;
   signal driveREADSPEED            : integer range 0 to 134217727;
   
   signal allow_speedhack           : std_logic := '0';
   
   signal handleDrive               : std_logic := '0';
   signal startMotor                : std_logic := '0';
   signal startMotorReset           : std_logic := '0';
   signal ackDrive                  : std_logic := '0';
   signal ackDriveEnd               : std_logic := '0';
   signal seekOnDiskDrive           : std_logic := '0';
   signal seekOnDiskPlay            : std_logic := '0';
   signal ackRead                   : std_logic := '0';
   signal calcSeekTime              : std_logic := '0';
   signal addSeekTime               : std_logic := '0';
   signal limitDelayTime            : std_logic := '0';
         
   signal currentLBA                : integer range 0 to 524287;        
   signal physicalLBA               : integer range 0 to 524287;        
   signal seekLBA                   : integer range 0 to 524287; 
   signal playLBA                   : integer range 0 to 524287; 
   signal diffLBA                   : integer range 0 to 524287; 
   signal seekTimeMul               : integer range 0 to 127; 
   signal currentTrackBCD           : std_logic_vector(7 downto 0);
   signal nextTrack                 : std_logic_vector(7 downto 0);
   
   signal readAfterSeek             : std_logic := '0';
   signal playAfterSeek             : std_logic := '0';
   signal lastSectorHeaderValid     : std_logic := '0'; 
   
   signal errorResponseDrive_new    : std_logic := '0'; 
   signal errorResponseDrive_error  : std_logic_vector(7 downto 0);
   signal errorResponseDrive_reason : std_logic_vector(7 downto 0);

   -- exchange with data part
   signal readOnDisk                : std_logic := '0';   
   signal readOnDisk_buffer         : std_logic := '0';   
   signal readLBA                   : integer range 0 to 524287; 
   signal readLBA_buffer            : integer range 0 to 524287; 
   signal trackNumberBCD            : unsigned(7 downto 0) := x"00";
   signal trackNumber               : std_logic_vector(6 downto 0);
   
   signal copyData                  : std_logic := '0';  
   signal seekOK                    : std_logic := '1';
   signal afterSeek                 : std_logic := '0'; 
   signal startReading              : std_logic := '0';  
   signal startPlaying              : std_logic := '0';  
   signal processDataSector         : std_logic := '0';  
   signal processCDDASector         : std_logic := '0';  
   signal processSeekHeader         : std_logic := '0';  
   signal clearSectorBuffers        : std_logic := '0';  
   signal writeSectorPointer        : unsigned(2 downto 0) := (others => '0');
   signal readSectorPointer         : unsigned(2 downto 0) := (others => '0');
   
   type tphysicalUpdateState is
   (
      PHYSICALUPDATE_IDLE,
      PHYSICALUPDATE_START,
      PHYSICALUPDATE_CHECK,
      PHYSICALUPDATE_CALC1,
      PHYSICALUPDATE_CALC2,
      PHYSICALUPDATE_CALCDONE,
      PHYSICALUPDATE_READSUBCHANNEL
   );
   signal physicalUpdateState : tphysicalUpdateState := PHYSICALUPDATE_IDLE;
   
   signal phy_base                 : integer range 0 to 524287;
   signal phy_oldOffset            : integer range 0 to 31;
   signal phy_newOffset            : integer range 0 to 31;
   
   -- sector fetch
   type tsectorFetch is
   (
      SFETCH_IDLE,
      SFETCH_DELAY,
      SFETCH_START,
      SFETCH_HPSACK,
      SFETCH_HPSWORD,
      SFETCH_HPSDATA
   );
   signal sectorFetchState          : tsectorFetch := SFETCH_IDLE;
   
   signal sectorBuffer_addrA        : std_logic_vector(9 downto 0) := (others => '0');
   signal sectorBuffer_DataA        : std_logic_vector(31 downto 0) := (others => '0');
   signal sectorBuffer_wrenA        : std_logic;
   signal sectorBuffer_addrB        : std_logic_vector(9 downto 0);
   signal sectorBuffer_DataB        : std_logic_vector(31 downto 0);
      
   signal positionInIndex           : integer range -524288 to 524287; 
   signal lastReadSector            : integer range 0 to 524287; 
   signal subchannelSector          : integer range 0 to 524287; 
   signal fetchCount                : integer range 0 to 588;
   signal fetchDelay                : integer range 0 to 15;
      
   signal slow_timeout              : integer range 0 to 16777215 := 0;
   signal slow_block                : std_logic := '0';
   
   signal peakvolumeL               : signed(15 downto 0);
   signal peakvolumeR               : signed(15 downto 0);
      
   -- read subchannel
   type treadSubchannelState is
   (
      SSUB_IDLE,
      SSUB_START,
      SSUB_CALCPOS,
      SSUB_CALCSECTOR
   );
   signal readSubchannelState       : treadSubchannelState := SSUB_IDLE;
   
   signal readSubchannel            : std_logic := '0';
   signal triggerUpdateSubchannel   : std_logic := '0';
   signal UpdateSubchannel          : std_logic := '0';
   signal UpdateSubchannelDone      : std_logic := '0';
   signal subchannelLBAwork         : integer range 0 to 524287;  
   signal sub_SecondsHigh           : unsigned(3 downto 0); 
   signal sub_SecondsLow            : unsigned(3 downto 0); 
   signal sub_MinutesHigh           : unsigned(3 downto 0); 
   signal sub_MinutesLow            : unsigned(3 downto 0);
      
   -- sector process
   type tsectorProcess is
   (
      SPROC_IDLE,
      SPROC_SEEKREADHEADER,
      SPROC_SEEKREADSUBHEADER,
      SPROC_READHEADER,
      SPROC_READSUBHEADER,
      SPROC_START,
      SPROC_FIRST,
      SPROC_DATA,
      SPROC_XA_FIRST,
      SPROC_XA,
      SPROC_CDDAFIRST,
      SPROC_CDDA
   );
   signal sectorProcessState        : tsectorProcess := SPROC_IDLE;
   
   type tsectorBufferSizes is array(0 to 7) of integer range 0 to 588;
   signal sectorBufferSizes         : tsectorBufferSizes;
   
   signal sectorBufferFilled        : std_logic := '0';
   
   signal sectorBuffers_addrA       : std_logic_vector(12 downto 0) := (others => '0');
   signal sectorBuffers_DataA       : std_logic_vector(31 downto 0) := (others => '0');
   signal sectorBuffers_wrenA       : std_logic;
   signal sectorBuffers_addrB       : std_logic_vector(12 downto 0);
   signal sectorBuffers_DataB       : std_logic_vector(31 downto 0);
   
   signal procCount                 : integer range 0 to 588;
   signal procSize                  : integer range 0 to 588;
   signal procReadAddr              : integer range 0 to 588;
   signal header                    : std_logic_vector(31 downto 0);
   signal subheader                 : std_logic_vector(31 downto 0);
   signal headerIsData              : std_logic;
   signal headerDataCheck           : std_logic;
   signal headerDataSector          : std_logic;
   
   type tsubdata is array(0 to 11) of std_logic_vector(7 downto 0);
   signal subdata                   : tsubdata;
   signal nextSubdata               : tsubdata;
   
   signal XA_addr                   : integer range 0 to 587;
   signal XA_data                   : std_logic_vector(31 downto 0);
   signal XA_write                  : std_logic := '0';
   signal XA_start                  : std_logic := '0';
   signal XA_reset                  : std_logic := '0';
   signal XA_EOF                    : std_logic := '0';
   signal xa_muted                  : std_logic;
   signal Xa_playing                : std_logic;
   signal cdaudio_left              : signed(15 downto 0);
   signal cdaudio_right             : signed(15 downto 0);
   
   signal CDDA_write                : std_logic;
   signal CDDA_data                 : std_logic_vector(31 downto 0);
   
   -- copy data
   type tCopyState is
	(
		COPY_IDLE,
		COPY_FIRST,
		COPY_DATA
	);
   signal copyState                 : tCopyState := COPY_IDLE;

   signal copyCount                 : integer range 0 to 588;
   signal copyByteCnt               : integer range 0 to 3;
   signal copySize                  : integer range 0 to 588;    
   signal copyReadAddr              : integer range 0 to 588;
   
   signal copySectorPointer         : unsigned(2 downto 0) := (others => '0');
   signal ackRead_data              : std_logic := '0';
      
   -- cd audio volume
   signal cdvol_next00              : std_logic_vector(7 downto 0) := (others => '0');
   signal cdvol_next01              : std_logic_vector(7 downto 0) := (others => '0');
   signal cdvol_next10              : std_logic_vector(7 downto 0) := (others => '0');
   signal cdvol_next11              : std_logic_vector(7 downto 0) := (others => '0');
   signal cdvol_00                  : std_logic_vector(7 downto 0) := (others => '0');
   signal cdvol_01                  : std_logic_vector(7 downto 0) := (others => '0');
   signal cdvol_10                  : std_logic_vector(7 downto 0) := (others => '0');
   signal cdvol_11                  : std_logic_vector(7 downto 0) := (others => '0');
   
   signal cd_volume_step            : integer range 0 to 7;
   signal soundmulresult            : signed(16 downto 0) := (others => '0');
   signal soundmul1                 : signed(15 downto 0) := (others => '0');
   signal soundmul2                 : unsigned(7 downto 0) := (others => '0');
   signal soundsum                  : signed(17 downto 0) := (others => '0');
      
   -- track infos
   --signal totalLBAs                 : integer range 0 to 524287; 
   --signal trackcount                : std_logic_vector(7 downto 0);
   signal trackcountBCD             : std_logic_vector(7 downto 0);
   signal totalSecondsBCD           : std_logic_vector(7 downto 0);
   signal totalMinutesBCD           : std_logic_vector(7 downto 0);
   
   signal trackInfo_addrA           : std_logic_vector(6 downto 0) := (others => '0');
   signal trackInfo_DataA           : std_logic_vector(54 downto 0) := (others => '0');
   signal trackInfo_DataOutA        : std_logic_vector(54 downto 0) := (others => '0');
   signal trackInfo_wrenA           : std_logic;
   signal trackInfo_addrB           : std_logic_vector(6 downto 0) := (others => '0');
   signal trackInfo_DataOutB        : std_logic_vector(54 downto 0);
      
   signal startLBA                  : integer range 0 to 524287;
   signal endLBA                    : integer range 0 to 524287;
   signal minutesBCD                : std_logic_vector(7 downto 0);
   signal secondsBCD                : std_logic_vector(7 downto 0);
   signal isAudio                   : std_logic;
   
   signal isAudioCD                 : std_logic := '0';
   signal libcryptKey               : std_logic_vector(15 downto 0);
      
   type ttrackSearchState is
	(
		TRACKSEARCH_IDLE,
		TRACKSEARCH_READ,
      TRACKSEARCH_CHECK
	);
   signal trackSearchState          : ttrackSearchState := TRACKSEARCH_IDLE;

   signal newCDCounter              : unsigned(25 downto 0); -- ~2seconds
   signal newCD                     : std_logic := '0';
   signal newCD_1                   : std_logic := '0';

   -- savestates
   type t_ssarray is array(0 to 127) of std_logic_vector(31 downto 0);
   signal ss_in   : t_ssarray := (others => (others => '0'));
   signal ss_out  : t_ssarray := (others => (others => '0'));

   signal SS_rden_sectorbuffer   : std_logic;
   signal SS_rden_sectorbuffers  : std_logic;

   signal ss_idle_timeout        : integer range 0 to 7;
   
   signal ss_timeout             : unsigned(23 downto 0);

   -- debug
   -- synthesis translate_off
   type tsectorBuffer is array(0 to 587) of std_logic_vector(31 downto 0);
   type tsectorBuffers is array(0 to 7) of tsectorBuffer;
   signal sectorBuffers             : tsectorBuffers;
   -- synthesis translate_on   
      
begin 

   fullyIdle <= '1' when (cmd_busy = '0' and working = '0' and driveBusy = '0' and sectorFetchState = SFETCH_IDLE and sectorProcessState = SPROC_IDLE and copyState = COPY_IDLE) else '0';

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
   
   dma_readdata <= FifoData_Dout when (FifoData_Empty = '0') else (others => '0');
   
   LBAdisplay  <= to_unsigned(currentLBA, 20);
   
   ss_out(21)( 7 downto  0) <= CDROM_STATUS;
   ss_out(21)(12 downto  8) <= CDROM_IRQENA;
   ss_out(21)(20 downto 16) <= CDROM_IRQFLAG;
   ss_out(13)(28 downto 24) <= pendingDriveIRQ;
   ss_out(22)(17)           <= xa_muted;
   ss_out(23)( 7 downto  0) <= cdvol_next00;
   ss_out(23)(15 downto  8) <= cdvol_next01;
   ss_out(23)(23 downto 16) <= cdvol_next10;
   ss_out(23)(31 downto 24) <= cdvol_next11;
   ss_out(24)( 7 downto  0) <= cdvol_00;    
   ss_out(24)(15 downto  8) <= cdvol_01;    
   ss_out(24)(23 downto 16) <= cdvol_10;    
   ss_out(24)(31 downto 24) <= cdvol_11;    
   
   -- cpu interface
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         FifoData_reset    <= '0';
         FifoResponse_Rd   <= '0';
         FifoParam_Wr      <= '0';
      
         if (reset = '1') then
            
            FifoData_reset  <= '1';
            
            irqTimeout      <= 0;
            
            CDROM_STATUS    <= ss_in(21)(7 downto 0); -- x"18";
            CDROM_IRQENA    <= ss_in(21)(12 downto 8); -- (others => '0');
            CDROM_IRQFLAG   <= ss_in(21)(20 downto 16); -- (others => '0');
            pendingDriveIRQ <= ss_in(13)(28 downto 24); -- (others => '0');
            xa_muted        <= ss_in(22)(17); -- '0';
            
            cdvol_next00    <= ss_in(23)( 7 downto  0); -- x"80"
            cdvol_next01    <= ss_in(23)(15 downto  8); -- x"00"
            cdvol_next10    <= ss_in(23)(23 downto 16); -- x"00"
            cdvol_next11    <= ss_in(23)(31 downto 24); -- x"80"
            cdvol_00        <= ss_in(24)( 7 downto  0); -- x"80"
            cdvol_01        <= ss_in(24)(15 downto  8); -- x"00"
            cdvol_10        <= ss_in(24)(23 downto 16); -- x"00"
            cdvol_11        <= ss_in(24)(31 downto 24); -- x"80"
            
         elsif (ce = '1') then
         
            beginCommand      <= '0';
            irqOut            <= '0';
            ackRead_valid     <= '0';
            ackPendingIRQ     <= '0';
            ackPendingSector  <= '0';
            copyData          <= '0';

         
            CDROM_STATUS(2) <= '0';                      -- ADPBUSY XA-ADPCM fifo empty  (0=Empty) ;set when playing XA-ADPCM sound -> not used in duckstation
            CDROM_STATUS(3) <= FifoParam_Empty;          -- PRMEMPT Parameter fifo empty (1=Empty) ;triggered before writing 1st byte
            CDROM_STATUS(4) <= not FifoParam_NearFull;   -- PRMWRDY Parameter fifo full  (0=Full)  ;triggered after writing 16 bytes
            CDROM_STATUS(5) <= not FifoResponse_Empty;   -- RSLRRDY Response fifo empty  (0=Empty) ;triggered after reading LAST byte
            CDROM_STATUS(6) <= not FifoData_Empty;       -- DRQSTS  Data fifo empty      (0=Empty) ;triggered after reading LAST byte
            CDROM_STATUS(7) <= cmdPending;               -- BUSYSTS Command/parameter transmission busy  (1=Busy)  
         
            if (bus_write = '1') then
            
               if (bus_addr = x"0") then
                  CDROM_STATUS(1 downto 0) <= bus_dataWrite(1 downto 0);
               else
                  case (CDROM_STATUS(1 downto 0)) is
                     when "00" =>
                        case (bus_addr) is
                           when x"1" =>
                              beginCommand <= '1';
                              newCmd       <= bus_dataWrite;
                              
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
                              if (bus_dataWrite(6) = '1') then
                                 --todo: clear param fifo
                              end if;
                           
                           when others => null;
                        end case;
                     
                     when "10" =>
                        case (bus_addr) is
                           when x"1" => -- sound map coding info write -> do nothing
                           when x"2" => cdvol_next00 <= bus_dataWrite;
                           when x"3" => cdvol_next01 <= bus_dataWrite;
                           when others => null;
                        end case;
                        
                     when "11" =>
                        case (bus_addr) is
                           when x"1" => cdvol_next11 <= bus_dataWrite;
                           when x"2" => cdvol_next10 <= bus_dataWrite;
                           when x"3" => 
                              if (bus_dataWrite(5) = '1') then
                                 cdvol_00 <= cdvol_next00;
                                 cdvol_01 <= cdvol_next01;
                                 cdvol_10 <= cdvol_next10;
                                 cdvol_11 <= cdvol_next11;
                              end if;
                              xa_muted <= bus_dataWrite(0);
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
            
            if (CDROM_IRQFLAG /= "00000") then
               irqTimeout <= 0;
            elsif (irqTimeout < 10000) then
               irqTimeout <= irqTimeout + 1;
            elsif (pendingDriveIRQ /= "00000" and ackPendingIRQ = '0' and ackPendingIRQNext = '0') then
               ackPendingIRQ   <= '1';
               if (pendingDriveIRQ = "00001") then
                  ackPendingSector <= '1';
               end if;
            end if;
            
            if (cmdAck = '1' or cmdIRQ = '1') then
               CDROM_IRQFLAG <= "00011";
               if (CDROM_IRQENA(1 downto 0) /= "00") then
                  irqOut <= '1';
               end if;
            end if;            

            if (driveAck = '1' or ackDrive = '1') then
               if (CDROM_IRQFLAG /= "00000") then
                  pendingDriveIRQ      <= "00010";
                  pendingDriveResponse <= internalStatus;
               else
                  CDROM_IRQFLAG <= "00010";
                  if (CDROM_IRQENA(1) = '1') then
                     irqOut <= '1';
                  end if;
               end if;
            end if;             

            if (ackDriveEnd = '1') then
               if (CDROM_IRQFLAG /= "00000") then
                  pendingDriveIRQ      <= "00100";
                  pendingDriveResponse <= internalStatus_1;
               else
                  CDROM_IRQFLAG <= "00100";
                  if (CDROM_IRQENA(2) = '1') then
                     irqOut <= '1';
                  end if;
               end if;
            end if;
            
            if (ackRead = '1' or ackRead_data = '1') then
               if (CDROM_IRQFLAG = "00001") then -- irq for sector still pending, sector missed
                  -- will be handled when next sector is fetched from cpu interface
               elsif (CDROM_IRQFLAG /= "00000") then -- store sector done if current irq is something else, so CPU will be notified later
                  pendingDriveIRQ      <= "00001";
                  pendingDriveResponse <= internalStatus;
               else
                  CDROM_IRQFLAG <= "00001";
                  if (CDROM_IRQENA(0) = '1') then
                     irqOut <= '1';
                  end if;
                  ackRead_valid <= '1';
               end if;
            end if;
            
            if (ackPendingIRQNext = '1') then
               CDROM_IRQFLAG   <= pendingDriveIRQ;
               pendingDriveIRQ <= (others => '0');
               if ((CDROM_IRQENA and pendingDriveIRQ) /= "00000") then
                  irqOut <= '1';
               end if;
            end if;
            
            if (getIDAck = '1' and (hasCD = '0' or isAudioCD = '1')) then -- no async here, working will halt in case irq is still pending
               CDROM_IRQFLAG <= "00101";
               if (CDROM_IRQENA(0) = '1' or CDROM_IRQENA(2) = '1') then
                  irqOut <= '1';
               end if;
            end if;
            if (getIDAck = '1' and (hasCD = '1' and isAudioCD = '0')) then -- no async here, working will halt in case irq is still pending
               CDROM_IRQFLAG <= "00010";
               if (CDROM_IRQENA(1) = '1') then
                  irqOut <= '1';
               end if;
            end if;   
               
            if (errorResponseNext_new = '1') then
               CDROM_IRQFLAG   <= "00101";
               pendingDriveIRQ <= (others => '0');
               if (CDROM_IRQENA(2) = '1' or CDROM_IRQENA(0) = '1') then
                  irqOut <= '1';
               end if;
            end if; 
            
            if (CDDA_outcnt = 8) then
               CDROM_IRQFLAG <= "00001";
               if (CDROM_IRQENA(0) = '1') then
                  irqOut <= '1';
               end if;
            end if;
            
            if (softReset = '1') then
               FifoData_reset <= '1';
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
      NearFull => FifoParam_NearFull,

      Dout     => FifoParam_Dout,    
      Rd       => FifoParam_Rd,      
      Empty    => FifoParam_Empty   
   );
   
   
   ss_out(18)(1)             <= cmdPending;   
   ss_out(18)(0)             <= cmd_busy;     
   ss_out(12)(16 downto  0)  <= std_logic_vector(to_unsigned(cmd_delay, 17)); 
   ss_out(13)(23 downto 16)  <= nextCmd;
   ss_out(18)(2)             <= working;      
   ss_out( 0)(31 downto  0)  <= std_logic_vector(to_unsigned(workDelay, 32));    
   ss_out(14)(15 downto  8)  <= workCommand;  
   ss_out(18)(7)             <= muted;  
   ss_out(18)(3)             <= setLocActive; 
   ss_out(14)(23 downto 16)  <= std_logic_vector(setLocMinute); 
   ss_out(14)(31 downto 24)  <= std_logic_vector(setLocSecond); 
   ss_out(15)( 7 downto  0)  <= std_logic_vector(setLocFrame);
   ss_out(17)( 7 downto  0)  <= session; 
   ss_out(15)(23 downto 16)  <= std_logic_vector(fastForwardRate); 
   ss_out(16)(23 downto 16)  <= XaFilterFile;
   ss_out(16)(31 downto 24)  <= XaFilterChannel;
   ss_out(25)(20 downto 16)  <= lastreportCDDA;
   
   -- command processing
   process(clk1x)
      variable paramCountNew   : integer range 0 to 6;
      variable applyNewcommand : std_logic;
   begin
      if (rising_edge(clk1x)) then
         
         FifoResponse_reset      <= '0';
         FifoResponse_Wr         <= '0';
         FifoParam_Rd            <= '0';
         FifoParam_reset         <= '0';
         
         cmdResetXa              <= '0';
      
         if (reset = '1') then
            
            FifoParam_reset         <= '1';
            FifoResponse_reset      <= '1';
            cmdPending              <= ss_in(18)(1); -- '0'
            cmd_busy                <= ss_in(18)(0); -- '0'
            cmd_delay               <= to_integer(unsigned(ss_in(12)(16 downto 0))); -- 0
            nextCmd                 <= ss_in(13)(23 downto 16); -- '0';
            fifoParamCount          <= 0;
            working                 <= ss_in(18)(2); -- '0'
            workDelay               <= to_integer(unsigned(ss_in(0)(31 downto 0))); -- 0
            workCommand             <= ss_in(14)(15 downto 8);
               
            muted                   <= ss_in(18)(7); -- '0'
            
            setLocActive            <= ss_in(18)(3); -- '0'
            setLocMinute            <= unsigned(ss_in(14)(23 downto 16));
            setLocSecond            <= unsigned(ss_in(14)(31 downto 24));
            setLocFrame             <= unsigned(ss_in(15)(7 downto 0));
            
            session                 <= ss_in(17)(7 downto 0); -- 0
            fastForwardRate         <= signed(ss_in(15)(23 downto 16)); -- 0
            
            XaFilterFile            <= ss_in(16)(23 downto 16);
            XaFilterChannel         <= ss_in(16)(31 downto 24);
            
            lastreportCDDA          <= ss_in(25)(20 downto 16); -- x"1F";
            CDDA_outcnt             <= 0;
            
         elsif (ce = '1') then
         
            handleCommand           <= '0';
            cmdAck                  <= '0';
            cmdIRQ                  <= '0';
            driveAck                <= '0';
            getIDAck                <= '0';
            softReset               <= '0';
            seekOnDiskCmd           <= '0';
            stop_afterseek          <= '0';
            setMode                 <= '0';
            readSN                  <= '0';
            play                    <= '0';
            setSession              <= '0';
            cmdStartMotor           <= '0';
            cmdStop                 <= '0';
            drive_stop              <= '0';
            startMotorCMD           <= '0';
            shell_close             <= '0';
            errorResponseCmd_new    <= '0';
            errorResponseNext_new   <= '0';
            ClearXACurrentSet       <= '0';
            updatePhysicalPosition  <= '0';
         
            -- receive new command request or decrease wait timer on pending command
            if (beginCommand = '1') then
            
               case (newCmd) is
                  when x"02"  => paramCountNew := 3; --Setloc
                  when x"0D"  => paramCountNew := 2; --SetFilter
                  when x"0E"  => paramCountNew := 1; --Setmode
                  when x"12"  => paramCountNew := 1; --SetSession
                  when x"14"  => paramCountNew := 1; --GetTD
                  when x"19"  => paramCountNew := 1; --Test
                  when x"1D"  => paramCountNew := 2; --GetQ
                  when x"1F"  => paramCountNew := 6; --VideoCD
                  when others => paramCountNew := 0;
               end case;
               
               -- if a second command is executed when a first is still pending depends on which commands they are according to duckstation
               -- so we use the heuristic from duckstation and extend it by the exceptions that don't work in duckstation
               -- until a better solution is found               
               applyNewcommand := '1';
               
               if (cmdPending = '1') then
                  if (newCmd = x"0E" and nextCmd = x"02") then applyNewcommand := '0'; end if; -- happens in "reel fishing" startup -> ignore second command
               end if;
               
               if (applyNewcommand = '1') then
                  
                  if (cmdPending = '1' and paramCount > paramCountNew) then
                     FifoParam_reset <= '1';
                  end if;
                  
                  working <= '0'; -- second response from reset will interfere with command (e.g. wipeout xl)
               
                  cmdPending <= '1';
                  cmd_busy   <= '1';
                  if (driveState = DRIVE_OPENING) then
                     cmd_delay  <= 15000 - 2;
                  else
                     cmd_delay  <= 25000 - 2;
                  end if;
                  if (newCmd = x"1C") then -- init
                     cmd_delay <= 120000 - 2;
                  end if;
      
                  nextCmd    <= newCmd;
                  paramCount <= paramCountNew;
                  
                  if (driveState = DRIVE_IDLE and internalStatus(1) = '1' and newCmd = x"11") then
                     updatePhysicalPosition <= '1';
                  end if;
                  
               end if;
         
            elsif (cmd_busy = '1') then
               if (CDROM_IRQFLAG /= "00000" or dma_read = '1') then
                  if (cmd_delay < 8192) then
                     cmd_delay <= 8192;
                  end if;
               else
                  if (cmd_delay > 0) then
                     if (cmd_delay < 16 or ((driveBusy = '0' or driveDelay > 100) and (working = '0' or workDelay > 100))) then
                        cmd_delay <= cmd_delay - 1;
                     end if;
                  else
                     handleCommand <= '1';
                     cmd_busy      <= '0';
                  end if;
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
               
                  if (FifoResponse_empty = '0' and nextCmd /= x"0F" and nextCmd /= x"10" and nextCmd /= x"11" and nextCmd /= x"13" and nextCmd /= x"14" and nextCmd /= x"19") then
                     FifoResponse_reset <= '1';
                  end if;
                  
                  if (nextCmd /= x"02" and nextCmd /= x"0D") then
                     FifoParam_reset <= '1';
                  end if;
                  
                  case (nextCmd) is
                     when x"00" => -- Sync
                        errorResponseCmd_new    <= '1';
                        errorResponseCmd_error  <= x"01";
                        errorResponseCmd_reason <= x"40";
                        cmdPending <= '0';
                        
                     when x"01" => -- Getstat
                        cmdAck         <= '1';
                        cmdPending     <= '0';
                        if (hasCD = '1' and driveState /= DRIVE_OPENING) then
                           shell_close <= '1';
                        end if;
                        
                     when x"02" => -- Setloc
                        setLocReadStep <= 5;
                        setLocActive   <= '1';
                        cmdAck         <= '1';
                        cmdPending     <= '0';
                        
                     when x"03" => -- play
                        cmdPending <= '0';
                        if (hasCD = '0') then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"80";
                        else
                        
                           playTrack <= '0';
                           nextTrack <= x"00";
                           if (FifoParam_Empty = '0') then
                              playLBA   <= to_integer(unsigned(trackInfo_DataOutA(18 downto 0))) + PREGAPSIZE;
                              playTrack <= '1';
                              nextTrack <= FifoParam_Dout;
                           end if;
                           
                           --playLBA   <= to_integer(unsigned(trackInfo_DataOutA(18 downto 0))) + PREGAPSIZE; -- debug test!
                           --playTrack <= '1'; -- debug test!
                           
                           cmdAck          <= '1';
                           fastForwardRate <= (others => '0');
                           
                           --fastForwardRate <= to_signed(-4, 8); -- debug test!
                           
                           if ((FifoParam_Empty = '1' or FifoParam_Dout = x"00") and (setLocActive = '0' or seekLBA = lastReadSector) and (driveState = DRIVE_PLAYING or ((driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or driveState = DRIVE_SEEKIMPLICIT) and playAfterSeek = '1'))) then
                              playLBA <= currentLBA;
                           else
                              play           <= '1';
                              lastreportCDDA <= (others => '1');
							  if (FifoParam_Empty = '1' or FifoParam_Dout = x"00") then
							     playLBA <= currentLBA;
                              end if;
                           end if; 
                        end if;
                        
                     when x"04" => -- forward
                        if (driveState /= DRIVE_PLAYING) then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"80";
                        else
                           if (fastForwardRate < 0) then
                              fastForwardRate <= to_signed(4, 8);
                           elsif (fastForwardRate < 12) then
                              fastForwardRate <= fastForwardRate + 4;
                           end if;
                           cmdAck      <= '1';
                           cmdPending  <= '0';
                        end if;
                        
                     when x"05" => -- backward
                        if (driveState /= DRIVE_PLAYING) then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"80";
                        else
                           if (fastForwardRate > 0) then
                              fastForwardRate <= to_signed(-4, 8);
                           elsif (fastForwardRate > -12) then
                              fastForwardRate <= fastForwardRate - 4;
                           end if;
                           cmdAck      <= '1';
                           cmdPending  <= '0';
                        end if;
                        
                     --when "06" => readN at readS 0x1B
                     
                     when x"07" => -- MotorOn
                        cmdPending  <= '0';
                        if (internalStatus(1) = '1') then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"20";
                        else
                           cmdAck      <= '1';
                           if (working = '0') then
                              working     <= '1';
                              workDelay   <= 400000 - 2;
                              workCommand <= nextCmd;
                              if (hasCD = '1') then
                                 cmdStartMotor <= '1';
                              end if;
                           end if;
                        end if;
                        
                     when x"08" => -- Stop
                        cmdAck      <= '1';
                        cmdPending  <= '0';
                        if (internalStatus(1) = '1') then
                           if (modeReg(7) = '1') then
                              workDelay   <= 25000000 - 2;
                           else
                              workDelay   <= 13000000 - 2;
                           end if;
                        else
                           workDelay   <= 7000 - 2;
                        end if;
                        working     <= '1';
                        workCommand <= nextCmd;
                        cmdStop     <= '1';
                        
                     when x"09" => -- pause
						-- Reject PAUSE while still seeking (first sector not delivered)
						if (driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or ((driveState = DRIVE_READING or driveState = DRIVE_PLAYING) and internalStatus(6) = '1')) then	  
                           -- Return NOT_READY (0x80)
						   cmdPending              <= '0';
						   errorResponseCmd_new    <= '1';	
						   errorResponseCmd_error  <= x"01"; -- STAT_ERROR
                           errorResponseCmd_reason <= x"80"; -- NOT_READY
                        else
						   cmdAck      <= '1';
                           cmdPending  <= '0';
                           working     <= '1';
                           workDelay   <= 7000 - 2;
                           workCommand <= nextCmd;
                           cmdResetXa  <= '1';
                           if (driveState = DRIVE_READING or driveState = DRIVE_PLAYING) then
                              -- todo: should this be swapped between single speed and double speed? DuckStation has double speed longer and psx spx doc has single speed being longer
                              if (modeReg(7) = '1') then
                                 workDelay  <= 2157295 + driveDelay; -- value from psx spx doc
                              else
                                 workDelay  <= 1066874 + driveDelay; -- value from psx spx doc
                              end if;
                           end if;
                           if (driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or driveState = DRIVE_SEEKIMPLICIT) then
                              -- todo: complete seek?
                              stop_afterseek <= '1';
                           else
                              drive_stop <= '1';
                           end if;
					    end if;
                     
                     when x"0A" => -- reset
                        if (working = '1' and workCommand = x"0A") then
                           cmdPending <= '0';
                        else
                           --todo
                           --if (driveState == DRIVESTATE::SEEKLOGICAL || driveState == DRIVESTATE::SEEKPHYSICAL || driveState == DRIVESTATE::SEEKIMPLICIT)
                           --{
                           --   updatePositionWhileSeeking();
                           --}
                           cmdAck      <= '1';
                           softReset   <= '1';
                           working     <= '1';
                           workDelay   <= workDelay + 399999; -- cannot ignore old workdelay, otherwise reset after pause is too fast(e.g. GTA PAL)
                           workCommand <= nextCmd;
                           -- call here second time, so response has new values after reset?
                           cmd_delay   <= 24999 - 2;
                           cmd_busy    <= '1';
                        end if;
                     
                     when x"0B" => -- mute
                        muted       <= '1';
                        cmdAck      <= '1';
                        cmdPending  <= '0';
                        
                     when x"0C" => -- demute
                        muted       <= '0';
                        cmdAck      <= '1';
                        cmdPending  <= '0';
                        
                     when x"0D" => -- setfilter
                        setFilterReadStep <= 3;
                        ClearXACurrentSet <= '1';
                        cmdAck            <= '1';
                        cmdPending        <= '0';
                        
                     when x"0E" => -- setmode
                        setMode      <= '1';
                        newMode      <= FifoParam_Dout;
                        cmdAck       <= '1';
                        cmdPending   <= '0';
                     
                     when x"0F" => -- getparam
                        cmdPending  <= '0';
                        cmdIRQ      <= '1';
                        
                     when x"10" => -- GetLocL
                        cmdPending        <= '0';
                        if (lastSectorHeaderValid = '0') then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"80";
                        else
                           -- todo: update position?
                           cmdIRQ            <= '1';
                        end if;
                        
                     when x"11" => -- GetLocP
                        cmdPending        <= '0';
                        if (hasCD = '0') then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"80";
                        else
                           -- todo: update position?
                           cmdIRQ            <= '1';
                        end if;
                        
                     when x"12" => -- SetSession
                        cmdPending     <= '0';
                        if (hasCD = '0' or driveState = DRIVE_READING or driveState = DRIVE_PLAYING) then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"80";
                        else
                           session    <= FifoParam_Dout;
                           setSession <= '1';
                           cmdAck     <= '1';
                        end if;
                        
                     when x"13" => -- GetTN
                        cmdPending     <= '0';
                        if (hasCD = '0') then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"80";
                        else
                           cmdIRQ         <= '1';
                        end if;
                        
                     when x"14" => -- GetTD
                        cmdPending   <= '0';
                        if (hasCD = '0') then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"80";
                        elsif (unsigned(FifoParam_Dout) > unsigned(trackcountBCD)) then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"10";
                        else
                           cmdIRQ         <= '1';
                        end if;
                        
                     when x"15" | x"16" => -- SeekL/SeekP
                        --todo: if seeking, update position?
                        cmdAck                <= '1';
                        cmdPending            <= '0';
                        seekOnDiskCmd         <= '1';
                        setLocActive          <= '0';
                        cmdResetXa            <= '1';
                        
                     when x"17" | x"18" => -- SetClock/GetClock
                        cmdPending <= '0';
                        errorResponseCmd_new    <= '1';
                        errorResponseCmd_error  <= x"01";
                        errorResponseCmd_reason <= x"40";
                        
                     when x"19" => -- test
                        cmdPending     <= '0';
                        if (FifoParam_Dout = x"04" or FifoParam_Dout = x"05" or FifoParam_Dout = x"20" or FifoParam_Dout = x"22") then
                           cmdIRQ <= '1';
                        else
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"40";
                        end if;
                        
                     when x"1A" => -- getID
                        cmdPending     <= '0';
                        if (hasCD = '0') then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"80";
                        else
                           cmdAck      <= '1';
                           working     <= '1';
                           workDelay   <= 33867 - 2;
                           workCommand <= nextCmd;
                           -- if (driveState == DRIVESTATE::SPINNINGUP && driveBusy) workDelay += driveDelay; -- todo: required?
                        end if;
                        
                     when x"06" | x"1B" => -- ReadN/ReadS
                        cmdPending <= '0';
                        if (hasCD = '0') then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"80";
                        elsif (isAudioCD = '1' and modeReg(0) = '0') then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"40";
                        else
                           -- todo: missing checks
                           cmdAck <= '1';
                           
                           if ((setLocActive = '0' or seekLBA = lastReadSector) and (driveState = DRIVE_READING or ((driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or driveState = DRIVE_SEEKIMPLICIT) and readAfterSeek = '1'))) then
                              setLocActive <= '0';
                           else
                              readSN <= '1';
                           end if;
                        end if;
                        
                     when x"1C" => -- Init
                        cmdPending <= '0';
                        errorResponseCmd_new    <= '1';
                        errorResponseCmd_error  <= x"01";
                        errorResponseCmd_reason <= x"40";
                        
                     when x"1D" => -- GetQ
                        cmdPending <= '0';
                        errorResponseCmd_new    <= '1';
                        errorResponseCmd_error  <= x"01";
                        errorResponseCmd_reason <= x"40";
                        
                     when x"1E" => -- ReadTOC
                        cmdPending <= '0';
                        if (hasCD = '0') then
                           errorResponseCmd_new    <= '1';
                           errorResponseCmd_error  <= x"01";
                           errorResponseCmd_reason <= x"80";
                        else
                           cmdAck      <= '1';
                           working     <= '1';
                           workDelay   <= 16934400 - 2;
                           workCommand <= nextCmd;
                        end if;
                     
                     when x"1F" => -- VideoCD
                        cmdPending <= '0';
                        errorResponseCmd_new    <= '1';
                        errorResponseCmd_error  <= x"01";
                        errorResponseCmd_reason <= x"40";
                     
                     when others =>
                        errorResponseCmd_new    <= '1';
                        errorResponseCmd_error  <= x"01";
                        errorResponseCmd_reason <= x"40";
                        cmdPending <= '0';
                        
                  end case;
                  
               end if;
            elsif (working = '1') then -- second processing of recurring commands
               if (workDelay > 0) then
                  workDelay <= workDelay - 1;
                  if (workCommand = x"1A") then -- GetID
                     -- todo: do region check here...but why?
                     if (workDelay = 10) then FifoResponse_reset <= '1'; end if; 
                     if (workDelay = 9) then 
                        FifoResponse_Wr <= '1'; 
                        FifoResponse_Din <= internalStatus; 
                        if (hasCD = '0')     then FifoResponse_Din(3) <= '1'; end if; 
                        if (hasCD = '1')     then FifoResponse_Din(1) <= '1'; end if; -- from start motor
                        if (isAudioCD = '1') then FifoResponse_Din(3) <= '1'; end if; 
                     end if;
                     if (workDelay = 8) then
                        FifoResponse_Wr <= '1'; 
                        FifoResponse_Din <= x"00";
                        if (hasCD = '0')     then FifoResponse_Din(6) <= '1'; end if; 
                        if (isAudioCD = '1') then FifoResponse_Din(7) <= '1'; FifoResponse_Din(4) <= '1'; end if; 
                     end if;
                     if (workDelay = 7) then FifoResponse_Wr <= '1'; FifoResponse_Din <= x"20"; end if; -- ? 
                     if (workDelay = 6) then FifoResponse_Wr <= '1'; FifoResponse_Din <= x"00"; end if; -- ? 
                     if (workDelay = 5) then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('S')), 8)); end if;
                     if (workDelay = 4) then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('C')), 8)); end if; 
                     if (workDelay = 3) then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('E')), 8)); end if; 
                     if (region = "00") then -- ntsc-u
                        if (workDelay = 2) then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('A')), 8)); end if; 
                     elsif (region = "01") then -- ntsc-j
                        if (workDelay = 2) then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('I')), 8)); end if; 
                     elsif (region = "10") then -- pal
                        if (workDelay = 2) then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('E')), 8)); end if; 
                     end if;
                  end if;
               else
                  working <= '0';
                  if (workCommand = x"1A") then -- GetID
                     if (hasCD = '1') then
                        startMotorCMD <= '1';
                     end if;
                     getIDAck <= '1';
                  else
                     driveAck <= '1';
                  end if;
               end if;
            elsif (workDelay > 0) then 
               workDelay <= workDelay - 1;
            end if;
            
            -- don't end work command if last command isn't processed
            if (workDelay = 11 and CDROM_IRQFLAG /= "00000") then workDelay <= 11; end if; 
            
            if (seekOnDiskCmd = '1' or seekOnDiskDrive = '1') then
               setLocActive <= '0';
            end if;
            
            -- processing of commands that take several parameters
            
            -- setLoc
            if (setLocReadStep > 0) then
               setLocReadStep <= setLocReadStep - 1;
               case (setLocReadStep) is
                  when 5 => 
                     setLocMinute <= unsigned(FifoParam_Dout(7 downto 4)) * 10 + unsigned(FifoParam_Dout(3 downto 0));
                     FifoParam_Rd <= '1';
                  when 3 => 
                     setLocSecond <= unsigned(FifoParam_Dout(7 downto 4)) * 10 + unsigned(FifoParam_Dout(3 downto 0));
                     FifoParam_Rd <= '1';
                  when 1 => 
                     setLocFrame     <= unsigned(FifoParam_Dout(7 downto 4)) * 10 + unsigned(FifoParam_Dout(3 downto 0));
                     FifoParam_reset <= '1';
                  when others => null;
               end case;
            end if;
            
            -- setFilter
            if (setFilterReadStep > 0) then
               setFilterReadStep <= setFilterReadStep - 1;
               case (setFilterReadStep) is
                  when 3 => 
                     XaFilterFile <= FifoParam_Dout;
                     FifoParam_Rd <= '1';
                  when 1 => 
                     XaFilterChannel <= FifoParam_Dout;
                     FifoParam_reset <= '1';
                  when others => null;
               end case;
            end if;
            
            -- responses
            if (cmdAck = '1' or ackRead_valid = '1') then
               FifoResponse_Din <= internalStatus;
               FifoResponse_Wr  <= '1';
            end if;
            
            if (driveAck = '1' or ackDrive = '1' or ackDriveEnd = '1') then
               if (CDROM_IRQFLAG = "00000") then
                  if (ackDriveEnd = '1') then
                     FifoResponse_Din <= internalStatus_1;
                  else
                     FifoResponse_Din <= internalStatus;
                  end if;
                  FifoResponse_Wr  <= '1';
               end if;
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

            ackPendingIRQNext <= ackPendingIRQ;
            if (ackPendingIRQ = '1') then
               FifoResponse_reset <= '1';
            end if;
            if (ackPendingIRQNext = '1') then
               FifoResponse_Din  <= pendingDriveResponse;
               FifoResponse_Wr   <= '1';
            end if;
            
            -- long getparam response
            if (nextCmd = x"0F") then
               if (cmd_delay = 6 and FifoResponse_empty = '0') then 
                  FifoResponse_reset <= '1'; 
               end if;
               if (cmd_delay = 5)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= internalStatus; end if;
               if (cmd_delay = 4)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= modeReg; end if;
               if (cmd_delay = 3)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= x"00"; end if;
               if (cmd_delay = 2)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= XaFilterFile; end if;
               if (cmd_delay = 1)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= XaFilterChannel; end if;
            end if;
            
            -- long GetLocL response
            if (nextCmd = x"10") then
               if (cmd_delay = 9 and FifoResponse_empty = '0') then 
                  FifoResponse_reset <= '1'; 
               end if;
               if (cmd_delay = 8 and lastSectorHeaderValid = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= header( 7 downto  0); end if;
               if (cmd_delay = 7 and lastSectorHeaderValid = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= header(15 downto  8); end if;
               if (cmd_delay = 6 and lastSectorHeaderValid = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= header(23 downto 16); end if;
               if (cmd_delay = 5 and lastSectorHeaderValid = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= header(31 downto 24); end if;
               if (cmd_delay = 4 and lastSectorHeaderValid = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= subheader( 7 downto  0); end if;
               if (cmd_delay = 3 and lastSectorHeaderValid = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= subheader(15 downto  8); end if;
               if (cmd_delay = 2 and lastSectorHeaderValid = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= subheader(23 downto 16); end if;
               if (cmd_delay = 1 and lastSectorHeaderValid = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= subheader(31 downto 24); end if;
            end if;
            
            -- long GetLocP response
            if (nextCmd = x"11") then
               if (cmd_delay = 9 and FifoResponse_empty = '0') then 
                  FifoResponse_reset <= '1'; 
               end if;
               if (cmd_delay = 8 and hasCD = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= subdata(1); end if;
               if (cmd_delay = 7 and hasCD = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= subdata(2); end if;
               if (cmd_delay = 6 and hasCD = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= subdata(3); end if;
               if (cmd_delay = 5 and hasCD = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= subdata(4); end if;
               if (cmd_delay = 4 and hasCD = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= subdata(5); end if;
               if (cmd_delay = 3 and hasCD = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= subdata(7); end if;
               if (cmd_delay = 2 and hasCD = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= subdata(8); end if;
               if (cmd_delay = 1 and hasCD = '1')  then FifoResponse_Wr <= '1'; FifoResponse_Din <= subdata(9); end if;
            end if;
            
            -- long GetTN response
            if (nextCmd = x"13") then
               if (cmd_delay = 4 and FifoResponse_empty = '0') then 
                  FifoResponse_reset <= '1'; 
               end if;
               if (cmd_delay = 3 and hasCD = '1') then FifoResponse_Wr <= '1'; FifoResponse_Din <= internalStatus; end if;
               if (cmd_delay = 2 and hasCD = '1') then FifoResponse_Wr <= '1'; FifoResponse_Din <= x"01"; end if; -- todo:  first track number always 1?
               if (cmd_delay = 1 and hasCD = '1') then FifoResponse_Wr <= '1'; FifoResponse_Din <= trackcountBCD; end if;
            end if;
            
            -- long GetTD response
            
            if (nextCmd = x"14") then
               if (cmd_delay = 4 and FifoResponse_empty = '0') then 
                  FifoResponse_reset <= '1'; 
               end if;
               if (FifoParam_Dout = x"00") then -- track 0 -> total size of CD
                  if (cmd_delay = 3 and hasCD = '1') then FifoResponse_Wr <= '1'; FifoResponse_Din <= internalStatus; end if;
                  if (cmd_delay = 2 and hasCD = '1') then FifoResponse_Wr <= '1'; FifoResponse_Din <= totalMinutesBCD; end if;
                  if (cmd_delay = 1 and hasCD = '1') then FifoResponse_Wr <= '1'; FifoResponse_Din <= totalSecondsBCD; end if;
               elsif (FifoParam_Dout <= trackcountBCD) then
                  if (cmd_delay = 3 and hasCD = '1') then FifoResponse_Wr <= '1'; FifoResponse_Din <= internalStatus; end if;
                  if (cmd_delay = 2 and hasCD = '1') then FifoResponse_Wr <= '1'; FifoResponse_Din <= minutesBCD; end if;
                  if (cmd_delay = 1 and hasCD = '1') then FifoResponse_Wr <= '1'; FifoResponse_Din <= secondsBCD; end if;
               end if;
            end if;

            -- long test response
            if (nextCmd = x"19") then
               if (cmd_delay = 11 and FifoResponse_empty = '0') then 
                  FifoResponse_reset <= '1'; 
               end if;
                    
               case (FifoParam_Dout) is
                  when x"04" => -- Reset SCEx counters
                     if (cmd_delay = 1) then FifoResponse_Wr <= '1'; FifoResponse_Din <= internalStatus; startMotorCMD <= '1'; end if;
               
                  when x"05" => -- Read SCEx counters
                     if (cmd_delay = 3) then FifoResponse_Wr <= '1'; FifoResponse_Din <= internalStatus; end if;
                     if (cmd_delay = 2) then FifoResponse_Wr <= '1'; FifoResponse_Din <= x"00"; end if; -- ?
                     if (cmd_delay = 1) then FifoResponse_Wr <= '1'; FifoResponse_Din <= x"00"; end if; -- ?
                  
                  when x"20" => -- Get CDROM BIOS Date/Version
                     if (cmd_delay = 4) then FifoResponse_Wr <= '1'; FifoResponse_Din <= x"95"; end if;
                     if (cmd_delay = 3) then FifoResponse_Wr <= '1'; FifoResponse_Din <= x"05"; end if;
                     if (cmd_delay = 2) then FifoResponse_Wr <= '1'; FifoResponse_Din <= x"16"; end if;
                     if (cmd_delay = 1) then FifoResponse_Wr <= '1'; FifoResponse_Din <= x"C1"; end if;
                  
                  when x"22" => -- region
                     if (region = "00") then -- ntsc-u
                        if (cmd_delay = 7)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('f')), 8)); end if;
                        if (cmd_delay = 6)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('o')), 8)); end if;
                        if (cmd_delay = 5)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('r')), 8)); end if;
                        if (cmd_delay = 4)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos(' ')), 8)); end if;
                        if (cmd_delay = 3)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('U')), 8)); end if;
                        if (cmd_delay = 2)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('/')), 8)); end if;
                        if (cmd_delay = 1)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('C')), 8)); end if;
                     elsif (region = "01") then -- ntsc-j
                        if (cmd_delay = 9)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('f')), 8)); end if;
                        if (cmd_delay = 8)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('o')), 8)); end if;
                        if (cmd_delay = 7)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('r')), 8)); end if;
                        if (cmd_delay = 6)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos(' ')), 8)); end if;
                        if (cmd_delay = 5)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('J')), 8)); end if;
                        if (cmd_delay = 4)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('a')), 8)); end if;
                        if (cmd_delay = 3)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('p')), 8)); end if;
                        if (cmd_delay = 2)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('a')), 8)); end if;
                        if (cmd_delay = 1)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('n')), 8)); end if;
                     elsif (region = "10") then -- pal
                        if (cmd_delay = 10) then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('f')), 8)); end if;
                        if (cmd_delay = 9)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('o')), 8)); end if;
                        if (cmd_delay = 8)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('r')), 8)); end if;
                        if (cmd_delay = 7)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos(' ')), 8)); end if;
                        if (cmd_delay = 6)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('E')), 8)); end if;
                        if (cmd_delay = 5)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('u')), 8)); end if;
                        if (cmd_delay = 4)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('r')), 8)); end if;
                        if (cmd_delay = 3)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('o')), 8)); end if;
                        if (cmd_delay = 2)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('p')), 8)); end if;
                        if (cmd_delay = 1)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(to_unsigned(natural(character'pos('e')), 8)); end if;
                     end if;
               
                  when others => null;
               end case;
            end if;
            
            -- CDDA reporting
            if (processCDDASector = '1' and driveState = DRIVE_PLAYING and modeReg(2) = '1' and lastreportCDDA /= '0' & nextSubdata(9)(7 downto 4)) then
               lastreportCDDA     <= '0' & nextSubdata(9)(7 downto 4);
               -- don't return CDDA response if a command is currently in process or response is still pending
               -- latching it and respond later when irq and response have been processed is not possible or too late, so rather drop it
               if (CDDA_outcnt = 0 and CDROM_IRQFLAG = "00000" and FifoResponse_Empty = '1' and handleCommand = '0' and cmd_busy = '0') then
                  CDDA_outcnt        <= 8;
                  FifoResponse_reset <= '1';
               end if;
            end if;
            
            if (CDDA_outcnt > 0) then
               CDDA_outcnt <= CDDA_outcnt - 1;
               if (CDDA_outcnt = 8)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= internalStatus; end if;
               if (CDDA_outcnt = 7)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= nextSubdata(1); end if;
               if (CDDA_outcnt = 6)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= nextSubdata(2); end if;
               if (nextSubdata(9)(4) = '1') then
                  if (CDDA_outcnt = 5)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= nextSubdata(3); end if;
                  if (CDDA_outcnt = 4)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= x"80" or nextSubdata(4); end if;
                  if (CDDA_outcnt = 3)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= nextSubdata(5); end if;
               else
                  if (CDDA_outcnt = 5)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= nextSubdata(7); end if;
                  if (CDDA_outcnt = 4)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= nextSubdata(8); end if;
                  if (CDDA_outcnt = 3)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= nextSubdata(9); end if;
               end if;
               if (nextSubdata(8)(0) = '1') then
                  if (CDDA_outcnt = 2)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(peakvolumeR(7 downto 0)); end if;
                  if (CDDA_outcnt = 1)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= '1' & std_logic_vector(peakvolumeR(14 downto 8)); end if;
               else
                  if (CDDA_outcnt = 2)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= std_logic_vector(peakvolumeL(7 downto 0)); end if;
                  if (CDDA_outcnt = 1)  then FifoResponse_Wr <= '1'; FifoResponse_Din <= '0' & std_logic_vector(peakvolumeL(14 downto 8)); end if;
               end if;
            end if;
            
            if (newCD = '1' and newCD_1 = '0') then
               FifoResponse_reset <= '1';
               cmdPending         <= '0';
               cmd_busy           <= '0';
               cmd_delay          <= 0;
            end if;
            
            if (softReset = '1') then
               FifoParam_reset <= '1';
            end if;
         
         end if; -- ce
         
         if (FifoParam_reset = '1') then
            fifoParamCount <= 0;
         elsif (FifoParam_Wr = '1') then
            -- synthesis translate_off
            if (fifoParamCount < 16) then
            -- synthesis translate_on
               fifoParamCount <= fifoParamCount + 1;
            -- synthesis translate_off
            end if;
            -- synthesis translate_on
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
   
   ss_out(18)(4)            <= driveBusy;           
   ss_out(15)(27 downto 24) <= std_logic_vector(to_unsigned(tdrivestate'POS(driveState), 4));  
   ss_out( 4)(26 downto  0) <= std_logic_vector(to_unsigned(driveDelay, 27));           
   ss_out( 5)(26 downto  0) <= std_logic_vector(to_unsigned(driveDelayNext, 27));           
   ss_out(13)( 7 downto  0) <= internalStatus;       
   ss_out(13)(15 downto  8) <= modeReg;                   
   ss_out( 3)(19 downto  0) <= std_logic_vector(to_unsigned(currentLBA, 20));           
   ss_out( 7)(19 downto  0) <= std_logic_vector(to_unsigned(physicalLBA, 20));           
   ss_out(18)(5)            <= readAfterSeek;        
   ss_out(18)(6)            <= playAfterSeek;        
   ss_out(18)(8)            <= lastSectorHeaderValid;
   ss_out(16)( 2 downto  0) <= std_logic_vector(writeSectorPointer);   
   ss_out(16)(10 downto  8) <= std_logic_vector(readSectorPointer);    
   ss_out(25)( 7 downto  0) <= currentTrackBCD;    
   
   gSSsubdata: for i in 0 to 11 generate
   begin
      ss_out(i + 76)(7 downto 0) <= subdata(i);
   end generate;
   
   process (FORCECDSPEED, allow_speedhack, modeReg)
   begin
      if (FORCECDSPEED = "000" or allow_speedhack = '0') then
         if (modeReg(7) = '1') then
            driveREADSPEED <= READSPEED2X;
         else
            driveREADSPEED <= READSPEED1X;
         end if;
      else
         case (FORCECDSPEED) is
            when "010"   => driveREADSPEED <= READSPEED2X;
            when "011"   => driveREADSPEED <= READSPEED4X;
            when "100"   => driveREADSPEED <= READSPEED6X;
            when "101"   => driveREADSPEED <= READSPEED8X;
            when others =>  driveREADSPEED <= READSPEED1X;
         end case;
      end if;
   end process;
   
   -- drive
   process(clk1x)
      variable skipreading     : std_logic;
      variable physicalLBANew  : integer range 0 to 524287;
   begin
      if (rising_edge(clk1x)) then

         if (SS_reset = '1') then
            startMotorReset        <= '1'; 
         elsif (SS_wren = '1') then
            startMotorReset        <= '0'; 
            startMotor             <= '0';
         end if;

         if (reset = '1') then
            
            driveBusy               <= ss_in(18)(4); -- 0
            driveState              <= tdrivestate'VAL(to_integer(unsigned(ss_in(15)(27 downto 24)))); -- DRIVE_IDLE;  
            
            driveDelay              <= to_integer(unsigned(ss_in(4)(26 downto 0))); -- 0
            driveDelayNext          <= to_integer(unsigned(ss_in(5)(26 downto 0))); -- 0
                     
            internalStatus          <= ss_in(13)(7 downto 0); -- x"10"; -- shell open
            modeReg                 <= ss_in(13)(15 downto 8); -- x"20"; -- read_raw_sector set
                     
            currentLBA              <= to_integer(unsigned(ss_in(3)(19 downto 0))); -- 0
            physicalLBA             <= to_integer(unsigned(ss_in(7)(19 downto 0))); -- 0
            
            readAfterSeek           <= ss_in(18)(5); -- '0'
            playAfterSeek           <= ss_in(18)(6); -- '0';
            lastSectorHeaderValid   <= ss_in(18)(8); -- '0';
            
            writeSectorPointer      <= unsigned(ss_in(16)( 2 downto 0)); -- 0
            readSectorPointer       <= unsigned(ss_in(16)(10 downto 8)); -- 0
            
            currentTrackBCD         <= ss_in(25)( 7 downto 0); -- 0
            
            for i in 0 to 11 loop
               subdata(i) <= ss_in(i + 76)(7 downto 0);
            end loop;
            
            startMotorReset <= '0';
            if (startMotorReset = '1') then
               startMotor <= '1';
            end if;
            
            calcSeekTime  <= '0';
            addSeekTime   <= '0';
            
            allow_speedhack <= '0';
            Xa_playing      <= '0';
            
         elsif (softReset = '1') then
         
            modeReg        <= x"20"; -- read_raw_sector set
            internalStatus <= x"00";
            if (hasCD = '1') then
               internalStatus(1) <= '1';
               
               if (currentLBA /= 0) then
               	driveState <= DRIVE_SEEKIMPLICIT;
                  --seekStartLBA = currentLBA; -- todo
                  --seekEndLBA = 0;
                  readOnDisk   <= '1';
                  readLBA      <= 0;
               else
                  driveState <= DRIVE_SPEEDCHANGEORTOCREAD;
               end if;
               
               driveBusy  <= '1';
               if (modeReg(7) = '1') then -- double speed
                  driveDelay     <= 16934400 + 33868800 + 19999;
               else
                  driveDelay     <= 16934400 + 19999;
               end if;  

               if (INSTANTSEEK = '0') then
                  calcSeekTime   <= '1';   
                  limitDelayTime <= '0';
               end if;
               diffLBA <= currentLBA;
            
            else
               driveBusy  <= '0';
               driveState <= DRIVE_IDLE;
               driveDelay <= 0;
            end if;
            
         elsif (ce = '1') then
         
            handleDrive             <= '0';
            readOnDisk              <= '0';
            ackDrive                <= '0';
            ackDriveEnd             <= '0';
            seekOnDiskDrive         <= '0';
            seekOnDiskPlay          <= '0';
            errorResponseDrive_new  <= '0';
            startReading            <= '0';
            startPlaying            <= '0';
            ackRead                 <= '0';
            processDataSector       <= '0';
            processCDDASector       <= '0';
            processSeekHeader       <= '0';
            clearSectorBuffers      <= '0';
            triggerUpdateSubchannel <= '0';
            calcSeekTime            <= '0';
            addSeekTime             <= '0';
         
            startMotor   <= '0'; 
            
            internalStatus_1 <= internalStatus;
            
            if ((driveState /= DRIVE_READING and startReading = '0') or XA_write = '1' or mdec_idle = '0') then
               allow_speedhack <= '0';
            end if;
            
            if (XA_reset = '1') then
               Xa_playing <= '0';
            elsif (XA_start = '1') then
               Xa_playing <= '1';
            end if;
            
            sectorBufferFilled <= '0';
            if (driveState = DRIVE_READING and sectorBufferSizes(to_integer((writeSectorPointer + 4))) /= 0) then -- allow up to 4 buffers to be filled
               sectorBufferFilled <= not Xa_playing;
            end if;
         
            if (driveBusy = '1') then
               if (driveDelay > 0) then
                  if ((sectorBufferFilled = '0' and LIMITREADSPEED = '0') or CDROM_IRQFLAG = "00000" or driveDelay > 8191) then
                     if (sectorFetchState = SFETCH_IDLE or driveDelay > 127) then -- make sure to stop drive countdown if data isn't ready early enough so commands are still possible
                        driveDelay <= driveDelay - 1;
                     end if;
                  end if;
               elsif (sectorFetchState = SFETCH_IDLE and readOnDisk = '0' and readOnDisk_buffer = '0' and sectorProcessState = SPROC_IDLE and copyState = COPY_IDLE) then
                  handleDrive <= '1';
                  driveBusy   <= '0';
                  
                  -- completeSeek
                  if (driveState = DRIVE_SEEKIMPLICIT or driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL) then
                     
                     seekOK <= '1';
                     
                     for i in 0 to 11 loop
                        subdata(i) <= nextSubdata(i);
                     end loop;
                     
                     -- todo: check subdata against current frame/second/minute?
                     
                     if (nextSubdata(0)(6) = '1') then --isData
                        if (driveState = DRIVE_SEEKLOGICAL) then
                           processSeekHeader     <= '1';
                           lastSectorHeaderValid <= '1';
                        end if;
                     else
                        if (driveState = DRIVE_SEEKLOGICAL) then
                           seekOK <= modeReg(0); -- cdda
                        end if;
                     end if;
                     if (nextSubdata(1) = LEAD_OUT_TRACK_NUMBER) then
                        seekOK <= '0';
                     end if;
                      
                     currentLBA   <= lastReadSector;
                     physicalLBA  <= lastReadSector;
                      
                  end if;
                  
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
                           startReading      <= '1';
                           allow_speedhack   <= '1';
                           afterSeek         <= '1';
                           readAfterSeek     <= '0';
                           internalStatus(6) <= '1'; -- keep seek on until read is active
                        elsif (playAfterSeek = '1') then
                           startPlaying  <= '1';
                           afterSeek     <= '1';
                           playAfterSeek <= '0';
                        else
                           ackDrive <= '1';
                        end if;
                     else
                        lastSectorHeaderValid     <= '0';
                        errorResponseDrive_new    <= '1';
                        errorResponseDrive_error  <= x"04";
                        errorResponseDrive_reason <= x"04";
                     end if;
                     
                     
                  when DRIVE_READING | DRIVE_PLAYING =>
                     if (nextSubdata(1) = LEAD_OUT_TRACK_NUMBER) then
                        internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
						-- The motor should remain ON during normal CD audio playback. End-of-track detection should NOT stop the motor.
                        -- always signal end of playback with interrupt
                        -- internalStatus(1)          <= '0'; -- motor off
                        driveState   <= DRIVE_IDLE;
                        ackDriveEnd  <= '1';
                     else
                        skipreading := '0';
						if (setLocActive = '1' and (currentLBA - seekLBA) >= 2) then
						   skipreading := '1';
						end if;
                        if (isAudio = '1') then
                           if (currentTrackBCD = x"00") then -- auto find track number from subheader
                              currentTrackBCD <= nextSubdata(1);
                           elsif (nextSubdata(1) /= currentTrackBCD and modeReg(1) = '1') then --auto pause when track switches
                              skipreading := '1';
                              ackDriveEnd <= '1';
                              internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
                              driveState   <= DRIVE_IDLE;
                           end if;
                        end if;   
                        
                        if (skipreading = '0') then
                           readLBA      <= lastReadSector + 1;
                           if (isAudio = '0' and driveState = DRIVE_READING) then
                              processDataSector     <= '1';
                              lastSectorHeaderValid <= '1';
                              internalStatus(5)     <= '1'; -- reading
                              internalStatus(6)     <= '0'; -- seek off
                              if ((modeReg(6) = '0' or headerIsData = '1') and (modeReg(5) = '1' or headerDataSector = '1')) then
                                 writeSectorPointer    <= writeSectorPointer + 1;
                                 ackRead               <= '1';
                              end if;
                           elsif (isAudio = '1' and (driveState = DRIVE_PLAYING or (driveState = DRIVE_READING and modeReg(0) = '1'))) then
                              processCDDASector <= '1';
                              if (fastForwardRate /= 0) then
                                 readLBA <= lastReadSector + to_integer(fastForwardRate);
                              end if;
                           end if;
                           
                           if (fastCD = '1') then
                              driveDelay      <= 9999 - 2;
                           else
                              driveDelay      <= driveREADSPEED - 2;
                           end if;
                           
                           driveBusy    <= '1';
                           currentLBA   <= lastReadSector;
                           physicalLBA  <= lastReadSector;
                           for i in 0 to 11 loop
                              subdata(i) <= nextSubdata(i);
                           end loop;
                           readOnDisk   <= '1';
                        end if;
                     end if;
                     
                  when DRIVE_SPEEDCHANGEORTOCREAD =>
                     driveState     <= DRIVE_IDLE;
               
                  when DRIVE_SPINNINGUP =>
                     driveState     <= DRIVE_IDLE;
                     internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
                     if (hasCD = '1') then
                        internalStatus(1) <= '1';
                     end if;
                  
                  when DRIVE_CHANGESESSION =>
                     driveState     <= DRIVE_IDLE;
                     internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
                     if (hasCD = '1') then
                        internalStatus(1) <= '1';
                     end if;
                     if (session = x"01") then --todo: multisession
                        ackDrive <= '1';
                     end if;
                     
                  when DRIVE_OPENING =>
                     startMotor <= '1';
                  
                  when others => null;
               end case;
            end if;
            
            seekLBA <= to_integer(setLocMinute) * FRAMES_PER_MINUTE + to_integer(setLocSecond) * FRAMES_PER_SECOND + to_integer(setLocFrame);
            
            if (seekOnDiskCmd = '1' or seekOnDiskDrive = '1' or seekOnDiskPlay = '1') then
               if (seekOnDiskPlay = '1') then
                  readLBA <= playLBA;
                  if (playLBA > currentLBA) then diffLBA <= playLBA - currentLBA; else diffLBA <= currentLBA - playLBA; end if;
               else
                  readLBA <= seekLBA;
                  if (seekLBA > currentLBA) then diffLBA <= seekLBA - currentLBA; else diffLBA <= currentLBA - seekLBA; end if;
               end if;
               readOnDisk            <= '1';
               if (seekOnDiskCmd = '1') then
                  readAfterSeek         <= '0';
                  playAfterSeek         <= '0';
               end if;
               lastSectorHeaderValid      <= '0';
               internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
               internalStatus(1)          <= '1'; -- motor on
               internalStatus(6)          <= '1'; -- seeking
               driveDelay                 <= driveREADSPEED - 2;
               driveDelayNext             <= driveREADSPEED - 2;
               
               limitDelayTime             <= '0';

               if (INSTANTSEEK = '0') then
                  calcSeekTime <= '1';
                  if (driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or driveState = DRIVE_SEEKIMPLICIT) then
                     driveDelay     <= driveREADSPEED - 2 + driveDelay;
                     limitDelayTime <= '1';
                  elsif (driveState = DRIVE_SPEEDCHANGEORTOCREAD and (seekOnDiskPlay = '0' and playAfterSeek = '0')) then
                     driveDelay <= driveREADSPEED - 2 + driveDelay;
                  end if; 
               end if;
               
               driveBusy      <= '1';
               if (nextCmd = x"15") then
                  driveState  <= DRIVE_SEEKLOGICAL;
               else
                  driveState  <= DRIVE_SEEKPHYSICAL;
               end if;
            end if;    
            
            if (stop_afterseek = '1') then
               readAfterSeek <= '0';
               playAfterSeek <= '0';
            end if;
            
            if (calcSeekTime = '1') then
            
               addSeekTime <= '1';
               
               -- todo: research more accurate values
               if (diffLBA < 3) then
                  seekTimeMul <= 3;
               elsif (diffLBA < 5) then
                  seekTimeMul <= diffLBA;
               elsif (diffLBA < 32) then
                  seekTimeMul <= 5;
               elsif (diffLBA < 75) then
                  seekTimeMul <= 5 + diffLBA / 8; -- 5 .. 14
               elsif (diffLBA < 4500) then
                  seekTimeMul <= 14 + diffLBA / 256; -- 14 .. 31
               else
                  seekTimeMul <= 31 + diffLBA / 8192; -- 31 .. 73
               end if;
                  
            end if;
            
            if (addSeekTime = '1') then
               if (limitDelayTime = '1' and (driveDelay + driveREADSPEED * seekTimeMul) > 22880000) then -- max seek time
                  driveDelay <= 22880000;
               else
                  driveDelay <= driveDelay + driveREADSPEED * seekTimeMul;
               end if;
            end if;
            
            if (readSN = '1') then
               if (driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or driveState = DRIVE_SEEKIMPLICIT) then
                  -- todo: updatePositionWhileSeeking();
               end if;
               if (setLocActive = '1') then
                  seekOnDiskDrive   <= '1';
                  readAfterSeek     <= '1';
                  playAfterSeek     <= '0';
               else
                  internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
                  startReading      <= '1';
                  allow_speedhack   <= '1';
                  afterSeek         <= '0';
               end if;
            end if;
            
            if (play = '1') then
               if (driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or driveState = DRIVE_SEEKIMPLICIT) then
                  -- todo: updatePositionWhileSeeking();
               end if;
               currentTrackBCD <= nextTrack;
               if (playTrack = '1') then
                  seekOnDiskPlay    <= '1';
                  readAfterSeek     <= '0';
                  playAfterSeek     <= '1';
               elsif (setLocActive = '1') then
                  seekOnDiskDrive   <= '1';
                  readAfterSeek     <= '0';
                  playAfterSeek     <= '1';
               else
                  startPlaying <= '1';
                  afterSeek    <= '0';
               end if;
            end if;
            
            if (setSession = '1') then
               driveState     <= DRIVE_CHANGESESSION;
               driveBusy      <= '1';
               driveDelay     <= 33868800 / 2;
            end if; 
            
            if (startReading = '1') then
               clearSectorBuffers <= '1';
			   
			   if (afterSeek = '0') then
			      internalStatus(6) <= '1';  -- seeking until first sector arrives
			   end if;
															
               --todo: check for setLocActive needed when coming from readSN?
               if (driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or driveState = DRIVE_SEEKIMPLICIT) then
                  readAfterSeek     <= '1';
                  playAfterSeek     <= '0';
               else
                  internalStatus(1)          <= '1'; -- motor on
                  if (fastCD = '1') then
                     driveDelay         <= 9999 - 2;
                     driveDelayNext     <= 9999 - 2;
                  else
                     driveDelay      <= driveREADSPEED - 2;
                     driveDelayNext  <= driveREADSPEED - 2;
                  end if;
                  driveBusy          <= '1';
                  driveState         <= DRIVE_READING;
                  writeSectorPointer <= (others => '0');
                  readSectorPointer  <= (others => '0');
                  readOnDisk         <= '1';
                  readLBA            <= currentLBA;
                  seekTimeMul        <= 1;
                  if (INSTANTSEEK = '0' and afterSeek = '0') then
                     if (driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or driveState = DRIVE_SEEKIMPLICIT) then
                        driveDelay <= driveREADSPEED - 2 + driveDelay;
                     elsif (driveState = DRIVE_SPEEDCHANGEORTOCREAD) then
                        driveDelay  <= driveREADSPEED - 2 + driveDelay;
                     end if;
                     addSeekTime    <= '1';
                     limitDelayTime <= '0';
                  end if;
               end if;
            end if;
            
            if (startPlaying = '1') then
               clearSectorBuffers <= '1';
               --todo: check for setLocActive needed when coming from readSN?
               if (driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or driveState = DRIVE_SEEKIMPLICIT) then
                  readAfterSeek     <= '0';
                  playAfterSeek     <= '1';
               else
                  internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
                  internalStatus(1)          <= '1'; -- motor on
                  internalStatus(7)          <= '1'; -- playing_cdda
                  if (fastCD = '1') then
                     driveDelay         <= 9999 - 2;
                     driveDelayNext     <= 9999 - 2;
                  else
                     driveDelay      <= driveREADSPEED - 2;
                     driveDelayNext  <= driveREADSPEED - 2;
                  end if;
                  driveBusy          <= '1';
                  driveState         <= DRIVE_PLAYING;
                  writeSectorPointer <= (others => '0');
                  readSectorPointer  <= (others => '0');
                  readOnDisk         <= '1';
                  readLBA            <= currentLBA;
                  seekTimeMul        <= 1;
                  if (INSTANTSEEK = '0' and afterSeek = '0') then
                     if (driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or driveState = DRIVE_SEEKIMPLICIT) then
                        driveDelay <= driveREADSPEED - 2 + driveDelay;
                     end if;
                     addSeekTime    <= '1';
                     limitDelayTime <= '0';
                  end if;
               end if;
            end if;
            
            if (cmdStop = '1') then
               lastSectorHeaderValid      <= '0';
               driveState                 <= DRIVE_IDLE;
               driveBusy                  <= '0';
               internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
               internalStatus(1)          <= '0';   --motor off
            end if;
            
            if (drive_stop = '1') then
               driveState <= DRIVE_IDLE;
               driveBusy  <= '0';
               internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
            end if;
            
            if (startMotor = '1' or cmdStartMotor = '1') then
               if (driveState /= DRIVE_SPINNINGUP) then
                  driveState     <= DRIVE_SPINNINGUP;
                  driveDelay     <= 44100*300;
                  driveDelayNext <= 44100*300;
                  driveBusy      <= '1';
               end if;
            end if;
            
            if (LIDopen = '1') then
               internalStatus(4) <= '1';
            elsif (shell_close = '1') then
               internalStatus(4) <= '0';
            end if;
            
            if (ackRead_valid = '1' or ackPendingSector = '1') then
               readSectorPointer <= readSectorPointer + 1;
            end if;
            
            if (startMotorCMD = '1') then
               internalStatus(1) <= '1'; -- motor on
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
                     else
                        driveDelay     <= 33868800; -- 44100 * 0x300; -- 100%
                     end if;
                     if (driveState = DRIVE_IDLE) then
                        driveState <= DRIVE_SPEEDCHANGEORTOCREAD;
                        driveBusy  <= '1';
                     end if;
                  end if;
               end if;
            end if;
            
            -- updatePhysicalPosition triggered from GetLocP only - todo: trigger constantly when motor on and not seeking/reading?
            case (physicalUpdateState) is
            
               when PHYSICALUPDATE_IDLE =>
                  if (updatePhysicalPosition = '1') then
                     physicalUpdateState <= PHYSICALUPDATE_START;
                  end if;
            
               when PHYSICALUPDATE_START =>
                  physicalUpdateState <= PHYSICALUPDATE_CHECK;
                  -- todo: if (!lastSectorHeaderValid) -> different base position and different sectors per track?
                  -- todo: fixed 32 sectorPerTrack, should be 7.0f + 2.811844405f * std::log((float)(currentLBA / 4500) + 1);
                  if (currentlba < 32) then
                     phy_base <= currentlba;
                  else
                     phy_base <= currentlba - 31;
                  end if;
                  
               when PHYSICALUPDATE_CHECK =>
                  physicalUpdateState <= PHYSICALUPDATE_CALC1;
                  if (physicalLBA < phy_base) then
                     physicalLBA <= phy_base;
                  end if;
                  
               when PHYSICALUPDATE_CALC1 =>
                  physicalUpdateState <= PHYSICALUPDATE_CALC2;
                  phy_oldOffset <= physicalLBA - phy_base;
                  
               when PHYSICALUPDATE_CALC2 =>  
                  physicalUpdateState <= PHYSICALUPDATE_CALCDONE;
                  phy_newOffset <= (phy_oldOffset + 1) mod 32;
            
               when PHYSICALUPDATE_CALCDONE =>
                  physicalLBANew := phy_base + phy_newOffset;
                  physicalLBA    <= physicalLBANew; 
                  if (physicalLBA /= physicalLBANew) then
                     physicalUpdateState     <= PHYSICALUPDATE_READSUBCHANNEL;
                     triggerUpdateSubchannel <= '1';
                  else
                     physicalUpdateState     <= PHYSICALUPDATE_IDLE;
                  end if;
            
               when PHYSICALUPDATE_READSUBCHANNEL =>
                  if (UpdateSubchannelDone = '1') then
                     physicalUpdateState     <= PHYSICALUPDATE_IDLE;
                     for i in 0 to 11 loop
                        subdata(i) <= nextSubdata(i);
                     end loop;
                  end if;
            
            end case;
            
            newCD_1 <= newCD;
            if (newCD = '1' and newCD_1 = '0') then
               driveState                 <= DRIVE_OPENING;
               driveBusy                  <= '1';
               if (modeReg(7) = '1') then
                  driveDelay              <= 25000000;
               else
                  driveDelay              <= 13000000;
               end if;
               internalStatus(7 downto 5) <= "000"; -- ClearActiveBits
               internalStatus(1)          <= '0';   -- motor off
               internalStatus(4)          <= '1';   -- open LID
               errorResponseDrive_new     <= '1';
               errorResponseDrive_error   <= x"01";
               errorResponseDrive_reason  <= x"08";
            end if;
            
            --modeReg(1) <= '0'; -- debug autopause
            
         end if; -- ce
      end if;
   end process;
   
   iramSectorBuffer: entity mem.dpram
   generic map 
   ( 
      addr_width => 10, 
      data_width => 32
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => sectorBuffer_addrA,
      data_a      => sectorBuffer_DataA,
      wren_a      => sectorBuffer_wrenA,
                     
      clock_b     => clk1x,
      address_b   => sectorBuffer_addrB,
      data_b      => x"00000000",
      wren_b      => '0',
      q_b         => sectorBuffer_DataB
   );
   
   sectorBuffer_addrB <= std_logic_vector(SS_Adr(9 downto 0)) when (SS_rden = '1') else std_logic_vector(to_unsigned(procReadAddr, 10));
   
   sectorBuffers_addrB <= std_logic_vector(to_unsigned(to_integer(SS_Adr - 2048), 13)) when (SS_rden = '1' and SS_Adr >= 2048 and SS_Adr < 2048 + (1024 * 8)) else 
                          std_logic_vector(copySectorPointer & to_unsigned(copyReadAddr, 10));
   
   iramSectorBuffers: entity mem.dpram
   generic map 
   ( 
      addr_width => 13, 
      data_width => 32
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => sectorBuffers_addrA,
      data_a      => sectorBuffers_DataA,
      wren_a      => sectorBuffers_wrenA,
      
      clock_b     => clk1x,
      address_b   => sectorBuffers_addrB,
      data_b      => x"00000000",
      wren_b      => '0',
      q_b         => sectorBuffers_DataB
   );
   
   ss_out(19)              <= header;
   ss_out(20)              <= subheader;
   ss_out(6)(19 downto 0)  <= std_logic_vector(to_unsigned(lastReadSector, 20));
   ss_out(11)(19 downto 0) <= std_logic_vector(to_unsigned(positionInIndex, 20));
   
   ss_out(22)( 7 downto 0) <= XaCurrentFile;
   ss_out(22)(15 downto 8) <= XaCurrentChannel;
   ss_out(22)(16)          <= XaCurrentSet;
   
   gSSnextsubdata: for i in 0 to 11 generate
   begin
      ss_out(i + 64)(7 downto 0) <= nextSubdata(i);
   end generate;
   
   gSSsectorBufferSizes: for i in 0 to 7 generate
   begin
      ss_out(i + 96)(11 downto 0) <= std_logic_vector(to_unsigned(sectorBufferSizes(i), 10)) & "00";
   end generate;
   
   -- data processing
   process(clk1x)
      variable checkData : std_logic_vector(31 downto 0);
      variable frameLeft : unsigned(6 downto 0);
   begin
      if (rising_edge(clk1x)) then

         FifoData_Wr  <= '0';
         
         sectorBuffer_wrenA  <= '0';
         sectorBuffers_wrenA <= '0';
         
         error               <= '0';
         
         pauseCD <= '0';
         if (pauseOnCDSlow = '1') then
            if ((sectorFetchState /= SFETCH_IDLE) and driveDelay < 32768) then
               pauseCD <= '1';
            end if;
         end if;
         
         if (testSeek = '0' and (driveState = DRIVE_SEEKLOGICAL or driveState = DRIVE_SEEKPHYSICAL or driveState = DRIVE_SEEKIMPLICIT)) then
            slow_block <= '1';
         elsif (handleDrive = '1' and (driveState = DRIVE_READING or driveState = DRIVE_PLAYING)) then
            slow_block <= '0';
         end if;
         
         if ((sectorFetchState /= SFETCH_IDLE) and driveDelay < 128 and slow_block = '0') then
            cdSlow       <= '1';
            slow_timeout <= 16777215;
         elsif (slow_timeout > 0) then
            slow_timeout <= slow_timeout - 1;
         else
            cdSlow <= '0';
         end if;
         
         XA_write   <= '0';
         XA_start   <= '0'; 
         CDDA_write <= '0'; 

         if (reset = '1') then
         
            cd_hps_req           <= '0';
            
            sectorFetchState     <= SFETCH_IDLE;
            sectorProcessState   <= SPROC_IDLE;
            copyState            <= COPY_IDLE;
            header               <= ss_in(19);
            subheader            <= ss_in(20);
            lastReadSector       <= to_integer(unsigned(ss_in(6)(19 downto 0))); -- 0
            
            XaCurrentFile        <= ss_in(22)( 7 downto 0);
            XaCurrentChannel     <= ss_in(22)(15 downto 8);
            XaCurrentSet         <= ss_in(22)(16);
            
            positionInIndex   <= to_integer(signed(ss_in(11)(19 downto 0))); -- 0
            
            for i in 0 to 11 loop
               nextSubdata(i) <= ss_in(i + 64)(7 downto 0);
            end loop;
            
            for i in 0 to 7 loop
               sectorBufferSizes(i) <= to_integer(unsigned(ss_in(i + 96)(11 downto 2)));
            end loop;
            
            cd_hps_lba <= (others => '1');
            
         elsif (SS_wren = '1') then
            
            if (SS_Adr >= 1024 and SS_Adr < 1024 + (RAW_SECTOR_SIZE / 4)) then
               sectorBuffer_addrA <= std_logic_vector(SS_Adr(9 downto 0));
               sectorBuffer_DataA <= SS_DataWrite;
               sectorBuffer_wrenA <= '1';
            end if;
            
            if (SS_Adr >= 2048 and SS_Adr < 2048 + (1024 * 8)) then 
               sectorBuffers_addrA <= std_logic_vector(to_unsigned(to_integer(SS_Adr - 2048), 13));
               sectorBuffers_DataA <= SS_DataWrite;
               sectorBuffers_wrenA <= '1';
               -- synthesis translate_off
               if ((to_integer(SS_Adr) mod 2048) < 588) then
                  sectorBuffers(((to_integer(SS_Adr) - 2048) / 1024))(to_integer(SS_Adr) mod 2048) <= SS_DataWrite;
               end if;
               -- synthesis translate_on
            end if;
            
            if (SS_Adr = 1024) then headerIsData <= '1'; headerDataSector <= '1'; headerDataCheck <= '1'; end if;
            if (SS_Adr = 1027 and SS_DataWrite(31 downto 24) /= x"02") then headerDataCheck <= '0'; headerDataSector <= '0'; end if;
            if (SS_Adr = 1028 and SS_DataWrite(22) = '1' and SS_DataWrite(18) = '1' and headerDataCheck = '1') then headerIsData <= '0'; end if;
            
         else
         
            if (ce = '1') then
               ackRead_data         <= '0';
               UpdateSubchannelDone <= '0';
            end if;
            
            readSubchannel <= '0';
   
            if (readOnDisk = '1') then
               readOnDisk_buffer <= '1';
               readLBA_buffer    <= readLBA;
            end if;
      
            case (sectorFetchState) is
            
               when SFETCH_IDLE =>
                  if (readOnDisk_buffer = '1' and ce = '1') then
                     lastReadSector    <= readLBA_buffer;
                     sectorFetchState  <= SFETCH_DELAY;
                     fetchCount        <= 0;
                     fetchDelay        <= 15;
                     readOnDisk_buffer <= '0';
                  end if;
                  
               when SFETCH_DELAY => -- delay to give processing a head start with copy and wait for HPS ack before new request
                  if (cd_hps_ack = '0') then
                     if (fetchDelay > 0) then
                        fetchDelay <= fetchDelay - 1;
                     elsif (trackSearchState = TRACKSEARCH_IDLE) then
                        sectorFetchState <= SFETCH_START;
                        if (trackNumberBCD = "01" and isAudio = '0') then
                           positionInIndex <= lastReadSector - startLBA - PREGAPSIZE;  
-- synthesis translate_off
                           positionInIndex <= lastReadSector - startLBA; -- pregap not present in simulation
-- synthesis translate_on
                        else
                           positionInIndex <= lastReadSector - startLBA;
                        end if;
                     end if;   
                  end if;
                  
               when SFETCH_START =>
                  if (cd_hps_lba /= std_logic_vector(to_unsigned(lastReadSector, 32))) then
                     sectorFetchState <= SFETCH_HPSACK;
                     cd_hps_req       <= '1';
                  else
                     sectorFetchState <= SFETCH_IDLE;
                  end if;
                     
                  cd_hps_lba       <= std_logic_vector(to_unsigned(lastReadSector, 32));
                  cd_hps_lba_sim   <= (others => '0'); 
                  -- synthesis translate_off
                  cd_hps_lba_sim(23 downto 0)  <= std_logic_vector(to_unsigned(lastReadSector - startLBA, 24));
                  cd_hps_lba_sim(31 downto 24) <= '0' & trackNumber;
                  -- synthesis translate_on
                  
                  readSubchannel <= '1';
															
                  if (
                      (libcryptKey(15) = '1' and ((lastReadSector + 2) = 14105 or (lastReadSector + 2) = 14110)) or
                      (libcryptKey(14) = '1' and ((lastReadSector + 2) = 14231 or (lastReadSector + 2) = 14236)) or
                      (libcryptKey(13) = '1' and ((lastReadSector + 2) = 14485 or (lastReadSector + 2) = 14490)) or
                      (libcryptKey(12) = '1' and ((lastReadSector + 2) = 14579 or (lastReadSector + 2) = 14584)) or
                      (libcryptKey(11) = '1' and ((lastReadSector + 2) = 14649 or (lastReadSector + 2) = 14654)) or
                      (libcryptKey(10) = '1' and ((lastReadSector + 2) = 14899 or (lastReadSector + 2) = 14904)) or
                      (libcryptKey(9)  = '1' and ((lastReadSector + 2) = 15056 or (lastReadSector + 2) = 15061)) or
                      (libcryptKey(8)  = '1' and ((lastReadSector + 2) = 15130 or (lastReadSector + 2) = 15135)) or
                      (libcryptKey(7)  = '1' and ((lastReadSector + 2) = 15242 or (lastReadSector + 2) = 15247)) or
                      (libcryptKey(6)  = '1' and ((lastReadSector + 2) = 15312 or (lastReadSector + 2) = 15317)) or
                      (libcryptKey(5)  = '1' and ((lastReadSector + 2) = 15378 or (lastReadSector + 2) = 15383)) or
                      (libcryptKey(4)  = '1' and ((lastReadSector + 2) = 15628 or (lastReadSector + 2) = 15633)) or
                      (libcryptKey(3)  = '1' and ((lastReadSector + 2) = 15919 or (lastReadSector + 2) = 15924)) or
                      (libcryptKey(2)  = '1' and ((lastReadSector + 2) = 16031 or (lastReadSector + 2) = 16036)) or
                      (libcryptKey(1)  = '1' and ((lastReadSector + 2) = 16101 or (lastReadSector + 2) = 16106)) or
                      (libcryptKey(0)  = '1' and ((lastReadSector + 2) = 16167 or (lastReadSector + 2) = 16172))
                  ) then
                      readSubchannel <= '0';
                  end if;
                  
                  if (hasCD = '0') then
                     cd_hps_req       <= '0';
                     sectorFetchState <= SFETCH_IDLE;
                  end if;
                  
               when SFETCH_HPSACK => 
                  if (cd_hps_ack = '1') then
                     sectorFetchState <= SFETCH_HPSWORD;
                     cd_hps_req       <= '0';
                     peakvolumeL      <= (others => '0');
                     peakvolumeR      <= (others => '0');
                  end if;
               
               when SFETCH_HPSWORD =>
                  if (cd_hps_write = '1') then
                     sectorFetchState                <= SFETCH_HPSDATA;
                     if (positionInIndex >= 0) then
                        sectorBuffer_DataA(15 downto 0) <= cd_hps_data;
                        if (signed(cd_hps_data) > peakvolumeL) then
                           peakvolumeL <= signed(cd_hps_data);
                        end if;
                     else
                        sectorBuffer_DataA(15 downto 0) <= (others => '0');
                     end if; 
                  end if;
               
               when SFETCH_HPSDATA =>
                  if (cd_hps_write = '1') then
                     sectorBuffer_addrA <= std_logic_vector(to_unsigned(fetchCount, 10));
                     sectorBuffer_wrenA <= '1';
                     checkData := sectorBuffer_DataA;
                     if (positionInIndex >= 0) then
                        checkData(31 downto 16) := cd_hps_data;
                        if (signed(cd_hps_data) > peakvolumeR) then
                           peakvolumeR <= signed(cd_hps_data);
                        end if;
                     else
                        checkData(31 downto 16) := (others => '0');
                     end if;
                     sectorBuffer_DataA <= checkData;
                     
                     if (fetchCount = 587) then
                        sectorFetchState <= SFETCH_IDLE;
                     else
                        fetchCount  <= fetchCount + 1;
                        sectorFetchState <= SFETCH_HPSWORD;
                     end if;
                     
                     if (fetchCount = 0) then headerIsData <= '1'; headerDataSector <= '1'; headerDataCheck <= '1'; end if;
                     if (fetchcount = 3 and checkData(31 downto 24) /= x"02") then headerDataCheck <= '0'; headerDataSector <= '0'; end if;
                     if (fetchcount = 4 and checkData(22) = '1' and checkData(18) = '1' and headerDataCheck = '1') then headerIsData <= '0'; end if;
                  end if;
                  
            end case;
            
            -- reset cached sector on CD switch
            if (newCD = '1' and newCD_1 = '0') then
               cd_hps_lba <= (others => '1');
            end if;
            
            case (readSubchannelState) is
            
               when SSUB_IDLE =>
                  null;
                  
               when SSUB_START =>
                  nextSubdata(0)       <= '0' & (not isAudio) & "000000"; -- index control bits
                  nextSubdata(1)       <= std_logic_vector(trackNumberBCD); 

                  if ((subchannelSector - startLBA) >= PREGAPSIZE) then
                     nextSubdata(2)       <= x"01"; -- index number
                     if (isAudio = '0') then
                        subchannelLBAwork    <= subchannelSector - startLBA;
                     else
                        subchannelLBAwork    <= subchannelSector - startLBA - PREGAPSIZE;
                     end if;
                  else
                     nextSubdata(2)       <= x"00"; -- index number
                     subchannelLBAwork    <= PREGAPSIZE - (subchannelSector - startLBA) - 1;
                  end if;
                  readSubchannelState  <= SSUB_CALCPOS;
                  sub_SecondsHigh      <= (others => '0');
                  sub_SecondsLow       <= (others => '0');
                  sub_MinutesHigh      <= (others => '0');
                  sub_MinutesLow       <= (others => '0');
                  
               
               when SSUB_CALCPOS | SSUB_CALCSECTOR =>
                  if (subchannelLBAwork >= FRAMES_PER_SECOND) then
                     subchannelLBAwork <= subchannelLBAwork - FRAMES_PER_SECOND;
                  
                     if (sub_SecondsLow < 9) then
                        sub_SecondsLow <= sub_SecondsLow + 1;
                     else
                        sub_SecondsLow <= (others => '0');
                        if (sub_SecondsHigh < 5) then
                           sub_SecondsHigh <= sub_SecondsHigh + 1;
                        else
                           sub_SecondsHigh <= (others => '0');
                           if (sub_MinutesLow < 9) then
                              sub_MinutesLow <= sub_MinutesLow + 1;
                           else
                              sub_MinutesLow  <= (others => '0');
                              sub_MinutesHigh <= sub_MinutesHigh + 1;
                           end if;
                        end if;
                     end if;
                  else
                     frameLeft := to_unsigned(subchannelLBAwork, 7);
                     subchannelLBAwork <= 0;
                     if (readSubchannelState = SSUB_CALCPOS) then
                        readSubchannelState        <= SSUB_CALCSECTOR;
                        subchannelLBAwork          <= subchannelSector; 
                        nextSubdata(3)             <= std_logic_vector(sub_MinutesHigh & sub_MinutesLow);
                        nextSubdata(4)             <= std_logic_vector(sub_SecondsHigh & sub_SecondsLow);
                        nextSubdata(5)(7 downto 4) <= std_logic_vector(resize(frameLeft / 10, 4));
                        nextSubdata(5)(3 downto 0) <= std_logic_vector(resize(frameLeft mod 10, 4));
                        sub_SecondsHigh            <= (others => '0');
                        sub_SecondsLow             <= (others => '0');
                        sub_MinutesHigh            <= (others => '0');
                        sub_MinutesLow             <= (others => '0');
                     else
                        readSubchannelState        <= SSUB_IDLE;
                        UpdateSubchannelDone       <= UpdateSubchannel;
                        UpdateSubchannel           <= '0';
                        nextSubdata(7)             <= std_logic_vector(sub_MinutesHigh & sub_MinutesLow);
                        nextSubdata(8)             <= std_logic_vector(sub_SecondsHigh & sub_SecondsLow);
                        nextSubdata(9)(7 downto 4) <= std_logic_vector(resize(frameLeft / 10, 4));
                        nextSubdata(9)(3 downto 0) <= std_logic_vector(resize(frameLeft mod 10, 4));
                     end if;
                  end if;
               
            end case;
            
            if (readSubchannel = '1' or triggerUpdateSubchannel = '1') then
               readSubchannelState <= SSUB_START;
               if (triggerUpdateSubchannel = '1') then
                  subchannelSector <= physicalLBA;
                  UpdateSubchannel <= '1';
               else
                  subchannelSector <= lastReadSector +2;
               end if;
            end if;
            
            case (sectorProcessState) is
            
               when SPROC_IDLE =>
                  procReadAddr <= SECTOR_SYNC_SIZE / 4;
                  if (processDataSector = '1' and ce = '1') then
                     sectorProcessState <= SPROC_READHEADER;
                     procReadAddr       <= procReadAddr + 1;
                     procCount          <= 0;
                  elsif (processCDDASector = '1' and ce = '1') then
                     procReadAddr       <= 0;
                     procCount          <= 0;
                     sectorProcessState <= SPROC_CDDAFIRST;
                  elsif (processSeekHeader = '1' and ce = '1') then
                     sectorProcessState <= SPROC_SEEKREADHEADER;
                     procReadAddr       <= procReadAddr + 1;
                  end if;
                  
               when SPROC_SEEKREADHEADER    => sectorProcessState <= SPROC_SEEKREADSUBHEADER; header    <= sectorBuffer_DataB;
               when SPROC_SEEKREADSUBHEADER => sectorProcessState <= SPROC_IDLE;              subheader <= sectorBuffer_DataB;
                  
               when SPROC_READHEADER =>
                  sectorProcessState <= SPROC_READSUBHEADER;
                  header <= sectorBuffer_DataB;
                  
               when SPROC_READSUBHEADER => 
                  subheader <= sectorBuffer_DataB;
                  sectorProcessState <= SPROC_START;
                  if (modeReg(6) = '1') then -- xa_enable
                     if (header(31 downto 24) = x"02") then
                        if (sectorBuffer_DataB(22) = '1') then -- realtime
                           if (sectorBuffer_DataB(18) = '1') then -- audio
                              procReadAddr         <= 0;
                              sectorProcessState   <= SPROC_XA_FIRST;
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
                  if (sectorBufferSizes(to_integer(writeSectorPointer)) /= 0) then
                     --error <= '1';
                  end if;
                  sectorBufferSizes(to_integer(writeSectorPointer)) <= procSize;
               
               when SPROC_DATA =>
                  procCount    <= procCount + 1;
                  if (procReadAddr < 587) then
                     procReadAddr <= procReadAddr + 1;
                  end if;
                  -- synthesis translate_off
                  sectorBuffers(to_integer(writeSectorPointer))(procCount) <= sectorBuffer_DataB;
                  -- synthesis translate_on
                  sectorBuffers_addrA <= std_logic_vector(writeSectorPointer & to_unsigned(procCount, 10));
                  sectorBuffers_DataA <= sectorBuffer_DataB;
                  sectorBuffers_wrenA <= '1';
                  if (procCount = (procSize - 1)) then
                     sectorProcessState  <= SPROC_IDLE;
                  end if;
                  
               when SPROC_XA_FIRST =>
                  sectorProcessState <= SPROC_XA;
                  procReadAddr       <= procReadAddr + 1;
                  if (modeReg(3) = '1' and ((XaFilterChannel /= subheader(15 downto 8)) or XaFilterFile /= subheader(7 downto 0))) then
                     sectorProcessState <= SPROC_IDLE;
                  else
                     if (XaCurrentSet = '0') then
                        if (subheader(15 downto 8) = x"FF" and (modeReg(3) = '0' or XaFilterChannel /= x"FF")) then
                           sectorProcessState <= SPROC_IDLE;   
                        else
                           XaCurrentFile    <= subheader(7 downto 0);
                           XaCurrentChannel <= subheader(15 downto 8);
                           XaCurrentSet     <= '1';   
                        end if;
                     elsif (XaCurrentSet = '1' and ((XaCurrentChannel /= subheader(15 downto 8)) or XaCurrentFile /= subheader(7 downto 0))) then
                        sectorProcessState <= SPROC_IDLE;
                     end if;
                  end if;
                  
               when SPROC_XA =>
                  procCount    <= procCount + 1;
                  if (procReadAddr < 587) then
                     procReadAddr <= procReadAddr + 1;
                  end if;
                  if (procCount = 587) then
                     sectorProcessState  <= SPROC_IDLE;
                     XA_start            <= '1';
                  end if;
                  XA_write <= '1';
                  XA_data  <= sectorBuffer_DataB;
                  XA_addr  <= procCount;
                  
               when SPROC_CDDAFIRST =>
                  sectorProcessState <= SPROC_CDDA;
                  procReadAddr       <= procReadAddr + 1;
               
               when SPROC_CDDA =>
                  procCount    <= procCount + 1;
                  if (procReadAddr < 587) then
                     procReadAddr <= procReadAddr + 1;
                  end if;
                  if (procCount = 587) then
                     sectorProcessState  <= SPROC_IDLE;
                  end if;
                  CDDA_write <= '1';
                  CDDA_data  <= sectorBuffer_DataB;
                  
            end case;
            

            case (copyState) is
            
               when COPY_IDLE =>
                  if (copyData = '1' and ce = '1') then
                     copyState         <= COPY_FIRST;
                     copyCount         <= 0;
                     copyReadAddr      <= 0;
                     copyByteCnt       <= 0;
                     copySectorPointer <= readSectorPointer;
                     sectorBufferSizes(to_integer(readSectorPointer)) <= 0;
                     if (sectorBufferSizes(to_integer(readSectorPointer)) = 0) then
                        copySize <= RAW_SECTOR_OUTPUT_SIZE / 4;
                     else
                        copySize <= sectorBufferSizes(to_integer(readSectorPointer));
                     end if;
                  end if;
               
               when COPY_FIRST =>
                  copyState     <= COPY_DATA;
                   if (sectorBufferSizes(to_integer(writeSectorPointer)) /= 0) then -- additional irq for missed sector
                     ackRead_data <= '1';
                  end if;
               
               when COPY_DATA =>
                  FifoData_Wr  <= '1';
                  case (copyByteCnt) is
                     when 0 => 
                        copyByteCnt <= 1; 
                        FifoData_Din <= sectorBuffers_DataB(7 downto 0);
                        
                     when 1 => 
                        copyByteCnt <= 2; 
                        FifoData_Din <= sectorBuffers_DataB(15 downto 8);
                        
                     when 2 => 
                        copyByteCnt  <= 3; 
                        FifoData_Din <= sectorBuffers_DataB(23 downto 16); 
                        copyReadAddr <= copyReadAddr + 1;
                        
                     when 3 => 
                        copyByteCnt  <= 0; 
                        FifoData_Din <= sectorBuffers_DataB(31 downto 24); 
                        copyCount    <= copyCount + 1;
                        if (copyCount = (copySize - 1)) then
                           copyState  <= COPY_IDLE;
                        end if;
                     when others => null;
                  end case;
                 
            end case;
            
            -- if data fifo is reset while copy is still ongoing, stop copy immidiatly so fifo stays empty
            if (FifoData_reset = '1' and copyState /= COPY_IDLE) then
               copyState   <= COPY_IDLE;
               FifoData_Wr <= '0';
            end if;
            
            if (clearSectorBuffers = '1') then
               sectorBufferSizes <= (others => 0);
            end if;

         end if;
         
         if (XA_eof = '1') then
            XaCurrentFile    <= (others => '0');
            XaCurrentChannel <= (others => '0');
            XaCurrentSet     <= '0';         
         end if;
         
         if (ClearXACurrentSet = '1') then
            XaCurrentSet     <= '0';
         end if;
         
      end if;
   end process;
   
--##############################################################
--############################### Audio
--##############################################################
   
   XA_reset <= reset or softReset or startReading or startPlaying or cmdResetXa or seekOnDiskDrive;
   
   icd_xa : entity work.cd_xa
   port map
   (
      clk1x                => clk1x,    
      reset                => reset,

      spu_tick             => spu_tick,
      
      CDDA_write           => CDDA_write,
      CDDA_data            => CDDA_data, 
      
      XA_addr              => XA_addr,  
      XA_data              => XA_data,  
      XA_write             => XA_write, 
      XA_start             => XA_start,
      XA_reset             => XA_reset,
      
      XA_eof               => XA_eof,
      
      cdaudio_left         => cdaudio_left, 
      cdaudio_right        => cdaudio_right
   );
   
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then
         
         if (spu_tick = '1') then
            if ((driveState = DRIVE_PLAYING or (driveState = DRIVE_READING and modeReg(0) = '1') or (modeReg(6) = '1' and xa_muted = '0')) and muted = '0') then
               cd_volume_step <= 0;
            else
               cd_left  <= (others => '0');
               cd_right <= (others => '0');
            end if;
         end if;
      
         case (cd_volume_step) is
            when 0 =>
               soundmul1 <= cdaudio_left;
               soundmul2 <= unsigned(cdvol_00);
               
            when 1 =>
               soundmul1 <= cdaudio_right;
               soundmul2 <= unsigned(cdvol_10);

            when 2 =>
               soundmul1 <= cdaudio_left;
               soundmul2 <= unsigned(cdvol_01);
               
               soundsum <= resize(soundmulresult, 18);
               
            when 3 =>
               soundmul1 <= cdaudio_right;
               soundmul2 <= unsigned(cdvol_11); 
               
               soundsum <= soundsum + resize(soundmulresult, 18);
            
            when 4 =>
               if (soundsum < -32768) then cd_left <= x"8000";
               elsif (soundsum > 32767) then cd_left <= x"7FFF";
               else cd_left <= soundsum(15 downto 0);
               end if;
            
               soundsum <= resize(soundmulresult, 18);
            
            when 5 =>
               soundsum <= soundsum + resize(soundmulresult, 18);
               
            when 6 =>
               if (soundsum < -32768) then cd_right <= x"8000";
               elsif (soundsum > 32767) then cd_right <= x"7FFF";
               else cd_right <= soundsum(15 downto 0);
               end if;
            
            when others => null;
         end case;
         if (cd_volume_step < 7) then
            cd_volume_step <= cd_volume_step + 1;
         end if; 
         
         soundmulresult <= resize(shift_right(soundmul1 * signed('0' & soundmul2), 7), 17);  
      
      end if;
   end process;
   
--##############################################################
--############################### track infos
--##############################################################

   ss_out(15)(15 downto 8) <= std_logic_vector(trackNumberBCD);
   ss_out(25)(14 downto 8) <= trackNumber;
   
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         trackInfo_wrenA <= '0';
         
         if (reset = '1') then
         
            trackSearchState     <= TRACKSEARCH_IDLE;
         
            trackNumberBCD       <= unsigned(ss_in(15)(15 downto 8)); --  x"00";
            trackInfo_addrB      <= ss_in(25)(14 downto 8); -- x"00";
            trackNumber          <= ss_in(25)(14 downto 8); -- x"00";
            
            newCD                <= '0';
            newCDCounter         <= (others => '0');
            
         else  
         
            newCD <= '0';
            if (ce = '1') then
               if (newCDCounter > 0) then
                  newCDCounter <= newCDCounter - 1;
                  newCD        <= '1';
               end if;
            end if;
               
            case (trackSearchState) is
            
               when TRACKSEARCH_IDLE => 
                  if (sectorFetchState = SFETCH_IDLE and readOnDisk_buffer = '1' and ce = '1') then
                     trackSearchState <= TRACKSEARCH_READ;
                     trackInfo_addrB  <= std_logic_vector(to_unsigned(1, 7));
                     trackNumberBCD   <= x"01";
                  end if;
                  
               when TRACKSEARCH_READ =>
                  trackSearchState <= TRACKSEARCH_CHECK;
               
               when TRACKSEARCH_CHECK => 
                  if (lastReadSector >= startLBA and lastReadSector <= endLBA) then
                     trackSearchState <= TRACKSEARCH_IDLE;
                     trackNumber      <= trackInfo_addrB;
                  elsif (trackNumberBCD = x"99") then
                     trackSearchState <= TRACKSEARCH_IDLE;
                     trackNumberBCD   <= x"AA";
                     trackNumber      <= std_logic_vector(to_unsigned(0, 7));
                  else
                     trackSearchState <= TRACKSEARCH_READ;
                     trackInfo_addrB  <= std_logic_vector(unsigned(trackInfo_addrB) + 1);
                     if (trackNumberBCD(3 downto 0) = x"9") then
                        trackNumberBCD(3 downto 0) <= x"0";
                        trackNumberBCD(7 downto 4) <= trackNumberBCD(7 downto 4) + 1;
                     else
                        trackNumberBCD(3 downto 0) <= trackNumberBCD(3 downto 0) + 1;
                     end if;
                  end if;
            
            end case;
            
            if (trackinfo_write = '1') then
            
               newCDCounter <= (others => '1');
            
               -- header
               if (to_integer(unsigned(trackinfo_addr)) = 0) then
                  --trackcount    <= trackinfo_data(7 downto 0);
                  trackcountBCD <= trackinfo_data(15 downto 8);
               end if;
               
               --if (to_integer(unsigned(trackinfo_addr)) = 1) then
               --   totalLBAs <= to_integer(unsigned(trackinfo_data(18 downto 0)));
               --end if;
               
               if (to_integer(unsigned(trackinfo_addr)) = 2) then
                  totalSecondsBCD <= trackinfo_data(7 downto 0);
                  totalMinutesBCD <= trackinfo_data(15 downto 8);
               end if;               
               
               if (to_integer(unsigned(trackinfo_addr)) = 3) then
                  libcryptKey <= trackinfo_data(15 downto 0);
                  region_out  <= trackinfo_data(17 downto 16);
                  resetFromCD <= trackinfo_data(18) and (not LIDopen);
               end if;
            
               -- tracks
               if (trackinfo_addr(1 downto 0) = "00") then
                  trackInfo_DataA(18 downto 0)  <= trackinfo_data(18 downto 0); -- lbaStart
               end if;
               if (trackinfo_addr(1 downto 0) = "01") then
                  trackInfo_DataA(37 downto 19) <= trackinfo_data(18 downto 0); -- lbaEnd
               end if;
               if (trackinfo_addr(1 downto 0) = "10") then
                  trackInfo_DataA(45 downto 38) <= trackinfo_data( 7 downto 0); -- secondsBCD
                  trackInfo_DataA(53 downto 46) <= trackinfo_data(15 downto 8); -- minutesBCD
                  trackInfo_DataA(54)           <= trackinfo_data(16);          -- isAudio
                  if (to_integer(unsigned(trackinfo_addr)) = 6) then
                     isAudioCD <= trackinfo_data(16);
                  end if;
               end if;
               if (trackinfo_addr(1 downto 0) = "11") then
                  trackInfo_addrA <= trackinfo_addr(8 downto 2);
                  trackInfo_wrenA <= '1';
               end if;
               
            elsif (FifoParam_Empty = '0') then
               
               trackInfo_addrA <= std_logic_vector(to_unsigned(to_integer(unsigned(FifoParam_Dout(6 downto 4))) * 8 + 
                                                   to_integer(unsigned(FifoParam_Dout(6 downto 4))) * 2 + 
                                                   to_integer(unsigned(FifoParam_Dout(3 downto 0))), 7));
               
            --else trackInfo_addrA <= "0000100"; -- debug test!
            
            end if;
            
         end if;

      end if;
   end process;
   
   startLBA   <= to_integer(unsigned(trackInfo_DataOutB(18 downto 0)));
   endLBA     <= to_integer(unsigned(trackInfo_DataOutB(37 downto 19)));
   isAudio    <= trackInfo_DataOutB(54);    

   secondsBCD <= trackInfo_DataOutA(45 downto 38);
   minutesBCD <= trackInfo_DataOutA(53 downto 46);   
   
   iramTrackInfos: entity mem.dpram
   generic map 
   ( 
      addr_width => 7, 
      data_width => 55
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => trackInfo_addrA,
      data_a      => trackInfo_DataA,
      wren_a      => trackInfo_wrenA,
      q_a         => trackInfo_DataOutA,
      
      clock_b     => clk1x,
      address_b   => trackInfo_addrB,
      data_b      => (54 downto 0 => '0'),
      wren_b      => '0',
      q_b         => trackInfo_DataOutB
   );
   
--##############################################################
--############################### savestates
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (SS_reset = '1') then
         
            for i in 0 to 127 loop
               ss_in(i) <= (others => '0');
            end loop;
            
            ss_in(13) <= x"00002010"; -- pendingDriveIRQ & nextCmd & modeReg & internalStatus
            
            ss_in(21) <= x"00000018"; -- CDROM_IRQFLAG & CDROM_IRQENA & CDROM_STATUS;
            
            ss_in(23) <= x"80000080"; --  CD Volume;
            ss_in(24) <= x"80000080"; --  CD Volume;
            
            ss_in(25) <= x"001F0000"; --  lastreportCDDA & trackNumber & currentTrackBCD;
            
         elsif (SS_wren = '1' and SS_Adr < 128) then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         end if;
         
         if (cmd_busy = '1' or working = '1' or (driveBusy = '1' and driveDelay < 1024)) then
            ss_idle_timeout <= 7;
         elsif (ss_idle_timeout > 0) then
            ss_idle_timeout <= ss_idle_timeout - 1;
         end if;
         
         SS_idle <= '0';
         if ((FifoParam_Empty = '1' or ss_timeout(23) = '1') and (FifoResponse_Empty = '1' or ss_timeout(23) = '1') and cmd_busy = '0' and working = '0' and ss_idle_timeout = 0 and
           sectorFetchState = SFETCH_IDLE and readOnDisk = '0' and readOnDisk_buffer = '0' and readSubchannelState = SSUB_IDLE and sectorProcessState = SPROC_IDLE and copyState = COPY_IDLE) then
            SS_idle    <= '1';
            if (FifoParam_Empty = '1' and FifoResponse_Empty = '1') then
               ss_timeout <= (others => '0');
            end if;
         end if;
         
         Pause_idle_cd <= '1';
         
         if (ss_timeout(23) = '0') then
            ss_timeout <= ss_timeout + 1;
         end if;
         
         SS_rden_sectorbuffer <= '0';
         if (SS_rden = '1' and SS_Adr >= 1024 and SS_Adr < 1024 + (RAW_SECTOR_SIZE / 4)) then
            SS_rden_sectorbuffer <= '1';
         end if;
         
         SS_rden_sectorbuffers <= '0';
         if (SS_rden = '1' and SS_Adr >= 2048 and SS_Adr < 2048 + (1024 * 8)) then
            SS_rden_sectorbuffers <= '1';
         end if;
         
         if (SS_rden_sectorbuffer = '1') then
            SS_DataRead <= sectorBuffer_DataB;
         elsif (SS_rden_sectorbuffers = '1') then
            SS_DataRead <= sectorBuffers_DataB;
         elsif (SS_rden = '1' and SS_Adr < 128) then
            SS_DataRead <= ss_out(to_integer(SS_Adr));
         end if;
      
      end if;
   end process;

   -- synthesis translate_off

   goutput : if 1 = 1 generate
   signal outputCnt  : unsigned(31 downto 0) := (others => '0'); 
   signal clkCounter : unsigned(31 downto 0);
   
   begin
      process
         constant WRITETIME               : std_logic := '1';
            
         file outfile                     : text;
         variable f_status                : FILE_OPEN_STATUS;
         variable line_out                : line;
               
         variable bus_read_1              : std_logic;
         variable bus_addr_1              : unsigned(3 downto 0);
         variable cmdAck_1                : std_logic;
         variable driveAck_1              : std_logic;
         variable ackDrive_1              : std_logic;
         variable ackRead_valid_1         : std_logic;
         variable ackDriveEnd_1           : std_logic;
         variable ackPendingIRQNext_1     : std_logic;
         variable errorResponseNext_new_1 : std_logic;
         variable readOnDisk_1            : std_logic;
         variable readOnDisk_2            : std_logic;
         variable readOnDisk_3            : std_logic;
         variable fifoResponseSize        : unsigned(31 downto 0);
         variable newoutputCnt            : unsigned(31 downto 0); 
         variable fifoDataWrCnt           : unsigned(7 downto 0);
         variable datatemp                : unsigned(31 downto 0);
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
            
            if (beginCommand = '1') then
               write(line_out, string'("CMD: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter - 1));
                  write(line_out, string'(" ")); 
               end if;
               write(line_out, to_hstring(newCmd));
               write(line_out, string'(" 00000000")); 
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            
            if (cmdAck_1 = '1') then
               write(line_out, string'("RSPFIFO: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter - 3));
                  write(line_out, string'(" ")); 
               end if;
               write(line_out, to_hstring(FifoResponse_Din));
               write(line_out, string'(" "));
               write(line_out, to_hstring(fifoResponseSize));               
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            cmdAck_1 := cmdAck or cmdIRQ;            
            
            if (driveAck_1 = '1' or ackDrive_1 = '1' or ackRead_valid_1 = '1' or ackDriveEnd_1 = '1' or ackPendingIRQNext_1 = '1') then
               write(line_out, string'("RSPFIFO2: "));
               if (WRITETIME = '1') then
                  if (driveAck_1 = '1') then write(line_out, to_hstring(clkCounter - 2));
                  elsif (ackDrive_1 = '1') then write(line_out, to_hstring(clkCounter - 3));
                  elsif (ackRead_valid_1 = '1') then write(line_out, to_hstring(clkCounter - 6));
                  elsif (ackDriveEnd_1 = '1') then write(line_out, to_hstring(clkCounter - 5));
                  elsif (ackPendingIRQNext_1 = '1') then write(line_out, to_hstring(clkCounter - 5));
                  end if;
                  write(line_out, string'(" ")); 
               end if;
               write(line_out, to_hstring(FifoResponse_Din));
               write(line_out, string'(" "));
               write(line_out, to_hstring(fifoResponseSize));               
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            driveAck_1 := driveAck;
            ackDrive_1 := ackDrive;
            ackRead_valid_1 := ackRead_valid;
            ackDriveEnd_1 := ackDriveEnd;
            ackPendingIRQNext_1 := ackPendingIRQNext;
            
            if (getIDAck = '1') then
               write(line_out, string'("RSPFIFO2: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter - 3));
                  write(line_out, string'(" ")); 
               end if;
               write(line_out, to_hstring(FifoResponse_Dout));
               write(line_out, string'(" "));
               write(line_out, to_hstring(fifoResponseSize));               
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if;
            
            if (errorResponseCmd_new = '1') then
               write(line_out, string'("RSPERROR: ")); 
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter));
                  write(line_out, string'(" ")); 
               end if;
               write(line_out, string'("00 00")); 
               write(line_out, to_hstring(errorResponseCmd_reason));
               write(line_out, to_hstring(errorResponseCmd_error));
               write(line_out, to_hstring(internalStatus));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if;      

            if (errorResponseNext_new_1 = '1') then
               write(line_out, string'("RSPFIFO2: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter - 4));
                  write(line_out, string'(" ")); 
               end if;
               write(line_out, to_hstring(internalStatus or errorResponseCmd_error));
                write(line_out, string'(" ")); 
               write(line_out, to_hstring(fifoResponseSize));               
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if;
            errorResponseNext_new_1 := errorResponseNext_new; 
            
            if (errorResponseDrive_new = '1') then
               write(line_out, string'("RSPERROR: ")); 
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter));
                  write(line_out, string'(" ")); 
               end if;
               write(line_out, string'("00 00")); 
               write(line_out, to_hstring(errorResponseDrive_reason));
               write(line_out, to_hstring(errorResponseDrive_error));
               write(line_out, to_hstring(internalStatus));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            
            if (processDataSector = '1' and (modeReg(6) = '0' or headerIsData = '1') and (modeReg(5) = '1' or headerDataSector = '1')) then
                write(line_out, string'("WPTR: "));
                if (WRITETIME = '1') then
                   write(line_out, to_hstring(clkCounter - 4));
                   write(line_out, string'(" ")); 
                end if;
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
            
            if (copyState = COPY_FIRST) then
               for i in 0 to (copySize - 1) loop
                  write(line_out, string'("DATA: "));
                  datatemp := to_unsigned(i * 4, 32);
                  write(line_out, to_hstring(datatemp(7 downto 0)));
                  write(line_out, string'(" "));
                  datatemp := unsigned(sectorBuffers(to_integer(copySectorPointer))(i));
                  write(line_out, to_hstring(datatemp)); 
                  writeline(outfile, line_out);
                  newoutputCnt := newoutputCnt + 1;
               end loop;
            end if;
            
            if (readOnDisk_3 = '1') then
               write(line_out, string'("SECTORREAD: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter - 7));
                  write(line_out, string'(" ")); 
               end if;
               write(line_out, string'("00 "));
               write(line_out, to_hstring(to_unsigned(lastReadSector, 32)));               
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if;
            readOnDisk_3 := readOnDisk_2;
            readOnDisk_2 := readOnDisk_1;
            readOnDisk_1 := readOnDisk;

            --if (copyState = COPY_DATA and copyByteCnt = 0) then
            --   write(line_out, string'("DATA: "));
            --   write(line_out, to_hstring(fifoDataWrCnt));
            --   write(line_out, string'(" "));
            --   write(line_out, to_hstring(sectorBuffers_DataB));               
            --   writeline(outfile, line_out);
            --   newoutputCnt := newoutputCnt + 1;
            --   fifoDataWrCnt := fifoDataWrCnt + 4;
            --elsif (copyState = COPY_IDLE) then
            --   fifoDataWrCnt := (others => '0');
            --end if;
            
            --if (dma_read = '1') then
            --   write(line_out, string'("DMAREAD: 00 000000"));
            --   write(line_out, to_hstring(dma_readdata));               
            --   writeline(outfile, line_out);
            --   newoutputCnt := newoutputCnt + 1;
            --end if; 
            
            if (bus_write = '1') then
               write(line_out, string'("CPUWRITE: ")); 
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter));
                  write(line_out, string'(" ")); 
               end if;
               write(line_out, string'("0")); 
               write(line_out, to_hstring(bus_addr));
               write(line_out, string'(" 000000")); 
               write(line_out, to_hstring(bus_dataWrite));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            
            if (bus_read_1 = '1') then
               write(line_out, string'("CPUREAD: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter - 1));
                  write(line_out, string'(" ")); 
               end if;
               write(line_out, string'("0")); 
               write(line_out, to_hstring(bus_addr_1));
               write(line_out, string'(" 000000")); 
               write(line_out, to_hstring(bus_dataRead));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            bus_read_1 := bus_read;
            bus_addr_1 := bus_addr;
            
            outputCnt <= newoutputCnt;
            clkCounter <= clkCounter + 1;
            
            if (reset = '1') then
               clkCounter <= x"00000000";
               file_close(outfile);
               file_open(f_status, outfile, "R:\\debug_cd_sim.txt", write_mode);
               file_close(outfile);
               file_open(f_status, outfile, "R:\\debug_cd_sim.txt", append_mode);
            end if;
           
         end loop;
         
      end process;
   
   end generate goutput;
   
   goutputcdda : if 1 = 1 generate
      signal outputCnt  : unsigned(23 downto 0) := (others => '0'); 
   begin
      process
         file outfile                  : text;
         variable f_status             : FILE_OPEN_STATUS;
         variable line_out             : line;
      begin
   
         file_open(f_status, outfile, "R:\\debug_cdda_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\debug_cdda_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk1x);
            
            if (CDDA_write = '1') then
               write(line_out, to_hstring(outputCnt));
               write(line_out, string'(" ")); 
               write(line_out, to_hstring(CDDA_data));
               writeline(outfile, line_out);
               outputCnt <= outputCnt + 1;
            end if; 
           
         end loop;
         
      end process;
   
   end generate goutputcdda;
   
   -- synthesis translate_on

end architecture;





